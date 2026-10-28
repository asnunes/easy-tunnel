use crate::connections::domain::ports::HostSource;
use std::{
    collections::BTreeSet,
    fs,
    path::{Path, PathBuf},
};

pub struct SshConfig {
    home: PathBuf,
}

impl SshConfig {
    pub fn new(home: PathBuf) -> Self {
        Self { home }
    }

    fn read(
        &self,
        path: &Path,
        visited: &mut BTreeSet<PathBuf>,
        hosts: &mut BTreeSet<String>,
    ) -> Result<(), String> {
        let canonical = match path.canonicalize() {
            Ok(path) => path,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(()),
            Err(error) => return Err(format!("Could not read SSH config: {error}")),
        };
        if !visited.insert(canonical.clone()) {
            return Ok(());
        }
        let text = fs::read_to_string(&canonical)
            .map_err(|e| format!("Could not read {}: {e}", path.display()))?;
        for line in text.lines() {
            let line = line.trim();
            if line.is_empty() || line.starts_with('#') {
                continue;
            }
            let split = line.find(|c: char| c.is_whitespace() || c == '=');
            let Some(split) = split else {
                continue;
            };
            let key = &line[..split];
            if !key.eq_ignore_ascii_case("host") && !key.eq_ignore_ascii_case("include") {
                continue;
            }
            let values = line[split..]
                .trim_start()
                .trim_start_matches('=')
                .trim_start();
            let values = shlex::split(values)
                .ok_or_else(|| format!("Invalid quoting in {}", path.display()))?;
            if key.eq_ignore_ascii_case("host") {
                hosts.extend(
                    values
                        .into_iter()
                        .filter(|host| !host.contains(['*', '?', '!'])),
                );
                continue;
            }
            for value in values {
                let pattern = if let Some(relative) = value.strip_prefix("~/") {
                    self.home.join(relative)
                } else if Path::new(&value).is_absolute() {
                    PathBuf::from(value)
                } else {
                    self.home.join(".ssh").join(value)
                };
                for included in glob::glob(&pattern.to_string_lossy()).map_err(|e| e.to_string())? {
                    self.read(&included.map_err(|e| e.to_string())?, visited, hosts)?;
                }
            }
        }
        Ok(())
    }
}

impl HostSource for SshConfig {
    fn list(&self) -> Result<Vec<String>, String> {
        let mut hosts = BTreeSet::new();
        self.read(
            &self.home.join(".ssh/config"),
            &mut BTreeSet::new(),
            &mut hosts,
        )?;
        Ok(hosts.into_iter().collect())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn discovers_aliases_in_includes_and_ignores_patterns() {
        let home = tempfile::tempdir().unwrap();
        fs::create_dir_all(home.path().join(".ssh/hosts")).unwrap();
        fs::write(
            home.path().join(".ssh/config"),
            "Host lab lab-alias *.work !excluded\nInclude hosts/*\nHost=nas # comment\n",
        )
        .unwrap();
        fs::write(
            home.path().join(".ssh/hosts/dev"),
            "Host dev\nInclude config\n",
        )
        .unwrap();
        assert_eq!(
            SshConfig::new(home.path().into()).list().unwrap(),
            vec!["dev", "lab", "lab-alias", "nas"]
        );
    }
}

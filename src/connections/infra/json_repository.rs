use super::stored_connection::StoredConnection;
use crate::connections::domain::{Connection, ports::ConnectionRepository};
use std::{fs, path::PathBuf};

pub struct JsonRepository {
    path: PathBuf,
}

impl JsonRepository {
    pub fn new(path: PathBuf) -> Self {
        Self { path }
    }
}

impl ConnectionRepository for JsonRepository {
    fn load(&self) -> Result<Vec<Connection>, String> {
        let data = match fs::read(&self.path) {
            Ok(data) => data,
            Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(vec![]),
            Err(error) => return Err(format!("Could not read saved connections: {error}")),
        };
        let connections: Vec<StoredConnection> = serde_json::from_slice(&data)
            .map_err(|error| format!("Could not parse {}: {error}", self.path.display()))?;
        connections
            .into_iter()
            .map(StoredConnection::into_connection)
            .collect()
    }

    fn save(&self, connections: &[Connection]) -> Result<(), String> {
        let parent = self.path.parent().ok_or("Invalid settings path")?;
        fs::create_dir_all(parent).map_err(|e| e.to_string())?;
        let data = serde_json::to_vec_pretty(
            &connections
                .iter()
                .map(StoredConnection::from)
                .collect::<Vec<_>>(),
        )
        .map_err(|e| e.to_string())?;
        fs::write(&self.path, data).map_err(|e| format!("Could not save connections: {e}"))
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn rejects_invalid_stored_values_without_changing_the_file() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("connections.json");
        let data = r#"[{"id":"lab","name":"Lab","sshHostAlias":"lab","forwards":[{"localPort":0,"destinationHost":"localhost","destinationPort":5432}]}]"#;
        fs::write(&path, data).unwrap();
        let repository = JsonRepository::new(path.clone());
        assert!(repository.load().is_err());
        assert_eq!(fs::read_to_string(path).unwrap(), data);
    }

    #[test]
    fn saves_and_reports_corrupted_data_without_overwriting() {
        let directory = tempfile::tempdir().unwrap();
        let path = directory.path().join("connections.json");
        let repository = JsonRepository::new(path.clone());
        assert!(repository.load().unwrap().is_empty());
        repository.save(&[]).unwrap();
        assert!(repository.load().unwrap().is_empty());
        fs::write(path, "broken").unwrap();
        assert!(repository.load().is_err());
    }
}

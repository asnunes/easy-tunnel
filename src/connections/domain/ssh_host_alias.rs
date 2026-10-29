#[derive(Clone, Debug, PartialEq, Eq)]
pub struct SshHostAlias(String);

impl SshHostAlias {
    pub fn parse(value: &str) -> Result<Self, String> {
        if value.is_empty()
            || value.starts_with('-')
            || !value
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '-' | '_' | ':'))
        {
            return Err("Select a valid SSH host alias.".into());
        }
        Ok(Self(value.into()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

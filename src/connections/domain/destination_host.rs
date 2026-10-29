#[derive(Clone, Debug, PartialEq, Eq)]
pub struct DestinationHost(String);

impl DestinationHost {
    pub fn parse(value: &str) -> Result<Self, String> {
        if value.is_empty()
            || !value
                .chars()
                .all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '-' | '_' | ':'))
        {
            return Err("Enter a destination hostname or IP address.".into());
        }
        Ok(Self(value.into()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

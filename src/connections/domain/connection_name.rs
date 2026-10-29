#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ConnectionName(String);

impl ConnectionName {
    pub fn parse(value: &str) -> Result<Self, String> {
        let value = value.trim();
        if value.is_empty() {
            return Err("Give this connection a name.".into());
        }
        Ok(Self(value.into()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

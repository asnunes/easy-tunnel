#[derive(Clone, Debug, PartialEq, Eq)]
pub struct ConnectionId(String);

impl ConnectionId {
    pub fn parse(value: &str) -> Result<Self, String> {
        if value.is_empty() {
            return Err("Give this connection an ID.".into());
        }
        Ok(Self(value.into()))
    }

    pub fn as_str(&self) -> &str {
        &self.0
    }
}

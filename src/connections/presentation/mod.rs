use crate::connections::domain::{Connection, PortForward};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConnectionInput {
    pub id: Option<String>,
    pub name: String,
    pub ssh_host_alias: String,
    pub forwards: Vec<PortForward>,
}

impl ConnectionInput {
    pub fn into_connection(self) -> Result<Connection, String> {
        let connection = Connection {
            id: self.id.unwrap_or_else(|| uuid::Uuid::new_v4().to_string()),
            name: self.name.trim().into(),
            ssh_host_alias: self.ssh_host_alias,
            forwards: self.forwards,
        };
        connection.validate()?;
        Ok(connection)
    }
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ConnectionsView {
    pub connections: Vec<Connection>,
    pub hosts: Vec<String>,
    pub host_error: Option<String>,
}

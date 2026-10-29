use crate::connections::domain::{
    Connection, ConnectionId, ConnectionName, DestinationHost, Port, PortForward, SshHostAlias,
};
use serde::{Deserialize, Serialize};

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub(super) struct StoredConnection {
    id: String,
    name: String,
    ssh_host_alias: String,
    forwards: Vec<StoredForward>,
}

impl StoredConnection {
    pub fn into_connection(self) -> Result<Connection, String> {
        Connection::new(
            ConnectionId::parse(&self.id)?,
            ConnectionName::parse(&self.name)?,
            SshHostAlias::parse(&self.ssh_host_alias)?,
            self.forwards
                .into_iter()
                .map(|forward| {
                    Ok(PortForward::new(
                        Port::new(forward.local_port)?,
                        DestinationHost::parse(&forward.destination_host)?,
                        Port::new(forward.destination_port)?,
                    ))
                })
                .collect::<Result<_, String>>()?,
        )
    }
}

impl From<&Connection> for StoredConnection {
    fn from(connection: &Connection) -> Self {
        Self {
            id: connection.id().into(),
            name: connection.name().into(),
            ssh_host_alias: connection.ssh_host_alias().as_str().into(),
            forwards: connection
                .forwards()
                .iter()
                .map(|forward| StoredForward {
                    local_port: forward.local_port().get(),
                    destination_host: forward.destination_host().as_str().into(),
                    destination_port: forward.destination_port().get(),
                })
                .collect(),
        }
    }
}

#[derive(Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct StoredForward {
    local_port: u16,
    destination_host: String,
    destination_port: u16,
}

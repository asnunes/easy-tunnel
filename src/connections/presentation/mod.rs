use crate::connections::domain::{
    Connection, ConnectionId, ConnectionName, DestinationHost, Port, PortForward, SshHostAlias,
};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct ConnectionInput {
    pub id: Option<String>,
    pub name: String,
    pub ssh_host_alias: String,
    pub forwards: Vec<PortForwardDto>,
}

impl ConnectionInput {
    pub fn into_connection(self) -> Result<Connection, String> {
        Connection::new(
            ConnectionId::parse(&self.id.unwrap_or_else(|| uuid::Uuid::new_v4().to_string()))?,
            ConnectionName::parse(&self.name)?,
            SshHostAlias::parse(&self.ssh_host_alias)?,
            self.forwards
                .into_iter()
                .map(PortForwardDto::into_forward)
                .collect::<Result<_, _>>()?,
        )
    }
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ConnectionView {
    pub id: String,
    pub name: String,
    pub ssh_host_alias: String,
    pub forwards: Vec<PortForwardDto>,
}

impl From<&Connection> for ConnectionView {
    fn from(connection: &Connection) -> Self {
        Self {
            id: connection.id().into(),
            name: connection.name().into(),
            ssh_host_alias: connection.ssh_host_alias().as_str().into(),
            forwards: connection
                .forwards()
                .iter()
                .map(PortForwardDto::from)
                .collect(),
        }
    }
}

#[derive(Clone, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct PortForwardDto {
    pub local_port: u16,
    pub destination_host: String,
    pub destination_port: u16,
}

impl PortForwardDto {
    fn into_forward(self) -> Result<PortForward, String> {
        Ok(PortForward::new(
            Port::new(self.local_port)?,
            DestinationHost::parse(&self.destination_host)?,
            Port::new(self.destination_port)?,
        ))
    }
}

impl From<&PortForward> for PortForwardDto {
    fn from(forward: &PortForward) -> Self {
        Self {
            local_port: forward.local_port().get(),
            destination_host: forward.destination_host().as_str().into(),
            destination_port: forward.destination_port().get(),
        }
    }
}

#[derive(Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct ConnectionsView {
    pub connections: Vec<ConnectionView>,
    pub hosts: Vec<String>,
    pub host_error: Option<String>,
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn maps_transport_dtos_to_valid_domain_values_and_back() {
        let value = json!({"id":"lab","name":"Lab","sshHostAlias":"lab","forwards":[{"localPort":5433,"destinationHost":"localhost","destinationPort":5432}]});
        let input: ConnectionInput = serde_json::from_value(value.clone()).unwrap();
        let connection = input.into_connection().unwrap();
        assert_eq!(
            serde_json::to_value(ConnectionView::from(&connection)).unwrap(),
            value
        );
    }

    #[test]
    fn rejects_invalid_input_before_it_reaches_the_use_case() {
        for port in [0, 65536] {
            let value = json!({"name":"Lab","sshHostAlias":"lab","forwards":[{"localPort":port,"destinationHost":"localhost","destinationPort":5432}]});
            let result = serde_json::from_value::<ConnectionInput>(value)
                .map_err(|e| e.to_string())
                .and_then(ConnectionInput::into_connection);
            assert!(result.is_err());
        }
    }
}

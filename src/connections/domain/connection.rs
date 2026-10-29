use super::{ConnectionId, ConnectionName, PortForward, SshHostAlias};
use std::collections::HashSet;

#[derive(Clone, Debug, PartialEq)]
pub struct Connection {
    id: ConnectionId,
    name: ConnectionName,
    ssh_host_alias: SshHostAlias,
    forwards: Vec<PortForward>,
}

impl Connection {
    pub fn new(
        id: ConnectionId,
        name: ConnectionName,
        ssh_host_alias: SshHostAlias,
        forwards: Vec<PortForward>,
    ) -> Result<Self, String> {
        if forwards.is_empty() {
            return Err("Add at least one port.".into());
        }
        let mut ports = HashSet::new();
        for forward in &forwards {
            if !ports.insert(forward.local_port()) {
                return Err(format!(
                    "Local port {} is used twice.",
                    forward.local_port().get()
                ));
            }
        }
        Ok(Self {
            id,
            name,
            ssh_host_alias,
            forwards,
        })
    }

    pub fn id(&self) -> &str {
        self.id.as_str()
    }
    pub fn name(&self) -> &str {
        self.name.as_str()
    }
    pub fn ssh_host_alias(&self) -> &SshHostAlias {
        &self.ssh_host_alias
    }
    pub fn forwards(&self) -> &[PortForward] {
        &self.forwards
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::connections::domain::{DestinationHost, Port};

    #[test]
    fn rejects_empty_and_duplicate_forward_collections() {
        let build = |forwards| {
            Connection::new(
                ConnectionId::parse("lab").unwrap(),
                ConnectionName::parse("Lab").unwrap(),
                SshHostAlias::parse("lab").unwrap(),
                forwards,
            )
        };
        let forward = PortForward::new(
            Port::new(5433).unwrap(),
            DestinationHost::parse("localhost").unwrap(),
            Port::new(5432).unwrap(),
        );
        assert!(build(vec![]).is_err());
        assert!(build(vec![forward.clone(), forward.clone()]).is_err());
        assert!(build(vec![forward]).is_ok());
    }

    #[test]
    fn invalid_values_cannot_be_constructed() {
        assert!(ConnectionId::parse("").is_err());
        assert!(ConnectionName::parse("  ").is_err());
        assert_eq!(ConnectionName::parse(" Lab ").unwrap().as_str(), "Lab");
        for host in ["", "host with spaces", "$(command)"] {
            assert!(SshHostAlias::parse(host).is_err());
            assert!(DestinationHost::parse(host).is_err());
        }
        assert!(SshHostAlias::parse("-option").is_err());
        assert!(DestinationHost::parse("::1").is_ok());
    }
}

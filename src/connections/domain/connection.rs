use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct Connection {
    pub id: String,
    pub name: String,
    pub ssh_host_alias: String,
    pub forwards: Vec<PortForward>,
}

impl Connection {
    pub fn validate(&self) -> Result<(), String> {
        if self.id.is_empty() || self.name.trim().is_empty() {
            return Err("Give this connection a name.".into());
        }
        if !valid_host(&self.ssh_host_alias) || self.ssh_host_alias.starts_with('-') {
            return Err("Select a valid SSH host alias.".into());
        }
        if self.forwards.is_empty() {
            return Err("Add at least one port.".into());
        }
        let mut ports = std::collections::HashSet::new();
        for forward in &self.forwards {
            forward.validate()?;
            if !ports.insert(forward.local_port) {
                return Err(format!("Local port {} is used twice.", forward.local_port));
            }
        }
        Ok(())
    }
}

#[derive(Clone, Debug, Serialize, Deserialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct PortForward {
    pub local_port: u16,
    pub destination_host: String,
    pub destination_port: u16,
}

impl PortForward {
    pub fn validate(&self) -> Result<(), String> {
        if self.local_port == 0 || self.destination_port == 0 {
            return Err("Ports must be between 1 and 65535.".into());
        }
        if !valid_host(&self.destination_host) {
            return Err("Enter a destination hostname or IP address.".into());
        }
        Ok(())
    }

    pub fn ssh_argument(&self) -> String {
        let host = if self.destination_host.contains(':') {
            format!("[{}]", self.destination_host)
        } else {
            self.destination_host.clone()
        };
        format!(
            "127.0.0.1:{}:{}:{}",
            self.local_port, host, self.destination_port
        )
    }
}

fn valid_host(host: &str) -> bool {
    !host.is_empty()
        && host
            .chars()
            .all(|c| c.is_ascii_alphanumeric() || matches!(c, '.' | '-' | '_' | ':'))
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn rejects_duplicate_ports_and_invalid_hosts() {
        let forward = PortForward {
            local_port: 5433,
            destination_host: "localhost".into(),
            destination_port: 5432,
        };
        let mut connection = Connection {
            id: "test".into(),
            name: "Test".into(),
            ssh_host_alias: "lab".into(),
            forwards: vec![forward.clone(), forward],
        };
        assert!(connection.validate().is_err());
        connection.forwards.pop();
        assert!(connection.validate().is_ok());
        connection.ssh_host_alias = "-oProxyCommand=bad".into();
        assert!(connection.validate().is_err());
    }

    #[test]
    fn formats_ipv6_destination_and_rejects_zero() {
        let mut forward = PortForward {
            local_port: 8080,
            destination_host: "::1".into(),
            destination_port: 80,
        };
        assert_eq!(forward.ssh_argument(), "127.0.0.1:8080:[::1]:80");
        forward.local_port = 0;
        assert!(forward.validate().is_err());
    }
}

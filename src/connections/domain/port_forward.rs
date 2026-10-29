use super::{DestinationHost, Port};

#[derive(Clone, Debug, PartialEq)]
pub struct PortForward {
    local_port: Port,
    destination_host: DestinationHost,
    destination_port: Port,
}

impl PortForward {
    pub fn new(
        local_port: Port,
        destination_host: DestinationHost,
        destination_port: Port,
    ) -> Self {
        Self {
            local_port,
            destination_host,
            destination_port,
        }
    }

    pub fn local_port(&self) -> Port {
        self.local_port
    }
    pub fn destination_host(&self) -> &DestinationHost {
        &self.destination_host
    }
    pub fn destination_port(&self) -> Port {
        self.destination_port
    }
}

use crate::connections::domain::Connection;

#[derive(Clone, Debug, PartialEq)]
pub enum TunnelStatus {
    Connecting,
    Connected,
    Disconnected,
    Failed,
}

#[derive(Clone, Debug, PartialEq)]
pub struct Tunnel {
    pub connection_id: String,
    pub status: TunnelStatus,
    pub process_id: Option<u32>,
    pub error: Option<String>,
}

pub trait TunnelProcess: Send {
    fn snapshot(&mut self) -> Result<Tunnel, String>;
    fn stop(&mut self) -> Result<(), String>;
}

pub trait TunnelLauncher: Send {
    fn launch(&self, connection: &Connection) -> Result<Box<dyn TunnelProcess>, String>;
}

pub trait TunnelEvents: Send {
    fn changed(&self, tunnels: &[Tunnel]);
}

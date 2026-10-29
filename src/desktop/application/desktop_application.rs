use crate::{
    connections::{
        application::use_case::{
            list_connections::{ConnectionListing, ListConnections},
            remove_connection::RemoveConnection,
            save_connection::SaveConnection,
        },
        domain::{
            Connection, ConnectionId,
            ports::{ConnectionRepository, HostSource},
        },
    },
    tunnels::{
        application::{
            Tunnels,
            use_case::{connect::Connect, disconnect::Disconnect, monitor_tunnels::MonitorTunnels},
        },
        domain::Tunnel,
    },
};

pub struct DesktopApplication {
    repository: Box<dyn ConnectionRepository>,
    hosts: Box<dyn HostSource>,
    tunnels: Tunnels,
    monitor: MonitorTunnels,
}

impl DesktopApplication {
    pub fn new(
        repository: Box<dyn ConnectionRepository>,
        hosts: Box<dyn HostSource>,
        tunnels: Tunnels,
        monitor: MonitorTunnels,
    ) -> Self {
        Self {
            repository,
            hosts,
            tunnels,
            monitor,
        }
    }

    pub fn execute(&mut self, command: Command) -> Result<Outcome, String> {
        match command {
            Command::Snapshot => {
                let connections = ListConnections {
                    repository: self.repository.as_ref(),
                    hosts: self.hosts.as_ref(),
                }
                .execute()?;
                Ok(Outcome::Snapshot(ApplicationSnapshot {
                    connections,
                    tunnels: self.tunnels.snapshots(),
                }))
            }
            Command::Save(connection) => {
                SaveConnection {
                    repository: self.repository.as_ref(),
                    activity: &self.tunnels,
                }
                .execute(connection)?;
                Ok(Outcome::Complete)
            }
            Command::Remove(id) => {
                RemoveConnection {
                    repository: self.repository.as_ref(),
                    activity: &self.tunnels,
                }
                .execute(id.as_str())?;
                Ok(Outcome::Complete)
            }
            Command::Connect(id) => {
                Connect {
                    repository: self.repository.as_ref(),
                    tunnels: &mut self.tunnels,
                }
                .execute(id.as_str())?;
                Ok(Outcome::Complete)
            }
            Command::Disconnect(id) => {
                Disconnect {
                    tunnels: &mut self.tunnels,
                }
                .execute(id.as_str())?;
                Ok(Outcome::Complete)
            }
        }
    }

    pub fn poll(&mut self) {
        self.monitor.execute(&mut self.tunnels);
    }
}

pub enum Command {
    Snapshot,
    Save(Connection),
    Remove(ConnectionId),
    Connect(ConnectionId),
    Disconnect(ConnectionId),
}

pub enum Outcome {
    Snapshot(ApplicationSnapshot),
    Complete,
}

pub struct ApplicationSnapshot {
    pub connections: ConnectionListing,
    pub tunnels: Vec<Tunnel>,
}

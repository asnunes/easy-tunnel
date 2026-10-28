use crate::connections::domain::{
    Connection,
    ports::{ConnectionRepository, HostSource},
};

pub struct ListConnections<'a> {
    pub repository: &'a dyn ConnectionRepository,
    pub hosts: &'a dyn HostSource,
}

impl ListConnections<'_> {
    pub fn execute(&self) -> Result<ConnectionListing, String> {
        let (hosts, host_error) = match self.hosts.list() {
            Ok(hosts) => (hosts, None),
            Err(error) => (vec![], Some(error)),
        };
        Ok(ConnectionListing {
            connections: self.repository.load()?,
            hosts,
            host_error,
        })
    }
}

pub struct ConnectionListing {
    pub connections: Vec<Connection>,
    pub hosts: Vec<String>,
    pub host_error: Option<String>,
}

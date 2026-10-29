use crate::{
    connections::presentation::ConnectionsView,
    desktop::application::desktop_application::ApplicationSnapshot,
    tunnels::presentation::TunnelView,
};
use serde::Serialize;

#[derive(Serialize)]
pub struct Snapshot {
    #[serde(flatten)]
    pub saved: ConnectionsView,
    pub tunnels: Vec<TunnelView>,
}

impl From<ApplicationSnapshot> for Snapshot {
    fn from(snapshot: ApplicationSnapshot) -> Self {
        Self {
            saved: ConnectionsView {
                connections: snapshot
                    .connections
                    .connections
                    .iter()
                    .map(Into::into)
                    .collect(),
                hosts: snapshot.connections.hosts,
                host_error: snapshot.connections.host_error,
            },
            tunnels: snapshot.tunnels.into_iter().map(Into::into).collect(),
        }
    }
}

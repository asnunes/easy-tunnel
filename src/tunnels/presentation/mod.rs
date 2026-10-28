use crate::tunnels::domain::{Tunnel, TunnelStatus};
use serde::Serialize;

#[derive(Clone, Serialize, PartialEq)]
#[serde(rename_all = "camelCase")]
pub struct TunnelView {
    pub connection_id: String,
    pub status: &'static str,
    pub process_id: Option<u32>,
    pub error: Option<String>,
}

impl From<Tunnel> for TunnelView {
    fn from(tunnel: Tunnel) -> Self {
        Self {
            connection_id: tunnel.connection_id,
            status: match tunnel.status {
                TunnelStatus::Connecting => "connecting",
                TunnelStatus::Connected => "connected",
                TunnelStatus::Disconnected => "disconnected",
                TunnelStatus::Failed => "failed",
            },
            process_id: tunnel.process_id,
            error: tunnel.error,
        }
    }
}

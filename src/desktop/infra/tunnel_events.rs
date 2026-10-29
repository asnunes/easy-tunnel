use crate::tunnels::{
    domain::{Tunnel, TunnelEvents},
    presentation::TunnelView,
};
use tauri::Emitter;

pub struct TauriTunnelEvents {
    app: tauri::AppHandle,
}

impl TauriTunnelEvents {
    pub fn new(app: tauri::AppHandle) -> Self {
        Self { app }
    }
}

impl TunnelEvents for TauriTunnelEvents {
    fn changed(&self, tunnels: &[Tunnel]) {
        let views: Vec<TunnelView> = tunnels.iter().cloned().map(Into::into).collect();
        let _ = self.app.emit("tunnels-changed", views);
    }
}

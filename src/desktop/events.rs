use crate::tunnels::presentation::TunnelView;
use tauri::Emitter;

pub fn tunnels_changed(app: &tauri::AppHandle, tunnels: &[TunnelView]) {
    let _ = app.emit("tunnels-changed", tunnels);
}

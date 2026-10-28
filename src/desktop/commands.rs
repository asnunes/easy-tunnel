use super::wiring::{Action, Desktop, Snapshot};
use crate::connections::presentation::ConnectionInput;
use tauri::{LogicalSize, State, WebviewWindow};

#[tauri::command]
pub async fn snapshot(state: State<'_, Desktop>) -> Result<Snapshot, String> {
    state
        .request(Action::Snapshot)
        .await?
        .ok_or("No snapshot returned.".into())
}

#[tauri::command]
pub async fn save_connection(
    state: State<'_, Desktop>,
    connection: ConnectionInput,
) -> Result<(), String> {
    state.request(Action::Save(connection)).await.map(|_| ())
}

#[tauri::command]
pub async fn remove_connection(state: State<'_, Desktop>, id: String) -> Result<(), String> {
    state.request(Action::Remove(id)).await.map(|_| ())
}

#[tauri::command]
pub async fn connect(state: State<'_, Desktop>, id: String) -> Result<(), String> {
    state.request(Action::Connect(id)).await.map(|_| ())
}

#[tauri::command]
pub async fn disconnect(state: State<'_, Desktop>, id: String) -> Result<(), String> {
    state.request(Action::Disconnect(id)).await.map(|_| ())
}

#[tauri::command]
pub fn resize_panel(window: WebviewWindow, editing: bool, height: f64) -> Result<(), String> {
    let old_size = window.outer_size().map_err(|e| e.to_string())?;
    let position = window.outer_position().map_err(|e| e.to_string())?;
    let scale = window.scale_factor().map_err(|e| e.to_string())?;
    let width = if editing { 430.0 } else { 340.0 };
    let mut x = position.x as f64 + old_size.width as f64 - width * scale;
    if let Some(monitor) = window.current_monitor().map_err(|e| e.to_string())? {
        x = x.max(monitor.position().x as f64);
    }
    window
        .set_size(LogicalSize::new(width, height.clamp(170.0, 600.0)))
        .map_err(|e| e.to_string())?;
    window
        .set_position(tauri::PhysicalPosition::new(x, position.y as f64))
        .map_err(|e| e.to_string())
}

#[tauri::command]
pub fn quit(app: tauri::AppHandle) {
    app.exit(0);
}

use super::snapshot::Snapshot;
use crate::connections::domain::ConnectionId;
use crate::connections::presentation::ConnectionInput;
use crate::desktop::{
    application::desktop_application::{Command, Outcome},
    infra::worker::DesktopWorker,
};
use tauri::{State, WebviewWindow};

#[tauri::command]
pub async fn snapshot(state: State<'_, DesktopWorker>) -> Result<Snapshot, String> {
    match state.request(Command::Snapshot).await? {
        Outcome::Snapshot(snapshot) => Ok(snapshot.into()),
        Outcome::Complete => Err("No snapshot returned.".into()),
    }
}

#[tauri::command]
pub async fn save_connection(
    state: State<'_, DesktopWorker>,
    connection: ConnectionInput,
) -> Result<(), String> {
    state
        .request(Command::Save(connection.into_connection()?))
        .await
        .map(|_| ())
}

#[tauri::command]
pub async fn remove_connection(state: State<'_, DesktopWorker>, id: String) -> Result<(), String> {
    state
        .request(Command::Remove(ConnectionId::parse(&id)?))
        .await
        .map(|_| ())
}

#[tauri::command]
pub async fn connect(state: State<'_, DesktopWorker>, id: String) -> Result<(), String> {
    state
        .request(Command::Connect(ConnectionId::parse(&id)?))
        .await
        .map(|_| ())
}

#[tauri::command]
pub async fn disconnect(state: State<'_, DesktopWorker>, id: String) -> Result<(), String> {
    state
        .request(Command::Disconnect(ConnectionId::parse(&id)?))
        .await
        .map(|_| ())
}

#[tauri::command]
pub fn resize_panel(window: WebviewWindow, editing: bool, height: f64) -> Result<(), String> {
    crate::desktop::infra::panel::resize(window, editing, height)
}

#[tauri::command]
pub fn quit(app: tauri::AppHandle) {
    app.exit(0);
}

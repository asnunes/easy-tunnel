use tauri::{LogicalSize, WebviewWindow};

pub fn resize(window: WebviewWindow, editing: bool, height: f64) -> Result<(), String> {
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

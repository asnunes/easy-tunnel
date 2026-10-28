use tauri::{
    Manager, PhysicalPosition,
    image::Image,
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
};

pub fn install(app: &tauri::App) -> tauri::Result<()> {
    let quit = MenuItem::with_id(app, "quit", "Quit Easy Tunnel", true, None::<&str>)?;
    let menu = Menu::with_items(app, &[&quit])?;
    let tray = TrayIconBuilder::new()
        .icon(Image::from_bytes(include_bytes!("../../icons/tray.png"))?)
        .icon_as_template(true)
        .tooltip("Easy Tunnel")
        .menu(&menu)
        .show_menu_on_left_click(false)
        .on_menu_event(|app, event| {
            if event.id.as_ref() == "quit" {
                app.exit(0);
            }
        })
        .on_tray_icon_event(|tray, event| {
            if let TrayIconEvent::Click {
                button: MouseButton::Left,
                button_state: MouseButtonState::Up,
                rect,
                ..
            } = event
            {
                let app = tray.app_handle();
                let Some(window) = app.get_webview_window("main") else {
                    return;
                };
                if window.is_visible().unwrap_or(false) {
                    let _ = window.hide();
                    return;
                }
                let scale = window.scale_factor().unwrap_or(1.0);
                let position = rect.position.to_physical::<f64>(scale);
                let size = rect.size.to_physical::<f64>(scale);
                let width = window
                    .outer_size()
                    .map(|s| s.width as f64)
                    .unwrap_or(340.0 * scale);
                let mut x = position.x + size.width - width;
                if let Ok(Some(monitor)) = window.current_monitor() {
                    x = x.max(monitor.position().x as f64).min(
                        (monitor.position().x as f64 + monitor.size().width as f64 - width)
                            .max(monitor.position().x as f64),
                    );
                }
                let _ =
                    window.set_position(PhysicalPosition::new(x, position.y + size.height + 5.0));
                let _ = window.show();
                let _ = window.set_focus();
            }
        })
        .build(app)?;
    if let Some(window) = app.get_webview_window("main") {
        if let Some(rect) = tray.rect()? {
            let scale = window.scale_factor().unwrap_or(1.0);
            let position = rect.position.to_physical::<f64>(scale);
            let size = rect.size.to_physical::<f64>(scale);
            window.set_position(PhysicalPosition::new(
                position.x + size.width - 340.0 * scale,
                position.y + size.height + 5.0,
            ))?;
        } else {
            window.center()?;
        }
        window.show()?;
        window.set_focus()?;
    }
    Ok(())
}

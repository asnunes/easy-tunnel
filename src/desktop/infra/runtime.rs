use super::tray;
use crate::desktop::presentation::commands;
use tauri::Manager;

pub fn run() {
    let app = tauri::Builder::default()
        .setup(|app| {
            #[cfg(target_os = "macos")]
            app.set_activation_policy(tauri::ActivationPolicy::Accessory);
            app.manage(crate::desktop::wiring::build(app.handle())?);
            tray::install(app)?;
            Ok(())
        })
        .invoke_handler(tauri::generate_handler![
            commands::snapshot,
            commands::save_connection,
            commands::remove_connection,
            commands::connect,
            commands::disconnect,
            commands::resize_panel,
            commands::quit
        ])
        .on_window_event(|window, event| {
            if let tauri::WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = window.hide();
            }
        })
        .build(tauri::generate_context!())
        .expect("Could not start Easy Tunnel");
    app.run(|handle, event| {
        if matches!(event, tauri::RunEvent::Exit) {
            handle.state::<super::worker::DesktopWorker>().shutdown();
        }
    });
}

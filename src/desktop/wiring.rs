use super::{
    application::desktop_application::DesktopApplication,
    infra::{tunnel_events::TauriTunnelEvents, worker::DesktopWorker},
};
use crate::{
    connections::infra::{json_repository::JsonRepository, ssh_config::SshConfig},
    tunnels::{
        application::{Tunnels, use_case::monitor_tunnels::MonitorTunnels},
        infra::openssh::OpenSsh,
    },
};
use tauri::Manager;

pub fn build(app: &tauri::AppHandle) -> Result<DesktopWorker, Box<dyn std::error::Error>> {
    let repository = Box::new(JsonRepository::new(
        app.path().app_data_dir()?.join("connections.json"),
    ));
    let hosts = Box::new(SshConfig::new(app.path().home_dir()?));
    let tunnels = Tunnels::new(Box::new(OpenSsh));
    let monitor = MonitorTunnels::new(Box::new(TauriTunnelEvents::new(app.clone())));
    let application = DesktopApplication::new(repository, hosts, tunnels, monitor);
    Ok(DesktopWorker::start(application))
}

use super::{
    application::desktop_application::DesktopApplication,
    infra::{
        tunnel_events::{EventCallback, NativeTunnelEvents},
        worker::DesktopWorker,
    },
};
use crate::{
    connections::infra::{json_repository::JsonRepository, ssh_config::SshConfig},
    tunnels::{
        application::{Tunnels, use_case::monitor_tunnels::MonitorTunnels},
        infra::openssh::OpenSsh,
    },
};
use std::path::PathBuf;

pub fn build(
    data_dir: PathBuf,
    home_dir: PathBuf,
    callback: Option<EventCallback>,
) -> DesktopWorker {
    let repository = Box::new(JsonRepository::new(data_dir.join("connections.json")));
    let hosts = Box::new(SshConfig::new(home_dir));
    let tunnels = Tunnels::new(Box::new(OpenSsh));
    let monitor = MonitorTunnels::new(Box::new(NativeTunnelEvents::new(callback)));
    let application = DesktopApplication::new(repository, hosts, tunnels, monitor);
    DesktopWorker::start(application)
}

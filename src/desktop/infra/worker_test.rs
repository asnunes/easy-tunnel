use super::*;
use crate::{
    connections::domain::{
        Connection, ConnectionId, ConnectionName, DestinationHost, Port, PortForward, SshHostAlias,
        ports::{ConnectionRepository, HostSource},
    },
    desktop::{
        application::desktop_application::ApplicationSnapshot, presentation::snapshot::Snapshot,
    },
    tunnels::{
        application::{Tunnels, use_case::monitor_tunnels::MonitorTunnels},
        domain::{Tunnel, TunnelEvents, TunnelLauncher, TunnelProcess, TunnelStatus},
    },
};
use std::cell::RefCell;

#[test]
fn dispatches_connection_operations_and_publishes_domain_events() {
    let (worker, events, stopped) = worker();
    let connection = connection();
    assert!(matches!(
        worker.exchange(Command::Save(connection.clone())).unwrap(),
        Outcome::Complete
    ));
    let initial = snapshot(&worker);
    assert_eq!(initial.connections.connections, vec![connection.clone()]);
    assert_eq!(
        initial.connections.host_error.as_deref(),
        Some("SSH config is unreadable")
    );

    worker.exchange(Command::Connect(id())).unwrap();
    let tunnels = events.recv_timeout(Duration::from_secs(2)).unwrap();
    assert_eq!(tunnels[0].status, TunnelStatus::Connected);
    assert!(worker.exchange(Command::Save(connection)).is_err());

    let json = serde_json::to_value(Snapshot::from(snapshot(&worker))).unwrap();
    assert_eq!(json["connections"][0]["sshHostAlias"], "lab");
    assert_eq!(json["connections"][0]["forwards"][0]["localPort"], 5433);
    assert_eq!(json["hostError"], "SSH config is unreadable");
    assert_eq!(json["tunnels"][0]["status"], "connected");
    assert_eq!(json["tunnels"][0]["processId"], 123);
    assert!(json.get("saved").is_none());

    worker.exchange(Command::Disconnect(id())).unwrap();
    stopped.recv_timeout(Duration::from_secs(2)).unwrap();
    assert_eq!(
        events.recv_timeout(Duration::from_secs(2)).unwrap()[0].status,
        TunnelStatus::Disconnected
    );
    worker.exchange(Command::Remove(id())).unwrap();
    assert!(snapshot(&worker).connections.connections.is_empty());
    worker.shutdown();
    assert!(worker.exchange(Command::Snapshot).is_err());
}

#[test]
fn shutdown_acknowledges_only_after_releasing_running_processes() {
    let (worker, events, stopped) = worker();
    worker.exchange(Command::Save(connection())).unwrap();
    worker.exchange(Command::Connect(id())).unwrap();
    events.recv_timeout(Duration::from_secs(2)).unwrap();
    worker.shutdown();
    assert!(stopped.try_recv().is_ok());
}

fn worker() -> (
    DesktopWorker,
    mpsc::Receiver<Vec<Tunnel>>,
    mpsc::Receiver<()>,
) {
    let (events, received) = mpsc::channel();
    let (stopped, stops) = mpsc::channel();
    let application = DesktopApplication::new(
        Box::new(MemoryRepository(RefCell::new(vec![]))),
        Box::new(UnreadableHosts),
        Tunnels::new(Box::new(Launcher(stopped))),
        MonitorTunnels::new(Box::new(Events(events))),
    );
    (DesktopWorker::start(application), received, stops)
}

fn snapshot(worker: &DesktopWorker) -> ApplicationSnapshot {
    match worker.exchange(Command::Snapshot).unwrap() {
        Outcome::Snapshot(snapshot) => snapshot,
        Outcome::Complete => panic!("Expected a snapshot"),
    }
}

fn id() -> ConnectionId {
    ConnectionId::parse("lab").unwrap()
}

fn connection() -> Connection {
    Connection::new(
        id(),
        ConnectionName::parse("Lab").unwrap(),
        SshHostAlias::parse("lab").unwrap(),
        vec![PortForward::new(
            Port::new(5433).unwrap(),
            DestinationHost::parse("localhost").unwrap(),
            Port::new(5432).unwrap(),
        )],
    )
    .unwrap()
}

struct MemoryRepository(RefCell<Vec<Connection>>);
impl ConnectionRepository for MemoryRepository {
    fn load(&self) -> Result<Vec<Connection>, String> {
        Ok(self.0.borrow().clone())
    }
    fn save(&self, connections: &[Connection]) -> Result<(), String> {
        *self.0.borrow_mut() = connections.to_vec();
        Ok(())
    }
}

struct UnreadableHosts;
impl HostSource for UnreadableHosts {
    fn list(&self) -> Result<Vec<String>, String> {
        Err("SSH config is unreadable".into())
    }
}

struct Launcher(Sender<()>);
impl TunnelLauncher for Launcher {
    fn launch(&self, connection: &Connection) -> Result<Box<dyn TunnelProcess>, String> {
        Ok(Box::new(Process {
            id: connection.id().into(),
            stopped: self.0.clone(),
        }))
    }
}

struct Process {
    id: String,
    stopped: Sender<()>,
}
impl TunnelProcess for Process {
    fn snapshot(&mut self) -> Result<Tunnel, String> {
        Ok(Tunnel {
            connection_id: self.id.clone(),
            status: TunnelStatus::Connected,
            process_id: Some(123),
            error: None,
        })
    }
    fn stop(&mut self) -> Result<(), String> {
        Ok(())
    }
}
impl Drop for Process {
    fn drop(&mut self) {
        let _ = self.stopped.send(());
    }
}

struct Events(Sender<Vec<Tunnel>>);
impl TunnelEvents for Events {
    fn changed(&self, tunnels: &[Tunnel]) {
        let _ = self.0.send(tunnels.to_vec());
    }
}

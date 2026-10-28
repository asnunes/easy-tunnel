pub mod use_case;
use crate::{
    connections::domain::Connection,
    tunnels::domain::{Tunnel, TunnelLauncher, TunnelProcess, TunnelStatus},
};
use std::collections::BTreeMap;

pub struct Tunnels {
    launcher: Box<dyn TunnelLauncher>,
    processes: BTreeMap<String, Box<dyn TunnelProcess>>,
    states: BTreeMap<String, Tunnel>,
}

impl Tunnels {
    pub fn new(launcher: Box<dyn TunnelLauncher>) -> Self {
        Self {
            launcher,
            processes: BTreeMap::new(),
            states: BTreeMap::new(),
        }
    }

    pub fn start(&mut self, connection: &Connection) -> Result<(), String> {
        connection.validate()?;
        if self.processes.contains_key(&connection.id) {
            return Err("This connection is already running.".into());
        }
        let mut process = self.launcher.launch(connection)?;
        let snapshot = process.snapshot()?;
        self.states.insert(connection.id.clone(), snapshot);
        self.processes.insert(connection.id.clone(), process);
        Ok(())
    }

    pub fn stop(&mut self, id: &str) -> Result<(), String> {
        if let Some(process) = self.processes.get_mut(id) {
            process.stop()?;
        }
        self.processes.remove(id);
        self.states.insert(
            id.into(),
            Tunnel {
                connection_id: id.into(),
                status: TunnelStatus::Disconnected,
                process_id: None,
                error: None,
            },
        );
        Ok(())
    }

    pub fn snapshots(&mut self) -> Vec<Tunnel> {
        let mut finished = Vec::new();
        for (id, process) in &mut self.processes {
            let snapshot = process.snapshot().unwrap_or_else(|error| Tunnel {
                connection_id: id.clone(),
                status: TunnelStatus::Failed,
                process_id: None,
                error: Some(error),
            });
            if matches!(
                snapshot.status,
                TunnelStatus::Disconnected | TunnelStatus::Failed
            ) {
                finished.push(id.clone());
            }
            self.states.insert(id.clone(), snapshot);
        }
        for id in finished {
            self.processes.remove(&id);
        }
        self.states.values().cloned().collect()
    }
}

impl crate::connections::domain::ports::ConnectionActivity for Tunnels {
    fn is_running(&self, id: &str) -> bool {
        self.processes.contains_key(id)
    }
}

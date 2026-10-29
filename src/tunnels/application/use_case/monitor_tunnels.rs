use crate::tunnels::{
    application::Tunnels,
    domain::{Tunnel, TunnelEvents},
};

pub struct MonitorTunnels {
    events: Box<dyn TunnelEvents>,
    previous: Vec<Tunnel>,
}

impl MonitorTunnels {
    pub fn new(events: Box<dyn TunnelEvents>) -> Self {
        Self {
            events,
            previous: vec![],
        }
    }

    pub fn execute(&mut self, tunnels: &mut Tunnels) {
        let current = tunnels.snapshots();
        if current == self.previous {
            return;
        }
        self.events.changed(&current);
        self.previous = current;
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::{
        connections::domain::Connection,
        tunnels::domain::{TunnelLauncher, TunnelProcess},
    };
    use std::sync::mpsc::{self, Sender};

    #[test]
    fn publishes_only_changed_domain_snapshots() {
        let (sender, receiver) = mpsc::channel();
        let mut monitor = MonitorTunnels::new(Box::new(Events(sender)));
        let mut tunnels = Tunnels::new(Box::new(UnusedLauncher));
        monitor.execute(&mut tunnels);
        assert!(receiver.try_recv().is_err());
        tunnels.stop("lab").unwrap();
        monitor.execute(&mut tunnels);
        assert_eq!(receiver.try_recv().unwrap()[0].connection_id, "lab");
        monitor.execute(&mut tunnels);
        assert!(receiver.try_recv().is_err());
        tunnels.stop("other").unwrap();
        monitor.execute(&mut tunnels);
        assert_eq!(receiver.try_recv().unwrap().len(), 2);
    }

    struct Events(Sender<Vec<Tunnel>>);
    impl TunnelEvents for Events {
        fn changed(&self, tunnels: &[Tunnel]) {
            self.0.send(tunnels.to_vec()).unwrap();
        }
    }

    struct UnusedLauncher;
    impl TunnelLauncher for UnusedLauncher {
        fn launch(&self, _: &Connection) -> Result<Box<dyn TunnelProcess>, String> {
            unreachable!()
        }
    }
}

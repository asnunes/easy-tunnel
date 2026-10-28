use crate::{
    connections::domain::Connection,
    tunnels::domain::{Tunnel, TunnelLauncher, TunnelProcess, TunnelStatus},
};
use std::{
    collections::VecDeque,
    io::{BufRead, BufReader},
    process::{Child, Command, Stdio},
    sync::mpsc::{self, Receiver},
    thread,
};

pub struct OpenSsh;

impl TunnelLauncher for OpenSsh {
    fn launch(&self, connection: &Connection) -> Result<Box<dyn TunnelProcess>, String> {
        let mut command = Command::new("/usr/bin/ssh");
        command.args(arguments(connection));
        Ok(Box::new(SshProcess::spawn(connection, &mut command)?))
    }
}

impl SshProcess {
    fn spawn(connection: &Connection, command: &mut Command) -> Result<Self, String> {
        let mut child = command
            .stdin(Stdio::null())
            .stdout(Stdio::null())
            .stderr(Stdio::piped())
            .spawn()
            .map_err(|e| format!("Could not start SSH: {e}"))?;
        let stderr = child.stderr.take().ok_or("SSH stderr is unavailable")?;
        let (sender, lines) = mpsc::channel();
        thread::spawn(move || {
            for line in BufReader::new(stderr).lines().map_while(Result::ok) {
                if sender.send(line).is_err() {
                    break;
                }
            }
        });
        Ok(Self {
            connection_id: connection.id.clone(),
            child,
            lines,
            messages: VecDeque::new(),
            connected: false,
            stopped: false,
        })
    }
}

fn arguments(connection: &Connection) -> Vec<String> {
    let mut args: Vec<String> = [
        "-N",
        "-T",
        "-v",
        "-o",
        "BatchMode=yes",
        "-o",
        "PreferredAuthentications=publickey",
        "-o",
        "ExitOnForwardFailure=yes",
        "-o",
        "StrictHostKeyChecking=yes",
        "-o",
        "ControlMaster=no",
        "-o",
        "ControlPath=none",
        "-o",
        "ForkAfterAuthentication=no",
        "-o",
        "PermitLocalCommand=no",
        "-o",
        "ConnectTimeout=10",
    ]
    .into_iter()
    .map(String::from)
    .collect();
    for forward in &connection.forwards {
        args.extend(["-L".into(), forward.ssh_argument()]);
    }
    args.push(connection.ssh_host_alias.clone());
    args
}

struct SshProcess {
    connection_id: String,
    child: Child,
    lines: Receiver<String>,
    messages: VecDeque<String>,
    connected: bool,
    stopped: bool,
}

impl SshProcess {
    fn read_messages(&mut self) {
        for line in self.lines.try_iter() {
            if line.contains("Entering interactive session.") {
                self.connected = true;
            }
            if line.starts_with("debug") {
                continue;
            }
            if self.messages.len() == 8 {
                self.messages.pop_front();
            }
            self.messages.push_back(line);
        }
    }
}

impl TunnelProcess for SshProcess {
    fn snapshot(&mut self) -> Result<Tunnel, String> {
        self.read_messages();
        let exit = self.child.try_wait().map_err(|e| e.to_string())?;
        let (status, error) = if let Some(exit) = exit {
            self.read_messages();
            if self.stopped {
                (TunnelStatus::Disconnected, None)
            } else {
                let detail = self.messages.iter().cloned().collect::<Vec<_>>().join("\n");
                (
                    TunnelStatus::Failed,
                    Some(if detail.is_empty() {
                        format!("SSH exited ({exit}). Check this host in Terminal.")
                    } else {
                        detail
                    }),
                )
            }
        } else if self.connected {
            (TunnelStatus::Connected, None)
        } else {
            (TunnelStatus::Connecting, None)
        };
        Ok(Tunnel {
            connection_id: self.connection_id.clone(),
            status,
            process_id: if exit.is_none() {
                Some(self.child.id())
            } else {
                None
            },
            error,
        })
    }

    fn stop(&mut self) -> Result<(), String> {
        if self.child.try_wait().map_err(|e| e.to_string())?.is_none() {
            self.child
                .kill()
                .map_err(|e| format!("Could not stop SSH: {e}"))?;
        }
        self.child.wait().map_err(|e| e.to_string())?;
        self.stopped = true;
        Ok(())
    }
}

impl Drop for SshProcess {
    fn drop(&mut self) {
        let _ = self.stop();
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::connections::domain::PortForward;
    #[test]
    fn uses_one_foreground_process_and_local_only_forwards() {
        let connection = Connection {
            id: "test".into(),
            name: "Test".into(),
            ssh_host_alias: "lab".into(),
            forwards: vec![PortForward {
                local_port: 5433,
                destination_host: "localhost".into(),
                destination_port: 5432,
            }],
        };
        let args = arguments(&connection);
        assert!(
            args.windows(2)
                .any(|a| a == ["-L", "127.0.0.1:5433:localhost:5432"])
        );
        assert!(args.contains(&"ExitOnForwardFailure=yes".into()));
        assert!(args.contains(&"ControlPath=none".into()));
        assert_eq!(args.last().unwrap(), "lab");
    }
}

#[cfg(test)]
#[path = "openssh_test.rs"]
mod integration_tests;

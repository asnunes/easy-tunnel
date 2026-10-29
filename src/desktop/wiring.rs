use crate::{
    connections::{
        application::use_case::{
            list_connections::ListConnections, remove_connection::RemoveConnection,
            save_connection::SaveConnection,
        },
        domain::ports::{ConnectionRepository, HostSource},
        infra::{json_repository::JsonRepository, ssh_config::SshConfig},
        presentation::{ConnectionInput, ConnectionsView},
    },
    tunnels::{
        application::{
            Tunnels,
            use_case::{connect::Connect, disconnect::Disconnect},
        },
        infra::openssh::OpenSsh,
        presentation::TunnelView,
    },
};
use serde::Serialize;
use std::{
    sync::mpsc::{self, Sender},
    thread,
    time::Duration,
};
use tauri::Manager;

pub fn build(app: &tauri::AppHandle) -> Result<Desktop, Box<dyn std::error::Error>> {
    let repository: Box<dyn ConnectionRepository> = Box::new(JsonRepository::new(
        app.path().app_data_dir()?.join("connections.json"),
    ));
    let hosts: Box<dyn HostSource> = Box::new(SshConfig::new(app.path().home_dir()?));
    let mut tunnels = Tunnels::new(Box::new(OpenSsh));
    let (sender, receiver) = mpsc::channel::<Request>();
    let app = app.clone();
    thread::spawn(move || {
        let mut previous = Vec::new();
        loop {
            match receiver.recv_timeout(Duration::from_millis(150)) {
                Ok(request) => {
                    if matches!(request.action, Action::Shutdown) {
                        drop(tunnels);
                        let _ = request.reply.send(Ok(None));
                        break;
                    }
                    let result = execute(
                        request.action,
                        repository.as_ref(),
                        hosts.as_ref(),
                        &mut tunnels,
                    );
                    let _ = request.reply.send(result);
                }
                Err(mpsc::RecvTimeoutError::Disconnected) => break,
                Err(mpsc::RecvTimeoutError::Timeout) => {}
            }
            let current: Vec<TunnelView> =
                tunnels.snapshots().into_iter().map(Into::into).collect();
            if current != previous {
                super::events::tunnels_changed(&app, &current);
                previous = current;
            }
        }
    });
    Ok(Desktop { sender })
}

pub struct Desktop {
    sender: Sender<Request>,
}

impl Desktop {
    pub async fn request(&self, action: Action) -> Result<Option<Snapshot>, String> {
        let sender = self.sender.clone();
        tauri::async_runtime::spawn_blocking(move || {
            let (reply, receiver) = mpsc::channel();
            sender
                .send(Request { action, reply })
                .map_err(|_| "The tunnel worker stopped.")?;
            receiver.recv().map_err(|_| "The tunnel worker stopped.")?
        })
        .await
        .map_err(|e| e.to_string())?
    }

    pub fn shutdown(&self) {
        let (reply, receiver) = mpsc::channel();
        if self
            .sender
            .send(Request {
                action: Action::Shutdown,
                reply,
            })
            .is_ok()
        {
            let _ = receiver.recv();
        }
    }
}

pub enum Action {
    Snapshot,
    Save(ConnectionInput),
    Remove(String),
    Connect(String),
    Disconnect(String),
    Shutdown,
}

#[derive(Serialize)]
pub struct Snapshot {
    #[serde(flatten)]
    pub saved: ConnectionsView,
    pub tunnels: Vec<TunnelView>,
}

type Reply = Result<Option<Snapshot>, String>;

fn execute(
    action: Action,
    repository: &dyn ConnectionRepository,
    hosts: &dyn HostSource,
    tunnels: &mut Tunnels,
) -> Reply {
    match action {
        Action::Snapshot => {
            let listing = ListConnections { repository, hosts }.execute()?;
            Ok(Some(Snapshot {
                saved: ConnectionsView {
                    connections: listing.connections.iter().map(Into::into).collect(),
                    hosts: listing.hosts,
                    host_error: listing.host_error,
                },
                tunnels: tunnels.snapshots().into_iter().map(Into::into).collect(),
            }))
        }
        Action::Save(input) => {
            let connection = input.into_connection()?;
            SaveConnection {
                repository,
                activity: tunnels,
            }
            .execute(connection)?;
            Ok(None)
        }
        Action::Remove(id) => {
            RemoveConnection {
                repository,
                activity: tunnels,
            }
            .execute(&id)?;
            Ok(None)
        }
        Action::Connect(id) => {
            Connect {
                repository,
                tunnels,
            }
            .execute(&id)?;
            Ok(None)
        }
        Action::Disconnect(id) => {
            Disconnect { tunnels }.execute(&id)?;
            Ok(None)
        }
        Action::Shutdown => unreachable!(),
    }
}

struct Request {
    action: Action,
    reply: Sender<Reply>,
}

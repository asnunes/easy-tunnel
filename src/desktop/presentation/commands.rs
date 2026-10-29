use crate::{
    connections::{domain::ConnectionId, presentation::ConnectionInput},
    desktop::application::desktop_application::Command,
};
use serde::Deserialize;

#[derive(Deserialize)]
#[serde(tag = "command", rename_all = "snake_case")]
pub enum NativeCommand {
    Snapshot,
    SaveConnection { connection: ConnectionInput },
    RemoveConnection { id: String },
    Connect { id: String },
    Disconnect { id: String },
}

impl NativeCommand {
    pub fn into_command(self) -> Result<Command, String> {
        match self {
            Self::Snapshot => Ok(Command::Snapshot),
            Self::SaveConnection { connection } => Ok(Command::Save(connection.into_connection()?)),
            Self::RemoveConnection { id } => Ok(Command::Remove(ConnectionId::parse(&id)?)),
            Self::Connect { id } => Ok(Command::Connect(ConnectionId::parse(&id)?)),
            Self::Disconnect { id } => Ok(Command::Disconnect(ConnectionId::parse(&id)?)),
        }
    }
}

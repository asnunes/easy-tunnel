use crate::connections::domain::{
    Connection,
    ports::{ConnectionActivity, ConnectionRepository},
};

pub struct SaveConnection<'a> {
    pub repository: &'a dyn ConnectionRepository,
    pub activity: &'a dyn ConnectionActivity,
}

impl SaveConnection<'_> {
    pub fn execute(&self, connection: Connection) -> Result<(), String> {
        connection.validate()?;
        if self.activity.is_running(&connection.id) {
            return Err("Disconnect before editing this connection.".into());
        }
        let mut connections = self.repository.load()?;
        if let Some(existing) = connections.iter_mut().find(|c| c.id == connection.id) {
            *existing = connection;
        } else {
            connections.push(connection);
        }
        self.repository.save(&connections)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::connections::{
        application::use_case::remove_connection::RemoveConnection, domain::PortForward,
        infra::json_repository::JsonRepository,
    };

    #[test]
    fn persists_edits_and_rejects_changes_while_running() {
        let directory = tempfile::tempdir().unwrap();
        let repository = JsonRepository::new(directory.path().join("connections.json"));
        let mut connection = Connection {
            id: "lab".into(),
            name: "Home lab".into(),
            ssh_host_alias: "homelab".into(),
            forwards: vec![PortForward {
                local_port: 5433,
                destination_host: "localhost".into(),
                destination_port: 5432,
            }],
        };
        SaveConnection {
            repository: &repository,
            activity: &Activity(false),
        }
        .execute(connection.clone())
        .unwrap();
        connection.name = "Updated".into();
        assert!(
            SaveConnection {
                repository: &repository,
                activity: &Activity(true)
            }
            .execute(connection.clone())
            .is_err()
        );
        assert_eq!(repository.load().unwrap()[0].name, "Home lab");
        SaveConnection {
            repository: &repository,
            activity: &Activity(false),
        }
        .execute(connection.clone())
        .unwrap();
        assert_eq!(repository.load().unwrap(), vec![connection]);
        assert!(
            RemoveConnection {
                repository: &repository,
                activity: &Activity(true)
            }
            .execute("lab")
            .is_err()
        );
        RemoveConnection {
            repository: &repository,
            activity: &Activity(false),
        }
        .execute("lab")
        .unwrap();
        assert!(repository.load().unwrap().is_empty());
    }

    struct Activity(bool);
    impl ConnectionActivity for Activity {
        fn is_running(&self, _: &str) -> bool {
            self.0
        }
    }
}

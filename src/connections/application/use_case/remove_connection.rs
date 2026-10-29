use crate::connections::domain::ports::{ConnectionActivity, ConnectionRepository};

pub struct RemoveConnection<'a> {
    pub repository: &'a dyn ConnectionRepository,
    pub activity: &'a dyn ConnectionActivity,
}

impl RemoveConnection<'_> {
    pub fn execute(&self, id: &str) -> Result<(), String> {
        if self.activity.is_running(id) {
            return Err("Disconnect before deleting this connection.".into());
        }
        let mut connections = self.repository.load()?;
        connections.retain(|c| c.id() != id);
        self.repository.save(&connections)
    }
}

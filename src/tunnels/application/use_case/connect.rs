use crate::connections::domain::ports::ConnectionRepository;
use crate::tunnels::application::Tunnels;

pub struct Connect<'a> {
    pub repository: &'a dyn ConnectionRepository,
    pub tunnels: &'a mut Tunnels,
}

impl Connect<'_> {
    pub fn execute(&mut self, id: &str) -> Result<(), String> {
        let connection = self
            .repository
            .load()?
            .into_iter()
            .find(|c| c.id() == id)
            .ok_or("Connection not found.")?;
        self.tunnels.start(&connection)
    }
}

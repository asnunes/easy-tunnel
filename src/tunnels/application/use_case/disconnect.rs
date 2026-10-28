use crate::tunnels::application::Tunnels;

pub struct Disconnect<'a> {
    pub tunnels: &'a mut Tunnels,
}

impl Disconnect<'_> {
    pub fn execute(&mut self, id: &str) -> Result<(), String> {
        self.tunnels.stop(id)
    }
}

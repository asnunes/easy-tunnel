use super::Connection;

pub trait ConnectionRepository: Send {
    fn load(&self) -> Result<Vec<Connection>, String>;
    fn save(&self, connections: &[Connection]) -> Result<(), String>;
}

pub trait HostSource: Send {
    fn list(&self) -> Result<Vec<String>, String>;
}

pub trait ConnectionActivity {
    fn is_running(&self, id: &str) -> bool;
}

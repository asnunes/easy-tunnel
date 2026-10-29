use crate::tunnels::{
    domain::{Tunnel, TunnelEvents},
    presentation::TunnelView,
};
use std::ffi::{CString, c_char};

pub struct NativeTunnelEvents {
    callback: Option<EventCallback>,
}

impl NativeTunnelEvents {
    pub fn new(callback: Option<EventCallback>) -> Self {
        Self { callback }
    }
}

impl TunnelEvents for NativeTunnelEvents {
    fn changed(&self, tunnels: &[Tunnel]) {
        let Some(callback) = self.callback else {
            return;
        };
        let views: Vec<TunnelView> = tunnels.iter().cloned().map(Into::into).collect();
        if let Ok(json) = serde_json::to_string(&views)
            && let Ok(message) = CString::new(json)
        {
            callback(message.as_ptr());
        }
    }
}

// The receiver copies this borrowed string before returning from the callback.
pub type EventCallback = extern "C" fn(*const c_char);

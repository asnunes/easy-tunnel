use super::{tunnel_events::EventCallback, worker::DesktopWorker};
use crate::desktop::{
    presentation::{commands::NativeCommand, response::NativeResponse},
    wiring,
};
use std::{
    ffi::{CStr, CString, c_char},
    path::PathBuf,
};

/// Starts the Rust application for the native macOS host.
///
/// # Safety
/// Both paths must point to NUL-terminated UTF-8 strings for this call.
/// The callback must remain callable until `easy_tunnel_destroy` returns.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn easy_tunnel_create(
    data_dir: *const c_char,
    home_dir: *const c_char,
    callback: Option<EventCallback>,
) -> *mut NativeBackend {
    let (Ok(data_dir), Ok(home_dir)) = (unsafe { read_string(data_dir) }, unsafe {
        read_string(home_dir)
    }) else {
        return std::ptr::null_mut();
    };
    Box::into_raw(Box::new(NativeBackend {
        worker: wiring::build(PathBuf::from(data_dir), PathBuf::from(home_dir), callback),
    }))
}

/// Executes a request. Free its owned response with `easy_tunnel_free_string`.
///
/// # Safety
/// `backend` must be a live handle from `easy_tunnel_create`, and `request` must
/// point to a NUL-terminated UTF-8 string for this call. Do not destroy the handle
/// while a request is executing.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn easy_tunnel_request(
    backend: *mut NativeBackend,
    request: *const c_char,
) -> *mut c_char {
    let result = (|| {
        let backend = unsafe { backend.as_ref() }.ok_or("The backend is not running.")?;
        let request = unsafe { read_string(request) }?;
        let command: NativeCommand =
            serde_json::from_str(&request).map_err(|error| error.to_string())?;
        backend.worker.request(command.into_command()?)
    })();
    let response = NativeResponse::from(result);
    let json =
        serde_json::to_string(&response).expect("Response contains only JSON-compatible values");
    CString::new(json)
        .expect("JSON escapes NUL characters")
        .into_raw()
}

/// Releases an owned response returned by `easy_tunnel_request`.
///
/// # Safety
/// `value` must be null or an unfreed pointer returned by `easy_tunnel_request`.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn easy_tunnel_free_string(value: *mut c_char) {
    if !value.is_null() {
        drop(unsafe { CString::from_raw(value) });
    }
}

/// Stops all tunnels and releases the backend. No callbacks run after return.
///
/// # Safety
/// `backend` must be null or a live handle returned by `easy_tunnel_create`.
/// No requests may be using this handle, and it must not be reused afterwards.
#[unsafe(no_mangle)]
pub unsafe extern "C" fn easy_tunnel_destroy(backend: *mut NativeBackend) {
    if backend.is_null() {
        return;
    }
    let backend = unsafe { Box::from_raw(backend) };
    backend.worker.shutdown();
}

pub struct NativeBackend {
    worker: DesktopWorker,
}

unsafe fn read_string(value: *const c_char) -> Result<String, String> {
    if value.is_null() {
        return Err("Missing native request value.".into());
    }
    unsafe { CStr::from_ptr(value) }
        .to_str()
        .map(str::to_owned)
        .map_err(|error| error.to_string())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn native_bridge_round_trip_validates_and_persists_connections() {
        let directory = tempfile::tempdir().unwrap();
        let path = CString::new(directory.path().to_str().unwrap()).unwrap();
        unsafe {
            let backend = easy_tunnel_create(path.as_ptr(), path.as_ptr(), None);
            assert!(!backend.is_null());
            let save = request(
                backend,
                json!({"command":"save_connection","connection":{"name":"Lab","sshHostAlias":"lab","forwards":[{"localPort":8080,"destinationHost":"localhost","destinationPort":80}]}}),
            );
            assert!(save["error"].is_null());
            let loaded = request(backend, json!({"command":"snapshot"}));
            assert_eq!(loaded["snapshot"]["connections"][0]["name"], "Lab");
            assert_eq!(
                loaded["snapshot"]["connections"][0]["forwards"][0]["localPort"],
                8080
            );
            let invalid = request(backend, json!({"command":"connect","id":""}));
            assert!(invalid["error"].is_string());
            easy_tunnel_destroy(backend);
        }
    }

    unsafe fn request(backend: *mut NativeBackend, value: serde_json::Value) -> serde_json::Value {
        let input = CString::new(value.to_string()).unwrap();
        let output = unsafe { easy_tunnel_request(backend, input.as_ptr()) };
        let value =
            serde_json::from_str(unsafe { CStr::from_ptr(output) }.to_str().unwrap()).unwrap();
        unsafe { easy_tunnel_free_string(output) };
        value
    }
}

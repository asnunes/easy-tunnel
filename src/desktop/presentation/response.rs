use super::snapshot::Snapshot;
use crate::desktop::application::desktop_application::Outcome;
use serde::Serialize;

#[derive(Serialize)]
pub struct NativeResponse {
    snapshot: Option<Snapshot>,
    error: Option<String>,
}

impl From<Result<Outcome, String>> for NativeResponse {
    fn from(result: Result<Outcome, String>) -> Self {
        match result {
            Ok(Outcome::Snapshot(snapshot)) => Self {
                snapshot: Some(snapshot.into()),
                error: None,
            },
            Ok(Outcome::Complete) => Self {
                snapshot: None,
                error: None,
            },
            Err(error) => Self {
                snapshot: None,
                error: Some(error),
            },
        }
    }
}

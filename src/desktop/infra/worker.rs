use crate::desktop::application::desktop_application::{Command, DesktopApplication, Outcome};
use std::{
    sync::mpsc::{self, Sender},
    thread,
    time::Duration,
};

#[derive(Clone)]
pub struct DesktopWorker {
    sender: Sender<Request>,
}

impl DesktopWorker {
    pub fn start(mut application: DesktopApplication) -> Self {
        let (sender, receiver) = mpsc::channel();
        thread::spawn(move || {
            loop {
                match receiver.recv_timeout(Duration::from_millis(150)) {
                    Ok(Request::Execute { command, reply }) => {
                        let _ = reply.send(application.execute(command));
                    }
                    Ok(Request::Shutdown { reply }) => {
                        drop(application);
                        let _ = reply.send(());
                        break;
                    }
                    Err(mpsc::RecvTimeoutError::Disconnected) => break,
                    Err(mpsc::RecvTimeoutError::Timeout) => {}
                }
                application.poll();
            }
        });
        Self { sender }
    }

    pub fn request(&self, command: Command) -> Result<Outcome, String> {
        self.exchange(command)
    }

    pub fn shutdown(&self) {
        let (reply, receiver) = mpsc::channel();
        if self.sender.send(Request::Shutdown { reply }).is_ok() {
            let _ = receiver.recv();
        }
    }

    fn exchange(&self, command: Command) -> Result<Outcome, String> {
        let (reply, receiver) = mpsc::channel();
        self.sender
            .send(Request::Execute { command, reply })
            .map_err(|_| "The tunnel worker stopped.")?;
        receiver.recv().map_err(|_| "The tunnel worker stopped.")?
    }
}

enum Request {
    Execute {
        command: Command,
        reply: Sender<Result<Outcome, String>>,
    },
    Shutdown {
        reply: Sender<()>,
    },
}

#[cfg(test)]
#[path = "worker_test.rs"]
mod tests;

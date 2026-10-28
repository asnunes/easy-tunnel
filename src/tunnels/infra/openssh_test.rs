use super::*;
use crate::connections::domain::PortForward;
use std::{
    fs,
    io::{Read, Write},
    net::{TcpListener, TcpStream},
    path::Path,
    time::{Duration, Instant},
};

#[test]
fn forwards_real_ssh_traffic_reports_busy_ports_and_reaps_children() {
    let fixture = Fixture::new();
    let destination = TcpListener::bind("127.0.0.1:0").unwrap();
    let remote_port = destination.local_addr().unwrap().port();
    let local_port = free_port();
    let connection = Connection {
        id: "fixture".into(),
        name: "Fixture".into(),
        ssh_host_alias: "fixture".into(),
        forwards: vec![PortForward {
            local_port,
            destination_host: "127.0.0.1".into(),
            destination_port: remote_port,
        }],
    };
    let mut command = Command::new("/usr/bin/ssh");
    command
        .args(["-F", fixture.config.to_str().unwrap()])
        .args(arguments(&connection));
    let mut process = SshProcess::spawn(&connection, &mut command).unwrap();
    wait_until(&mut process, TunnelStatus::Connected);
    let mut client = TcpStream::connect(("127.0.0.1", local_port)).unwrap();
    client
        .set_read_timeout(Some(Duration::from_secs(3)))
        .unwrap();
    client.write_all(b"hello tunnel").unwrap();
    destination.set_nonblocking(true).unwrap();
    let deadline = Instant::now() + Duration::from_secs(3);
    let mut server = loop {
        if let Ok((stream, _)) = destination.accept() {
            break stream;
        }
        assert!(
            Instant::now() < deadline,
            "Forward did not reach destination"
        );
        thread::sleep(Duration::from_millis(20));
    };
    server
        .set_read_timeout(Some(Duration::from_secs(3)))
        .unwrap();
    let mut bytes = [0; 12];
    server.read_exact(&mut bytes).unwrap();
    assert_eq!(&bytes, b"hello tunnel");
    server.write_all(b"ok").unwrap();
    let mut response = [0; 2];
    client.read_exact(&mut response).unwrap();
    assert_eq!(&response, b"ok");

    let mut occupied_command = Command::new("/usr/bin/ssh");
    occupied_command
        .args(["-F", fixture.config.to_str().unwrap()])
        .args(arguments(&connection));
    let mut occupied = SshProcess::spawn(&connection, &mut occupied_command).unwrap();
    let failure = wait_until(&mut occupied, TunnelStatus::Failed);
    assert!(failure.error.unwrap().contains("Address already in use"));

    process.stop().unwrap();
    assert!(process.child.try_wait().unwrap().is_some());
    assert_eq!(
        process.snapshot().unwrap().status,
        TunnelStatus::Disconnected
    );
    assert!(TcpStream::connect(("127.0.0.1", local_port)).is_err());
    let mut restarted_command = Command::new("/usr/bin/ssh");
    restarted_command
        .args(["-F", fixture.config.to_str().unwrap()])
        .args(arguments(&connection));
    let mut restarted = SshProcess::spawn(&connection, &mut restarted_command).unwrap();
    wait_until(&mut restarted, TunnelStatus::Connected);
    drop(restarted);
    assert!(TcpStream::connect(("127.0.0.1", local_port)).is_err());
}

fn wait_until(process: &mut SshProcess, expected: TunnelStatus) -> Tunnel {
    let deadline = Instant::now() + Duration::from_secs(8);
    loop {
        let snapshot = process.snapshot().unwrap();
        if snapshot.status == expected {
            return snapshot;
        }
        assert!(
            snapshot.status != TunnelStatus::Failed && Instant::now() < deadline,
            "Unexpected SSH state: {snapshot:?}"
        );
        thread::sleep(Duration::from_millis(25));
    }
}

fn free_port() -> u16 {
    TcpListener::bind("127.0.0.1:0")
        .unwrap()
        .local_addr()
        .unwrap()
        .port()
}

fn key(path: &Path) {
    assert!(
        Command::new("/usr/bin/ssh-keygen")
            .args(["-q", "-t", "ed25519", "-N", "", "-f"])
            .arg(path)
            .status()
            .unwrap()
            .success()
    );
}

struct Fixture {
    _directory: tempfile::TempDir,
    daemon: Child,
    config: std::path::PathBuf,
}

impl Fixture {
    fn new() -> Self {
        let directory = tempfile::tempdir().unwrap();
        let root = directory.path();
        key(&root.join("host"));
        key(&root.join("identity"));
        fs::copy(root.join("identity.pub"), root.join("authorized_keys")).unwrap();
        let port = free_port();
        let public_key = fs::read_to_string(root.join("host.pub")).unwrap();
        fs::write(
            root.join("known_hosts"),
            format!("[127.0.0.1]:{port} {public_key}"),
        )
        .unwrap();
        fs::write(root.join("sshd_config"), format!("Port {port}\nListenAddress 127.0.0.1\nHostKey {}/host\nPidFile {}/pid\nAuthorizedKeysFile {}/authorized_keys\nPasswordAuthentication no\nUsePAM no\nStrictModes no\nAllowTcpForwarding yes\n", root.display(), root.display(), root.display())).unwrap();
        let daemon = Command::new("/usr/sbin/sshd")
            .args(["-D", "-e", "-f"])
            .arg(root.join("sshd_config"))
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .unwrap();
        let config = root.join("config");
        fs::write(&config, format!("Host fixture\n HostName 127.0.0.1\n Port {port}\n IdentityFile {}/identity\n IdentitiesOnly yes\n UserKnownHostsFile {}/known_hosts\n", root.display(), root.display())).unwrap();
        let fixture = Self {
            _directory: directory,
            daemon,
            config,
        };
        let deadline = Instant::now() + Duration::from_secs(3);
        while TcpStream::connect(("127.0.0.1", port)).is_err() {
            assert!(Instant::now() < deadline, "Local sshd did not start");
            thread::sleep(Duration::from_millis(25));
        }
        fixture
    }
}

impl Drop for Fixture {
    fn drop(&mut self) {
        let _ = self.daemon.kill();
        let _ = self.daemon.wait();
    }
}

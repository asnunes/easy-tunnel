import { invoke } from "@tauri-apps/api/core";
import { listen } from "@tauri-apps/api/event";

export const api = {
  snapshot: () => invoke<Snapshot>("snapshot"),
  save: (connection: ConnectionInput) =>
    invoke<void>("save_connection", { connection }),
  remove: (id: string) => invoke<void>("remove_connection", { id }),
  connect: (id: string) => invoke<void>("connect", { id }),
  disconnect: (id: string) => invoke<void>("disconnect", { id }),
  resize: (editing: boolean, height: number) =>
    invoke<void>("resize_panel", { editing, height }),
  quit: () => invoke<void>("quit"),
  listen: (onChange: (tunnels: Tunnel[]) => void) =>
    listen<Tunnel[]>("tunnels-changed", (event) => onChange(event.payload)),
};

export interface Snapshot {
  connections: Connection[];
  hosts: string[];
  hostError: string | null;
  tunnels: Tunnel[];
}

export interface Connection {
  id: string;
  name: string;
  sshHostAlias: string;
  forwards: PortForward[];
}

export interface ConnectionInput extends Omit<Connection, "id"> {
  id?: string;
}

export interface PortForward {
  localPort: number;
  destinationHost: string;
  destinationPort: number;
}

export interface Tunnel {
  connectionId: string;
  status: "connecting" | "connected" | "disconnected" | "failed";
  processId: number | null;
  error: string | null;
}

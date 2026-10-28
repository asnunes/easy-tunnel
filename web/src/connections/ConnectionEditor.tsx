import { useState, type FormEvent } from "react";
import { Plus, X } from "lucide-react";
import type { Connection, ConnectionInput } from "../api";
import { PortForwardRow, type ForwardDraft } from "./PortForwardRow";

export function ConnectionEditor({
  connection,
  hosts,
  active,
  busy,
  onSave,
  onCancel,
  onRemove,
}: Props) {
  const [name, setName] = useState(connection?.name ?? "");
  const [host, setHost] = useState(connection?.sshHostAlias ?? hosts[0] ?? "");
  const [forwards, setForwards] = useState<ForwardDraft[]>(
    connection?.forwards.map((p) => ({
      localPort: String(p.localPort),
      destinationHost: p.destinationHost,
      destinationPort: String(p.destinationPort),
    })) ?? [emptyForward()],
  );
  const [error, setError] = useState<string | null>(null);
  const [confirmDelete, setConfirmDelete] = useState(false);
  const availableHosts = [
    ...new Set([...(connection ? [connection.sshHostAlias] : []), ...hosts]),
  ];
  const disabled = busy || active;

  function submit(event: FormEvent) {
    event.preventDefault();
    if (disabled) return;
    if (!forwards.length) {
      setError("Add at least one port.");
      return;
    }
    const ports = forwards.map((p) => Number(p.localPort));
    if (new Set(ports).size !== ports.length) {
      setError("Each local port must be unique.");
      return;
    }
    setError(null);
    void onSave({
      id: connection?.id,
      name: name.trim(),
      sshHostAlias: host,
      forwards: forwards.map((p) => ({
        localPort: Number(p.localPort),
        destinationHost: p.destinationHost.trim(),
        destinationPort: Number(p.destinationPort),
      })),
    });
  }

  return (
    <form onSubmit={submit}>
      <header className="panel-header editor-header">
        <h1>{connection ? "Edit connection" : "Add connection"}</h1>
        <button
          className="icon-button"
          type="button"
          aria-label="Back to connections"
          onClick={onCancel}
        >
          <X size={16} />
        </button>
      </header>
      <div className="editor-content">
        <div className="connection-fields">
          <label>
            Name
            <input
              autoFocus
              required
              value={name}
              placeholder="Home lab"
              disabled={disabled}
              onChange={(e) => setName(e.target.value)}
            />
          </label>
          <label>
            SSH host
            <select
              aria-label="SSH host"
              required
              value={host}
              disabled={disabled || !availableHosts.length}
              onChange={(e) => setHost(e.target.value)}
            >
              {!availableHosts.length && (
                <option value="">No hosts found</option>
              )}
              {availableHosts.map((alias) => (
                <option key={alias}>{alias}</option>
              ))}
            </select>
          </label>
        </div>
        {!availableHosts.length && (
          <p className="hint">
            Add a named Host to ~/.ssh/config, then refresh the host list.
          </p>
        )}
        {active && (
          <p className="hint">Disconnect this tunnel before editing.</p>
        )}
        <div className="port-headings" aria-hidden>
          <span>Local port</span>
          <span />
          <span>Destination</span>
          <span>Port</span>
          <span />
        </div>
        {forwards.map((forward, index) => (
          <PortForwardRow
            key={index}
            forward={forward}
            index={index}
            disabled={disabled}
            onChange={(value) =>
              setForwards((previous) =>
                previous.map((p, i) => (i === index ? value : p)),
              )
            }
            onRemove={() =>
              setForwards((previous) => previous.filter((_, i) => i !== index))
            }
          />
        ))}
        <button
          type="button"
          className="text-button add-port"
          disabled={disabled}
          onClick={() =>
            setForwards((previous) => [...previous, emptyForward()])
          }
        >
          <Plus size={14} />
          Add port
        </button>
        {error && (
          <p role="alert" className="error">
            {error}
          </p>
        )}
      </div>
      <footer className="editor-footer">
        {connection && (
          <button
            type="button"
            className="text-button danger"
            disabled={disabled}
            onClick={() =>
              confirmDelete
                ? void onRemove(connection.id)
                : setConfirmDelete(true)
            }
          >
            {confirmDelete ? "Confirm delete" : "Delete"}
          </button>
        )}
        <div className="footer-actions">
          <button
            type="button"
            className="button"
            onClick={onCancel}
            disabled={busy}
          >
            Cancel
          </button>
          <button
            className="button primary"
            type="submit"
            disabled={disabled || !host}
          >
            {busy ? "Saving…" : "Save"}
          </button>
        </div>
      </footer>
    </form>
  );
}

function emptyForward(): ForwardDraft {
  return { localPort: "", destinationHost: "localhost", destinationPort: "" };
}

interface Props {
  connection: Connection | null;
  hosts: string[];
  active: boolean;
  busy: boolean;
  onSave: (connection: ConnectionInput) => Promise<void>;
  onCancel: () => void;
  onRemove: (id: string) => Promise<void>;
}

import { Plus, RefreshCw } from "lucide-react";
import type { Connection, Tunnel } from "../api";
import { ConnectionRow } from "./ConnectionRow";

export function ConnectionList({
  connections,
  tunnels,
  busy,
  loading,
  onEdit,
  onAdd,
  onToggle,
  onRefresh,
}: Props) {
  return (
    <>
      <header className="panel-header">
        <h1>Easy Tunnel</h1>
        <button
          className="icon-button"
          aria-label="Refresh SSH hosts"
          disabled={busy}
          onClick={onRefresh}
        >
          <RefreshCw size={14} />
        </button>
      </header>
      {loading ? (
        <p className="empty">Loading connections…</p>
      ) : connections.length === 0 ? (
        <p className="empty">No saved connections.</p>
      ) : (
        <ul className="connection-list">
          {connections.map((connection) => {
            const tunnel = tunnels.find(
              (t) => t.connectionId === connection.id,
            );
            return (
              <ConnectionRow
                key={connection.id}
                connection={connection}
                tunnel={tunnel}
                busy={busy}
                onEdit={() => onEdit(connection)}
                onToggle={() =>
                  onToggle(
                    connection.id,
                    tunnel?.status === "connected" ||
                      tunnel?.status === "connecting",
                  )
                }
              />
            );
          })}
        </ul>
      )}
      <div className="list-footer">
        <button
          className="text-button"
          disabled={loading || busy}
          onClick={onAdd}
        >
          <Plus size={15} />
          Add connection
        </button>
      </div>
    </>
  );
}

interface Props {
  connections: Connection[];
  tunnels: Tunnel[];
  busy: boolean;
  loading: boolean;
  onEdit: (connection: Connection) => void;
  onAdd: () => void;
  onToggle: (id: string, active: boolean) => void;
  onRefresh: () => void;
}

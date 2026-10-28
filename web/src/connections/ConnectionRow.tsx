import { ChevronRight, LoaderCircle } from "lucide-react";
import type { Connection, Tunnel } from "../api";

export function ConnectionRow({
  connection,
  tunnel,
  busy,
  onEdit,
  onToggle,
}: Props) {
  const active =
    tunnel?.status === "connected" || tunnel?.status === "connecting";
  return (
    <li className="connection-item">
      <div className="connection-row">
        <button
          className="connection-name"
          onClick={onEdit}
          aria-label={`Edit ${connection.name}`}
        >
          <span>{connection.name}</span>
          <ChevronRight size={15} aria-hidden />
        </button>
        {tunnel?.status === "connecting" && (
          <LoaderCircle className="spinner" size={14} aria-label="Connecting" />
        )}
        <button
          className="switch"
          role="switch"
          aria-checked={active}
          aria-label={`Tunnel for ${connection.name}`}
          disabled={busy}
          onClick={onToggle}
        >
          <span />
        </button>
      </div>
      {tunnel?.error && (
        <p className="connection-error" role="alert">
          {tunnel.error}
        </p>
      )}
    </li>
  );
}

interface Props {
  connection: Connection;
  tunnel?: Tunnel;
  busy: boolean;
  onEdit: () => void;
  onToggle: () => void;
}

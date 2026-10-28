import { X } from "lucide-react";

export function PortForwardRow({
  forward,
  index,
  disabled,
  onChange,
  onRemove,
}: Props) {
  return (
    <div className="port-row">
      <input
        aria-label={`Local port ${index + 1}`}
        type="number"
        min="1"
        max="65535"
        required
        value={forward.localPort}
        placeholder="5433"
        disabled={disabled}
        onChange={(event) =>
          onChange({ ...forward, localPort: event.target.value })
        }
      />
      <span className="port-arrow" aria-hidden>
        →
      </span>
      <input
        aria-label={`Destination host ${index + 1}`}
        required
        value={forward.destinationHost}
        placeholder="localhost"
        disabled={disabled}
        onChange={(event) =>
          onChange({ ...forward, destinationHost: event.target.value })
        }
      />
      <input
        aria-label={`Remote port ${index + 1}`}
        type="number"
        min="1"
        max="65535"
        required
        value={forward.destinationPort}
        placeholder="5432"
        disabled={disabled}
        onChange={(event) =>
          onChange({ ...forward, destinationPort: event.target.value })
        }
      />
      <button
        className="icon-button"
        type="button"
        aria-label={`Remove port ${index + 1}`}
        disabled={disabled}
        onClick={onRemove}
      >
        <X size={14} />
      </button>
    </div>
  );
}

export interface ForwardDraft {
  localPort: string;
  destinationHost: string;
  destinationPort: string;
}

interface Props {
  forward: ForwardDraft;
  index: number;
  disabled: boolean;
  onChange: (forward: ForwardDraft) => void;
  onRemove: () => void;
}

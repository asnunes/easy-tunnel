import { useEffect, useRef, useState } from "react";
import { api, type Connection, type ConnectionInput } from "./api";
import { ConnectionList } from "./connections/ConnectionList";
import { ConnectionEditor } from "./connections/ConnectionEditor";
import { useConnections } from "./hooks/useConnections";

export default function App() {
  const model = useConnections();
  const [editing, setEditing] = useState<Connection | null | undefined>(
    undefined,
  );
  const content = useRef<HTMLDivElement>(null);
  const isEditing = editing !== undefined;

  useEffect(() => {
    const element = content.current;
    if (!element) return;
    const observer = new ResizeObserver(() => {
      void api.resize(isEditing, element.scrollHeight + 2).catch(() => {});
    });
    observer.observe(element);
    return () => observer.disconnect();
  }, [isEditing]);

  function closeEditor() {
    setEditing(undefined);
    model.clearError();
  }

  async function save(connection: ConnectionInput) {
    if (await model.save(connection)) closeEditor();
  }
  async function remove(id: string) {
    if (await model.remove(id)) closeEditor();
  }

  const active = model.tunnels.some(
    (t) =>
      t.connectionId === editing?.id &&
      (t.status === "connected" || t.status === "connecting"),
  );
  return (
    <main className={isEditing ? "panel editing" : "panel"}>
      <div ref={content}>
        {isEditing ? (
          <ConnectionEditor
            connection={editing}
            hosts={model.hosts}
            active={active}
            busy={model.busy}
            onSave={save}
            onCancel={closeEditor}
            onRemove={remove}
          />
        ) : (
          <ConnectionList
            connections={model.connections}
            tunnels={model.tunnels}
            busy={model.busy}
            loading={model.loading}
            onEdit={(connection) => {
              model.clearError();
              setEditing(connection);
            }}
            onAdd={() => {
              model.clearError();
              setEditing(null);
            }}
            onToggle={(id, active) => {
              void model.toggle(id, active);
            }}
            onRefresh={() => {
              void model.refresh();
            }}
          />
        )}
        {model.error && (
          <p role="alert" className="error global-error">
            {model.error}
          </p>
        )}
        {model.hostError && (
          <p role="alert" className="error global-error">
            {model.hostError}
          </p>
        )}
        {!isEditing && (
          <div className="app-footer">
            <button
              className="text-button quit"
              onClick={() => {
                void api.quit();
              }}
            >
              Quit Easy Tunnel
            </button>
          </div>
        )}
      </div>
    </main>
  );
}

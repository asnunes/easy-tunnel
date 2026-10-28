import { useCallback, useEffect, useState } from "react";
import { api, type Snapshot, type ConnectionInput } from "../api";

export function useConnections() {
  const [data, setData] = useState<Snapshot>({
    connections: [],
    hosts: [],
    hostError: null,
    tunnels: [],
  });
  const [loading, setLoading] = useState(true);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const refresh = useCallback(async () => {
    const snapshot = await api.snapshot();
    setData(snapshot);
  }, []);

  useEffect(() => {
    let disposed = false;
    let unlisten: (() => void) | undefined;
    void (async () => {
      try {
        unlisten = await api.listen((tunnels) => {
          if (!disposed) setData((previous) => ({ ...previous, tunnels }));
        });
        if (disposed) {
          unlisten();
          return;
        }
        await refresh();
      } catch (cause) {
        if (!disposed) setError(String(cause));
      } finally {
        if (!disposed) setLoading(false);
      }
    })();
    return () => {
      disposed = true;
      unlisten?.();
    };
  }, [refresh]);

  async function perform(operation: () => Promise<void>) {
    setBusy(true);
    setError(null);
    try {
      await operation();
      await refresh();
      return true;
    } catch (cause) {
      setError(String(cause));
      return false;
    } finally {
      setBusy(false);
    }
  }

  return {
    ...data,
    loading,
    busy,
    error,
    clearError: () => setError(null),
    save: (connection: ConnectionInput) => perform(() => api.save(connection)),
    remove: (id: string) => perform(() => api.remove(id)),
    toggle: (id: string, active: boolean) =>
      perform(() => (active ? api.disconnect(id) : api.connect(id))),
    refresh: () => perform(refresh),
  };
}

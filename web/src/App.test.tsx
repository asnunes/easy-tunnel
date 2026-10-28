// @vitest-environment jsdom
import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { cleanup, render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import App from "./App";
import { api } from "./api";

vi.mock("./api", () => ({
  api: {
    snapshot: vi.fn(),
    listen: vi.fn(),
    save: vi.fn(),
    remove: vi.fn(),
    connect: vi.fn(),
    disconnect: vi.fn(),
    resize: vi.fn().mockResolvedValue(undefined),
    quit: vi.fn(),
  },
}));

beforeEach(() => {
  vi.stubGlobal(
    "ResizeObserver",
    class {
      observe() {}
      disconnect() {}
    },
  );
  vi.mocked(api.snapshot).mockResolvedValue({
    connections: [
      {
        id: "lab",
        name: "Home lab",
        sshHostAlias: "homelab",
        forwards: [
          {
            localPort: 8080,
            destinationHost: "localhost",
            destinationPort: 3000,
          },
        ],
      },
    ],
    hosts: ["homelab"],
    hostError: null,
    tunnels: [],
  });
  vi.mocked(api.listen).mockResolvedValue(() => {});
});
afterEach(() => {
  cleanup();
  vi.clearAllMocks();
});

it("opens and cancels the compact editor, then connects from the list", async () => {
  const user = userEvent.setup();
  render(<App />);
  await user.click(
    await screen.findByRole("button", { name: "Edit Home lab" }),
  );
  expect(screen.getByRole("heading").textContent).toBe("Edit connection");
  expect(screen.queryByText("Easy Tunnel")).toBeNull();
  await user.click(screen.getByRole("button", { name: "Cancel" }));
  await user.click(screen.getByRole("switch", { name: "Tunnel for Home lab" }));
  await waitFor(() => expect(api.connect).toHaveBeenCalledWith("lab"));
});

it("shows connection errors received from the Rust worker", async () => {
  render(<App />);
  await screen.findByText("Home lab");
  const callback = vi.mocked(api.listen).mock.calls[0][0];
  const { act } = await import("@testing-library/react");
  act(() =>
    callback([
      {
        connectionId: "lab",
        status: "failed",
        processId: null,
        error: "Permission denied (publickey).",
      },
    ]),
  );
  expect(screen.getByRole("alert").textContent).toContain("Permission denied");
});

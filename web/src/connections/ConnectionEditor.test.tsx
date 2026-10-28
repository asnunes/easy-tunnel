// @vitest-environment jsdom
import { afterEach, expect, it, vi } from "vitest";
import { cleanup, render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { ConnectionEditor } from "./ConnectionEditor";
import type { Connection } from "../api";

afterEach(cleanup);

const connection: Connection = {
  id: "lab",
  name: "Home lab",
  sshHostAlias: "homelab",
  forwards: [
    { localPort: 5433, destinationHost: "localhost", destinationPort: 5432 },
  ],
};

it("adds another forward and saves both without losing the connection identity", async () => {
  const user = userEvent.setup();
  const onSave = vi.fn().mockResolvedValue(undefined);
  render(
    <ConnectionEditor
      connection={connection}
      hosts={["homelab"]}
      active={false}
      busy={false}
      onSave={onSave}
      onCancel={() => {}}
      onRemove={async () => {}}
    />,
  );
  await user.click(screen.getByText("Add port"));
  await user.type(screen.getByLabelText("Local port 2"), "8080");
  await user.type(screen.getByLabelText("Remote port 2"), "3000");
  await user.click(screen.getByRole("button", { name: /^Save$/ }));
  expect(onSave).toHaveBeenCalledWith({
    ...connection,
    forwards: [
      ...connection.forwards,
      { localPort: 8080, destinationHost: "localhost", destinationPort: 3000 },
    ],
  });
});

it("rejects duplicate ports and prevents editing a running connection", async () => {
  const user = userEvent.setup();
  const onSave = vi.fn();
  const { rerender } = render(
    <ConnectionEditor
      connection={connection}
      hosts={["homelab"]}
      active={false}
      busy={false}
      onSave={onSave}
      onCancel={() => {}}
      onRemove={async () => {}}
    />,
  );
  await user.click(screen.getByText("Add port"));
  await user.type(screen.getByLabelText("Local port 2"), "5433");
  await user.type(screen.getByLabelText("Remote port 2"), "3000");
  await user.click(screen.getByRole("button", { name: /^Save$/ }));
  expect(screen.getByRole("alert").textContent).toContain("unique");
  expect(onSave).not.toHaveBeenCalled();
  rerender(
    <ConnectionEditor
      connection={connection}
      hosts={["homelab"]}
      active
      busy={false}
      onSave={onSave}
      onCancel={() => {}}
      onRemove={async () => {}}
    />,
  );
  expect(
    (screen.getByLabelText("Local port 1") as HTMLInputElement).disabled,
  ).toBe(true);
});

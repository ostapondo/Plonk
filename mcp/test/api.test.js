import { test } from "node:test";
import assert from "node:assert/strict";
import {
  text,
  agentIdentityName,
  runWithIdentity,
  processIdentityHolder,
} from "../dist/api.js";

test("a reply carrying an error is flagged as one", () => {
  // Without isError the model reads a refusal as a successful call and carries
  // on as if the window had moved.
  const result = text({ error: "Plonk menu bar app is not running." });
  assert.equal(result.isError, true);
});

test("an ordinary reply is not flagged", () => {
  const result = text({ ok: true, moved: 3 });
  assert.equal(result.isError, undefined);
});

test("a reply is handed back as readable JSON", () => {
  const result = text({ ok: true });
  assert.equal(result.content[0].type, "text");
  assert.deepEqual(JSON.parse(result.content[0].text), { ok: true });
});

test("an identity is visible to everything inside its holder", () => {
  runWithIdentity({ identity: { name: "claude-code", version: "1.0", pid: 1 } }, () => {
    assert.equal(agentIdentityName(), "claude-code");
  });
});

test("one session's identity does not leak into another", () => {
  // Every HTTP session runs in its own holder. If one could see another's
  // name, exclusive mode would gate on whoever connected last.
  runWithIdentity({ identity: { name: "first", version: "", pid: 1 } }, () => {
    runWithIdentity({ identity: { name: "second", version: "", pid: 2 } }, () => {
      assert.equal(agentIdentityName(), "second");
    });
    assert.equal(agentIdentityName(), "first");
  });
});

test("an unidentified caller has no name rather than borrowing one", () => {
  runWithIdentity({}, () => {
    assert.equal(agentIdentityName(), "");
  });
});

test("the process-wide holder is the one stdio fills", () => {
  const holder = processIdentityHolder();
  assert.equal(holder, processIdentityHolder());
  holder.identity = { name: "plonk-cli", version: "", pid: 7 };
  try {
    assert.equal(agentIdentityName(), "plonk-cli");
  } finally {
    holder.identity = undefined;
  }
});

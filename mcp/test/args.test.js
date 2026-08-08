// Run against the compiled output, so what is tested is what ships.
import { test } from "node:test";
import assert from "node:assert/strict";
import { options } from "../dist/args.js";

test("keeps positional arguments in order", () => {
  const { flags, rest } = options(["snap", "Safari", "1"]);
  assert.deepEqual(rest, ["snap", "Safari", "1"]);
  assert.deepEqual(flags, {});
});

test("takes the word after a flag as its value", () => {
  const { flags, rest } = options(["launch", "review", "--screen", "1"]);
  assert.equal(flags.screen, "1");
  assert.deepEqual(rest, ["launch", "review"]);
});

test("a flag at the end of argv is a switch", () => {
  assert.equal(options(["state", "--json"]).flags.json, "true");
});

test("a flag followed by another flag is a switch, not its value", () => {
  const { flags } = options(["shot", "--json", "--mode", "window"]);
  assert.equal(flags.json, "true");
  assert.equal(flags.mode, "window");
});

test("a flag value is not mistaken for a positional argument", () => {
  // --screen 1 must not leave "1" in rest, or `plonk zones --screen 1 thirds`
  // would assign the set named "1".
  const { rest } = options(["zones", "--screen", "1", "thirds"]);
  assert.deepEqual(rest, ["zones", "thirds"]);
});

test("a negative number is a value, not a flag", () => {
  assert.equal(options(["awake", "on", "--minutes", "-1"]).flags.minutes, "-1");
});

test("the last spelling of a repeated flag wins", () => {
  assert.equal(options(["--mode", "region", "--mode", "screen"]).flags.mode, "screen");
});

test("empty argv parses to nothing", () => {
  assert.deepEqual(options([]), { flags: {}, rest: [] });
});

import { spawnSync } from "node:child_process";
import { readFileSync } from "node:fs";
import { test } from "node:test";
import assert from "node:assert/strict";

import { PACKAGE_VERSION } from "../dist/version.js";

const manifest = JSON.parse(readFileSync(new URL("../package.json", import.meta.url), "utf8"));

test("reads the CLI version from package.json", () => {
  assert.equal(PACKAGE_VERSION, manifest.version);
});

for (const flag of ["--version", "-v"]) {
  test(`${flag} prints the package version and exits successfully`, () => {
    const result = spawnSync(process.execPath, ["dist/cli.js", flag], {
      cwd: new URL("..", import.meta.url),
      encoding: "utf8",
    });

    assert.equal(result.status, 0, result.stderr);
    assert.equal(result.stdout.trim(), manifest.version);
  });
}

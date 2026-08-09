#!/usr/bin/env node
// Writes the manifest.json that goes inside the MCPB bundle, taking every
// field from something that already exists rather than from a second copy.
//
// The tool list is the reason this is a script and not a checked-in file. A
// manifest that lists tools is what Claude Desktop and Smithery show before
// anyone installs anything, so a stale list is a promise the server does not
// keep. Here the list comes from the built server itself: we start it, call
// tools/list over stdio, and write down what it answered. It cannot drift.
//
// Usage:
//   node scripts/make-mcpb-manifest.mjs <server-dir> <output-file> [--input-schemas]
//
// <server-dir> holds the compiled server (mcp/dist), <output-file> is where
// the manifest goes. The server is never asked to do any work — tools/list is
// answered from the schema, so Plonk itself does not have to be running.
//
// --input-schemas puts each tool's inputSchema in the manifest, which the MCPB
// schema forbids: it declares tool entries "additionalProperties": false, so
// only name and description are allowed there. It exists for one consumer.
// The Smithery CLI copies manifest.tools into a server card and validates it
// against the MCP tool schema, where inputSchema is *required*; leaving the
// array out instead gets the release rejected as "No values to set". Their two
// checks cannot both be satisfied, so the bundle we publish to Smithery is
// built with this flag and skips MCPB validation, and the one we ship
// everywhere else stays conformant. Drop the flag once Smithery validates
// server cards built from MCPB manifests against the MCPB schema.

import { spawn } from "node:child_process";
import { readFileSync, writeFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const argv = process.argv.slice(2);
const inputSchemas = argv.includes("--input-schemas");
const [serverDir, output] = argv.filter((arg) => !arg.startsWith("--"));

if (!serverDir || !output) {
  console.error("usage: make-mcpb-manifest.mjs <server-dir> <output-file> [--input-schemas]");
  process.exit(1);
}

const pkg = JSON.parse(readFileSync(join(ROOT, "mcp", "package.json"), "utf8"));

/**
 * Starts the compiled server, speaks just enough MCP to get past the
 * handshake, and resolves with the tools it declares.
 *
 * The timeout is not politeness: a server that never answers would otherwise
 * hang a release build, and a bundle is better not built than built with no
 * tools in its manifest.
 */
function listTools(entry) {
  return new Promise((resolve, reject) => {
    const server = spawn(process.execPath, [entry], { stdio: ["pipe", "pipe", "ignore"] });
    const timer = setTimeout(() => {
      server.kill();
      reject(new Error(`${entry} did not answer tools/list within 15s`));
    }, 15_000);

    const send = (message) => server.stdin.write(`${JSON.stringify(message)}\n`);
    let buffered = "";

    server.on("error", reject);
    server.stdout.on("data", (chunk) => {
      buffered += chunk;
      const lines = buffered.split("\n");
      buffered = lines.pop() ?? "";
      for (const line of lines) {
        if (!line.trim()) continue;
        let message;
        try {
          message = JSON.parse(line);
        } catch {
          continue; // Not every line has to be ours.
        }
        if (message.id === 1) {
          send({ jsonrpc: "2.0", method: "notifications/initialized" });
          send({ jsonrpc: "2.0", id: 2, method: "tools/list" });
        }
        if (message.id === 2) {
          clearTimeout(timer);
          server.kill();
          resolve(message.result?.tools ?? []);
        }
      }
    });

    send({
      jsonrpc: "2.0",
      id: 1,
      method: "initialize",
      params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "make-mcpb-manifest", version: pkg.version },
      },
    });
  });
}

const tools = await listTools(join(serverDir, "server.js"));
if (tools.length === 0) throw new Error("the server declared no tools — refusing to write a manifest that says so");

// Descriptions in the server are written for a model deciding whether to call
// the tool, so they run long. A directory listing shows one line, so take the
// first sentence and leave the rest to the server itself.
const summarize = (text = "") => text.split(/(?<=\.)\s/)[0].trim();

const manifest = {
  manifest_version: "0.3",
  name: "plonk",
  display_name: "Plonk",
  version: pkg.version,
  description: pkg.description,
  long_description:
    "Plonk is a macOS window manager with snap zones you draw yourself and workspaces that reopen your apps on the " +
    "right monitor. This bundle installs its MCP server, which lets an agent do the same things you can: place " +
    "windows, launch a saved workspace, hold sleep off, take a screenshot, read text off the screen with on-device " +
    "OCR.\n\n" +
    "The server is a bridge, not the app. It talks to Plonk over a loopback API on your own Mac, so **Plonk has to " +
    "be installed and running** for the tools to do anything: `brew install --cask ostapondo/plonk/plonk`. Nothing " +
    "leaves the machine — no account, no cloud, no telemetry.",
  author: {
    name: "ostapondo",
    url: "https://github.com/ostapondo",
  },
  repository: {
    type: "git",
    url: "https://github.com/ostapondo/plonk",
  },
  homepage: "https://ostapondo.github.io/Plonk/",
  documentation: "https://github.com/ostapondo/plonk#readme",
  support: "https://github.com/ostapondo/plonk/issues",
  icon: "icon.png",
  server: {
    type: "node",
    entry_point: "server/server.js",
    mcp_config: {
      command: "node",
      args: ["${__dirname}/server/server.js"],
    },
  },
  tools: tools.map((tool) => ({
    name: tool.name,
    description: summarize(tool.description),
    // Off-spec, and only ever set for Smithery — see the note above the flag.
    ...(inputSchemas ? { inputSchema: tool.inputSchema } : {}),
  })),
  keywords: pkg.keywords,
  license: pkg.license,
  compatibility: {
    // Everything here goes through the macOS Accessibility API. On another
    // platform the bundle would install and every call would fail, so say so
    // in the manifest instead of in a support thread.
    platforms: ["darwin"],
    runtimes: { node: ">=18.0.0" },
  },
};

writeFileSync(output, `${JSON.stringify(manifest, null, 2)}\n`);
console.log(`manifest.json: ${tools.length} tools${inputSchemas ? " with input schemas" : ""}, version ${pkg.version}`);

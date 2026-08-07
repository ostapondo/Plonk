#!/usr/bin/env node
// Plonk MCP server — bridges AI agents to the Plonk menu bar app (localhost HTTP).
//
// Default transport is stdio: one process per client, spawned by it.
// `--http [--port N]` serves Streamable HTTP at http://127.0.0.1:<port>/mcp
// instead, for clients that cannot spawn a process — several at once.
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { BASE, isAppReachable, setAgentIdentity } from "./api.js";
import { createPlonkServer, startHello, watchClientInfo } from "./factory.js";
import { serveHttp } from "./http.js";

const args = process.argv.slice(2);

if (args.includes("--http")) {
  const portIndex = args.indexOf("--port");
  const port = portIndex >= 0 ? Number(args[portIndex + 1]) : 43918;
  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    console.error("plonk-mcp: --port needs a number between 1 and 65535");
    process.exit(1);
  }
  await serveHttp(port);
} else {
  const server = createPlonkServer();
  watchClientInfo(server, ({ name, version }) => {
    setAgentIdentity(name, version);
    startHello({ name, version, pid: process.pid });
  });
  await server.connect(new StdioServerTransport());
}

// stdout carries the stdio protocol, so this goes to stderr. Not fatal: the
// app may still be starting, and every tool reports the same thing on its own.
if (!(await isAppReachable())) {
  console.error(`plonk-mcp: nothing is answering on ${BASE} — launch Plonk.app or its tools will fail.`);
}

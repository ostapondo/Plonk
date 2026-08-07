#!/usr/bin/env node
// Plonk MCP server — bridges AI agents to the Plonk menu bar app (localhost HTTP).
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { BASE, isAppReachable } from "./api.js";
import { register as registerState } from "./tools/state.js";
import { register as registerLayouts } from "./tools/layouts.js";
import { register as registerWorkspaces } from "./tools/workspaces.js";
import { register as registerZones } from "./tools/zones.js";
import { register as registerAwake } from "./tools/awake.js";
import { register as registerScreenshot } from "./tools/screenshot.js";
import { register as registerAnnotate } from "./tools/annotate.js";

const server = new McpServer({ name: "plonk", version: "1.0.0" });

registerState(server);
registerWorkspaces(server);
registerLayouts(server);
registerZones(server);
registerAwake(server);
registerScreenshot(server);
registerAnnotate(server);

const transport = new StdioServerTransport();
await server.connect(transport);

// stdout carries the protocol, so this goes to stderr. Not fatal: the app may
// still be starting, and every tool reports the same thing on its own.
if (!(await isAppReachable())) {
  console.error(`plonk-mcp: nothing is answering on ${BASE} — launch Plonk.app or its tools will fail.`);
}

#!/usr/bin/env node
// Plonk MCP server — bridges AI agents to the Plonk menu bar app (localhost HTTP).
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { createRequire } from "node:module";
import { BASE, call, isAppReachable, setAgentIdentity } from "./api.js";
import { register as registerState } from "./tools/state.js";
import { register as registerLayouts } from "./tools/layouts.js";
import { register as registerWorkspaces } from "./tools/workspaces.js";
import { register as registerZones } from "./tools/zones.js";
import { register as registerAwake } from "./tools/awake.js";
import { register as registerScreenshot } from "./tools/screenshot.js";
import { register as registerAnnotate } from "./tools/annotate.js";
import { register as registerAgents } from "./tools/agents.js";

const { version } = createRequire(import.meta.url)("../package.json");
const server = new McpServer({ name: "plonk", version });

registerState(server);
registerWorkspaces(server);
registerLayouts(server);
registerZones(server);
registerAwake(server);
registerScreenshot(server);
registerAnnotate(server);
registerAgents(server);

// The handshake tells us which client we serve; PLONK_AGENT_NAME lets the user
// name a session by hand ("work", "pet-project"). Registering keeps this
// client on the app's agent list; the heartbeat keeps it marked online.
// The initialized notification can outrun the initialize handler's bookkeeping
// in the SDK, leaving clientInfo briefly unset, so poll instead of trusting
// the callback's timing.
function identify(attempt = 0): void {
  const client = server.server.getClientVersion();
  if (!client && attempt < 50) {
    setTimeout(() => identify(attempt + 1), 100).unref();
    return;
  }
  const agentName = (process.env.PLONK_AGENT_NAME || client?.name || "mcp-client").replaceAll("/", "-");
  const agentVersion = client?.version ?? "";
  setAgentIdentity(agentName, agentVersion);
  const hello = () =>
    call("/agents/hello", {
      method: "POST",
      body: { name: agentName, version: agentVersion, pid: process.pid },
      timeoutMs: 3_000,
    });
  void hello();
  setInterval(hello, 30_000).unref();
}
server.server.oninitialized = () => identify();

const transport = new StdioServerTransport();
await server.connect(transport);

// stdout carries the protocol, so this goes to stderr. Not fatal: the app may
// still be starting, and every tool reports the same thing on its own.
if (!(await isAppReachable())) {
  console.error(`plonk-mcp: nothing is answering on ${BASE} — launch Plonk.app or its tools will fail.`);
}

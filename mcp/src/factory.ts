// Builds a fully-registered Plonk MCP server. Each connected client gets its
// own instance, so per-session state (clientInfo) stays separate.
import { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { createRequire } from "node:module";
import { call, type AgentIdentity } from "./api.js";
import { register as registerState } from "./tools/state.js";
import { register as registerLayouts } from "./tools/layouts.js";
import { register as registerWorkspaces } from "./tools/workspaces.js";
import { register as registerZones } from "./tools/zones.js";
import { register as registerAwake } from "./tools/awake.js";
import { register as registerScreenshot } from "./tools/screenshot.js";
import { register as registerAnnotate } from "./tools/annotate.js";
import { register as registerText } from "./tools/text.js";
import { register as registerRuler } from "./tools/ruler.js";
import { register as registerAgents } from "./tools/agents.js";
import { register as registerUpdate } from "./tools/update.js";

const { version } = createRequire(import.meta.url)("../package.json");

export function createPlonkServer(): McpServer {
  const server = new McpServer({ name: "plonk", version });
  registerState(server);
  registerWorkspaces(server);
  registerLayouts(server);
  registerZones(server);
  registerAwake(server);
  registerScreenshot(server);
  registerAnnotate(server);
  registerText(server);
  registerRuler(server);
  registerAgents(server);
  registerUpdate(server);
  return server;
}

/** Reports the client's name and version once the MCP handshake lands.
 * PLONK_AGENT_NAME lets the user name a session by hand ("work",
 * "pet-project"). The initialized notification can outrun the initialize
 * handler's bookkeeping in the SDK, leaving clientInfo briefly unset, so this
 * polls instead of trusting the callback's timing. */
export function watchClientInfo(
  server: McpServer,
  onKnown: (info: { name: string; version: string }) => void
): void {
  const poll = (attempt = 0): void => {
    const client = server.server.getClientVersion();
    if (!client && attempt < 50) {
      setTimeout(() => poll(attempt + 1), 100).unref();
      return;
    }
    const name = (process.env.PLONK_AGENT_NAME || client?.name || "mcp-client").replaceAll("/", "-");
    onKnown({ name, version: client?.version ?? "" });
  };
  server.server.oninitialized = () => poll();
}

/** Registers the identity with the app and keeps it marked online with a
 * heartbeat. Returns a stop function for when the session ends. */
export function startHello(identity: AgentIdentity): () => void {
  const hello = () =>
    call("/agents/hello", {
      method: "POST",
      body: { name: identity.name, version: identity.version, pid: identity.pid },
      timeoutMs: 3_000,
    });
  void hello();
  const timer = setInterval(hello, 30_000);
  timer.unref();
  return () => clearInterval(timer);
}

const sleep = (ms: number) => new Promise((resolve) => setTimeout(resolve, ms).unref());

/** Long-polls the app's inbox for tasks addressed to this client — the
 * channel that lets Plonk (voice, hotkeys, other agents) reach the agent.
 * A task is handed to the client's own model through MCP sampling, so the loop
 * only runs for clients that declared that capability: polling drains the
 * queue, and draining what this client cannot act on would silently throw the
 * user's words away instead of leaving them for a CLI adapter.
 * Returns a stop function; it is a no-op when the loop never started. */
export function startInboxLoop(server: McpServer, identity: AgentIdentity): () => void {
  if (!server.server.getClientCapabilities()?.sampling) {
    console.error(
      `plonk-mcp: ${identity.name} does not support MCP sampling, so Plonk cannot hand it spoken ` +
        `or queued prompts. Configure a CLI adapter for it in Plonk (Settings, AI · MCP) to use voice.`
    );
    return () => {};
  }
  let stopped = false;
  const loop = async (): Promise<void> => {
    while (!stopped) {
      const res = await call<{ tasks?: { id: string; prompt: string }[] }>(
        `/agents/inbox?agent=${encodeURIComponent(identity.name)}&wait=25`,
        { timeoutMs: 30_000 }
      );
      if (stopped) return;
      if ("error" in res) {
        await sleep(5_000);
        continue;
      }
      for (const task of res.tasks ?? []) {
        server.server
          .createMessage({
            messages: [{ role: "user", content: { type: "text", text: task.prompt } }],
            maxTokens: 4_000,
            systemPrompt:
              "The user sent this through Plonk, the Mac window manager this agent controls over MCP. Act on it with the plonk tools where they apply.",
          })
          .catch((err) => console.error(`plonk-mcp: sampling failed for task ${task.id}:`, err));
      }
    }
  };
  void loop();
  return () => {
    stopped = true;
  };
}

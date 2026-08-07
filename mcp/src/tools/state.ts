import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { call, text, type State } from "../api.js";

export function register(server: McpServer): void {
  server.tool(
    "get_state",
    "Get the current desktop state: all screens/monitors (index, frame, visible area — coordinates have origin at top-left of the primary screen, y grows down), all open windows (app name, title, which screen it is on, absolute frame, and 'fraction' — its position as fractions 0..1 of that screen's visible area), saved layout names, and whether keep-awake is on. ALWAYS call this first before applying a layout, to see which apps are running and how many monitors there are.",
    {},
    async () => text(await call<State>("/state"))
  );
}

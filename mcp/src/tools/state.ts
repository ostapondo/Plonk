import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { call, text, type State } from "../api.js";

export function register(server: McpServer): void {
  server.tool(
    "get_state",
    "Get the current desktop state: all screens/monitors (index, frame, visible area — coordinates have origin at top-left of the primary screen, y grows down), all open windows (app name, title, which screen it is on, absolute frame, and 'fraction' — its position as fractions 0..1 of that screen's visible area), saved layout names, 'app_rules' (where each app's new windows open, see set_app_rule), 'place_new_windows' and 'auto_fill_zones', whether a keep-awake session is holding, and 'disabled_features': the modules the user switched off in Plonk (zones, workspaces, shot, ruler, awake and so on). A tool belonging to one of those fails with an error saying so until the user switches it back on. ALWAYS call this first before applying a layout, to see which apps are running and how many monitors there are.",
    {},
    async () => text(await call<State>("/state"))
  );
}

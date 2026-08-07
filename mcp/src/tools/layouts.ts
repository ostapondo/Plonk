import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, text, type LayoutResults } from "../api.js";
import { itemsSchema } from "../schemas.js";

export function register(server: McpServer): void {
  server.tool(
    "apply_layout",
    "Move and resize windows to build a layout. Each item places one window: 'app' is the app name (fuzzy matched), optional 'title' filters windows of that app by title substring, optional 'screen' is the monitor index from get_state (each monitor can get its own layout — just send items with different 'screen' values; defaults to the screen the window is currently on), 'frame' is {x,y,w,h} as fractions 0..1 of that screen's visible area with origin at TOP-LEFT (left half = {x:0,y:0,w:0.5,h:1}; bottom-right quarter = {x:0.5,y:0.5,w:0.5,h:0.5}; centered 60% = {x:0.2,y:0.15,w:0.6,h:0.7}). Windows are unminimized if needed. Returns per-item success/errors.",
    { items: itemsSchema },
    async ({ items }) => text(await call<LayoutResults>("/layout", { method: "POST", body: { items } }))
  );

  // Saved layouts became workspaces, which also know how to launch their apps.
  // These two stay so older clients keep working; prefer save_workspace and
  // launch_workspace, which can carry an app's bundle id and what it opens.
  server.tool(
    "save_layout",
    "Save the named window arrangement as a workspace. Legacy name kept for older clients — new integrations should call save_workspace, which can also record whether running apps get moved into place. Omit 'items' to snapshot the windows exactly as they are on screen right now; pass 'items' to describe the arrangement explicitly. Saving over an existing name replaces it. Saved workspaces are listed in get_state, with their full contents.",
    {
      name: z.string().describe("Workspace name, e.g. 'work', 'focus'"),
      items: itemsSchema.optional(),
    },
    async ({ name, items }) => text(await call("/workspaces/save", { method: "POST", body: { name, items } }))
  );

  server.tool(
    "apply_saved_layout",
    "Launch a saved workspace by name. Legacy name kept for older clients — new integrations should call launch_workspace, which adds a 'screen' option to pull the whole workspace onto one monitor. Opens every app that is not running, waits for its windows, and moves them into the saved positions; macOS cannot open an app straight into a position, so windows appear first and jump into place. Returns per-app success and reports apps that never opened a window. Takes up to a minute for a large workspace.",
    { name: z.string() },
    async ({ name }) =>
      text(await call<LayoutResults>("/workspaces/launch", { method: "POST", body: { name }, timeoutMs: 90_000 }))
  );

  server.tool(
    "snap_window",
    "Drop one window into a numbered zone of the snap-zone set assigned to that monitor. The numbers are the ones Plonk draws on the zones while a window is dragged, so 'the middle zone' of a three-zone set is 2. Zone sets and their per-monitor assignment are in get_state; use apply_layout instead when the user describes a size rather than a zone.",
    {
      app: z.string().describe("App name to match, e.g. 'Visual Studio Code'"),
      zone: z.number().int().min(1).describe("1-based zone number, as shown on the drag overlay"),
      title: z.string().optional().describe("Only windows whose title contains this substring"),
      screen: z.number().int().optional().describe("Monitor index; defaults to the one the window is on"),
    },
    async (args) => text(await call("/layout/zone", { method: "POST", body: args }))
  );

  server.tool(
    "delete_layout",
    "Delete the saved workspace with that name, whether it was saved with save_layout or save_workspace. Legacy name kept for older clients — new integrations should call delete_workspace, which does the same. Use it to clean up saved workspaces that are no longer wanted; existing names are listed in get_state.",
    { name: z.string() },
    async ({ name }) => text(await call("/workspaces/delete", { method: "POST", body: { name } }))
  );
}

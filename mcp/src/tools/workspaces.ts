import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, text, type LaunchResults } from "../api.js";
import { workspaceItemsSchema } from "../schemas.js";

// Launching waits for every app to open a window, which the app gives up on
// after 20 seconds per app.
const LAUNCH_TIMEOUT_MS = 90_000;

export function register(server: McpServer): void {
  server.tool(
    "save_workspace",
    "Save a workspace: the apps of a desktop setup, where each window goes, and what each app should open. Pass 'items' to describe the arrangement, or omit them to snapshot the windows exactly as they are on screen right now. Saving over an existing name replaces it. Saved workspaces are listed in get_state, with their full contents.",
    {
      name: z.string().describe("Workspace name, e.g. 'work', 'writing'"),
      items: workspaceItemsSchema.optional(),
      move_existing: z
        .boolean()
        .optional()
        .describe(
          "When true (the default), an app that is already running has its windows moved into place. When false, running apps are left alone and only missing apps are launched."
        ),
    },
    async ({ name, items, move_existing }) =>
      text(await call("/workspaces/save", { method: "POST", body: { name, items, move_existing } }))
  );

  server.tool(
    "launch_workspace",
    "Launch a saved workspace: opens every app that is not running, waits for its windows, and moves them into the saved positions. Each window returns to the monitor it was captured on, so a workspace spanning several displays comes back spanning them. macOS cannot open an app straight into a position, so windows appear first and jump into place. Returns per-app success, and reports apps that never opened a window. Takes up to a minute for a large workspace.",
    {
      name: z.string(),
      screen: z
        .number()
        .int()
        .optional()
        .describe(
          "Pull the whole workspace onto this monitor instead of the ones it was captured on. Use when a display is no longer attached, or to move a setup to another screen."
        ),
    },
    async ({ name, screen }) =>
      text(
        await call<LaunchResults>("/workspaces/launch", {
          method: "POST",
          body: { name, screen },
          timeoutMs: LAUNCH_TIMEOUT_MS,
        })
      )
  );

  server.tool(
    "delete_workspace",
    "Delete a saved workspace by name. Use this to clean up workspaces you created that are no longer wanted.",
    { name: z.string() },
    async ({ name }) => text(await call("/workspaces/delete", { method: "POST", body: { name } }))
  );
}

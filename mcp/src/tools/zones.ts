import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, text } from "../api.js";
import { zonesSchema } from "../schemas.js";

export function register(server: McpServer): void {
  server.tool(
    "save_zone_set",
    "Create or replace a named zone set used for drag snapping. Zones are rectangles {x,y,w,h} as fractions 0..1 of a screen's visible area, origin TOP-LEFT; each zone must stay inside the screen, but zones may overlap each other (the smallest one under the cursor wins). Pass 'screen' to also assign the set to that monitor so it becomes active immediately. Built-in sets already exist: Halves, Thirds, 60 / 40, Quarters, Priority.",
    {
      name: z.string().describe("Zone set name, e.g. 'coding'"),
      zones: zonesSchema,
      screen: z.number().int().optional().describe("Monitor index to assign this set to (0 = primary)"),
    },
    async ({ name, zones, screen }) =>
      text(await call("/zones/save", { method: "POST", body: { name, zones, screen } }))
  );

  server.tool(
    "assign_zone_set",
    "Assign a zone set (built-in or saved) to a monitor. Omit 'name' to restore the default set (Halves); pass 'edge' for edge snapping instead of zones. Available set names and current assignments are in get_state.",
    {
      screen: z.number().int().describe("Monitor index (0 = primary)"),
      name: z.string().optional().describe("Zone set name, or 'edge' for edge snapping; omit for the default set"),
    },
    async ({ screen, name }) => text(await call("/zones/assign", { method: "POST", body: { screen, name } }))
  );

  server.tool(
    "delete_zone_set",
    "Delete a saved zone set. Monitors using it fall back to the default set. Built-in sets cannot be deleted.",
    { name: z.string() },
    async ({ name }) => text(await call("/zones/delete", { method: "POST", body: { name } }))
  );
}

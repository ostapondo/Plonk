import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, text } from "../api.js";
import { zonesSchema } from "../schemas.js";

export function register(server: McpServer): void {
  server.tool(
    "save_zone_set",
    "Create or replace a named zone set used for drag snapping. Zones are rectangles {x,y,w,h} as fractions 0..1 of a screen's visible area, origin TOP-LEFT; each zone must stay inside the screen, but zones may overlap each other (the smallest one under the cursor wins). A zone may also carry a 'name' ('chat', 'editor'): it is drawn under the zone's number, the user can say it out loud, and snap_window takes it instead of the number; names must be unique within the set, ignoring case, and cannot be a bare number. Pass 'screen' to also assign the set to that monitor so it becomes active immediately. Pass 'gap' to give this set its own spacing around windows in points, or null to make it follow the default gap again; omitting it keeps whatever the set had. Built-in sets already exist: Halves, Thirds, 60 / 40, Quarters, Priority.",
    {
      name: z.string().describe("Zone set name, e.g. 'coding'"),
      zones: zonesSchema,
      screen: z.number().int().optional().describe("Monitor index to assign this set to (0 = primary)"),
      gap: z
        .number()
        .min(0)
        .nullable()
        .optional()
        .describe("This set's own gap in points; null follows the default gap (get_state.zone_gap); omit to leave unchanged"),
    },
    async ({ name, zones, screen, gap }) =>
      text(await call("/zones/save", { method: "POST", body: { name, zones, screen, gap } }))
  );

  server.tool(
    "assign_zone_set",
    "Assign a zone set (built-in or saved) to one monitor, so dragging a window there snaps to that set's zones. Each monitor keeps its own assignment; assigning replaces whatever that monitor used before and takes effect on the next drag. Omit 'name' to restore the default set (Halves); pass 'edge' for plain edge snapping instead of zones. Available set names and current per-monitor assignments are in get_state.",
    {
      screen: z.number().int().describe("Monitor index (0 = primary)"),
      name: z.string().optional().describe("Zone set name, or 'edge' for edge snapping; omit for the default set"),
    },
    async ({ screen, name }) => text(await call("/zones/assign", { method: "POST", body: { screen, name } }))
  );

  server.tool(
    "delete_zone_set",
    "Delete a saved zone set by name. Any monitor currently using it falls back to the default set (Halves), so snapping keeps working. Only sets made with save_zone_set can go: the built-ins (Halves, Thirds, 60 / 40, Quarters, Priority) are refused. Deleting is immediate and cannot be undone — the zones would have to be described again. Saved sets and their per-monitor assignments are listed in get_state; use assign_zone_set instead when a monitor should merely stop using a set that others still need.",
    { name: z.string().describe("Saved zone set name, as shown in get_state") },
    async ({ name }) => text(await call("/zones/delete", { method: "POST", body: { name } }))
  );

  server.tool(
    "set_app_rule",
    "Make an app's windows open into a numbered zone from now on, so an arrangement holds without anyone dragging: 'Slack always in zone 1 on the second monitor'. 'app' is matched anywhere in the app's name or bundle id, case-insensitively, the way get_state.excluded_apps entries are; a bundle id such as 'com.tinyspeck.slackmacgap' is the safest form. 'zone' is the number Plonk draws on the zone (1-based) in the set assigned to that monitor. 'screen' is a monitor index from get_state and is stored as that display's identity, so it survives a reboot renumbering the screens; omit it and the window stays on whichever screen it opened on. One rule per app: setting it again replaces the old one; a rule that names the app exactly wins over a bare-word rule. Applies to ordinary windows that open after it is set, not to windows already open (use snap_window for those) and not to dialogs or panels. An app on get_state.excluded_apps is left alone even with a rule. A rule beats the habit Plonk keeps of where an app's last window went, and both beat filling an empty zone. Current rules are get_state.app_rules. Fails when 'screen' names a monitor that is not attached or a zone that monitor's set does not have.",
    {
      app: z.string().describe("App name or bundle id to match, e.g. 'com.apple.Safari' or 'Safari'"),
      zone: z.number().int().min(1).describe("1-based zone number, as shown on the drag overlay"),
      screen: z.number().int().optional().describe("Monitor index from get_state (0 = primary); omit for the screen the window opens on"),
    },
    async ({ app, zone, screen }) =>
      text(await call("/zones/rules", { method: "POST", body: { app, zone, screen } }))
  );

  server.tool(
    "clear_app_rule",
    "Remove the rule set for an app with set_app_rule, so its new windows open wherever the app puts them again, or where its last window went when that habit is switched on in Plonk. 'app' is the pattern exactly as get_state.app_rules lists it, ignoring case. Fails when no rule matches; nothing else changes.",
    { app: z.string().describe("The app pattern as listed in get_state.app_rules") },
    async ({ app }) => text(await call("/zones/rules/delete", { method: "POST", body: { app } }))
  );
}

import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, text } from "../api.js";

export function register(server: McpServer): void {
  server.tool(
    "set_active",
    "Turn stay-active on or off, so chat apps go on showing the user as available instead of Away. " +
      "Pick this over 'set_awake' by what is being protected: set_awake holds a power assertion and stops the Mac sleeping, which does nothing for a Slack or Teams status; set_active resets the system idle timer by posting a Shift keypress every two minutes, which is what those apps actually read. Resetting the idle timer also postpones sleep, so stay-active implies keep-awake and there is no need to turn both on. " +
      "Two ways to end the session: 'until' ends it at a wall-clock time ('17:00', or an ISO-8601 timestamp); 'minutes' ends it after a countdown. Give neither and it runs until switched off, or until the user's configured default timeout expires. " +
      "This only starts and ends sessions. The recurring schedule (hours and weekdays) and the list of apps that arm it automatically are settings on the Stay active page, not parameters here; get_state reports both under 'active_details'. " +
      "Switching it by hand overrides the schedule until the schedule itself next changes, so turning it off during scheduled hours lasts until those hours end rather than being undone on the next tick. " +
      "Returns 'active', whether a keypress is actually being posted right now, and 'status', what happened in words. Those differ when Plonk has no Accessibility permission (nothing can be posted) or when the user disallowed running on battery and the Mac is unplugged; neither is reported as an error, since the request was understood. An 'until' that has already passed is an error.",
    {
      on: z.boolean(),
      minutes: z
        .number()
        .int()
        .min(1)
        .optional()
        .describe("End the session after this many minutes"),
      until: z
        .string()
        .optional()
        .describe(
          "End at a time of day, e.g. '17:00' (the next such moment — tomorrow if today's has passed), or an ISO-8601 timestamp like '2026-08-08T17:00:00Z'"
        ),
    },
    async ({ on, minutes, until }) =>
      text(await call("/active", { method: "POST", body: { on, minutes, until } }))
  );
}

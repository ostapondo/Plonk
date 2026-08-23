import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, text } from "../api.js";

export function register(server: McpServer): void {
  server.tool(
    "set_awake",
    "Keep the Mac from sleeping, and optionally keep the user shown as available in chat apps. One session with two levels, called Pulse in the app. " +
      "'available' picks the level. Left off, Plonk holds a power assertion: the Mac does not sleep, but Slack and Teams still slide the user to Away, because those read the system idle timer and an assertion does not touch it. Turned on, Plonk also resets that idle timer with a Shift keypress every two minutes, which is what keeps a chat status green — and which postpones sleep by itself, so being available always includes being awake. Use it whenever the point is how the user looks to other people rather than whether a job finishes. " +
      "Three ways to end the session, in order of preference: 'pid' ends it the moment that process exits — best by far when something is running, because a build or a render knows when it is finished and nothing is left holding the machine awake afterwards; 'until' ends it at a wall-clock time ('17:00', or an ISO-8601 timestamp); 'minutes' ends it after a countdown. Give none of them and it runs until switched off, or until the user's configured default timeout expires. " +
      "Switching it by hand overrides the schedule until the schedule itself next changes, so turning it off during scheduled hours lasts until those hours end rather than being undone on the next tick. Sessions Plonk starts on its own — a recurring schedule of hours and weekdays, a list of apps whose being open arms it, or the charger being plugged in — are settings on the Pulse page rather than parameters here; get_state reports all of them under 'awake_details'. " +
      "Behavior also follows those settings: a session may pause on battery, so the returned 'status' is what actually happened, 'awake' is whether an assertion is held right now, and 'available' is whether a keypress is actually being posted. Those differ from what was asked for when Plonk has no Accessibility permission (nothing can be posted, though the Mac still stays awake) or when the user disallowed running on battery and the Mac is unplugged; neither is an error, since the request was understood. The menu bar cube glows while a session holds. " +
      "A process-bound session is deliberately not restored if Plonk restarts, since the pid would mean nothing by then. Errors come back for a pid that is not running or a time that has already passed.",
    {
      on: z.boolean(),
      available: z
        .boolean()
        .optional()
        .describe(
          "Also reset the idle timer, so chat apps go on showing the user as available instead of Away. This is the user's stored level rather than a property of one session: later sessions run at it too, until it is changed again. Omit to leave it as the user set it"
        ),
      minutes: z.number().int().min(1).optional().describe("End the session after this many minutes"),
      until: z
        .string()
        .optional()
        .describe(
          "End at a time of day, e.g. '17:00' (the next such moment — tomorrow if today's has passed), or an ISO-8601 timestamp like '2026-08-08T17:00:00Z'"
        ),
      pid: z
        .number()
        .int()
        .min(1)
        .optional()
        .describe(
          "End when this process exits. Use the pid of the long job being waited on; get_state lists a pid for every open window"
        ),
    },
    async ({ on, available, minutes, until, pid }) =>
      text(await call("/awake", { method: "POST", body: { on, available, minutes, until, pid } }))
  );
}

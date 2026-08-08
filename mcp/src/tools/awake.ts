import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, text } from "../api.js";

export function register(server: McpServer): void {
  server.tool(
    "set_awake",
    "Turn keep-awake on or off, so the Mac does not sleep part-way through something. " +
      "Three ways to end the session, in order of preference: 'pid' ends it the moment that process exits — best by far when something is running, because a build or a render knows when it is finished and nothing is left holding the machine awake afterwards; 'until' ends it at a wall-clock time ('17:00', or an ISO-8601 timestamp); 'minutes' ends it after a countdown. Give none of them and it runs until switched off. " +
      "Behavior also follows the user's settings: keep-awake may pause on battery or engage automatically while charging, so the returned 'status' is what actually happened and 'awake' is whether an assertion is held right now. The menu bar icon glows while it is. " +
      "A process-bound session is deliberately not restored if Plonk restarts, since the pid would mean nothing by then. Errors come back for a pid that is not running or a time that has already passed.",
    {
      on: z.boolean(),
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
    async ({ on, minutes, until, pid }) =>
      text(await call("/awake", { method: "POST", body: { on, minutes, until, pid } }))
  );
}

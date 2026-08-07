import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, text } from "../api.js";

export function register(server: McpServer): void {
  server.tool(
    "set_awake",
    "Turn keep-awake on or off. Optional 'minutes' limits the session (it ends automatically). Behavior also follows the user's settings: keep-awake may pause on battery or engage automatically while charging; the returned 'status' explains the current state. The menu bar icon glows while active.",
    {
      on: z.boolean(),
      minutes: z.number().int().min(1).optional().describe("Auto-off after this many minutes"),
    },
    async ({ on, minutes }) => text(await call("/awake", { method: "POST", body: { on, minutes } }))
  );
}

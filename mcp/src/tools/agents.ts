import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { agentIdentityName, call, text } from "../api.js";

export function register(server: McpServer): void {
  server.tool(
    "select_agent",
    "Make an agent the user's active one in Plonk. Omit 'name' to select this client itself; pass \"\" to clear the choice so any agent may drive. The active agent shows in Plonk's menu bar and settings, and is where voice and other outgoing requests will go. With 'exclusive' true the app also rejects window and settings changes from every other agent (they can still read state and take screenshots). Connected agents are listed in get_state under 'agents'.",
    {
      name: z
        .string()
        .optional()
        .describe("Agent name from get_state's 'agents'; omit for this client, \"\" to clear"),
      exclusive: z
        .boolean()
        .optional()
        .describe("Also turn 'only the active agent controls' on or off"),
    },
    async ({ name, exclusive }) => {
      const target = name === undefined ? agentIdentityName() : name;
      const selected = await call("/agents/select", { method: "POST", body: { name: target } });
      if ("error" in selected || exclusive === undefined) return text(selected);
      const mode = await call("/agents/exclusive", { method: "POST", body: { on: exclusive } });
      return text({ ...selected, ...mode });
    }
  );
}

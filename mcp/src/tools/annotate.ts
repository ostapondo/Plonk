import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, text } from "../api.js";

const pointSchema = z.object({
  x: z.number().min(0).max(1),
  y: z.number().min(0).max(1),
});

export function register(server: McpServer): void {
  server.tool(
    "annotate_screenshot",
    "Draw on a screenshot you already took, then copy it to the clipboard and show it to the user. Call take_screenshot first and LOOK at the image: you cannot know where anything is until you have seen it. Points are fractions 0..1 of the image, origin TOP-LEFT, so a rectangle around a left sidebar that is a seventh of the width and starts under the title bar is [{x:0,y:0.05},{x:0.14,y:1}]. Rectangle and ellipse take two opposite corners, arrow takes start then tip, pen and highlight take a run of points. Returns the marked image so you can check what you drew.",
    {
      path: z.string().describe("Path returned by take_screenshot"),
      marks: z
        .array(
          z.object({
            kind: z.enum(["rectangle", "ellipse", "arrow", "pen", "highlight"]),
            points: z.array(pointSchema).min(2),
            color: z
              .enum(["red", "orange", "yellow", "green", "blue", "purple", "black", "white"])
              .optional()
              .describe("Defaults to red"),
            width: z
              .number()
              .optional()
              .describe("Stroke width as a fraction of image width; defaults to 0.004"),
          })
        )
        .min(1),
      output: z.string().optional().describe("Where to write it; defaults to the source name plus ' marked'"),
      clipboard: z.boolean().optional().describe("Copy the result to the clipboard (default true)"),
    },
    async (args) => text(await call("/shot/annotate", { method: "POST", body: args }))
  );
}

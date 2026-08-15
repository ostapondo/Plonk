import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, text } from "../api.js";

// The interactive mode hands the user a crosshair and waits for them.
const INTERACTIVE_TIMEOUT_MS = 5 * 60_000;

const pointSchema = z.object({
  x: z.number().min(0).max(1),
  y: z.number().min(0).max(1),
});

export function register(server: McpServer): void {
  server.tool(
    "measure_screen",
    "Measure something on the screen in points and pixels, without taking a picture of it. Plonk photographs the screen once, finds where the colour under the given point stops changing in each direction, and returns that box — the button, the cell, the panel, the gap — the way a designer's ruler would. " +
      "Prefer this over take_screenshot whenever the answer is a number: how tall that row is, whether two paddings match, how wide the sidebar is, is that tap target 44 points. An image would cost far more tokens and still have to be eyeballed. Use extract_text when the answer is words, and take_screenshot when it is 'what does this look like'. " +
      "Three ways to ask. Pass 'point' for the box under one place on the screen. Pass 'from' and 'to' for the straight-line distance between two places, which needs no capture at all. Pass 'interactive' to hand the user a crosshair and wait up to five minutes while they measure it themselves, which is the one to use when it is their screen and their judgement of what to measure. " +
      "Points are fractions 0..1 of the screen's visible area with origin at TOP-LEFT, the same space apply_layout and save_zone_set use, so {x:0.5,y:0.5} is the middle of the screen. " +
      "Returns 'points' {x,y,w,h} in screen points (absolute, origin top-left of the primary display), 'pixels' {w,h} in the display's own pixels — twice the points on a Retina screen, which is the difference that matters when checking an asset — 'fraction' {x,y,w,h} of that screen's visible area ready to hand to apply_layout, 'scale', and 'text', the same line Plonk shows the user. A distance also carries 'distance' and 'distance_pixels'. " +
      "Needs macOS Screen Recording permission, the same as a screenshot; without it the call fails rather than guessing. What is measured is a still taken when the call started, so a screen that is animating measures as it was at that moment.",
    {
      point: pointSchema
        .optional()
        .describe(
          "Where to look, as fractions 0..1 of the screen's visible area, origin TOP-LEFT. {x:0.5,y:0.5} is the middle of the screen"
        ),
      from: pointSchema.optional().describe("One end of a distance, in the same fractions as 'point'"),
      to: pointSchema.optional().describe("The other end of a distance, in the same fractions as 'point'"),
      screen: z
        .number()
        .int()
        .optional()
        .describe("Monitor index from get_state (0 = primary, the default). Every point is a fraction of this screen"),
      interactive: z
        .boolean()
        .optional()
        .describe(
          "Hand the user the ruler instead of measuring a given point: they hover, drag, click to copy and press Escape, and the last measurement comes back. Waits up to five minutes"
        ),
    },
    async ({ point, from, to, screen, interactive }) =>
      text(
        await call("/ruler/measure", {
          method: "POST",
          body: { point, from, to, screen, interactive },
          timeoutMs: interactive ? INTERACTIVE_TIMEOUT_MS : 30_000,
        })
      )
  );
}

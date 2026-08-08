import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, text } from "../api.js";

// The interactive mode hands the user a crosshair and waits for them.
const INTERACTIVE_TIMEOUT_MS = 5 * 60_000;

export function register(server: McpServer): void {
  server.tool(
    "extract_text",
    "Read the words off the screen, or off a saved image, and return them as text. Recognition runs on the Mac itself and nothing is uploaded. " +
      "Prefer this over take_screenshot whenever the answer is words rather than a picture — an error dialog, a log, a terminal, a table, text baked into an image or a paused video, a PDF page in a viewer that will not let text be selected. It costs a fraction of the tokens an image does and does not depend on reading pixels correctly. " +
      "Use take_screenshot instead when layout, colour or 'what does this look like' is the question. " +
      "mode 'screen' captures everything with no user interaction; 'region' and 'window' hand the user the native crosshair or window picker and wait for them, up to five minutes. Pass 'path' instead of a mode to read an image already on disk, including one take_screenshot just wrote. " +
      "Returns 'text' (every line in reading order, top to bottom) and 'lines' — each with the recognized string, Vision's 0..1 'confidence', and 'box' {x,y,w,h} as fractions 0..1 of the image with origin at TOP-LEFT. Those boxes share the coordinate space annotate_screenshot draws in, so a line can be circled where it was found by passing the same path to that tool. The text is also copied to the clipboard unless 'clipboard' is false. " +
      "An area with no readable text returns ok with an empty 'text' and a 'note' rather than an error.",
    {
      mode: z
        .enum(["screen", "region", "window"])
        .default("region")
        .describe("What to capture; ignored when 'path' is given"),
      path: z.string().optional().describe("Read this image file instead of capturing (.png, .jpg)"),
      clipboard: z.boolean().optional().describe("Copy the recognized text to the clipboard (default true)"),
      languages: z
        .array(z.string())
        .optional()
        .describe(
          "BCP-47 tags to recognize, most likely first, e.g. ['uk-UA','en-US']. Omit to use the user's configured choice. Which are available depends on the macOS version; get_state lists the current setting under 'text_languages'"
        ),
    },
    async ({ mode, path, clipboard, languages }) =>
      text(
        await call("/shot/text", {
          method: "POST",
          body: { mode, path, clipboard, languages },
          timeoutMs: path || mode === "screen" ? 60_000 : INTERACTIVE_TIMEOUT_MS,
        })
      )
  );
}

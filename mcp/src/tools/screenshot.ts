import { readFile } from "node:fs/promises";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, text } from "../api.js";

interface CaptureResult {
  ok?: boolean;
  path?: string;
  /** Copy scaled down for the model; absent when the capture already fits. */
  preview_path?: string;
  clipboard?: boolean;
  editor_open?: boolean;
  error?: string;
}

// The interactive modes hand the user a crosshair and wait for them.
const INTERACTIVE_TIMEOUT_MS = 5 * 60_000;
// Refuse to inline anything larger; a full retina desktop is easily 10 MB,
// which is dead weight in the conversation.
const MAX_INLINE_BYTES = 4 << 20;

export function register(server: McpServer): void {
  server.tool(
    "take_screenshot",
    "Capture the screen and return the image so it can be looked at. mode 'screen' captures everything (no user interaction), 'region' and 'window' hand the user the native crosshair/window picker and wait for them. Set annotate=true to open Plonk's drawing editor on the capture instead of returning it — use that when the user wants to mark the shot up themselves. Optional 'path' writes to an explicit file, otherwise the configured screenshot folder is used; 'clipboard' overrides the configured copy-to-clipboard behavior. The returned image is scaled down for legibility; the file at 'path' keeps full resolution. To draw on the result, pass that 'path' to annotate_screenshot.",
    {
      mode: z.enum(["screen", "region", "window"]).default("screen"),
      annotate: z.boolean().optional().describe("Open the annotation editor instead of returning the image"),
      path: z.string().optional().describe("Explicit output file path (.png)"),
      clipboard: z.boolean().optional().describe("Also copy the capture to the clipboard"),
      include_image: z
        .boolean()
        .optional()
        .describe("Return the image content itself, so it can be inspected (default true)"),
    },
    async ({ mode, annotate, path, clipboard, include_image }) => {
      const result = await call<CaptureResult>("/shot/capture", {
        method: "POST",
        body: { mode, annotate, path, clipboard, preview: include_image !== false },
        timeoutMs: mode === "screen" ? undefined : INTERACTIVE_TIMEOUT_MS,
      });

      const savedPath = "path" in result && typeof result.path === "string" ? result.path : undefined;
      if (!savedPath || include_image === false) return text(result);

      const preview = "preview_path" in result && typeof result.preview_path === "string"
        ? result.preview_path
        : undefined;
      const imagePath = preview ?? savedPath;
      try {
        const data = await readFile(imagePath);
        if (data.byteLength > MAX_INLINE_BYTES) {
          return text({
            ...result,
            note: `image is ${Math.round(data.byteLength / 1024)} KB, too large to inline — read it from 'path' if needed`,
          });
        }
        return {
          content: [
            { type: "text" as const, text: JSON.stringify(result, null, 2) },
            { type: "image" as const, data: data.toString("base64"), mimeType: "image/png" },
          ],
        };
      } catch {
        return text({ ...result, warning: `saved but could not be read back from ${imagePath}` });
      }
    }
  );
}

import { readFile } from "node:fs/promises";
import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { z } from "zod";
import { call, INTERACTIVE_TIMEOUT_MS, text } from "../api.js";

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
const INTERACTIVE_MODES = new Set(["region", "window"]);
// Refuse to inline anything larger; a full retina desktop is easily 10 MB,
// which is dead weight in the conversation.
const MAX_INLINE_BYTES = 4 << 20;

/**
 * Which mode a call really asks for.
 *
 * Naming a window is asking for that window, so a caller that passes 'app' and
 * leaves 'mode' at its default gets the window rather than the whole screen —
 * which would answer a question nobody asked and look right enough to be
 * believed. Only the default is overridden: asking for a crosshair outright
 * still hands the user a crosshair.
 */
export function captureMode(mode: string, app?: string, titleContains?: string): string {
  return mode === "screen" && (app || titleContains) ? "app" : mode;
}

export function register(server: McpServer): void {
  server.tool(
    "take_screenshot",
    "Capture the screen and return the image so it can be looked at. mode 'screen' captures everything (no user interaction); mode 'app' captures one named window and needs no user interaction either — pass 'app' and/or 'title_contains', and it works even when that window is behind others, minimized excepted, without raising it or taking focus; 'region' and 'window' hand the user the native crosshair/window picker and wait for them. Prefer 'app' whenever the user asks about a particular program (\"what is playing in Spotify\", \"read the error in Xcode\") — it is the only mode that can see a window the user cannot, and it does not disturb their desktop. Set annotate=true to open Plonk's drawing editor on the capture instead of returning it — use that when the user wants to mark the shot up themselves. Optional 'path' writes to an explicit file, otherwise the configured screenshot folder is used; 'clipboard' overrides the configured copy-to-clipboard behavior. The returned image is scaled down for legibility; the file at 'path' keeps full resolution. To draw on the result, pass that 'path' to annotate_screenshot.",
    {
      mode: z.enum(["screen", "app", "region", "window"]).default("screen"),
      app: z
        .string()
        .optional()
        .describe("mode 'app': app name or bundle id, case-insensitive substring (e.g. 'Spotify')"),
      title_contains: z
        .string()
        .optional()
        .describe("mode 'app': narrows to a window whose title contains this, for an app with several"),
      annotate: z.boolean().optional().describe("Open the annotation editor instead of returning the image"),
      path: z.string().optional().describe("Explicit output file path (.png)"),
      clipboard: z.boolean().optional().describe("Also copy the capture to the clipboard"),
      include_image: z
        .boolean()
        .optional()
        .describe("Return the image content itself, so it can be inspected (default true)"),
    },
    async ({ mode, app, title_contains, annotate, path, clipboard, include_image }) => {
      const wanted = captureMode(mode, app, title_contains);
      const result = await call<CaptureResult>("/shot/capture", {
        method: "POST",
        body: { mode: wanted, app, title_contains, annotate, path, clipboard, preview: include_image !== false },
        timeoutMs: INTERACTIVE_MODES.has(wanted) ? INTERACTIVE_TIMEOUT_MS : undefined,
      });

      const savedPath = "path" in result ? result.path : undefined;
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

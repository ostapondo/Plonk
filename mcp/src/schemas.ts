// Shared zod schemas for tool inputs.
import { z } from "zod";

export const pointSchema = z.object({
  x: z.number().min(0).max(1),
  y: z.number().min(0).max(1),
});

export const frameSchema = z.object({
  x: z.number().min(0).max(1),
  y: z.number().min(0).max(1),
  w: z.number().min(0).max(1),
  h: z.number().min(0).max(1),
});

export const itemsSchema = z
  .array(
    z.object({
      app: z.string().describe("App name to match, e.g. 'Safari', 'Visual Studio Code'"),
      title: z.string().optional().describe("Only windows whose title contains this substring"),
      screen: z.number().int().optional().describe("Monitor index from get_state (0 = primary)"),
      frame: frameSchema,
    })
  )
  .min(1);

export const zonesSchema = z.array(frameSchema).min(1);

export const workspaceItemsSchema = z
  .array(
    z.object({
      app: z.string().describe("App name as it appears in get_state, e.g. 'Safari'"),
      bundle_id: z
        .string()
        .optional()
        .describe("Bundle identifier, e.g. 'com.apple.Safari'. Required to launch an app that is not running"),
      bundle_path: z.string().optional().describe("Path to the .app, from get_state"),
      title: z.string().optional().describe("Prefer windows whose title contains this substring"),
      window_index: z
        .number()
        .int()
        .min(0)
        .optional()
        .describe("Which window of that app, when the workspace holds several of them"),
      screen: z.number().int().optional().describe("Monitor index from get_state (0 = primary)"),
      screen_uuid: z
        .string()
        .optional()
        .describe("Display UUID from a saved workspace; survives monitors being unplugged, unlike the index"),
      frame: frameSchema,
      minimized: z.boolean().optional().describe("Minimize the window once it is in place"),
      urls: z
        .array(z.string())
        .optional()
        .describe(
          "Files, folders or URLs this app opens when the workspace launches it, e.g. a project folder for an editor or a set of tabs for a browser"
        ),
      args: z
        .array(z.string())
        .optional()
        .describe("Launch arguments. Many Mac apps ignore these; prefer 'urls'"),
    })
  )
  .min(1);

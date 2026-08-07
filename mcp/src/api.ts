// Typed HTTP client for the Plonk app's localhost API.
import type { CallToolResult } from "@modelcontextprotocol/sdk/types.js";

export const BASE = "http://127.0.0.1:43917";
const DEFAULT_TIMEOUT_MS = 15_000;

export interface Frame {
  x: number;
  y: number;
  w: number;
  h: number;
}

export interface Screen {
  index: number;
  frame: Frame;
  visible: Frame;
}

export interface WindowInfo {
  app: string;
  pid: number;
  title: string;
  minimized: boolean;
  screen: number;
  window_index: number;
  bundle_id?: string;
  bundle_path?: string;
  frame: Frame;
  fraction?: Frame;
}

export interface WorkspaceItem {
  app: string;
  bundle_id?: string;
  bundle_path?: string;
  title?: string;
  window_index?: number;
  screen?: number;
  screen_uuid?: string;
  frame: Frame;
  minimized?: boolean;
  urls?: string[];
  args?: string[];
}

export interface Workspace {
  move_existing: boolean;
  apps: string[];
  items: WorkspaceItem[];
}

export interface AwakeDetails {
  requested: boolean;
  status: string;
  power: "ac" | "battery";
  allow_on_battery: boolean;
  auto_while_charging: boolean;
  keep_display_on: boolean;
  session_ends: string;
}

export interface State {
  awake: boolean;
  awake_details: AwakeDetails;
  accessibility_granted: boolean;
  saved_layouts: string[];
  workspaces: Record<string, Workspace>;
  zone_sets: Record<string, Frame[]>;
  screen_zone_sets: Record<string, string>;
  screens: Screen[];
  windows: WindowInfo[];
}

export interface LayoutItemResult {
  ok: boolean;
  app?: string;
  error?: string;
}

export interface LayoutResults {
  results: LayoutItemResult[];
  accessibility_granted?: boolean;
}

export interface LaunchItemResult {
  ok: boolean;
  app: string;
  /** Why the app was left alone, e.g. it was already open. */
  skipped?: string;
  error?: string;
}

export interface LaunchResults {
  ok: boolean;
  workspace: string;
  results: LaunchItemResult[];
}

export interface ApiError {
  error: string;
}

export type ApiResponse = Record<string, unknown>;

const NOT_RUNNING =
  "Plonk menu bar app is not running. Ask the user to launch Plonk.app (its icon should appear in the menu bar).";

export interface CallOptions {
  method?: "GET" | "POST";
  body?: unknown;
  /** Interactive captures wait for the user, so they need a longer budget. */
  timeoutMs?: number;
}

export async function call<T extends object = ApiResponse>(
  path: string,
  options: CallOptions = {}
): Promise<T | ApiError> {
  const { method = "GET", body, timeoutMs = DEFAULT_TIMEOUT_MS } = options;
  const timeout = AbortSignal.timeout(timeoutMs);

  let res: Response;
  try {
    res = await fetch(BASE + path, {
      method,
      headers: { "content-type": "application/json" },
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal: timeout,
    });
  } catch (err) {
    if (timeout.aborted) {
      return { error: `Plonk did not answer within ${timeoutMs / 1000}s. It may be waiting on a dialog.` };
    }
    return { error: NOT_RUNNING };
  }

  const text = await res.text();
  try {
    return JSON.parse(text) as T;
  } catch {
    return { error: `Plonk returned ${res.status} with an unexpected body: ${text.slice(0, 200)}` };
  }
}

/**
 * Whether the app is answering. Several servers may run at once — one per MCP
 * client — but all of them are useless without the app behind the port.
 */
export async function isAppReachable(timeoutMs = 2_000): Promise<boolean> {
  return !("error" in (await call("/ping", { timeoutMs })));
}

// An `error` key means the app refused or was unreachable; flagging it stops
// the model from reading the failure as a successful call.
export const text = (obj: object): CallToolResult => ({
  content: [{ type: "text", text: JSON.stringify(obj, null, 2) }],
  ...("error" in obj ? { isError: true } : {}),
});

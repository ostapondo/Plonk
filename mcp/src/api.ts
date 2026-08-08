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
  /** Non-zero while the session lasts only as long as that process does. */
  bound_pid: number;
}

export interface AgentInfo {
  name: string;
  version: string;
  pid?: number;
  online: boolean;
  last_seen: string;
  selected: boolean;
}

export interface State {
  awake: boolean;
  awake_details: AwakeDetails;
  accessibility_granted: boolean;
  /** Apps drag snapping and the placement shortcuts leave alone. */
  excluded_apps: string[];
  /** BCP-47 tags extract_text uses when none are passed; empty means automatic. */
  text_languages: string[];
  saved_layouts: string[];
  workspaces: Record<string, Workspace>;
  zone_sets: Record<string, Frame[]>;
  screen_zone_sets: Record<string, string>;
  screens: Screen[];
  windows: WindowInfo[];
  agents: AgentInfo[];
  selected_agent?: string;
  agent_exclusive: boolean;
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

// Stamped on every request so the app can attribute it to a client and, in
// exclusive mode, gate on it. One mechanism, one shape: the identity always
// lives in a holder. HTTP runs each request inside its session's holder; stdio
// fills the process-wide one, because process.stdin exists before any context
// we could enter and its callbacks never inherit one. HTTP never fills that
// holder, so a lost context there means no identity — an unidentified client
// the app can reject — rather than another session's name.
import { AsyncLocalStorage } from "node:async_hooks";

export interface AgentIdentity {
  name: string;
  version: string;
  pid: number;
}

/** Set once the handshake lands but read on every later call, hence a holder
 * object rather than the identity itself. */
export interface IdentityHolder {
  identity?: AgentIdentity;
}

const identityStore = new AsyncLocalStorage<IdentityHolder>();
const processHolder: IdentityHolder = {};

/** Run fn with a per-session identity; every call() inside sees it. */
export function runWithIdentity<T>(holder: IdentityHolder, fn: () => T): T {
  return identityStore.run(holder, fn);
}

/** The holder for a transport that serves a single client per process. */
export function processIdentityHolder(): IdentityHolder {
  return processHolder;
}

function currentIdentity(): AgentIdentity | undefined {
  return (identityStore.getStore() ?? processHolder).identity;
}

/** The client name this session registered with, e.g. "claude-code". */
export function agentIdentityName(): string {
  return currentIdentity()?.name ?? "";
}

function agentHeaders(): Record<string, string> {
  const id = currentIdentity();
  if (!id) return {};
  return {
    "x-plonk-agent": id.version ? `${id.name}/${id.version}` : id.name,
    "x-plonk-agent-pid": String(id.pid),
  };
}

// The app gates its API on a secret it writes to a file only this user can
// read, because binding to loopback keeps the network out and does nothing
// about the machine. Reading it is the whole handshake: anything that can read
// the file could ask macOS for the screen directly.
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { join } from "node:path";

const TOKEN_PATH = join(homedir(), "Library", "Application Support", "Plonk", "token");

let cachedToken: string | undefined;

/** Only a successful read is cached: a client started before the app has ever
 * run would otherwise never see the token the app writes on first launch. */
function apiToken(): string | undefined {
  if (cachedToken) return cachedToken;
  try {
    const token = readFileSync(TOKEN_PATH, "utf8").trim();
    if (token) cachedToken = token;
  } catch {
    // No app yet, or a file this user cannot read. The request goes without a
    // token and the app's own 401 explains it better than a guess here would.
  }
  return cachedToken;
}

/** The token as the HTTP transport needs it: to demand of its own callers what
 * the app demands of this process. Undefined when there is no readable file. */
export function localApiToken(): string | undefined {
  return apiToken();
}

/** Drops the cache and reads again, true only when the file now holds
 * something other than what this request actually sent — the one case where
 * repeating a refused request can help.
 *
 * `sent` rather than the cache, because the cache is shared: the hello
 * heartbeat and the inbox long-poll are always in flight beside a tool call,
 * so after a rotation the first 401 refreshes the cache and every other
 * request in the air would find it already fresh and give up, handing the
 * model a token error for a token that had just been fixed. */
function refreshToken(sent: string | undefined): boolean {
  cachedToken = undefined;
  const fresh = apiToken();
  return fresh !== undefined && fresh !== sent;
}

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

  // Captured per attempt, so the retry can tell "the token changed" from
  // "somebody else refreshed the cache while this request was in the air".
  let sent: string | undefined;
  const send = () => {
    sent = apiToken();
    return fetch(BASE + path, {
      method,
      headers: {
        "content-type": "application/json",
        ...agentHeaders(),
        ...(sent ? { "x-plonk-token": sent } : {}),
      },
      body: body !== undefined ? JSON.stringify(body) : undefined,
      signal: timeout,
    });
  };

  let res: Response;
  try {
    res = await send();
    // A long-lived client outlives the token if the file is ever replaced.
    // One re-read makes that a hiccup instead of a session to restart.
    if (res.status === 401 && refreshToken(sent)) res = await send();
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

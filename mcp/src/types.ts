// The shapes the app answers with. Kept apart from the client that fetches
// them so each file says one thing: this is what comes back, api.ts is how.
import type { z } from "zod";
import type { workspaceItemsSchema } from "./schemas.js";

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

export type WorkspaceItem = z.infer<typeof workspaceItemsSchema>[number];

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
  /** Whether the Mac has been told not to sleep when the lid is shut. */
  lid_closed: boolean;
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

/** Where an app's new windows open; see set_app_rule. */
export interface AppRule {
  app: string;
  zone: number;
  /** The monitor's index today, present only while that display is attached. */
  screen?: number;
  screen_uuid?: string;
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
  zone_gap: number;
  zone_set_gaps: Record<string, number>;
  screen_zone_sets: Record<string, string>;
  app_rules: AppRule[];
  /** Whether a new window goes where that app's last one went. */
  place_new_windows: boolean;
  /** Whether a window that opens on a screen with a free zone goes into the first one. */
  auto_fill_zones: boolean;
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

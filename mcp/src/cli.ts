#!/usr/bin/env node
// `plonk` — the same loopback API the MCP tools use, from a shell.
//
// Agents reach Plonk over MCP, and the settings window covers the rest, but
// neither helps a script, a Raycast command or a Makefile. This is that gap:
// every subcommand is one HTTP call to 127.0.0.1, and nothing here holds state.
import { spawn } from "node:child_process";
import { BASE, call, processIdentityHolder, type State } from "./api.js";

const USAGE = `plonk — drive the Plonk menu bar app from a shell

  plonk state [--json]              screens, windows, zone sets, workspaces
  plonk snap <app> <zone>           drop a window into a numbered zone
  plonk workspaces                  list saved workspaces
  plonk launch <name> [--screen N]  launch one
  plonk save <name>                 save the desktop as one
  plonk zones [--screen N] <set>    assign a zone set to a monitor
  plonk awake off
  plonk awake on [--minutes N] [--until HH:MM] [--pid N]
  plonk awake while <command...>    stay awake until that command exits
  plonk text [--mode region|window|screen] [--path FILE]
  plonk shot [--mode region|window|screen] [--path FILE]

Everything talks to ${BASE}; Plonk.app has to be running.`;

/** Pulls "--name value" out of argv and returns what is left. */
function options(argv: string[]): { flags: Record<string, string>; rest: string[] } {
  const flags: Record<string, string> = {};
  const rest: string[] = [];
  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg.startsWith("--")) {
      const key = arg.slice(2);
      const next = argv[i + 1];
      if (next === undefined || next.startsWith("--")) {
        flags[key] = "true";
      } else {
        flags[key] = next;
        i++;
      }
    } else {
      rest.push(arg);
    }
  }
  return { flags, rest };
}

/** Unwinds to the top instead of calling process.exit, which on a pipe cuts
 * stdout off mid-write: `plonk state --json | jq` would get invalid JSON.
 * Letting the process end on its own flushes first. */
class Exit extends Error {
  constructor(readonly code: number) {
    super(`exit ${code}`);
  }
}

function fail(message: string): never {
  console.error(`plonk: ${message}`);
  throw new Exit(1);
}

function number(raw: string | undefined, what: string): number | undefined {
  if (raw === undefined) return undefined;
  const value = Number(raw);
  if (!Number.isInteger(value)) fail(`${what} must be a whole number, got "${raw}"`);
  return value;
}

/** Prints the reply and exits non-zero when the app refused. */
function report(result: object): never {
  if ("error" in result) {
    console.error(`plonk: ${(result as { error: string }).error}`);
    throw new Exit(1);
  }
  console.log(JSON.stringify(result, null, 2));
  throw new Exit(0);
}

async function summarize(): Promise<never> {
  const state = await call<State>("/state");
  if ("error" in state) report(state);
  const lines: string[] = [];
  lines.push(`awake     ${state.awake_details.status}`);
  lines.push(`screens   ${state.screens.length}`);
  for (const screen of state.screens) {
    const set = state.screen_zone_sets[String(screen.index)];
    const zones = set === "" ? "edge snapping" : (set ?? "Halves");
    lines.push(`  ${screen.index}: ${Math.round(screen.frame.w)}x${Math.round(screen.frame.h)}  ${zones}`);
  }
  lines.push(`workspaces ${state.saved_layouts.join(", ") || "none"}`);
  lines.push(`zone sets  ${Object.keys(state.zone_sets).sort().join(", ")}`);
  if (state.excluded_apps?.length) lines.push(`excluded   ${state.excluded_apps.join(", ")}`);
  lines.push(`windows   ${state.windows.length}`);
  for (const window of state.windows) {
    lines.push(`  ${window.app}${window.title ? ` — ${window.title}` : ""} [screen ${window.screen}]`);
  }
  console.log(lines.join("\n"));
  throw new Exit(0);
}

/** Runs a command with its output passed through, holding keep-awake for
 * exactly as long as it lives. The exit status is the command's own, so this
 * drops into a Makefile without changing what a failure means. */
async function awakeWhile(argv: string[]): Promise<never> {
  if (argv.length === 0) fail("awake while needs a command to run");
  const child = spawn(argv[0], argv.slice(1), { stdio: "inherit" });

  // Both listeners go on before the round trip below: a command that finishes
  // inside it — `plonk awake while echo hi` — would otherwise fire exit into
  // an empty room and hang here forever.
  const finished = new Promise<number>((resolve) => {
    child.on("error", (err) => {
      console.error(`plonk: could not run ${argv[0]}: ${err.message}`);
      resolve(1);
    });
    child.on("exit", (code, signal) => resolve(signal ? 1 : (code ?? 0)));
  });

  // No pid means the spawn failed outright. Asking for keep-awake without one
  // would hold an assertion nothing ever releases.
  if (child.pid !== undefined) {
    const started = await call("/awake", { method: "POST", body: { on: true, pid: child.pid } });
    if ("error" in started) {
      console.error(`plonk: keep-awake not held — ${(started as { error: string }).error}`);
    }
  }
  // Plonk drops the assertion itself when the process goes; waiting here only
  // makes the shell finish at the same moment.
  throw new Exit(await finished);
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  // Everything after `awake while` belongs to the command being run, flags
  // included, so it is taken verbatim rather than parsed for plonk's own.
  // Otherwise `plonk awake while cargo build --release` builds in debug.
  if (argv[0] === "awake" && argv[1] === "while") await awakeWhile(argv.slice(2));

  const { flags, rest } = options(argv);
  const [command, ...args] = rest;
  const screen = number(flags.screen, "--screen");

  switch (command) {
    case undefined:
    case "help":
    case "-h":
    case "--help":
      console.log(USAGE);
      return;

    case "ping":
      report(await call("/ping"));
      break;

    case "state":
      if (flags.json) report(await call("/state"));
      await summarize();
      break;

    case "snap": {
      const [app, zone] = args;
      if (!app || zone === undefined) fail("snap needs an app and a zone number, e.g. plonk snap Safari 1");
      report(await call("/layout/zone", {
        method: "POST",
        body: { app, zone: number(zone, "zone"), screen },
      }));
      break;
    }

    case "workspaces": {
      const state = await call<State>("/state");
      if ("error" in state) report(state);
      console.log(state.saved_layouts.join("\n"));
      return;
    }

    case "launch":
      if (!args[0]) fail("launch needs a workspace name");
      report(await call("/workspaces/launch", {
        method: "POST",
        body: { name: args[0], screen },
        timeoutMs: 90_000,
      }));
      break;

    case "save":
      if (!args[0]) fail("save needs a name for the workspace");
      report(await call("/workspaces/save", { method: "POST", body: { name: args[0] } }));
      break;

    case "zones":
      if (!args[0]) fail("zones needs a set name, or 'edge' for edge snapping");
      report(await call("/zones/assign", { method: "POST", body: { screen: screen ?? 0, name: args[0] } }));
      break;

    case "awake": {
      // `while` is handled before flags are parsed; anything else must be on/off.
      if (args[0] !== "on" && args[0] !== "off") fail("awake needs 'on', 'off' or 'while <command>'");
      report(await call("/awake", {
        method: "POST",
        body: {
          on: args[0] === "on",
          minutes: number(flags.minutes, "--minutes"),
          until: flags.until,
          pid: number(flags.pid, "--pid"),
        },
      }));
      break;
    }

    case "text": {
      const result = await call<{ text?: string }>("/shot/text", {
        method: "POST",
        body: { mode: flags.mode ?? "region", path: flags.path },
        timeoutMs: 5 * 60_000,
      });
      if ("error" in result) report(result);
      // Bare text, so it can be piped.
      console.log(result.text ?? "");
      return;
    }

    case "shot":
      report(await call("/shot/capture", {
        method: "POST",
        body: { mode: flags.mode ?? "region", path: flags.path },
        timeoutMs: 5 * 60_000,
      }));
      break;

    default:
      fail(`unknown command "${command}"\n\n${USAGE}`);
  }
}

// Named so the app can attribute the calls, and so "only the active agent
// controls" can be pointed at the shell like anything else.
processIdentityHolder().identity = { name: "plonk-cli", version: "", pid: process.pid };
try {
  await main();
} catch (err) {
  if (!(err instanceof Exit)) throw err;
  process.exitCode = err.code;
}

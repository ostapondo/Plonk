// Errors the client composes itself, worded for whoever will read them.

/** The identity `plonk` registers before its first call, so a refusal can be
 * addressed to a person at a prompt rather than to a model. */
export const CLI_NAME = "plonk-cli";

const NOT_RUNNING_FOR_AGENT =
  "Plonk menu bar app is not running. Ask the user to launch Plonk.app (its icon should appear in the menu bar).";

// A person who ran `npm i -g plonk-mcp` first has no reason to know the app is
// a separate install, so the cask is the useful half of this sentence.
const NOT_RUNNING_FOR_CLI =
  "Plonk.app is not running. Launch it (its icon appears in the menu bar), or install it first: brew install --cask ostapondo/plonk/plonk";

/** The refused-connection message for the client named `agent`. Same cause
 * either way; the CLI's form tells the reader what to do instead of telling
 * them to ask themselves. */
export function notRunningMessage(agent: string): string {
  return agent === CLI_NAME ? NOT_RUNNING_FOR_CLI : NOT_RUNNING_FOR_AGENT;
}

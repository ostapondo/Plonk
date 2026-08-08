// Argument parsing for the `plonk` command, kept out of cli.ts so it can be
// tested without running the CLI: importing cli.ts runs it.

export interface ParsedArgs {
  flags: Record<string, string>;
  rest: string[];
}

/**
 * Pulls "--name value" out of argv and returns what is left, in order.
 *
 * A flag with nothing usable after it — the end of argv, or another flag — is
 * a switch and reads as "true", so `--json` and `--screen 1` parse the same
 * way. Values are not converted here; the caller knows which of its flags are
 * numbers and says so in the error when one is not.
 */
export function options(argv: string[]): ParsedArgs {
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

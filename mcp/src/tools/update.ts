import type { McpServer } from "@modelcontextprotocol/sdk/server/mcp.js";
import { call, text } from "../api.js";

export function register(server: McpServer): void {
  server.tool(
    "check_for_update",
    "Ask Plonk whether a newer release exists, and report what is installed. Use this when the user asks what version they run, whether Plonk is up to date, or before calling install_update — which refuses unless a newer release is already on offer. The check is a network round trip to the GitHub releases API, so this returns immediately with the state as it stands and the result lands a moment later: read it back from get_state's 'update' key, or wait for an 'update' event on the change stream. If the user has turned update checks off, this fails with 409 rather than dialling out on their behalf — Plonk promises a process that only listens, and the user can still check by hand on its Updates page; report that back instead of retrying. Returns {installed, latest?, available, phase, status, automatic, notes?, page?}: 'available' is true only when 'latest' is newer than 'installed', 'phase' is idle|checking|available|downloading|verifying|installing|failed, and 'status' is a sentence fit to show the user.",
    {},
    async () => text(await call("/update/check", { method: "POST" }))
  );

  server.tool(
    "install_update",
    "Install the release that check_for_update found: Plonk downloads the build, checks it is signed with the same certificate as the running copy, swaps the bundle in, and relaunches itself. Prefer this over telling the user to download a build by hand — the signature check is also what preserves their Accessibility and Screen Recording grants, which a hand-installed copy can lose. Ask the user before calling it: it quits the app, so any window arrangement in flight stops and the local API is unreachable for a few seconds until the new copy is up. It fails without touching the installed copy when no newer release is on offer (call check_for_update first), when the user has update checks switched off (409 — installing downloads a build, so it is bound by the same promise as the check; they can install from Plonk's Updates page), when the download does not match the release or its signature, or when Plonk.app sits somewhere the user cannot write. Returns the same shape as check_for_update plus {installing: true} once the swap has started; poll get_state afterwards to confirm the new version came up.",
    {},
    async () => text(await call("/update/install", { method: "POST" }))
  );
}

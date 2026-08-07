# Agent rules — mcp/

Rules for the MCP server package. Repo-wide rules live in `../AGENTS.md`.

## Tool descriptions are product surface

The description strings in `src/tools/*.ts` are what AI agents read when
deciding which tool to call — and MCP directories score them (Glama rates
every tool across purpose clarity, usage guidance, behavioral transparency,
parameter semantics; the *worst* tool sets the floor of the whole server's
score). Treat them like published API docs:

- Every tool description answers four things: what it does, when to pick it
  over neighboring tools, how it behaves (side effects, timing, failure
  reporting), and what it returns.
- Every parameter that is not self-evident gets `.describe()` with units,
  ranges, defaults, and coordinate origin. Frames are fractions 0..1 with
  origin TOP-LEFT — spell that out wherever a frame or point appears.
- A concrete example beats prose: `{x:0,y:0,w:0.5,h:1}` is the left half.
- Deprecated aliases get full descriptions too. "Deprecated alias of X" alone
  scores as the server's worst tool; describe the behavior and point new
  integrations at the replacement.
- Descriptions only take effect for users and directories after an npm
  release, so a description fix warrants a version bump.

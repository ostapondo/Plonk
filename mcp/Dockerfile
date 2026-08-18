# Runs the Plonk MCP server for introspection/inspection purposes.
# The Mac menu bar app is not available in a container, so tools respond
# with a "Plonk.app is not reachable" error when invoked — but the server
# starts, lists its tools, and speaks MCP over stdio.
FROM node:20-slim@sha256:2cf067cfed83d5ea958367df9f966191a942351a2df77d6f0193e162b5febfc0
WORKDIR /app
COPY package.json package-lock.json tsconfig.json ./
COPY src ./src
RUN npm ci && npm run build && npm prune --omit=dev
ENTRYPOINT ["node", "dist/server.js"]

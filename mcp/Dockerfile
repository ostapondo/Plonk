# Runs the Plonk MCP server for introspection/inspection purposes.
# The Mac menu bar app is not available in a container, so tools respond
# with a "Plonk.app is not reachable" error when invoked — but the server
# starts, lists its tools, and speaks MCP over stdio.
FROM node:26-slim@sha256:4ebb5ace66f15a24c14c492e01a8beeed4fddf970a856109f5126e703e5fe503
WORKDIR /app
COPY package.json package-lock.json tsconfig.json ./
COPY src ./src
RUN npm ci && npm run build && npm prune --omit=dev
ENTRYPOINT ["node", "dist/server.js"]

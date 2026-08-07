# Runs the Plonk MCP server for introspection/inspection purposes.
# The Mac menu bar app is not available in a container, so tools respond
# with a "Plonk.app is not reachable" error when invoked — but the server
# starts, lists its tools, and speaks MCP over stdio.
FROM node:20-slim
WORKDIR /app
COPY package.json package-lock.json tsconfig.json ./
COPY src ./src
RUN npm ci && npm run build && npm prune --omit=dev
ENTRYPOINT ["node", "dist/server.js"]

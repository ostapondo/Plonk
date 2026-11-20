# Runs the Plonk MCP server for introspection/inspection purposes.
# The Mac menu bar app is not available in a container, so tools respond
# with a "Plonk.app is not reachable" error when invoked — but the server
# starts, lists its tools, and speaks MCP over stdio.
FROM node:26-slim@sha256:e6bedef217677b276c591795e169840edd9096dbf13f29df8ef8d1856b8820bc
WORKDIR /app
COPY package.json package-lock.json tsconfig.json ./
COPY src ./src
RUN npm ci && npm run build && npm prune --omit=dev
ENTRYPOINT ["node", "dist/server.js"]

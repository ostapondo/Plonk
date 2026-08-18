// Streamable HTTP transport: one process, many clients — for anything that
// cannot spawn a stdio process. Binds to loopback only and carries the same
// threat model as the app's own API: a web page must never be able to drive
// the desktop, and a DNS-rebinding page must not reach the port by Host games.
import { createServer, type IncomingMessage, type ServerResponse } from "node:http";
import { randomUUID, timingSafeEqual } from "node:crypto";
import { StreamableHTTPServerTransport } from "@modelcontextprotocol/sdk/server/streamableHttp.js";
import { localApiToken, runWithIdentity, type IdentityHolder } from "./api.js";
import { bindClient, createPlonkServer } from "./factory.js";

interface Session {
  transport: StreamableHTTPServerTransport;
  holder: IdentityHolder;
  stop?: () => void;
}

// The app's registry tells sessions apart by (name, pid). Every HTTP client
// shares this process, so each session gets a synthetic pid instead.
let syntheticPid = 100_000 + (process.pid % 1_000) * 100;

function headerToken(req: IncomingMessage): string {
  const value = req.headers["x-plonk-token"];
  return (Array.isArray(value) ? value[0] : value) ?? "";
}

/** Length is not the secret; which byte differed would be. */
function timingSafeEqualString(presented: string, token: string): boolean {
  const a = Buffer.from(presented, "utf8"), b = Buffer.from(token, "utf8");
  return a.length === b.length && a.length > 0 && timingSafeEqual(a, b);
}

function reject(res: ServerResponse, status: number, error: string): void {
  res.writeHead(status, { "content-type": "application/json" });
  res.end(JSON.stringify({ error }));
}

export async function serveHttp(port: number): Promise<void> {
  const sessions = new Map<string, Session>();

  const handle = async (req: IncomingMessage, res: ServerResponse): Promise<void> => {
    // Browsers always attach Origin to cross-site POSTs and Sec-Fetch-Site to
    // every request, and page script cannot suppress either.
    if (req.headers.origin !== undefined || req.headers["sec-fetch-site"] !== undefined) {
      reject(res, 403, "requests from web pages are not accepted");
      return;
    }
    const host = (req.headers.host ?? "").toLowerCase();
    if (host !== `127.0.0.1:${port}` && host !== `localhost:${port}`) {
      reject(res, 403, "unexpected Host header");
      return;
    }
    if (new URL(req.url ?? "/", `http://${host}`).pathname !== "/mcp") {
      reject(res, 404, "the MCP endpoint is /mcp");
      return;
    }
    // This process holds the app's token, so without a gate of its own it is a
    // way around the app's: anything local could call take_screenshot through
    // it and borrow Screen Recording. Same secret, same header, same file —
    // there is nothing extra for a client to be given.
    const token = localApiToken();
    if (!token) {
      reject(res, 503, "no Plonk API token could be read, so this transport is answering nothing");
      return;
    }
    if (!timingSafeEqualString(headerToken(req), token)) {
      reject(res, 401, "this request carried no valid token; send the contents of " +
        "~/Library/Application Support/Plonk/token as the X-Plonk-Token header");
      return;
    }

    const sessionId = req.headers["mcp-session-id"];
    const existing = typeof sessionId === "string" ? sessions.get(sessionId) : undefined;
    if (existing) {
      await runWithIdentity(existing.holder, () => existing.transport.handleRequest(req, res));
      return;
    }
    if (req.method !== "POST") {
      reject(res, 400, "start a session with an initialize POST first");
      return;
    }

    const session: Session = {
      holder: {},
      transport: new StreamableHTTPServerTransport({
        sessionIdGenerator: () => randomUUID(),
        onsessioninitialized: (sid) => {
          sessions.set(sid, session);
        },
      }),
    };
    session.transport.onclose = () => {
      session.stop?.();
      const sid = session.transport.sessionId;
      if (sid !== undefined) sessions.delete(sid);
    };

    const server = createPlonkServer();
    session.stop = bindClient(server, session.holder, () => syntheticPid++);
    await server.connect(session.transport);
    await runWithIdentity(session.holder, () => session.transport.handleRequest(req, res));
  };

  const httpServer = createServer((req, res) => {
    handle(req, res).catch((err) => {
      console.error("plonk-mcp:", err);
      if (!res.headersSent) reject(res, 500, "internal error");
    });
  });

  await new Promise<void>((resolve, rejectListen) => {
    httpServer.once("error", rejectListen);
    httpServer.listen(port, "127.0.0.1", resolve);
  });
  console.error(`plonk-mcp: Streamable HTTP at http://127.0.0.1:${port}/mcp`);
}

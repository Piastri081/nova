import { handleApi } from "./api";
import { handleAuth } from "./auth";
import { HttpError, json, preflight } from "./http";
import type { Env } from "./types";

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    if (request.method === "OPTIONS") {
      return preflight();
    }

    const url = new URL(request.url);

    try {
      if (url.pathname === "/health") {
        return json({ ok: true, service: "nova-api", time: Date.now() });
      }

      if (url.pathname.startsWith("/v1/auth/")) {
        return await handleAuth(request, env, url);
      }

      if (url.pathname.startsWith("/v1/")) {
        return await handleApi(request, env, url);
      }

      return json({ error: "Not found." }, 404);
    } catch (error) {
      if (error instanceof HttpError) {
        return json({ error: error.message }, error.status);
      }

      console.error("Unhandled API error", error);
      return json({ error: "Something went wrong." }, 500);
    }
  }
};

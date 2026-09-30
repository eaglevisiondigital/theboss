import { getRequestOrigin } from "./request-origin";

const MAX_LOGIN_BODY_BYTES = 16_384;

export function isSameOriginPost(request: Request, configuredOrigin?: string): boolean {
  if (request.method !== "POST") return false;
  const origin = request.headers.get("origin");
  const fetchSite = request.headers.get("sec-fetch-site");
  if (!origin || (fetchSite && fetchSite !== "same-origin")) return false;
  try {
    if (configuredOrigin) {
      const approved = new URL(configuredOrigin);
      const host = request.headers.get("host")?.toLowerCase();
      const defaultPort = approved.protocol === "https:" ? "443" : "80";
      if (
        !host || (host !== approved.host &&
          (approved.port || host !== `${approved.hostname}:${defaultPort}`))
      ) return false;
    }
    const parsedOrigin = new URL(origin);
    return (
      parsedOrigin.origin === getRequestOrigin(request, configuredOrigin) &&
      parsedOrigin.href === `${parsedOrigin.origin}/`
    );
  } catch {
    return false;
  }
}

export async function readLoginForm(request: Request): Promise<URLSearchParams | null> {
  if (request.headers.get("content-type")?.split(";")[0].trim() !== "application/x-www-form-urlencoded") {
    return null;
  }
  const declaredSize = request.headers.get("content-length");
  if (declaredSize && (!/^\d+$/.test(declaredSize) || Number(declaredSize) > MAX_LOGIN_BODY_BYTES)) {
    return null;
  }
  if (!request.body) return null;
  const reader = request.body.getReader();
  const chunks: Uint8Array[] = [];
  let size = 0;
  try {
    for (;;) {
      const { value, done } = await reader.read();
      if (done) break;
      size += value.byteLength;
      if (size > MAX_LOGIN_BODY_BYTES) {
        await reader.cancel();
        return null;
      }
      chunks.push(value);
    }
    const bytes = new Uint8Array(size);
    let offset = 0;
    for (const chunk of chunks) {
      bytes.set(chunk, offset);
      offset += chunk.byteLength;
    }
    const form = new URLSearchParams(new TextDecoder("utf-8", { fatal: true }).decode(bytes));
    if (["email", "password", "next"].some((name) => form.getAll(name).length > 1)) return null;
    return form;
  } catch {
    return null;
  } finally {
    reader.releaseLock();
  }
}

export function getLoginCredentials(form: URLSearchParams): { email: string; password: string } | null {
  const email = form.get("email")?.trim();
  const password = form.get("password");
  if (
    !email || email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
    !password || password.length > 1024
  ) return null;
  // No signup password policy is inferred. Existing accounts retain their policy.
  return { email, password };
}

import type { ProviderFetch } from "./contracts";
/** Bounded private transport. Exceptions/body/error messages never leave it. */
export async function providerText(fetcher: ProviderFetch, url: string, init: RequestInit): Promise<string | null> {
 try {
  const response = await fetcher(url, { ...init, redirect: "error", cache: "no-store", signal: AbortSignal.timeout(12_000) });
  if (!response.ok || !response.body || Number(response.headers.get("content-length") ?? 0) > 262_144) return null;
  const reader = response.body.getReader(); let size = 0; const chunks: Uint8Array[] = [];
  for (;;) { const { value, done } = await reader.read(); if (done) break; size += value.byteLength; if (size > 262_144) { await reader.cancel(); return null; } chunks.push(value); }
  const bytes = new Uint8Array(size); let offset = 0; for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.length; }
  return new TextDecoder("utf-8", { fatal: true }).decode(bytes).replace(/^\uFEFF/, "");
 } catch { return null; }
}

export async function providerJson(fetcher:ProviderFetch,url:string,init:RequestInit):Promise<unknown>{
 const text=await providerText(fetcher,url,init);if(text===null)return null;try{return JSON.parse(text);}catch{return null;}
}

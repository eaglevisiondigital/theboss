import { isSameOriginPost } from "../auth/request-security";
import type { RegistrationMutationClient } from "./mutation";
import { registrationFailure, verifiedRegistrationCaller } from "./mutation";
import { isRecord, readBoundedJson, uuidPattern } from "./input";

export const PRIVATE_DOCUMENT_BUCKET = "boss-registration-documents";
export const MAX_DOCUMENT_BYTES = 5 * 1024 * 1024;
export const documentMimeTypes = ["application/pdf", "image/jpeg", "image/png"] as const;
export type DocumentMimeType = typeof documentMimeTypes[number];
export function validDocumentBytes(bytes: Uint8Array, type: string): type is DocumentMimeType {
  if (!bytes.length || bytes.length > MAX_DOCUMENT_BYTES) return false;
  if (type === "application/pdf") return new TextDecoder().decode(bytes.subarray(0, 8)).startsWith("%PDF-") && new TextDecoder().decode(bytes.subarray(Math.max(0, bytes.length - 1024))).includes("%%EOF");
  if (type === "image/png") return bytes.length >= 24 && [137,80,78,71,13,10,26,10].every((value, index) => bytes[index] === value);
  return type === "image/jpeg" && bytes.length >= 4 && bytes[0] === 255 && bytes[1] === 216 && bytes[bytes.length - 2] === 255 && bytes[bytes.length - 1] === 217;
}
export async function readDocumentBytes(request: Request): Promise<Uint8Array | null> {
  const length = request.headers.get("content-length");
  if (!request.body || length && (!/^\d+$/.test(length) || Number(length) > MAX_DOCUMENT_BYTES)) return null;
  const reader = request.body.getReader(); const chunks: Uint8Array[] = []; let size = 0;
  try { for (;;) { const { done, value } = await reader.read(); if (done) break; size += value.byteLength; if (size > MAX_DOCUMENT_BYTES) { await reader.cancel(); return null; } chunks.push(value); }
    const result = new Uint8Array(size); let offset = 0; for (const chunk of chunks) { result.set(chunk, offset); offset += chunk.length; } return result;
  } catch { return null; } finally { reader.releaseLock(); }
}
export type DocumentClient = RegistrationMutationClient & { storage: { from(bucket: string): {
  upload(path: string, body: Uint8Array, options: { contentType: string; upsert: false; cacheControl: string }): Promise<{ error: unknown }>;
  download(path: string): Promise<{ data: Blob | null; error: unknown }>;
} } };
const safePath = (value: unknown): value is string => typeof value === "string" && value.length < 400 && /^[a-zA-Z0-9_/-]+\.(pdf|png|jpg|jpeg)$/.test(value) && !value.includes("..");
export async function performDocumentUpload(request: Request, client: DocumentClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return registrationFailure("PT403");
  const documentId = request.headers.get("x-document-id"); const requestId = request.headers.get("x-upload-request-id"); const completionId = request.headers.get("x-completion-request-id");
  const mime = request.headers.get("content-type")?.split(";")[0].trim();
  if (![documentId, requestId, completionId].every(id => id && uuidPattern.test(id)) || requestId === completionId || !mime || !documentMimeTypes.includes(mime as DocumentMimeType)) return registrationFailure("PT422");
  try {
    if (!await verifiedRegistrationCaller(client)) return registrationFailure("PT401");
    const bytes = await readDocumentBytes(request); if (!bytes || !validDocumentBytes(bytes, mime)) return registrationFailure("PT422");
    // Bind retries to the actual request bytes, including files of equal length.
    // This digest is not a malware scan or independent Storage-content proof.
    const digest = await crypto.subtle.digest("SHA-256", new Uint8Array(bytes).buffer);
    const sha256 = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("");
    const { data: intent, error: intentError } = await client.rpc("boss_registration_mutate", { p_request_id: requestId!, p_command: { operation: "document.intent", input: { document_id: documentId!, mime_type: mime, size_bytes: bytes.length, sha256 } } });
    if (intentError) return registrationFailure(intentError.code);
    if (!isRecord(intent) || intent.request_id !== requestId || typeof intent.intent_id !== "string" || !uuidPattern.test(intent.intent_id) || !safePath(intent.object_name)) return registrationFailure();
    const upload = await client.storage.from(PRIVATE_DOCUMENT_BUCKET).upload(intent.object_name, bytes, { contentType: mime, upsert: false, cacheControl: "0" });
    // A retry may find the immutable object already uploaded. Completion checks
    // authoritative Storage metadata and intent ownership rather than this error.
    const complete = await client.rpc("boss_registration_mutate", { p_request_id: completionId!, p_command: { operation: "document.complete", input: { document_id: documentId!, intent_id: intent.intent_id } } });
    if (complete.error) return registrationFailure(complete.error.code);
    if (!isRecord(complete.data) || complete.data.request_id !== completionId || complete.data.resource_id !== documentId) return registrationFailure();
    void upload; return { status: 200, body: { ok: true as const, result: { document_id: documentId } } };
  } catch { return registrationFailure(); }
}
export async function performDocumentDownload(request: Request, client: DocumentClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return registrationFailure("PT403");
  const input = await readBoundedJson(request, 4096);
  if (!isRecord(input) || Object.keys(input).some(key => !["document_id", "request_id", "purpose", "team_id"].includes(key)) || typeof input.document_id !== "string" || !uuidPattern.test(input.document_id) || typeof input.request_id !== "string" || !uuidPattern.test(input.request_id) || !["ordinary", "emergency"].includes(String(input.purpose)) || input.team_id !== undefined && (typeof input.team_id !== "string" || !uuidPattern.test(input.team_id))) return registrationFailure("PT422");
  try {
    if (!await verifiedRegistrationCaller(client)) return registrationFailure("PT401");
    const { data, error } = await client.rpc("boss_registration_mutate", { p_request_id: input.request_id, p_command: { operation: "document.access", input: { document_id: input.document_id, purpose: String(input.purpose), ...(typeof input.team_id === "string" ? { team_id: input.team_id } : {}) } } });
    if (error) return registrationFailure(error.code);
    if (!isRecord(data) || data.request_id !== input.request_id || data.resource_id !== input.document_id || !safePath(data.object_name) || !documentMimeTypes.includes(data.mime_type as DocumentMimeType)) return registrationFailure();
    const downloaded = await client.storage.from(PRIVATE_DOCUMENT_BUCKET).download(data.object_name);
    if (downloaded.error || !downloaded.data || downloaded.data.size > MAX_DOCUMENT_BYTES) return registrationFailure("PT403");
    const downloadedMime = downloaded.data.type.split(";")[0].trim().toLowerCase();
    if (downloadedMime !== data.mime_type || !validDocumentBytes(new Uint8Array(await downloaded.data.arrayBuffer()), data.mime_type)) return registrationFailure("PT403");
    const extension = data.mime_type === "application/pdf" ? "pdf" : data.mime_type === "image/png" ? "png" : "jpg";
    return { status: 200, file: downloaded.data, mime: data.mime_type as DocumentMimeType, filename: "private-document." + extension };
  } catch { return registrationFailure(); }
}

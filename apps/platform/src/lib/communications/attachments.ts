import { isSameOriginPost } from "../auth/request-security";
import { readDocumentBytes, validDocumentBytes, documentMimeTypes, MAX_DOCUMENT_BYTES, type DocumentMimeType } from "../registration/documents";
import { communicationFailure, verifiedCommunicationCaller, type CommunicationClient } from "./mutation";
import { isRecord, readBoundedJson, uuid } from "./input";

export const COMMUNICATION_ATTACHMENT_BUCKET = "boss-communication-attachments";
export type CommunicationAttachmentClient = CommunicationClient & { storage: { from(bucket: string): {
  upload(path: string, body: Uint8Array, options: { contentType: string; upsert: false; cacheControl: string }): Promise<{ error: unknown }>;
  download(path: string): Promise<{ data: Blob | null; error: unknown }>;
} } };
export function safeCommunicationPath(value: unknown, attachmentId: string, threadId?: string): value is string {
  if (typeof value !== "string" || value.length !== 147) return false;
  const parts = value.split("/"); return parts.length === 4 && parts.every(uuid) && parts[2] === attachmentId && (threadId === undefined || parts[1] === threadId);
}
export async function performCommunicationUpload(request: Request, client: CommunicationAttachmentClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return communicationFailure("PT403");
  const threadId = request.headers.get("x-thread-id"), requestId = request.headers.get("x-upload-request-id"), completionId = request.headers.get("x-completion-request-id");
  const mime = request.headers.get("content-type")?.split(";")[0].trim(); let filename: string;
  try { filename = decodeURIComponent(request.headers.get("x-file-name") ?? ""); } catch { return communicationFailure("PT422"); }
  if (![threadId, requestId, completionId].every(uuid) || requestId === completionId || !mime || !documentMimeTypes.includes(mime as DocumentMimeType) || !filename.trim() || filename.length > 200 || (/[\\/]/.test(filename) || [...filename].some(character => character.charCodeAt(0) < 32))) return communicationFailure("PT422");
  try {
    if (!await verifiedCommunicationCaller(client)) return communicationFailure("PT401");
    const bytes = await readDocumentBytes(request); if (!bytes || !validDocumentBytes(bytes, mime)) return communicationFailure("PT422");
    const digest = await crypto.subtle.digest("SHA-256", new Uint8Array(bytes).buffer);
    const content_sha256 = Array.from(new Uint8Array(digest), byte => byte.toString(16).padStart(2, "0")).join("");
    const { data: intent, error } = await client.rpc("boss_communications_mutate", { p_request_id: requestId!, p_command: { operation: "attachment.intent", input: { thread_id: threadId!, file_name: filename, mime_type: mime, size_bytes: bytes.length, content_sha256 } } });
    if (error) return communicationFailure(error.code);
    if (!isRecord(intent) || intent.request_id !== requestId || intent.operation !== "attachment.intent" || intent.bucket !== COMMUNICATION_ATTACHMENT_BUCKET || !uuid(intent.attachment_id) || !safeCommunicationPath(intent.object_name ?? intent.object_path, intent.attachment_id, threadId!)) return communicationFailure();
    if (intent.completed === true) {
      if (!["ready", "attached"].includes(String(intent.status))) return communicationFailure();
      return { status: 200, body: { ok: true as const, result: { attachment_id: intent.attachment_id, filename, mime_type: mime, size_bytes: bytes.length } } };
    }
    const objectName = (intent.object_name ?? intent.object_path) as string;
    await client.storage.from(COMMUNICATION_ATTACHMENT_BUCKET).upload(objectName, bytes, { contentType: mime, upsert: false, cacheControl: "0" });
    // Replay completion checks authoritative immutable Storage metadata. A retry
    // may encounter an already-uploaded object; client upload status is no grant.
    const complete = await client.rpc("boss_communications_mutate", { p_request_id: completionId!, p_command: { operation: "attachment.complete", input: { attachment_id: intent.attachment_id } } });
    if (complete.error) return communicationFailure(complete.error.code);
    if (!isRecord(complete.data) || complete.data.request_id !== completionId || complete.data.operation !== "attachment.complete" || complete.data.resource_id !== intent.attachment_id) return communicationFailure();
    return { status: 200, body: { ok: true as const, result: { attachment_id: intent.attachment_id, filename, mime_type: mime, size_bytes: bytes.length } } };
  } catch { return communicationFailure(); }
}
export async function performCommunicationDownload(request: Request, client: CommunicationAttachmentClient, origin: string) {
  if (!isSameOriginPost(request, origin)) return communicationFailure("PT403");
  const input = await readBoundedJson(request, 4096);
  if (!isRecord(input) || Object.keys(input).some(key => !["attachment_id", "request_id"].includes(key)) || !uuid(input.attachment_id) || !uuid(input.request_id)) return communicationFailure("PT422");
  try {
    if (!await verifiedCommunicationCaller(client)) return communicationFailure("PT401");
    const { data, error } = await client.rpc("boss_communications_mutate", { p_request_id: input.request_id, p_command: { operation: "attachment.access", input: { attachment_id: input.attachment_id } } });
    if (error) return communicationFailure(error.code);
    if (!isRecord(data) || data.request_id !== input.request_id || data.operation !== "attachment.access" || data.resource_id !== input.attachment_id || data.bucket !== COMMUNICATION_ATTACHMENT_BUCKET || !safeCommunicationPath(data.object_name ?? data.object_path, input.attachment_id) || !documentMimeTypes.includes(data.mime_type as DocumentMimeType)) return communicationFailure();
    const downloaded = await client.storage.from(COMMUNICATION_ATTACHMENT_BUCKET).download((data.object_name ?? data.object_path) as string);
    if (downloaded.error || !downloaded.data || downloaded.data.size > MAX_DOCUMENT_BYTES || downloaded.data.type.split(";")[0].trim().toLowerCase() !== data.mime_type || !validDocumentBytes(new Uint8Array(await downloaded.data.arrayBuffer()), data.mime_type)) return communicationFailure("PT403");
    const extension = data.mime_type === "application/pdf" ? "pdf" : data.mime_type === "image/png" ? "png" : "jpg";
    return { status: 200, file: downloaded.data, mime: data.mime_type as DocumentMimeType, filename: `private-attachment.${extension}` };
  } catch { return communicationFailure(); }
}

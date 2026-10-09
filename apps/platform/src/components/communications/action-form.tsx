"use client";
import { useRef, useState, type FormEvent, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import type { CommunicationCommand } from "@/lib/communications/contracts";
import type { NotificationCommand } from "@/lib/notifications/contracts";
import { isRecord, parseCommunicationCommand } from "@/lib/communications/input";
import { parseNotificationCommand } from "@/lib/notifications/input";
export function CommunicationActionForm({ build, children, label = "Save changes", name, notifications = false, onSaved }: { build: (data: FormData) => CommunicationCommand | NotificationCommand | null; children?: ReactNode; label?: string; name?: string; notifications?: boolean; onSaved?: (result: Record<string, unknown>) => void }) {
  const router = useRouter(), [pending, setPending] = useState(false), [message, setMessage] = useState("");
  const messageRef = useRef<HTMLParagraphElement>(null), request = useRef<{ signature: string; id: string } | null>(null);
  function announce(value: string) { setMessage(value); queueMicrotask(() => messageRef.current?.focus()); }
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (pending) return; const command = build(new FormData(event.currentTarget));
    if (!command || !(notifications ? parseNotificationCommand(command) : parseCommunicationCommand(command))) { announce("Review the fields, then try again."); return; }
    const signature = JSON.stringify(command); if (request.current?.signature !== signature) request.current = { signature, id: crypto.randomUUID() };
    setPending(true); setMessage("");
    try { const response = await fetch(notifications ? "/app/notifications/mutate" : "/app/communications/mutate", { method: "POST", credentials: "same-origin", cache: "no-store", headers: { "content-type": "application/json" }, body: JSON.stringify({ request_id: request.current.id, command }) }); const body: unknown = await response.json();
      if (!response.ok || !isRecord(body) || body.ok !== true || !isRecord(body.result)) { announce(response.status === 401 ? "Please sign in again to continue." : response.status === 403 ? "You do not have permission to make this change." : response.status === 409 ? "The record changed. Refresh and review it." : response.status === 429 ? "Please wait before sending another message." : "Review the fields and your access, then try again."); return; }
      setMessage("Saved."); onSaved?.(body.result); router.refresh();
    } catch { announce("The change could not be confirmed. Retry to safely check the same request."); } finally { setPending(false); }
  }
  return <form aria-label={name} className="communication-form" onSubmit={submit}><fieldset disabled={pending}>{children}<div className="communication-form-footer"><button className="button button-primary" type="submit">{pending ? "Saving..." : label}</button><p ref={messageRef} tabIndex={-1} role="status" aria-live="polite">{message}</p></div></fieldset></form>;
}
export const formText = (data: FormData, key: string) => String(data.get(key) ?? "").trim();
export function CommunicationField({ name, label, value = "", required = false, maxLength = 200 }: { name: string; label: string; value?: string; required?: boolean; maxLength?: number }) { return <label className="form-field"><span>{label}</span><input name={name} defaultValue={value} required={required} maxLength={maxLength} /></label>; }
export function CommunicationTextarea({ name, label, value = "", maxLength = 8000, required = true }: { name: string; label: string; value?: string; maxLength?: number; required?: boolean }) { return <label className="form-field"><span>{label}</span><textarea name={name} defaultValue={value} required={required} maxLength={maxLength} rows={5} /></label>; }

"use client";
import { useRef, useState, type FormEvent, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import type { CoordinationCommand } from "@/lib/coordination/mutation";
import { projectCoordinationResult } from "@/lib/coordination/input";
import { parseAttendanceCommand } from "@/lib/attendance/input";
import { parseVolunteerCommand } from "@/lib/volunteers/input";

export function CoordinationForm({ resource, build, children, label = "Save changes" }: { resource: "attendance" | "volunteers"; build: (data: FormData) => CoordinationCommand | null; children?: ReactNode; label?: string }) {
  const router = useRouter(), retry = useRef<{ signature: string; id: string } | null>(null), status = useRef<HTMLParagraphElement>(null);
  const [pending, setPending] = useState(false), [message, setMessage] = useState("");
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (pending) return;
    const command = build(new FormData(event.currentTarget));
    if (!command || !(resource === "attendance" ? parseAttendanceCommand(command) : parseVolunteerCommand(command))) { setMessage("Review the fields and times, then try again."); return; }
    const signature = JSON.stringify(command); if (retry.current?.signature !== signature) retry.current = { signature, id: crypto.randomUUID() };
    const requestId = retry.current.id; setPending(true); setMessage("");
    try {
      const response = await fetch(`/app/${resource}/mutate`, { method: "POST", credentials: "same-origin", cache: "no-store", headers: { "content-type": "application/json" }, body: JSON.stringify({ command, request_id: requestId }) });
      const body: unknown = await response.json();
      if (!response.ok || !body || typeof body !== "object" || !("ok" in body) || body.ok !== true || !("result" in body) || !projectCoordinationResult(body.result, requestId, command.operation)) {
        setMessage(response.status === 403 ? "You do not have permission to make this change." : response.status === 401 ? "Please sign in again to continue." : response.status === 409 ? "This record changed, its deadline passed or the shift is full. Refresh and review it." : "The change could not be confirmed. Retry to safely check the same request."); return;
      }
      setMessage("Saved."); router.refresh();
    } catch { setMessage("The change could not be confirmed. Retry to safely check the same request."); }
    finally { setPending(false); }
  }
  return <form className="coordination-form" onSubmit={submit} onChange={() => setMessage("")}><fieldset disabled={pending} className="calendar-fieldset">{children}<div className="coordination-form-footer"><button type="submit" className="button button-primary button-small">{pending ? "Saving..." : label}</button><p ref={status} role="status" aria-live="polite">{message}</p></div></fieldset></form>;
}
export const fieldText = (data: FormData, key: string) => String(data.get(key) ?? "").trim();
export const fieldNullable = (data: FormData, key: string) => fieldText(data, key) || null;
export const fieldInteger = (data: FormData, key: string) => fieldText(data, key) ? Number(fieldText(data, key)) : null;
export function CoordinationField({ name, label, value = "", type = "text", required = false, maxLength = 500, min, max }: { name: string; label: string; value?: string | number | null; type?: string; required?: boolean; maxLength?: number; min?: number; max?: number }) {
  return <label className="form-field"><span>{label}</span><input name={name} defaultValue={value ?? ""} type={type} required={required} maxLength={maxLength} min={min} max={max} step={type === "datetime-local" ? 1 : type === "number" ? 1 : undefined} /></label>;
}

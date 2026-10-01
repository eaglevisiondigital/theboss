"use client";
import { useRef, useState, type FormEvent, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import type { CalendarCommand, CalendarPreview } from "@/lib/calendar/contracts";
import { parseCalendarCommand, projectCalendarPreview } from "@/lib/calendar/input";
import { formatTime } from "@/lib/calendar/temporal";

export function CalendarActionForm({ build, children, label = "Save changes", preview = false, timezone = "UTC" }: { build: (data: FormData) => CalendarCommand | null; children: ReactNode; label?: string; preview?: boolean; timezone?: string }) {
  const router = useRouter(); const [pending,setPending] = useState(false); const [message,setMessage] = useState("");
  const [check,setCheck] = useState<{ signature: string; result: CalendarPreview } | null>(null);
  const request = useRef<{ signature: string; id: string } | null>(null);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (pending) return;
    const form = event.currentTarget; const data = new FormData(form); const command = build(data);
    if (!command || !parseCalendarCommand(command)) { setMessage("Review the fields and times. A time skipped by daylight saving needs a different time."); return; }
    const checkedCommand = { ...command, input: { ...command.input, override_conflicts: false } };
    const signature = JSON.stringify(checkedCommand); const needsPreview = preview && check?.signature !== signature;
    setPending(true); setMessage("");
    try {
      if (needsPreview) {
        const response = await fetch("/app/calendar/preview",{ method: "POST", credentials: "same-origin", cache: "no-store", headers: { "content-type": "application/json" }, body: JSON.stringify({ command: checkedCommand }) });
        const body: unknown = await response.json();
        if (!response.ok || typeof body !== "object" || body === null || !("ok" in body) || body.ok !== true || !("preview" in body)) { setMessage("The scheduling check failed. Refresh or review the fields and try again."); return; }
        const result = projectCalendarPreview(body.preview); if (!result) { setMessage("The scheduling check could not be confirmed."); return; }
        setCheck({ signature,result }); setMessage(result.has_conflicts ? "Review the conflicts below before saving." : "Schedule checked. Save when ready."); return;
      }
      if (preview && check?.result.has_conflicts && (!check.result.can_override || data.get("override_conflicts") !== "on")) { setMessage("This schedule has conflicts. An authorized override is required to save it."); return; }
      const finalSignature = JSON.stringify(command);
      if (request.current?.signature !== finalSignature) request.current = { signature: finalSignature,id: crypto.randomUUID() };
      const response = await fetch("/app/calendar/mutate",{ method: "POST", credentials: "same-origin", cache: "no-store", headers: { "content-type": "application/json" }, body: JSON.stringify({ command, request_id: request.current.id }) });
      const body: unknown = await response.json();
      if (!response.ok || typeof body !== "object" || body === null || !("ok" in body) || body.ok !== true) {
        setMessage(response.status === 409 ? "The record changed or conflicts with another event. Refresh and review the schedule." : response.status === 403 ? "You do not have permission to save this change." : response.status === 401 ? "Please sign in again to continue." : "The change could not be saved. Review the fields and try again."); return;
      }
      setMessage("Saved."); setCheck(null); router.refresh();
    } catch { setMessage("The change could not be confirmed. Retry to safely check the same request."); }
    finally { setPending(false); }
  }
  return <form className="calendar-form" onSubmit={submit} onChange={event => { setMessage(""); if (!(event.target instanceof HTMLInputElement) || event.target.name !== "override_conflicts") setCheck(null); }}>
    <fieldset disabled={pending} className="calendar-fieldset">{children}
      {check?.result.has_conflicts && <section className="calendar-conflicts" aria-label="Scheduling conflicts"><h3>Scheduling conflicts</h3><ul>{check.result.conflicts.map((conflict,index) => <li key={index}><strong>{conflict.title}</strong> <span>{conflict.kind} · {formatTime(conflict.start_at,timezone)} to {formatTime(conflict.end_at,timezone)} ({timezone})</span></li>)}</ul>{check.result.can_override && <label className="calendar-check"><input type="checkbox" name="override_conflicts" />Override these conflicts. This decision is recorded.</label>}</section>}
      <div className="calendar-form-footer"><button className="button button-primary" type="submit">{pending ? "Working..." : preview && !check ? "Check schedule" : label}</button><p role="status" aria-live="polite">{message}</p></div>
    </fieldset>
  </form>;
}
export const formText = (data: FormData,key: string) => String(data.get(key) ?? "").trim();
export const formNullable = (data: FormData,key: string) => formText(data,key) || null;
export function CalendarField({ label, name, value = "", type = "text", required = false, maxLength = 200 }: { label: string; name: string; value?: string | number; type?: string; required?: boolean; maxLength?: number }) {
  return <label className="form-field"><span>{label}</span><input name={name} type={type} defaultValue={value} required={required} maxLength={maxLength} step={type === "datetime-local" ? 1 : undefined} /></label>;
}

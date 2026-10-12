"use client";
import { useRef, useState, type FormEvent, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import type { RegistrationCommand, RegistrationRow } from "@/lib/registration/contracts";
import { isRecord, parseRegistrationCommand } from "@/lib/registration/input";

export function RegistrationActionForm({ build, children, label = "Save changes", onSaved, name }: { build: (data: FormData) => RegistrationCommand | null; children: ReactNode; label?: string; name?: string; onSaved?: (result: RegistrationRow) => void }) {
  const router = useRouter(); const [pending, setPending] = useState(false); const [message, setMessage] = useState("");
  const messageRef = useRef<HTMLParagraphElement>(null);
  function announce(value: string) { setMessage(value); queueMicrotask(() => messageRef.current?.focus()); }
  const request = useRef<{ signature: string; id: string } | null>(null);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (pending) return;
    const command = build(new FormData(event.currentTarget));
    if (!command || !parseRegistrationCommand(command)) { announce("Review the fields, then try again."); return; }
    const signature = JSON.stringify(command); if (request.current?.signature !== signature) request.current = { signature, id: crypto.randomUUID() };
    setPending(true); setMessage("");
    try {
      const response = await fetch("/app/registrations/mutate", { method: "POST", credentials: "same-origin", cache: "no-store", headers: { "content-type": "application/json" }, body: JSON.stringify({ request_id: request.current.id, command }) });
      const body: unknown = await response.json();
      if (!response.ok || !isRecord(body) || body.ok !== true || !isRecord(body.result)) { announce(response.status === 403 ? "You do not have permission to save this change." : response.status === 409 ? "The record changed or capacity is unavailable. Refresh and review it." : response.status === 401 ? "Please sign in again to continue." : "Review the fields and requirements, then try again."); return; }
      setMessage("Saved. Your records have been refreshed."); onSaved?.(body.result as RegistrationRow); router.refresh();
    } catch { announce("The change could not be confirmed. Retry to safely check the same request."); }
    finally { setPending(false); }
  }
  return <form aria-label={name} className="registration-form" onSubmit={submit}><fieldset disabled={pending}>{children}<div className="registration-form-footer"><button className="button button-primary" type="submit">{pending ? "Saving..." : label}</button><p ref={messageRef} tabIndex={-1} role="status" aria-live="polite">{message}</p></div></fieldset></form>;
}
export const formText = (data: FormData, key: string) => String(data.get(key) ?? "").trim();
export const formNullable = (data: FormData, key: string) => formText(data, key) || null;
export const formNumber = (data: FormData, key: string) => formText(data, key) ? Number(formText(data, key)) : null;
export function Field({ name, label, type = "text", value = "", required = false, maxLength = 200, min, max }: { name: string; label: string; type?: string; value?: string | number; required?: boolean; maxLength?: number; min?: number; max?: number }) {
  return <label className="form-field"><span>{label}</span><input name={name} type={type} defaultValue={value} required={required} maxLength={maxLength} min={min} max={max} step={type === "number" ? 1 : undefined} /></label>;
}
export function Textarea({ name, label, value = "", required = false, maxLength = 4000 }: { name: string; label: string; value?: string; required?: boolean; maxLength?: number }) {
  return <label className="form-field"><span>{label}</span><textarea name={name} defaultValue={value} required={required} maxLength={maxLength} rows={4} /></label>;
}
export function Select({ name, label, options, value, required = false }: { name: string; label: string; options: { value: string; label: string }[]; value?: string; required?: boolean }) {
  return <label className="form-field"><span>{label}</span><select name={name} defaultValue={value} required={required}>{options.map(option => <option value={option.value} key={option.value}>{option.label}</option>)}</select></label>;
}
export function Check({ name, label, checked = false }: { name: string; label: string; checked?: boolean }) { return <label className="registration-check"><input type="checkbox" name={name} defaultChecked={checked} />{label}</label>; }
export function Disclosure({ title, children }: { title: string; children: ReactNode }) { return <details className="registration-disclosure"><summary>{title}</summary>{children}</details>; }

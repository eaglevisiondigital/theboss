"use client";
import { useRef, useState, type FormEvent, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { isRecord } from "@/lib/coordination/input";
import { parseAchievementCommand, type AchievementCommand } from "@/lib/achievements/input";
export function AchievementActionForm({ label, children, build, onSaved }: { label: string; children?: ReactNode; build: (fields: FormData) => Omit<AchievementCommand, "request_id"> | null; onSaved?: (id: string) => void }) {
  const router = useRouter(), receipt = useRef<{ id: string; signature: string } | null>(null), [pending, setPending] = useState(false), [message, setMessage] = useState("");
  async function submit(e: FormEvent<HTMLFormElement>) {
    e.preventDefault(); if (pending) return; const action = build(new FormData(e.currentTarget)); if (!action) { setMessage("Review the recognition fields."); return; }
    const signature = JSON.stringify(action); if (receipt.current?.signature !== signature) receipt.current = { id: crypto.randomUUID(), signature };
    const command = parseAchievementCommand({ ...action, request_id: receipt.current.id }); if (!command) { setMessage("Review the recognition fields."); return; }
    setPending(true); setMessage("");
    try {
      const response = await fetch("/app/achievements/mutate", { method: "POST", credentials: "same-origin", cache: "no-store", headers: { "content-type": "application/json" }, body: JSON.stringify(command) }), body: unknown = await response.json();
      if (!response.ok || !isRecord(body) || body.ok !== true || body.action !== action.action || typeof body.id !== "string") { setMessage(response.status === 403 ? "This recognition scope is restricted." : response.status === 409 ? "The recognition changed. Refresh and review it." : "The change could not be confirmed."); return; }
      receipt.current = null; setMessage(body.has_more === true ? "Batch confirmed. Continue evaluation to finish the remaining facts." : "Change confirmed."); onSaved?.(body.id); router.refresh();
    } catch { setMessage("The change could not be confirmed."); } finally { setPending(false); }
  }
  return <form onSubmit={submit} className="game-action-form"><fieldset className="calendar-fieldset" disabled={pending}>{children}<button className="button button-outline button-small" type="submit">{pending ? "Saving..." : label}</button><p role="status" aria-live="polite">{message}</p></fieldset></form>;
}

"use client";
import { useRef, useState, type FormEvent, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import { parseRankingCommand, type RankingCommand } from "@/lib/rankings/action";
import { isRecord } from "@/lib/coordination/input";
import { statUuid } from "@/lib/stat-intelligence/input";
export function RankingActionForm({ label, children, build, onSaved }: { label: string; children?: ReactNode; build: (fields: FormData) => Omit<RankingCommand, "request_id"> | null; onSaved?: (id: string) => void }) {
  const router = useRouter(), receipt = useRef<{ id: string; signature: string } | null>(null);
  const [pending, setPending] = useState(false), [message, setMessage] = useState("");
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (pending) return;
    const action = build(new FormData(event.currentTarget)); if (!action) { setMessage("Review the competition fields."); return; }
    const signature = JSON.stringify(action); if (receipt.current?.signature !== signature) receipt.current = { id: crypto.randomUUID(), signature };
    const command = parseRankingCommand({ ...action, request_id: receipt.current.id }); if (!command) { setMessage("Review the competition fields."); return; }
    setPending(true); setMessage("");
    try {
      const response = await fetch("/app/competitions/mutate", { method: "POST", credentials: "same-origin", cache: "no-store", headers: { "content-type": "application/json" }, body: JSON.stringify(command) });
      const body: unknown = await response.json();
      if (!response.ok || !isRecord(body) || body.ok !== true || body.action !== action.action || !statUuid(body.id)) { setMessage(response.status === 403 ? "This scope is restricted." : response.status === 409 ? "The scope changed. Refresh and review it." : "The change could not be confirmed. Retry the same request safely."); return; }
      if (action.action === "ranking.rebuild" && typeof body.complete !== "boolean") { setMessage("The rebuild could not be confirmed."); return; }
      receipt.current = null;
      setMessage(body.complete === false ? "Batch complete. Continue rebuilding this scope." : "Change confirmed.");
      onSaved?.(body.id); router.refresh();
    } catch { setMessage("The change could not be confirmed. Retry the same request safely."); }
    finally { setPending(false); }
  }
  return <form onSubmit={submit} className="game-action-form"><fieldset className="calendar-fieldset" disabled={pending}>{children}<button type="submit" className="button button-outline button-small">{pending ? "Saving..." : label}</button><p role="status" aria-live="polite">{message}</p></fieldset></form>;
}

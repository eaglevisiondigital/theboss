"use client";
import { useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import { competitionClasses, parseStatAction, type StatAction } from "@/lib/stat-intelligence/action";
import { statUuid } from "@/lib/stat-intelligence/input";
export function StatManagement({ gameId, query }: { gameId?: string; query?: { organization_id: string; team_id: string; season_id: string; sport_key: string } }) {
  const router = useRouter(), receipt = useRef<{ signature: string; id: string } | null>(null);
  const [pending, setPending] = useState(false), [message, setMessage] = useState(""), [cursor, setCursor] = useState<string | undefined>();
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (pending) return;
    const fields = new FormData(event.currentTarget), action: StatAction | null = parseStatAction(gameId ? { operation: "classify", game_id: gameId, classification: fields.get("classification"), reason: fields.get("reason") } : { operation: "rebuild", query, ...(cursor ? { after_game: cursor } : {}) });
    if (!action) { setMessage("Review the statistical fields."); return; }
    const signature = JSON.stringify(action); if (receipt.current?.signature !== signature) receipt.current = { signature, id: crypto.randomUUID() };
    setPending(true); setMessage("");
    try {
      const response = await fetch("/app/statistics/mutate", { method: "POST", credentials: "same-origin", cache: "no-store", headers: { "content-type": "application/json" }, body: JSON.stringify({ request_id: receipt.current.id, action }) });
      const body: unknown = await response.json();
      if (!response.ok || !body || typeof body !== "object" || !("ok" in body) || body.ok !== true || !("operation" in body) || body.operation !== action.operation) { setMessage(response.status === 403 ? "Statistics authority is restricted." : response.status === 409 ? "Reopen the game before changing sealed eligibility." : "The statistical change could not be confirmed."); return; }
      if (action.operation === "rebuild") {
        if (!("complete" in body) || typeof body.complete !== "boolean" || !("cursor" in body) || body.cursor !== null && !statUuid(body.cursor)) { setMessage("The rebuild could not be confirmed."); return; }
        setCursor(body.complete || body.cursor === null ? undefined : body.cursor);
        setMessage(body.complete ? "Statistics rebuild complete." : "Batch complete. Continue rebuilding to finish this scope.");
      } else setMessage("Competition classification saved. It applies at the next finalization.");
      router.refresh();
    } catch { setMessage("The statistical change could not be confirmed. Retry the same request safely."); }
    finally { setPending(false); }
  }
  return <form className="game-action-form" onSubmit={submit}><fieldset className="calendar-fieldset" disabled={pending}>{gameId && <><label className="form-field"><span>Competition classification</span><select name="classification" required defaultValue=""><option value="">Choose classification</option>{competitionClasses.map(c => <option key={c} value={c}>{c.replaceAll("_", " ")}</option>)}</select></label><label className="form-field"><span>Reason</span><textarea name="reason" required maxLength={500} rows={2} /></label></>}<button type="submit" className="button button-outline button-small">{pending ? "Saving..." : gameId ? "Save statistical eligibility" : cursor ? "Continue statistics rebuild" : "Rebuild team-season statistics"}</button><p role="status" aria-live="polite">{message}</p></fieldset></form>;
}

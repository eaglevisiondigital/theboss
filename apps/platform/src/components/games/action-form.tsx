"use client";
import { useRef, useState, type FormEvent, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import type { GameCommand } from "@/lib/games/contracts";
import { gameResultMatchesCommand, parseGameCommand, projectGameResult } from "@/lib/games/input";
import { useOptionalBasketballIntent } from "../basketball/intent-provider";
export function GameForm({ build, children, label, confirmation }: { build: (data: FormData) => GameCommand | null; children?: ReactNode; label: string; confirmation?: string }) {
  const router = useRouter(), retry = useRef<{ signature: string; id: string } | null>(null), basketball = useOptionalBasketballIntent();
  const [pending, setPending] = useState(false), [message, setMessage] = useState("");
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (pending || basketball?.blocked) return;
    const command = build(new FormData(event.currentTarget));
    if (!command || !parseGameCommand(command)) { setMessage("Review the game fields, then try again."); return; }
    if (command.operation.startsWith("basketball.") && basketball) {
      setPending(true); setMessage("");
      try { const outcome = await basketball.send(command); setMessage(outcome.message); }
      finally { setPending(false); }
      return;
    }
    const signature = JSON.stringify(command); if (retry.current?.signature !== signature) retry.current = { signature, id: crypto.randomUUID() };
    const requestId = retry.current.id; setPending(true); setMessage("");
    try {
      const response = await fetch("/app/games/mutate", { method: "POST", credentials: "same-origin", cache: "no-store", headers: { "content-type": "application/json" }, body: JSON.stringify({ command, request_id: requestId }) });
      const body: unknown = await response.json();
      if (!response.ok || !body || typeof body !== "object" || !("ok" in body) || body.ok !== true || !("result" in body) || !projectGameResult(body.result)) { setMessage(response.status === 403 ? "You do not have permission to make this game change." : response.status === 401 ? "Please sign in again to continue." : response.status === 409 ? "The game, schedule or authority changed. Refresh and review it." : "The change could not be confirmed. Retry to safely check the same request."); return; }
      const result = projectGameResult(body.result)!;
      if (!gameResultMatchesCommand(result, command)) { setMessage("The change could not be confirmed. Retry to safely check the same request."); return; }
      setMessage(result.replayed ? "Already saved." : "Saved.");
      if (command.operation === "game.create" && result.game_id) router.push(`/app/games?game=${result.game_id}`); else router.refresh();
    } catch { setMessage("The change could not be confirmed. Retry to safely check the same request."); }
    finally { setPending(false); }
  }
  return <form className="game-action-form" onSubmit={submit} onChange={() => setMessage("")}><fieldset className="calendar-fieldset" disabled={pending}>{children}{confirmation && <label className="game-confirmation"><input name="confirmed" type="checkbox" required /><span>{confirmation}</span></label>}<div className="game-form-footer"><button type="submit" className="button button-primary button-small">{pending ? "Saving..." : label}</button><p role="status" aria-live="polite">{message}</p></div></fieldset></form>;
}

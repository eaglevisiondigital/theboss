"use client";
import { createContext, useContext, useRef, useState, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import type { GameCommand } from "@/lib/games/contracts";
import { GameIntent, type GameIntentOutcome } from "@/lib/games/intent";

type IntentContext = { blocked: boolean; pending: boolean; message: string; send: (command: GameCommand) => Promise<GameIntentOutcome>; refresh: () => void };
const GameIntentContext = createContext<IntentContext | null>(null);
export function useOptionalGameIntent() { return useContext(GameIntentContext); }
export function useGameIntent() { const context = useOptionalGameIntent(); if (!context) throw new Error("Sport controls require their game context."); return context; }

/** The provider survives canonical refresh and child form remounts within this game page. */
export function GameIntentProvider({ version, children }: { version: number; children: ReactNode }) {
  const router = useRouter(), controller = useRef(new GameIntent());
  const [pending, setPending] = useState(false), [message, setMessage] = useState("");
  const unconfirmed = controller.current.hasUnconfirmed(), blocked = pending || unconfirmed || controller.current.waitingFor(version);
  async function submit(command?: GameCommand) {
    setPending(true); setMessage("");
    const outcome = command ? await controller.current.execute(command) : await controller.current.retryUnconfirmed();
    setMessage(outcome.message); setPending(false);
    if (outcome.kind === "saved") router.refresh();
    return outcome;
  }
  const value: IntentContext = { blocked, pending, message, send: command => submit(command), refresh: () => router.refresh() };
  return <GameIntentContext.Provider value={value}><div className="basketball-intent-state"><p role="status" aria-live="polite">{pending ? "Saving..." : message || (blocked ? "Waiting for the updated game..." : "")}</p>{unconfirmed && <div className="game-attention"><p>A previous game change has an unconfirmed outcome. New game entries remain closed until it is checked.</p><button className="button button-primary" type="button" disabled={pending} onClick={() => void submit()}>Retry unconfirmed change</button></div>}{blocked && <button className="button button-outline" type="button" disabled={pending} onClick={() => router.refresh()}>Refresh game</button>}</div><fieldset className="calendar-fieldset" disabled={blocked}>{children}</fieldset></GameIntentContext.Provider>;
}

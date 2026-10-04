"use client";
import { createContext, useContext, useRef, useState, type ReactNode } from "react";
import { useRouter } from "next/navigation";
import type { GameCommand } from "@/lib/games/contracts";
import { BasketballIntent, type BasketballOutcome } from "@/lib/basketball/intent";

type IntentContext = { blocked: boolean; pending: boolean; message: string; send: (command: GameCommand) => Promise<BasketballOutcome>; refresh: () => void };
const BasketballIntentContext = createContext<IntentContext | null>(null);
export function useOptionalBasketballIntent() { return useContext(BasketballIntentContext); }
export function useBasketballIntent() { const context = useOptionalBasketballIntent(); if (!context) throw new Error("Basketball controls require their game context."); return context; }

/** The provider survives canonical refresh and child form remounts within this game page. */
export function BasketballIntentProvider({ version, children }: { version: number; children: ReactNode }) {
  const router = useRouter(), controller = useRef(new BasketballIntent());
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
  return <BasketballIntentContext.Provider value={value}><div className="basketball-intent-state"><p role="status" aria-live="polite">{pending ? "Saving..." : message || (blocked ? "Waiting for the updated game..." : "")}</p>{unconfirmed && <div className="game-attention"><p>A previous basketball change has an unconfirmed outcome. New basketball entries remain closed until it is checked.</p><button className="button button-primary" type="button" disabled={pending} onClick={() => void submit()}>Retry unconfirmed change</button></div>}{blocked && <button className="button button-outline" type="button" disabled={pending} onClick={() => router.refresh()}>Refresh game</button>}</div><fieldset className="calendar-fieldset" disabled={blocked}>{children}</fieldset></BasketballIntentContext.Provider>;
}

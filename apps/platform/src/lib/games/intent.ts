import type { GameCommand } from "./contracts";
import { gameResultMatchesCommand, parseGameCommand, projectGameResult } from "./input";
export type GameIntentOutcome = { kind: "saved" | "busy" | "refresh" | "denied" | "invalid" | "unknown"; message: string; version?: number; event_id?: string };
type Transport = (input: RequestInfo | URL, init?: RequestInit) => Promise<Response>;
/** One intent keeps its request ID until confirmed; a subsequent play is a new intent. */
export class GameIntent {
  private inFlight = false;
  private retry: { command: GameCommand; id: string } | null = null;
  private confirmedVersion = 0;
  constructor(private readonly makeId: () => string = () => crypto.randomUUID(), private readonly prefixes: readonly string[] = ["basketball.", "soccer.", "football.", "volleyball.", "diamond.", "tracking."]) {}
  waitingFor(version: number) { return this.inFlight || version < this.confirmedVersion; }
  hasUnconfirmed() { return this.retry !== null && !this.inFlight; }
  async execute(command: GameCommand, transport: Transport = fetch): Promise<GameIntentOutcome> {
    if (this.inFlight) return { kind: "busy", message: "A game change is being saved." };
    if (!parseGameCommand(command) || !this.prefixes.some(prefix => command.operation.startsWith(prefix))) return { kind: "invalid", message: "Review the game fields, then try again." };
    if (this.retry) return { kind: "unknown", message: "An earlier change is unconfirmed. Retry that change before recording another." };
    if (Number(command.operation === "tracking.profile.set" ? command.input.expected_game_version : command.input.expected_version) < this.confirmedVersion) return { kind: "refresh", message: "Waiting for the updated game. Refresh if it does not appear." };
    this.retry = { command: JSON.parse(JSON.stringify(command)) as GameCommand, id: this.makeId() };
    return this.send(transport);
  }
  async retryUnconfirmed(transport: Transport = fetch): Promise<GameIntentOutcome> {
    if (this.inFlight) return { kind: "busy", message: "A game change is being saved." };
    if (!this.retry) return { kind: "invalid", message: "There is no unconfirmed change to retry." };
    return this.send(transport);
  }
  private async send(transport: Transport): Promise<GameIntentOutcome> {
    const intent = this.retry!;
    this.inFlight = true;
    try {
      const response = await transport("/app/games/mutate", { method: "POST", credentials: "same-origin", cache: "no-store", headers: { "content-type": "application/json" }, body: JSON.stringify({ command: intent.command, request_id: intent.id }) });
      const body: unknown = await response.json();
      const result = body && typeof body === "object" && "ok" in body && body.ok === true && "result" in body ? projectGameResult(body.result) : null;
      if (response.ok && result && gameResultMatchesCommand(result, intent.command)) {
        this.retry = null;
        this.confirmedVersion = Math.max(this.confirmedVersion, result.version);
        return { kind: "saved", message: result.replayed ? "Already saved." : "Saved.", version: result.version, ...(result.event_id ? { event_id: result.event_id } : {}) };
      }
      if ([401, 403, 409, 422].includes(response.status)) {
        this.retry = null;
        return response.status === 409 ? { kind: "refresh", message: "The game or authority changed. Refresh and review before trying again." } : response.status === 422 ? { kind: "invalid", message: "This game change is not valid for the current game." } : { kind: "denied", message: response.status === 401 ? "Please sign in again to continue." : "You do not have permission to make this game change." };
      }
      return { kind: "unknown", message: "This change could not be confirmed. Use Retry unconfirmed change to safely check the original request." };
    } catch { return { kind: "unknown", message: "This change could not be confirmed. Use Retry unconfirmed change to safely check the original request." }; }
    finally { this.inFlight = false; }
  }
}

import { GameIntent, type GameIntentOutcome } from "../games/intent";
export type SoccerOutcome = GameIntentOutcome;
/** Soccer-only entry point; recovery uses the same immutable per-game transport. */
export class SoccerIntent extends GameIntent {
  constructor(makeId: () => string = () => crypto.randomUUID()) { super(makeId, ["soccer."]); }
}

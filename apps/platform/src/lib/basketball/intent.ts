import { GameIntent, type GameIntentOutcome } from "../games/intent";
export type BasketballOutcome = GameIntentOutcome;
/** Basketball-only compatibility wrapper around the shared per-game intent transport. */
export class BasketballIntent extends GameIntent {
  constructor(makeId: () => string = () => crypto.randomUUID()) { super(makeId, ["basketball."]); }
}

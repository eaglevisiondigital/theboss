import { GameIntent } from "../games/intent";
export class FootballIntent extends GameIntent { constructor(makeId?: () => string) { super(makeId, ["football."]); } }

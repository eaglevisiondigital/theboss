import { createPracticeSession, type PracticeSession } from "../stat-tracking/practice";
import type { TrackingSelection } from "../stat-tracking/profile";
import type { DiamondFact, DiamondRule, DiamondSport, DiamondState } from "./contracts";
import { initialDiamond, transitionDiamond } from "./reducer";
export type DiamondPractice = { session: PracticeSession; configuration: DiamondRule; state: DiamondState; facts: DiamondFact[] };
export function createDiamondPractice(sport: DiamondSport, profile: TrackingSelection, configuration: DiamondRule): DiamondPractice {
 const session=createPracticeSession(sport,profile);const c={...configuration,lineup_size:6};let state=initialDiamond(c);const facts:DiamondFact[]=[];
 for(const side of["primary","opponent"]as const){const order=session.participants.filter(p=>p.side===side).map(p=>p.key);const fact:DiamondFact={kind:"lineup_set",side,order,positions:{},pitcher:order.at(-1)!};facts.push(fact);state=transitionDiamond(c,state,fact);}
 const fact:DiamondFact={kind:"half_start"};facts.push(fact);state=transitionDiamond(c,state,fact);return{session,configuration:c,state,facts};
}
export function applyDiamondPractice(p:DiamondPractice,fact:DiamondFact):DiamondPractice{return{...p,state:transitionDiamond(p.configuration,p.state,fact),facts:[...p.facts,structuredClone(fact)]};}

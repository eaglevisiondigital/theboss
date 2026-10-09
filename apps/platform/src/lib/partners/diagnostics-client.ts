import {emitPartnerDiagnostic,partnerDiagnosticRoute,validPartnerCorrelation,type PartnerDiagnosticInput,type PartnerDiagnosticOperation}from"./diagnostics";
let lastRead:string|null=null,lastMutation:string|null=null,lastBoundary:string|null=null,accepted=false;
export function clearPartnerClientTrace(){lastRead=null;lastMutation=null;lastBoundary=null;accepted=false;}
export function partnerClientDiagnostic(input:Omit<PartnerDiagnosticInput,"correlationId"|"phase"|"route">,correlationId?:string){
 try{if(typeof window==="undefined")return;const route=partnerDiagnosticRoute(window.location.pathname);if(!route)return;
 const id=validPartnerCorrelation(correlationId)?correlationId:lastMutation??lastRead??lastBoundary??crypto.randomUUID();
 if(input.stage==="response_accepted")accepted=true;
 if(input.stage==="error_boundary")lastBoundary=id;
 emitPartnerDiagnostic({...input,route,phase:input.stage==="error_boundary"?"client-boundary":"client",correlationId:id,classification:input.stage==="error_boundary"&&accepted?"refresh-failed":input.classification});
 }catch{/* No storage or business dependency. */}
}
export function partnerClientRendered(correlationId:string,discovery=false){
 try{if(typeof window==="undefined"||!partnerDiagnosticRoute(window.location.pathname)||!validPartnerCorrelation(correlationId))return;
 emitPartnerDiagnostic({correlationId,parentCorrelationId:lastMutation,route:discovery?"/app/partners/discovery":"/app/partners",phase:"client",stage:"client_rendered",observedAt:discovery?"src/components/partners/discovery.tsx":"src/components/partners/workspace.tsx"});
 lastRead=correlationId;lastMutation=null;lastBoundary=null;accepted=false;
 }catch{/* Rendering stays independent. */}
}
export function partnerClientMutationStarted(operation:PartnerDiagnosticOperation,reconciling:boolean){
 try{const id=crypto.randomUUID();partnerClientDiagnostic({stage:reconciling?"reconciliation_attempted":"mutation_started",observedAt:"src/lib/partners/action.ts",operation,parentCorrelationId:lastRead},id);return id;}catch{return undefined;}
}
export function partnerClientResponse(correlationId:unknown,parent:string|undefined,status:number,operation:PartnerDiagnosticOperation){
 try{if(!validPartnerCorrelation(correlationId))return;lastMutation=correlationId;accepted=false;partnerClientDiagnostic({stage:"http_response",observedAt:"src/lib/partners/action.ts",parentCorrelationId:parent,operation,status},correlationId);}catch{/* Confirmation remains independent. */}
}

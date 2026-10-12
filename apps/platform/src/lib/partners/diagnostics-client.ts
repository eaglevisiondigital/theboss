import {emitPartnerDiagnostic,partnerDiagnosticRoute,validPartnerCorrelation,type PartnerDiagnosticInput,type PartnerDiagnosticOperation,type PartnerTraceState}from"./diagnostics";
let lastRead:string|null=null,lastMutation:string|null=null,lastBoundary:string|null=null,accepted=false;
// Registered diagnostic context before this event, not request/operation identity.
function registeredTraceState():PartnerTraceState{return lastMutation?"mutation_response":lastRead?"read":lastBoundary?"boundary":"uninitialized";}
export function clearPartnerClientTrace(){lastRead=null;lastMutation=null;lastBoundary=null;accepted=false;}
export function partnerClientDiagnostic(input:Omit<PartnerDiagnosticInput,"correlationId"|"phase"|"route"|"traceState">,correlationId?:string){
 try{if(typeof window==="undefined")return;const route=partnerDiagnosticRoute(window.location.pathname);if(!route)return;
 const traceState=registeredTraceState();
 const id=validPartnerCorrelation(correlationId)?correlationId:lastMutation??lastRead??lastBoundary??crypto.randomUUID();
 if(input.stage==="response_accepted")accepted=true;
 if(input.stage==="error_boundary")lastBoundary=id;
 emitPartnerDiagnostic({...input,route,phase:input.stage==="error_boundary"?"client-boundary":"client",correlationId:id,traceState,classification:input.stage==="error_boundary"&&accepted?"refresh-failed":input.classification});
 }catch{/* No storage or business dependency. */}
}
export function partnerClientGlobalError(kind:"window_error"|"unhandled_rejection",error:unknown){
 // This identifies the listener only. It does not identify a code origin or recovery.
 partnerClientDiagnostic({stage:"client_exception",observedAt:"src/instrumentation-client.ts",classification:kind,error});
}
export function partnerClientRendered(correlationId:string,discovery=false){
 try{if(typeof window==="undefined"||!partnerDiagnosticRoute(window.location.pathname)||!validPartnerCorrelation(correlationId))return;
 emitPartnerDiagnostic({correlationId,parentCorrelationId:lastMutation,traceState:registeredTraceState(),route:discovery?"/app/partners/discovery":"/app/partners",phase:"client",stage:"client_rendered",observedAt:discovery?"src/components/partners/discovery.tsx":"src/components/partners/workspace.tsx"});
 lastRead=correlationId;lastMutation=null;lastBoundary=null;accepted=false;
 }catch{/* Rendering stays independent. */}
}
export function partnerClientMutationStarted(operation:PartnerDiagnosticOperation,reconciling:boolean){
 try{const id=crypto.randomUUID();partnerClientDiagnostic({stage:reconciling?"reconciliation_attempted":"mutation_started",observedAt:"src/lib/partners/action.ts",operation,parentCorrelationId:lastRead},id);return id;}catch{return undefined;}
}
export function partnerClientResponse(correlationId:unknown,parent:string|undefined,status:number,operation:PartnerDiagnosticOperation){
 try{if(!validPartnerCorrelation(correlationId))return;lastMutation=correlationId;accepted=false;partnerClientDiagnostic({stage:"http_response",observedAt:"src/lib/partners/action.ts",parentCorrelationId:parent,operation,status},correlationId);}catch{/* Confirmation remains independent. */}
}

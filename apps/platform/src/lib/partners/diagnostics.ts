import { finiteErrorDetails } from "../diagnostics/error";
import { validMerchantCorrelation } from "../merchants/diagnostics";
import { PARTNER_FIELDS } from "./fields";
export const PARTNER_DIAGNOSTIC_PREFIX="BOSS_PARTNER_DIAGNOSTIC ";
export const PARTNER_CORRELATION_HEADER="x-boss-partner-diagnostic";
export const PARTNER_PARENT_HEADER="x-boss-partner-diagnostic-parent";
export const validPartnerCorrelation=validMerchantCorrelation;
export const partnerDiagnosticStages=["page_enter","read_started","read_completed","read_failed","contract_rejected","mutation_started","rpc_completed","rpc_failed","http_response","response_accepted","response_rejected","unknown_confirmation","refresh_requested","client_rendered","error_boundary","retry_requested","reconciliation_attempted","server_exception","client_exception"] as const;
const phases=["server-component","server-render","server-route","server-proxy","client","client-boundary"] as const;
const classifications=["event","exception","window_error","unhandled_rejection","contract-rejected","scope-denied","upstream-unavailable","confirmed-success","confirmed-rejection","unknown-result","invalid-json","invalid-receipt","refresh-failed"] as const;
const traceStates=["uninitialized","read","mutation_response","boundary"] as const;
export type PartnerTraceState=typeof traceStates[number];
const files=["src/app/app/partners/page.tsx","src/app/app/partners/discovery/page.tsx","src/app/app/partners/mutate/route.ts","src/lib/partners/data.ts","src/lib/partners/mutation.ts","src/lib/partners/action.ts","src/components/partners/workspace.tsx","src/components/partners/discovery.tsx","src/app/error.tsx","src/app/app/layout.tsx","src/instrumentation.ts","src/instrumentation-client.ts","src/proxy.ts"] as const;
export type PartnerDiagnosticRoute="/app/partners"|"/app/partners/mutate"|"/app/partners/discovery";
export type PartnerDiagnosticOperation=keyof typeof PARTNER_FIELDS|"partners.read"|"partners.discovery";
export type PartnerDiagnosticInput={correlationId:string;parentCorrelationId?:string|null;route?:PartnerDiagnosticRoute;phase:typeof phases[number];stage:typeof partnerDiagnosticStages[number];observedAt:typeof files[number];classification?:typeof classifications[number];traceState?:PartnerTraceState;operation?:PartnerDiagnosticOperation;status?:number;error?:unknown};
export function partnerDiagnosticRoute(path:unknown):PartnerDiagnosticRoute|null {
 if(typeof path!=="string")return null;const route=path.split(/[?#]/,1)[0];
 return ["/app/partners","/app/partners/mutate","/app/partners/discovery"].includes(route)?route as PartnerDiagnosticRoute:null;
}
export function partnerErrorDetails(error:unknown){return finiteErrorDetails(error,files);}
export function partnerDiagnosticRecord(input:PartnerDiagnosticInput){
 if(!validPartnerCorrelation(input.correlationId)||!partnerDiagnosticStages.includes(input.stage)||!phases.includes(input.phase)||!files.includes(input.observedAt))return null;
 const commit=process.env.BOSS_DIAGNOSTIC_COMMIT,deploy=process.env.BOSS_DIAGNOSTIC_DEPLOY;
 const operation=input.operation && (input.operation==="partners.read"||input.operation==="partners.discovery"||Object.hasOwn(PARTNER_FIELDS,input.operation))?input.operation:null;
 return {schema:"boss.partner.diagnostic.v2",timestamp:new Date().toISOString(),commit:typeof commit==="string"&&/^[a-f0-9]{40}$/.test(commit)?commit:"local",deployment:typeof deploy==="string"&&/^[a-f0-9]{24}$/.test(deploy)?deploy:"local",route:partnerDiagnosticRoute(input.route)??"/app/partners",phase:input.phase,stage:input.stage,correlation_id:input.correlationId,parent_correlation_id:validPartnerCorrelation(input.parentCorrelationId)?input.parentCorrelationId:null,observed_at:input.observedAt,operation,classification:classifications.includes(input.classification??"event")?input.classification??"event":"event",trace_state:input.phase.startsWith("client")&&traceStates.includes(input.traceState as PartnerTraceState)?input.traceState:null,http_status:Number.isInteger(input.status)&&Number(input.status)>=100&&Number(input.status)<=599?input.status:null,...(input.error===undefined?{exception_category:null,digest:null,source:null}:partnerErrorDetails(input.error))};
}
export function emitPartnerDiagnostic(input:PartnerDiagnosticInput,sink:(line:string)=>void=line=>console.info(line)){
 try{const record=partnerDiagnosticRecord(input);if(record)sink(PARTNER_DIAGNOSTIC_PREFIX+JSON.stringify(record));}catch{/* Observability cannot change execution. */}
}

import { type FailureCategory,type MinorUnits,type Outcome,type PartnerCapability,type PartnerMethod,type PartnerAccess,currentPartnerAccess,validMinor } from "./contracts";
export type TravelQuote = {providerId:string;sourceRevision:string;propertyId:string;ratePlan:string;destination:string;startsOn:string;endsOn:string;travelers:number;country:string;tier:"local"|"state"|"nationwide";currency:string;priceMinor:MinorUnits;taxMinor:MinorUnits;feeMinor:MinorUnits;available:boolean;expiresAt:string;cancellationTerms:string;comparison?:{approvedPolicyReference:string;comparisonMinor:MinorUnits};commission?:{approvedContractRevision:string;policyId:string}};
export type GiftCard = {providerId:string;externalId:string;brand:string;country:string;currency:string;denominationMinor:MinorUnits;faceMinor:MinorUnits;purchaseMinor:MinorUnits;delivery:"digital"|"physical";expiresAt:string;withdrawn:boolean;refundTerms:string;commissionPolicyId:string|null};
export type CommissionPolicy = {id:string;contractRevision:string;currency:string;basis:"fixed"|"percentage"|"zero"|"unknown";fixedMinor:MinorUnits|null;ratePpm:number|null;startsAt:string;endsAt:string;condition:"confirmed"|"fulfilled"|"settled"};
export type CommissionSource = {providerId:string;transactionId:string;externalEventId:string;currency:string;eligibleMinor:MinorUnits;occurredAt:string;condition:"requested"|"confirmed"|"fulfilled"|"settled";refundMinor:MinorUnits;canceled:boolean;evidenceReference:string};
export type CapabilityInputs = {
 catalog_read:{sequence:number;kind:"full"|"delta"};benefit_search:{category:string;marketId:string;after?:string};benefit_detail:{sourceId:string;revision:string};eligibility_check:{benefitId:string;access:PartnerAccess};
 external_redirect:{benefitId:string;approvedPolicyId:string};coupon_retrieval:{benefitId:string};reservation_quote:{destination:string;startsOn:string;endsOn:string;travelers:number};price_recheck:{quote:TravelQuote};
 booking_request:{quote:TravelQuote;requestId:string};booking_status:{providerReference:string};cancellation:{providerReference:string;requestId:string};refund_status:{providerReference:string};commission_report:{period:string};commission_reconciliation:{source:CommissionSource};
};
export type CapabilityValues = {catalog_read:{sequence:number;items:readonly unknown[]};benefit_search:{items:readonly unknown[]};benefit_detail:{sourceId:string;revision:string};eligibility_check:{eligible:boolean};external_redirect:{handoffReady:false};coupon_retrieval:{fulfillmentReady:false};reservation_quote:TravelQuote;price_recheck:TravelQuote;booking_request:{state:"not_executed"};booking_status:{state:"unknown"};cancellation:{state:"not_executed"};refund_status:{state:"unknown"};commission_report:{sources:readonly CommissionSource[]};commission_reconciliation:{evidenceOnly:true}};
export interface PartnerAdapter {readonly providerId:string;readonly method:PartnerMethod;readonly capabilities:readonly PartnerCapability[];execute<C extends PartnerCapability>(capability:C,input:CapabilityInputs[C]):Promise<Outcome<CapabilityValues[C]>>;}
/** No transport, secret loader, endpoint, SSO or live activation exists in this phase. */
export function disabledAdapter(providerId:string,method:PartnerMethod,capabilities:readonly PartnerCapability[]):PartnerAdapter {
 return {providerId,method,capabilities,async execute(capability){return {ok:false,category:capabilities.includes(capability)?"activation_disabled":"capability_unsupported"};}};
}
/** Explicit test-only construction; cannot accept transport/network execution. */
export function syntheticAdapter(providerId:`fixture:${string}`,fixtures:Partial<CapabilityValues>):PartnerAdapter {
 if(!providerId.startsWith("fixture:")||providerId.length<9)throw new Error("Synthetic adapter identity required");
 const capabilities=Object.keys(fixtures) as PartnerCapability[];
 return {providerId,method:"mock",capabilities,async execute<C extends PartnerCapability>(capability:C):Promise<Outcome<CapabilityValues[C]>> {const value=fixtures[capability];return value===undefined?{ok:false,category:"capability_unsupported"}:{ok:true,value:value as CapabilityValues[C]};}};
}
function calendarDate(value:string):boolean {return /^\d{4}-\d{2}-\d{2}$/.test(value)&&Number.isFinite(Date.parse(value))&&new Date(value).toISOString().slice(0,10)===value;}
export function inspectTravel(quote:TravelQuote,now:number,country:string,tier:string):Outcome<{available:boolean;discounted:boolean;commissionable:boolean}> {
 if(!Number.isFinite(now)||!Number.isFinite(Date.parse(quote.expiresAt))||Date.parse(quote.expiresAt)<=now)return {ok:false,category:"quote_expired"};
 if(quote.country!==country)return {ok:false,category:"territory_unsupported"};
 if(quote.tier!==tier||!validMinor(quote.priceMinor)||!validMinor(quote.taxMinor)||!validMinor(quote.feeMinor)||!Number.isInteger(quote.travelers)||quote.travelers<1||quote.travelers>20||!/^[A-Z]{3}$/.test(quote.currency)||!calendarDate(quote.startsOn)||!calendarDate(quote.endsOn)||Date.parse(quote.endsOn)<=Date.parse(quote.startsOn))return {ok:false,category:"invalid_source_record"};
 const discounted=!!quote.comparison&&quote.comparison.approvedPolicyReference.length>0&&validMinor(quote.comparison.comparisonMinor)&&BigInt(quote.comparison.comparisonMinor)>BigInt(quote.priceMinor)+BigInt(quote.taxMinor)+BigInt(quote.feeMinor);
 return {ok:true,value:{available:quote.available,discounted,commissionable:!!quote.commission&&quote.commission.approvedContractRevision.length>0&&quote.commission.policyId.length>0}};
}
export function recheckQuote(original:TravelQuote,current:TravelQuote,now:number,country:string,tier:string):Outcome<TravelQuote> {
 const status=inspectTravel(current,now,country,tier);if(!status.ok)return status;
 if(!status.value.available)return {ok:false,category:"provider_unavailable"};
 if(original.providerId!==current.providerId||original.propertyId!==current.propertyId||original.ratePlan!==current.ratePlan||original.startsOn!==current.startsOn||original.endsOn!==current.endsOn||original.travelers!==current.travelers||original.currency!==current.currency||original.priceMinor!==current.priceMinor||original.taxMinor!==current.taxMinor||original.feeMinor!==current.feeMinor||original.cancellationTerms!==current.cancellationTerms)return {ok:false,category:"invalid_source_record"};
 return {ok:true,value:current};
}
export function inspectGiftCard(card:GiftCard,now:number,country:string):Outcome<{discountMinor:MinorUnits;issuanceEnabled:false}> {
 if(card.country!==country)return {ok:false,category:"territory_unsupported"};
 if(!Number.isFinite(now)||!Number.isFinite(Date.parse(card.expiresAt))||Date.parse(card.expiresAt)<=now||card.withdrawn)return {ok:false,category:"stale_catalog"};
 if(!validMinor(card.faceMinor)||!validMinor(card.purchaseMinor)||!validMinor(card.denominationMinor)||card.faceMinor!==card.denominationMinor||BigInt(card.purchaseMinor)>BigInt(card.faceMinor)||!/^[A-Z]{3}$/.test(card.currency)||!card.brand||!card.refundTerms||!["digital","physical"].includes(card.delivery))return {ok:false,category:"invalid_source_record"};
 return {ok:true,value:{discountMinor:(BigInt(card.faceMinor)-BigInt(card.purchaseMinor)).toString(),issuanceEnabled:false}};
}
export function commissionEstimate(policy:CommissionPolicy,source:CommissionSource):Outcome<{estimatedMinor:MinorUnits|null;earnedRevenue:false;settlementExecuted:false}> {
 if(!["fixed","percentage","zero","unknown"].includes(policy.basis)||!["confirmed","fulfilled","settled"].includes(policy.condition)||!["requested","confirmed","fulfilled","settled"].includes(source.condition)||policy.currency!==source.currency||!validMinor(source.eligibleMinor)||!validMinor(source.refundMinor)||BigInt(source.refundMinor)>BigInt(source.eligibleMinor))return {ok:false,category:"invalid_source_record"};
 const at=Date.parse(source.occurredAt),start=Date.parse(policy.startsAt),end=Date.parse(policy.endsAt);
 if(!Number.isFinite(at)||!Number.isFinite(start)||!Number.isFinite(end)||at<start||at>=end)return {ok:false,category:"contract_inactive"};
 if(!policy.contractRevision||!source.evidenceReference||policy.basis==="fixed"&&(!validMinor(policy.fixedMinor)||policy.ratePpm!==null)||policy.basis==="percentage"&&(!Number.isInteger(policy.ratePpm)||Number(policy.ratePpm)<0||Number(policy.ratePpm)>1000000||policy.fixedMinor!==null)||["zero","unknown"].includes(policy.basis)&&(policy.fixedMinor!==null||policy.ratePpm!==null))return {ok:false,category:"invalid_source_record"};
 const eligible=BigInt(source.eligibleMinor)-BigInt(source.refundMinor),states=["requested","confirmed","fulfilled","settled"],ready=states.indexOf(source.condition)>=states.indexOf(policy.condition);
 let estimatedMinor:MinorUnits|null=null;
 if(source.canceled||eligible===0n)estimatedMinor="0";
 else if(ready&&policy.basis==="percentage")estimatedMinor=(eligible*BigInt(policy.ratePpm!)/1000000n).toString();
 else if(ready&&policy.basis==="fixed"&&source.refundMinor==="0")estimatedMinor=policy.fixedMinor;
 else if(ready&&policy.basis==="zero")estimatedMinor="0";
 return {ok:true,value:{estimatedMinor,earnedRevenue:false,settlementExecuted:false}};
}
export const failure=(category:FailureCategory):Outcome<never>=>({ok:false,category});
export function eligiblePartnerHandoff(access:PartnerAccess):Outcome<{ready:false}> {return currentPartnerAccess(access)?{ok:false,category:"activation_disabled"}:{ok:false,category:"contract_inactive"};}

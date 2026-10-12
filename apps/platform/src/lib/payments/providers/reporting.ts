import {providerContextValid,providerMinor,record,safeReference,type ProviderAccountContext,type ProviderCredentials,type ProviderFetch}from"./contracts";
import{providerJson,providerText}from"./http";
export type ReportedTransaction=Readonly<{transactionReference:string;requestReference?:string;batchReference?:string;amountMinor?:string;currency?:string;status:string}>;
const endpoints={sandbox:"https://apitest.authorize.net/xml/v1/request.api",production:"https://api.authorize.net/xml/v1/request.api"};
function ready(a:ProviderAccountContext,c:ProviderCredentials,provider:string){return a.provider===provider&&providerContextValid(a,c)&&a.capabilities.includes("settlement_query");}
function boundedDates(from:string,to:string){const f=Date.parse(from),t=Date.parse(to);return Number.isFinite(f)&&Number.isFinite(t)&&t>f&&t-f<=31*86400000;}
/** Reporting hints require authoritative transaction retrieval before payment
 * commitment. Processor cost is not inferred from gross, surcharge or net. */
export async function authorizeNetBatches(fetcher:ProviderFetch,a:ProviderAccountContext,c:ProviderCredentials,from:string,to:string):Promise<readonly string[]|null>{
 if(!ready(a,c,"authorize_net")||!c.apiLogin||!c.transactionKey||!boundedDates(from,to))return null;
 const value=await providerJson(fetcher,endpoints[a.environment],{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({getSettledBatchListRequest:{merchantAuthentication:{name:c.apiLogin,transactionKey:c.transactionKey},includeStatistics:false,firstSettlementDate:from,lastSettlementDate:to}})});
 if(!record(value)||!Array.isArray(value.batchList)||value.batchList.length>100)return null;
 const ids=value.batchList.map(b=>record(b)?safeReference(String(b.batchId??"")):undefined);return ids.every((x):x is string=>!!x)?ids:null;
}
export async function authorizeNetBatchPage(fetcher:ProviderFetch,a:ProviderAccountContext,c:ProviderCredentials,batch:string,page:number):Promise<readonly ReportedTransaction[]|null>{
 if(!ready(a,c,"authorize_net")||!c.apiLogin||!c.transactionKey||!safeReference(batch)||!Number.isSafeInteger(page)||page<0||page>10000)return null;
 const value=await providerJson(fetcher,endpoints[a.environment],{method:"POST",headers:{"content-type":"application/json"},body:JSON.stringify({getTransactionListRequest:{merchantAuthentication:{name:c.apiLogin,transactionKey:c.transactionKey},batchId:batch,paging:{limit:100,offset:page*100+1}}})});
 if(!record(value)||!Array.isArray(value.transactions)||value.transactions.length>100)return null;
 const result:ReportedTransaction[]=[];for(const t of value.transactions){if(!record(t)||!safeReference(String(t.transId??"")))return null;result.push({transactionReference:String(t.transId),requestReference:safeReference(t.invoiceNumber,20),batchReference:batch,amountMinor:providerMinor(t.settleAmount),status:["settledSuccessfully","refundSettledSuccessfully"].includes(String(t.transactionStatus))?String(t.transactionStatus):"unknown"});}return result;
}
export async function nmiReportPage(fetcher:ProviderFetch,a:ProviderAccountContext,c:ProviderCredentials,from:string,to:string,page:number):Promise<readonly ReportedTransaction[]|null>{
 if(!ready(a,c,"nmi")||a.environment!=="sandbox"||!c.apiKey||!boundedDates(from,to)||!Number.isSafeInteger(page)||page<0||page>10000)return null;
 const format=(x:string)=>new Date(x).toISOString().replace(/[-:TZ]/g,"").slice(0,14);
 const xml=await providerText(fetcher,"https://sandbox.nmi.com/api/query.php",{method:"POST",headers:{"content-type":"application/x-www-form-urlencoded"},body:new URLSearchParams({security_key:c.apiKey,start_date:format(from),end_date:format(to),result_limit:"100",page_number:String(page)}).toString()});
 if(!xml||/<!DOCTYPE|<!ENTITY/i.test(xml))return null;const records=[...xml.matchAll(/<transaction>([\s\S]*?)<\/transaction>/g)];if(records.length>100)return null;
 const result:ReportedTransaction[]=[];for(const[,t]of records){const transactionReference=t.match(/<transaction_id>([A-Za-z0-9_.:-]{1,100})<\/transaction_id>/)?.[1];if(!transactionReference)return null;const status=t.match(/<condition>([a-z_]{1,30})<\/condition>/)?.[1];result.push({transactionReference,requestReference:t.match(/<order_id>([a-z0-9]{20})<\/order_id>/)?.[1],currency:t.match(/<currency>([A-Z]{3})<\/currency>/)?.[1],status:["pending","pendingsettlement","complete","failed","canceled","unknown"].includes(status??"")?status!:"unknown"});}return result;
}

"use client";
import type { Json } from "@/lib/supabase/database.types";
import { useEffect,useState } from "react";
import { useRouter } from "next/navigation";
import { PARTNER_STATES,PARTNER_METHODS,PARTNER_CAPABILITIES,type PartnerAdminData } from "@/lib/partners/contracts";
import { parsePartnerCommand,type PartnerCommand } from "@/lib/partners/input";
import {requestPartnerMutation}from"@/lib/partners/action";
import {partnerClientDiagnostic,partnerClientRendered}from"@/lib/partners/diagnostics-client";
export function PartnerWorkspace({data,diagnosticCorrelation}:{data:PartnerAdminData;diagnosticCorrelation?:string}) {
 useEffect(()=>{if(diagnosticCorrelation)partnerClientRendered(diagnosticCorrelation);},[diagnosticCorrelation]);
 const router=useRouter(),[message,setMessage]=useState(""),[busy,setBusy]=useState(false),[pending,setPending]=useState<PartnerCommand|null>(null);
 if("unavailable"in data)return <p role="status">{data.restricted?"Partner administration is restricted.":"Partner administration is currently unavailable."}</p>;
 async function send(command:PartnerCommand,reconciling=false) {
  setBusy(true);setPending(command);setMessage("Submitting provider change.");
  try {const result=await requestPartnerMutation(command,undefined,reconciling);
   if(result.outcome==="confirmed-success"){setPending(null);setMessage("Provider change confirmed.");partnerClientDiagnostic({stage:"refresh_requested",observedAt:"src/components/partners/workspace.tsx",operation:command.action});router.refresh();return;}
   if(result.outcome==="confirmed-rejection"){setPending(null);setMessage("Provider operation declined. Review the current record and access.");}
   else setMessage("This change could not be confirmed. Retry the same request safely.");
  }catch(error){partnerClientDiagnostic({stage:"client_exception",observedAt:"src/components/partners/workspace.tsx",classification:"refresh-failed",error});setMessage("This change could not be confirmed. Retry the same request safely.");}finally{setBusy(false);}
 }
 function submit(event:React.FormEvent<HTMLFormElement>,action:PartnerCommand["action"],providerId?:string,version?:number) {
  event.preventDefault();const form=new FormData(event.currentTarget),input:Record<string,Json>={};
  for(const [key,value]of form.entries())if(typeof value==="string"&&value!=="")input[key]=value;
  if(providerId)input.provider_id=providerId;if(version!==undefined)input.expected_version=version;
  if(action==="provider.create")input.synthetic=form.get("synthetic")==="on";
  if(action==="configuration.create"){input.capabilities=form.getAll("capabilities").map(String);input.max_stale_seconds=Number(form.get("max_stale_seconds"));input.full_withdraw_missing=form.get("full_withdraw_missing")==="on";}
  if(action==="contract.create"){input.countries=[String(form.get("country"))];delete input.country;input.categories=form.getAll("categories").map(String);input.methods=form.getAll("methods").map(String);input.sharing_fields=[];input.retention_days=Number(form.get("retention_days"));input.display_rights=form.get("display_rights")==="on";input.caching_rights=form.get("caching_rights")==="on";}
  const command=parsePartnerCommand({request_id:crypto.randomUUID(),action,input});if(command)void send(command);else setMessage("Review the provider fields.");
 }
 return <section className="partner-workspace admin-workspace" aria-label="Partner administration"><p>Partner integrations are off. Registry and review records do not activate consumer benefits.</p><p role="status" aria-live="polite">{message}</p>
 {pending&&<button className="button button-outline" disabled={busy} onClick={()=>{partnerClientDiagnostic({stage:"retry_requested",observedAt:"src/components/partners/workspace.tsx",operation:pending.action});void send(pending,true);}}>Retry the same request</button>}
 <form className="admin-panel" onSubmit={e=>submit(e,"provider.create")}><h2>Add provider prospect</h2>
 <label>Provider reference<input name="key" required minLength={3} maxLength={80} pattern="[a-z][a-z0-9_-]{2,79}"/></label>
 <label>Display name<input name="name" required maxLength={120}/></label><label>Legal organization reference<input name="legal_reference" maxLength={200}/></label>
 <label><input name="synthetic" type="checkbox"/>Synthetic controlled record</label><button className="button" disabled={busy||pending!==null}>Add prospect</button></form>
 {data.providers.length===0&&<p>No providers have been configured.</p>}
 {data.providers.map(p=><article className="admin-panel" key={p.id}><h2>{p.name}</h2><p>{p.state.replaceAll("_"," ")} · {p.synthetic?"Synthetic controlled record":"Provider prospect"} · Integrations off</p>
 <a href={`/app/partners?provider_id=${p.id}`}>Review provider details</a><dl><dt>Provider reference</dt><dd>{p.key}</dd><dt>Catalog source records</dt><dd>{p.source_count}</dd><dt>Configured method</dt><dd>{"method"in p.configuration?p.configuration.method:"None"}</dd></dl>
 <form onSubmit={e=>submit(e,"provider.state",p.id,p.version)}><label>Reviewed state<select name="state" defaultValue={p.state}>{PARTNER_STATES.map(s=><option value={s} key={s}>{s.replaceAll("_"," ")}</option>)}</select></label>
 <label>Review reason<input name="reason" required minLength={10} maxLength={500}/></label><button className="button button-outline" disabled={busy||pending!==null}>Record state review</button></form><p>Contract approval and technical readiness are separate. No live activation is available.</p></article>)}
 {data.details&&data.providers.length===1&&<section aria-label="Exact provider policy review">
 <form className="admin-panel" onSubmit={e=>submit(e,"configuration.create",data.providers[0].id)}><h2>Technical configuration revision</h2>
 <label>Integration method<select name="method">{PARTNER_METHODS.map(m=><option key={m}>{m}</option>)}</select></label>
 <fieldset><legend>Documented capabilities</legend>{PARTNER_CAPABILITIES.map(c=><label key={c}><input type="checkbox" name="capabilities" value={c}/>{c.replaceAll("_"," ")}</label>)}</fieldset>
 <label>Maximum catalog age in seconds<input name="max_stale_seconds" type="number" min={60} max={2592000} required/></label><label>Effective start in UTC<input name="starts_at" placeholder="2026-10-01T00:00:00Z" required/></label>
 <label><input name="full_withdraw_missing" type="checkbox"/>Allow withdrawal after a complete approved full snapshot</label><button className="button" disabled={busy||pending!==null}>Record configuration</button><p>Credentials and external execution stay off.</p></form>
 <form className="admin-panel" onSubmit={e=>submit(e,"contract.create",data.providers[0].id)}><h2>Contract-policy revision</h2>
 <p>Reference reviewed legal documents. A draft record does not establish licensing rights.</p>
 {[["document_reference","Legal document reference"],["rights_holder_reference","Rights holder reference"],["product_id","Approved discount product ID"],["country","Country code"],["branding_rules","Branding restrictions"],["attribution_rules","Attribution requirements"],["refund_policy_reference","Refund/chargeback policy reference"],["starts_at","Effective start in UTC"],["ends_at","Effective end in UTC"]].map(([name,label])=><label key={name}>{label}<input name={name} required maxLength={name.endsWith("rules")?1000:200}/></label>)}
 <label>Minimum member tier<select name="minimum_tier"><option>local</option><option>state</option><option>nationwide</option></select></label>
 <fieldset><legend>Licensed categories</legend>{["retail","restaurants","fuel","automotive","gift_cards","hotels","travel","entertainment","tickets","other"].map(c=><label key={c}><input type="checkbox" name="categories" value={c}/>{c.replaceAll("_"," ")}</label>)}</fieldset>
 <fieldset><legend>Licensed delivery methods</legend>{PARTNER_METHODS.map(m=><label key={m}><input name="methods" type="checkbox" value={m}/>{m}</label>)}</fieldset>
 <label><input name="display_rights" type="checkbox"/>Documented display rights</label><label><input name="caching_rights" type="checkbox"/>Documented caching rights</label><label>Approved retention days<input name="retention_days" type="number" required min={0} max={3650}/></label>
 <button className="button" disabled={busy||pending!==null}>Record draft policy</button><p>No personal data sharing is configured here.</p></form>
 {data.details.contracts.map(c=><article className="admin-panel" key={c.id}><h2>Contract revision {c.revision}</h2><p>{c.state} · {c.countries.join(", ")} · {c.document_reference}</p><p>{c.starts_at} to {c.ends_at}</p>
 <form onSubmit={e=>submit(e,"contract.review",data.providers[0].id)}><input type="hidden" name="contract_id" value={c.id}/><label>Review state<select name="state"><option disabled={!c.can_approve}>approved</option><option>suspended</option><option>terminated</option></select></label><label>Independent approval reference<input name="approval_reference" required minLength={10} maxLength={200}/></label><button className="button button-outline" disabled={busy||pending!==null}>Record legal review</button></form></article>)}
 <form className="admin-panel" onSubmit={e=>submit(e,"territory.create",data.providers[0].id)}><h2>Record approved territory</h2>
 <label>Approved contract revision<select name="contract_id" required>{data.details.contracts.filter(c=>c.state==="approved").map(c=><option key={c.id} value={c.id}>Revision {c.revision}</option>)}</select></label>
 {[["country","Country code"],["region","State or region"],["market_id","Existing market ID"],["starts_at","Effective start in UTC"],["ends_at","Effective end in UTC"]].map(([name,label])=><label key={name}>{label}<input name={name} required={!["region","market_id"].includes(name)} maxLength={80}/></label>)}
 <button className="button" disabled={busy||pending!==null||!data.details.contracts.some(c=>c.state==="approved")}>Record territory</button></form>
 <section className="admin-panel"><h2>Approved territories</h2>{data.details.territories.map(t=><article key={t.id}><p>{t.country} {t.region} · {t.status} · ends {t.ends_at}</p>{t.status==="active"&&<form onSubmit={e=>submit(e,"territory.end",data.providers[0].id)}><input type="hidden" name="territory_id" value={t.id}/><button className="button button-outline" disabled={busy||pending!==null}>End territory</button></form>}</article>)}</section>
 {data.details.catalog.map(c=><article className="admin-panel" key={c.id}><h2>{c.title}</h2><p>Revision {c.source_revision} · {c.state} · expires {c.ends_at}</p><p>{c.member_terms}</p><p>{c.exclusions}</p><form onSubmit={e=>submit(e,"catalog.review",data.providers[0].id)}><input type="hidden" name="revision_id" value={c.id}/><label>Catalog review<select name="state"><option>reviewed</option><option>paused</option><option>rejected</option></select></label><button className="button button-outline" disabled={busy||pending!==null}>Record catalog review</button></form></article>)}
 <section className="admin-panel"><h2>Integration audit</h2>{data.details.imports.map(i=><p key={i.id}>Feed {i.feed_sequence} · {i.kind} · accepted {i.accepted}, quarantined {i.quarantined}, withdrawn {i.withdrawn}</p>)}</section>
 </section>}
 </section>;
}

"use client";
import { useRef, useState, type FormEvent } from "react";
import { useRouter } from "next/navigation";
import type { RegistrationCommand, RegistrationRow } from "@/lib/registration/contracts";
import { object, rows, text, number } from "@/lib/registration/contracts";
import { isRecord } from "@/lib/registration/input";
import { MAX_DOCUMENT_BYTES, documentMimeTypes } from "@/lib/registration/documents";
import { RegistrationActionForm as Action, Field, Textarea, Disclosure, formText } from "./action-form";
import { RegistrationForm } from "./form-engine";

export function PrivateUpload({ document }: { document: RegistrationRow }) {
  const router = useRouter(); const [pending,setPending]=useState(false); const [message,setMessage]=useState("");
  const retry=useRef<{ file: File; upload: string; complete: string } | null>(null);
  async function upload(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();const file=new FormData(event.currentTarget).get("file");if (!(file instanceof File) || !file.size || file.size > Math.min(number(document,"max_bytes",MAX_DOCUMENT_BYTES),MAX_DOCUMENT_BYTES) || !documentMimeTypes.includes(file.type as typeof documentMimeTypes[number])) { setMessage("Choose a PDF, JPEG or PNG within the allowed file size.");return; }
    if (pending) return;if (retry.current?.file.name !== file.name || retry.current?.file.lastModified !== file.lastModified || retry.current?.file.size !== file.size) retry.current={file,upload:crypto.randomUUID(),complete:crypto.randomUUID()};
    setPending(true);setMessage("");
    try { const response=await fetch("/app/registrations/upload",{method:"POST",credentials:"same-origin",cache:"no-store",headers:{"content-type":file.type,"x-document-id":text(document,"id"),"x-upload-request-id":retry.current.upload,"x-completion-request-id":retry.current.complete},body:file});
      setMessage(response.ok ? "Uploaded privately. Staff review is pending." : response.status===403 ? "You do not have permission to upload this document." : "The upload could not be confirmed. Review the file or retry the same upload.");if(response.ok){retry.current=null;router.refresh();}
    } catch {setMessage("Upload could not be confirmed. Retry the same file safely.");} finally {setPending(false);}
  }
  return <form className="registration-form" aria-label={"Upload "+text(document,"title")} onSubmit={upload}><fieldset disabled={pending}><label className="form-field"><span>Private file for {text(document,"title")}</span><input name="file" type="file" accept="application/pdf,image/jpeg,image/png" required /></label><p className="registration-helper">Up to {Math.min(number(document,"max_bytes",MAX_DOCUMENT_BYTES),MAX_DOCUMENT_BYTES)/1024/1024} MB. Uploads remain private and require review.</p><button className="button button-primary" type="submit">{pending ? "Uploading..." : "Upload private document"}</button><p role="status">{message}</p></fieldset></form>;
}
export function PrivateDownload({ document, teamId }: { document: RegistrationRow; teamId?: string }) {
  const [pending,setPending]=useState(false);const [message,setMessage]=useState("");
  async function download() {
    setPending(true);setMessage("");
    try {const response=await fetch("/app/registrations/download",{method:"POST",credentials:"same-origin",cache:"no-store",headers:{"content-type":"application/json"},body:JSON.stringify({request_id:crypto.randomUUID(),document_id:text(document,"id"),purpose:teamId?"emergency":"ordinary",...(teamId?{team_id:teamId}:{})})});
      if(!response.ok){setMessage(response.status===403?"You do not have permission to download this document.":"Document access is unavailable. Please try again.");return;}
      const blob=await response.blob();const url=URL.createObjectURL(blob);const a=window.document.createElement("a");a.href=url;a.download=blob.type==="application/pdf"?"private-document.pdf":blob.type==="image/png"?"private-document.png":"private-document.jpg";a.click();URL.revokeObjectURL(url);setMessage("Private download requested. This access was recorded.");
    } catch {setMessage("Document access is unavailable. Please try again.");} finally {setPending(false);}
  }
  return <div className="registration-private-action"><button className="button button-outline" disabled={pending} type="button" onClick={download}>{pending?"Checking access...":teamId?"Emergency document download":"Download privately"}</button><p role="status">{message}</p></div>;
}

export function SensitivePanel({ command, form, participantAge, context, onLoaded, onClosed }: { command: RegistrationCommand; form?: RegistrationRow; participantAge?: number; context?: RegistrationRow; onLoaded?: (result:RegistrationRow)=>void; onClosed?: ()=>void }) {
  const [data,setData]=useState<RegistrationRow|null>(null); const [pending,setPending]=useState(false);const [message,setMessage]=useState("");
  async function load(){setPending(true);setMessage("");try {const response=await fetch("/app/registrations/sensitive",{method:"POST",credentials:"same-origin",cache:"no-store",headers:{"content-type":"application/json"},body:JSON.stringify({request_id:crypto.randomUUID(),command})});const value:unknown=await response.json();if(!response.ok||!isRecord(value)||!isRecord(value.result)){setMessage(response.status===403?"You do not have permission to access this information.":"Information is unavailable. Please try again.");return;}const result=value.result as RegistrationRow;setData(result);onLoaded?.(result);}catch{setMessage("Information is unavailable. Please try again.");}finally{setPending(false);}}
  return <div className="registration-sensitive">{!data?<button className="button button-outline" type="button" disabled={pending} onClick={load}>{pending?"Checking access...":form?"Open restricted form":"Open restricted emergency information"}</button>:<><p className="registration-helper">This restricted access was recorded.</p><button className="button button-outline" type="button" onClick={()=>{setData(null);onClosed?.();}}>Close restricted information</button>{form ? <RegistrationForm registrationId={String(command.input.registration_id)} form={{...form,...data}} participantAge={participantAge} context={context??{}} /> : <dl className="registration-facts">{rows(data.contacts).map((contact,i)=><div key={i}><dt>Emergency contact</dt><dd>{text(contact,"name")} · {text(contact,"relationship")} · {text(contact,"phone")} {text(contact,"email")}</dd></div>)}{["medical","physician","insurance"].map(key=>Object.entries(object(data[key])).map(([label,value])=><div key={key+label}><dt>{label.replaceAll("_"," ")}</dt><dd>{String(value)}</dd></div>))}</dl>}</>}<p role="status">{message}</p></div>;
}
export function buildEmergencySaveCommand(registration: RegistrationRow, form: FormData, contactCount: number, data?: RegistrationRow): RegistrationCommand {
  const optional = (fields: Record<string, string>): RegistrationRow => Object.fromEntries(Object.entries(fields).flatMap(([key, control]) => {
    const value = formText(form, control); return value ? [[key, value]] : [];
  }));
  return { operation: "emergency.save", input: {
    registration_id: text(registration, "id"), ...(data ? { expected_version: number(data, "version") } : {}),
    contacts: Array.from({ length: contactCount }, (_, index) => ({ name: formText(form, "contact_name_" + index), relationship: formText(form, "contact_relationship_" + index), phone: formText(form, "contact_phone_" + index), ...optional({ email: "contact_email_" + index }) })),
    medical: optional({ allergies: "allergies", conditions: "conditions", medications: "medications", instructions: "instructions" }),
    physician: optional({ name: "physician_name", phone: "physician_phone" }),
    insurance: optional({ provider: "provider", policy_reference: "policy_reference" }),
  } };
}
export function EmergencyEditor({ registration, data, onSaved }: { registration: RegistrationRow; data?: RegistrationRow; onSaved?: ()=>void }) {
  const contacts=rows(data?.contacts);const [contactCount,setContactCount]=useState(Math.max(1,contacts.length));const medical=object(data?.medical);const physician=object(data?.physician);const insurance=object(data?.insurance);
  return <Disclosure title="Save emergency information"><Action name="Emergency information" label="Save restricted emergency information" onSaved={onSaved} build={fd=>buildEmergencySaveCommand(registration,fd,contactCount,data)}>{Array.from({length:contactCount},(_,i)=><fieldset className="registration-group" key={i}><legend>Emergency contact {i+1}</legend><div className="registration-fields"><Field name={"contact_name_"+i} label={"Contact "+(i+1)+" name"} required value={text(contacts[i],"name")} /><Field name={"contact_relationship_"+i} label={"Contact "+(i+1)+" relationship"} required value={text(contacts[i],"relationship")} /><Field name={"contact_phone_"+i} label={"Contact "+(i+1)+" phone"} type="tel" required value={text(contacts[i],"phone")} /><Field name={"contact_email_"+i} label={"Contact "+(i+1)+" email (optional)"} type="email" value={text(contacts[i],"email")} /></div></fieldset>)}<div className="registration-form-footer"><button className="button button-outline" type="button" disabled={contactCount>=10} onClick={()=>setContactCount(current=>current+1)}>Add emergency contact</button><button className="button button-outline" type="button" disabled={contactCount<=1} onClick={()=>setContactCount(current=>current-1)}>Remove last contact</button></div><div className="registration-fields"><Field name="physician_name" label="Physician name" value={text(physician,"name")} /><Field name="physician_phone" label="Physician phone" type="tel" value={text(physician,"phone")} /><Field name="provider" label="Insurance provider" value={text(insurance,"provider")} /><Field name="policy_reference" label="Insurance policy reference" value={text(insurance,"policy_reference")} /></div>{["allergies","conditions","medications","instructions"].map(key=><Textarea name={key} label={key[0].toUpperCase()+key.slice(1)} value={text(medical,key)} key={key} maxLength={2000} />)}<p className="registration-helper">Only authorized family or document staff can review these details. Enabled emergency access is restricted to responsible staff for the exact team.</p></Action></Disclosure>;
}
export function EmergencySection({ registration }: { registration: RegistrationRow }) {
  const teams=rows(registration.emergency_teams);const ops=Array.isArray(registration.operations)?registration.operations:[];
  const ordinary=registration.emergency_access_purpose==="ordinary";
  const [loaded,setLoaded]=useState<RegistrationRow|undefined>();const [purpose,setPurpose]=useState(ordinary?"":text(teams[0],"id"));const [revision,setRevision]=useState(0);
  return <section className="registration-card"><h3>Restricted emergency information</h3>{teams.length>0&&<label className="form-field"><span>Emergency team</span><select value={purpose} onChange={event=>{setPurpose(event.target.value);setLoaded(undefined);}}>{ordinary&&<option value="">Ordinary authorized access</option>}{teams.map(team=><option value={text(team,"id")} key={text(team,"id")}>{text(team,"label")}</option>)}</select></label>}{ops.includes("emergency.access")&&<SensitivePanel key={purpose+revision} command={{operation:"emergency.access",input:{registration_id:text(registration,"id"),purpose:purpose?"emergency":"ordinary",...(purpose?{team_id:purpose}:{})}}} onLoaded={setLoaded} onClosed={()=>setLoaded(undefined)} />}{ops.includes("emergency.save")&&(!text(registration,"emergency_record_id")||loaded)&&<EmergencyEditor key={loaded?number(loaded,"version"):0} registration={registration} data={loaded} onSaved={()=>{setLoaded(undefined);setRevision(value=>value+1);}} />}{ops.includes("emergency.save")&&text(registration,"emergency_record_id")&&!loaded&&<p>Open the existing restricted information before editing it.</p>}</section>;
}

"use client";
import { useId, useState } from "react";
import type { Json } from "@/lib/supabase/database.types";
import { object, rows, text, type FormCondition, type FormField, type RegistrationRow } from "@/lib/registration/contracts";
import { activeAnswers, collectFormAnswers, definitionJson, fieldTypeLabels, fieldTypes, matchesConditions, parseFormDefinition, requiredField } from "@/lib/registration/forms";
import { Check, Field, RegistrationActionForm, Select } from "./action-form";

const conditionLabels: Record<FormCondition["op"], string> = { equals: "Equals", not_equals: "Does not equal", includes: "Includes choice", lt: "Less than", gte: "At least" };
const numericCondition = (rule: FormCondition, previous: FormField[]) => rule.source === "participant_age" || rule.source === "context" && rule.field === "grade" || rule.source === "answer" && previous.find(field => field.key === rule.field)?.type === "number" || ["lt", "gte"].includes(rule.op);
function ConditionEditor({ name, rules, previous, onChange }: { name: string; rules: FormCondition[]; previous: FormField[]; onChange: (rules: FormCondition[]) => void }) {
  function change(index: number, patch: Partial<FormCondition>) { onChange(rules.map((rule, i) => i === index ? { ...rule, ...patch } : rule)); }
  return <fieldset className="registration-field-group"><legend>{name}</legend><p className="muted">All conditions must match. Use a previous answer, participant age, or registration choice.</p>
    {rules.map((rule, index) => <div className="registration-form-grid" key={index}>
      <label className="form-field"><span>Condition {index + 1} source</span><select value={rule.source} onChange={event => {
        const source = event.target.value as FormCondition["source"];
        const next: FormCondition = source === "participant_age" ? { source, op: "lt", value: 18 } : { source, field: source === "context" ? "grade" : previous[0]?.key ?? "", op: "equals", value: "" };
        onChange(rules.map((item, i) => i === index ? next : item));
      }}><option value="answer" disabled={!previous.length}>Previous answer</option><option value="participant_age">Participant age</option><option value="context">Registration choice</option></select></label>
      {rule.source !== "participant_age" && <label className="form-field"><span>Condition {index + 1} field</span><select value={rule.field ?? ""} onChange={event => change(index, { field: event.target.value, value: rule.source === "context" ? event.target.value === "grade" ? 0 : true : ["yes_no", "checkbox", "acknowledgment"].includes(previous.find(field => field.key === event.target.value)?.type ?? "") ? true : previous.find(field => field.key === event.target.value)?.type === "number" ? 0 : "" })}>
        {rule.source === "answer" ? previous.map(field => <option value={field.key} key={field.key}>{field.label}</option>) : <><option value="grade">Grade</option><option value="payment_plan_selected">Payment plan selected</option><option value="travel_team_selected">Travel team selected</option></>}
      </select></label>}
      <label className="form-field"><span>Condition {index + 1} comparison</span><select value={rule.op} onChange={event => change(index, { op: event.target.value as FormCondition["op"], value: ["lt", "gte"].includes(event.target.value) ? Number(rule.value) || 0 : rule.value })}>
        {Object.entries(conditionLabels).filter(([op]) => rule.source !== "participant_age" || ["lt", "gte"].includes(op)).map(([op, label]) => <option value={op} key={op}>{label}</option>)}
      </select></label>
      {rule.source === "context" && rule.field?.endsWith("selected") || rule.source === "answer" && ["yes_no", "checkbox", "acknowledgment"].includes(previous.find(field => field.key === rule.field)?.type ?? "") ?
        <label className="form-field"><span>Condition {index + 1} value</span><select value={String(rule.value)} onChange={event => change(index, { value: event.target.value === "true" })}><option value="true">Yes</option><option value="false">No</option></select></label> :
        <label className="form-field"><span>Condition {index + 1} value</span><input value={String(rule.value)} type={numericCondition(rule, previous) ? "number" : "text"} maxLength={200} onChange={event => change(index, { value: numericCondition(rule, previous) ? Number(event.target.value) : event.target.value })} /></label>}
      <button type="button" className="button button-secondary" onClick={() => onChange(rules.filter((_, i) => i !== index))}>Remove condition {index + 1}</button>
    </div>)}
    <button type="button" className="button button-secondary" disabled={rules.length >= 5} onClick={() => onChange([...rules, previous.length ? { source: "answer", field: previous[0].key, op: "equals", value: ["yes_no", "checkbox", "acknowledgment"].includes(previous[0].type) ? true : previous[0].type === "number" ? 0 : "" } : { source: "participant_age", op: "lt", value: 18 }])}>Add condition</button>
  </fieldset>;
}

export function FormBuilder({ offeringId }: { offeringId: string }) {
  const [fields, setFields] = useState<FormField[]>([{ key: "confirmation", type: "acknowledgment", label: "I confirm the participant information is current", required: true }]);
  const [problem, setProblem] = useState("");
  function update(index: number, patch: Partial<FormField>) { setFields(current => current.map((field, i) => i === index ? { ...field, ...patch } : field)); }
  function conditions(index: number, key: "show_if" | "required_if", rules: FormCondition[]) { setFields(current => current.map((field, i) => { if (i !== index) return field; const next = { ...field }; if (rules.length) next[key] = rules; else delete next[key]; return next; })); }
  return <RegistrationActionForm name="Publish a registration form" label="Publish new form version" build={data => {
    const definition = parseFormDefinition({ fields: fields.map(field => field.options ? { ...field, options: field.options.map(option => option.trim()).filter(Boolean) } : field) });
    if (!definition) { setProblem("Review question keys, choices and conditions. Conditions must refer to an earlier question; each key must be unique."); return null; }
    setProblem(""); return { operation: "form.publish", input: { offering_id: offeringId, form_key: String(data.get("form_key") ?? "").trim(), title: String(data.get("title") ?? "").trim(), definition: definitionJson(definition), sensitivity: String(data.get("sensitivity") ?? "ordinary"), required: data.has("required"), sort_order: 0 } };
  }}>
    <div className="registration-form-grid"><Field name="title" label="Form title" required /><Field name="form_key" label="Form reference name" required maxLength={60} />
      <Select name="sensitivity" label="Information sensitivity" options={[{ value: "ordinary", label: "General registration information" }, { value: "medical", label: "Restricted medical information" }]} value="ordinary" /></div>
    <p className="muted">Use a short reference such as participation_consent. Medical answers require separate authorized access. Publishing another version preserves earlier completed forms.</p>
    <Check name="required" label="Required to submit registration" checked />
    {fields.map((field, index) => <fieldset className="registration-field-group" key={index}><legend>Question {index + 1}</legend>
      <div className="registration-form-grid">
        <label className="form-field"><span>Question {index + 1} label</span><input value={field.label} maxLength={200} required onChange={event => update(index, { label: event.target.value })} /></label>
        <label className="form-field"><span>Question {index + 1} reference</span><input value={field.key} maxLength={60} required pattern="[a-z][a-z0-9_]{0,59}" onChange={event => update(index, { key: event.target.value })} /></label>
        <label className="form-field"><span>Question {index + 1} type</span><select value={field.type} onChange={event => {
          const next = { ...field, type: event.target.value }; if (["dropdown", "radio", "multi_select"].includes(next.type)) next.options ??= ["Option 1", "Option 2"]; else delete next.options;
          if (next.type !== "number") { delete next.min; delete next.max; } setFields(current => current.map((item, i) => i === index ? next : item));
        }}>{fieldTypes.map(type => <option key={type} value={type}>{fieldTypeLabels[type]}</option>)}</select></label>
        <label className="form-field"><span>Question {index + 1} section</span><input value={field.section ?? ""} maxLength={200} onChange={event => update(index, { section: event.target.value })} /></label>
        <label className="form-field"><span>Question {index + 1} help text</span><input value={field.help ?? ""} maxLength={4000} onChange={event => update(index, { help: event.target.value })} /></label>
        <label className="registration-check"><input type="checkbox" checked={field.required ?? false} onChange={event => update(index, { required: event.target.checked })} />Question {index + 1} is required</label>
      </div>
      {["dropdown", "radio", "multi_select"].includes(field.type) && <label className="form-field"><span>Question {index + 1} choices, one per line</span><textarea value={(field.options ?? []).join("\n")} rows={4} maxLength={10_000} onChange={event => update(index, { options: event.target.value.split("\n") })} /></label>}
      {field.type === "content" && <label className="form-field"><span>Instructions</span><textarea value={field.content ?? ""} rows={4} maxLength={4000} onChange={event => update(index, { content: event.target.value })} /></label>}
      {field.type === "number" && <div className="registration-form-grid">{(["min", "max"] as const).map(key => <label className="form-field" key={key}><span>{key === "min" ? "Minimum" : "Maximum"} value</span><input type="number" step="any" value={field[key] ?? ""} onChange={event => { const next = { ...field }; if (event.target.value === "") delete next[key]; else next[key] = Number(event.target.value); setFields(current => current.map((item, i) => i === index ? next : item)); }} /></label>)}</div>}
      {["short_text", "long_text", "email", "phone"].includes(field.type) && <label className="form-field"><span>Maximum answer length</span><input type="number" min={1} max={4000} value={field.max_length ?? ""} onChange={event => { const next = { ...field }; if (event.target.value === "") delete next.max_length; else next.max_length = Number(event.target.value); setFields(current => current.map((item, i) => i === index ? next : item)); }} /></label>}
      <details className="registration-disclosure"><summary>Conditional visibility and requirements for question {index + 1}</summary>
        <ConditionEditor name="Show this question when" rules={field.show_if ?? []} previous={fields.slice(0, index)} onChange={rules => conditions(index, "show_if", rules)} />
        <ConditionEditor name="Require this question when" rules={field.required_if ?? []} previous={fields.slice(0, index)} onChange={rules => conditions(index, "required_if", rules)} />
      </details>
      <div className="registration-form-footer"><button type="button" className="button button-secondary" disabled={index === 0} onClick={() => setFields(current => { const next = [...current]; [next[index - 1], next[index]] = [next[index], next[index - 1]]; return next; })}>Move question {index + 1} up</button>
        <button type="button" className="button button-secondary" disabled={index === fields.length - 1} onClick={() => setFields(current => { const next = [...current]; [next[index], next[index + 1]] = [next[index + 1], next[index]]; return next; })}>Move question {index + 1} down</button>
        <button type="button" className="button button-secondary" disabled={fields.length === 1} onClick={() => setFields(current => current.filter((_, i) => i !== index))}>Remove question {index + 1}</button></div>
    </fieldset>)}
    <button type="button" className="button button-secondary" disabled={fields.length >= 100} onClick={() => setFields(current => [...current, { key: `question_${current.length + 1}`, type: "short_text", label: `Question ${current.length + 1}`, required: false }])}>Add question</button>
    <p role="status" aria-live="polite">{problem}</p>
  </RegistrationActionForm>;
}

function answerLabel(value: Json | undefined): string {
  if (value === undefined || value === null || value === "") return "Not answered";
  if (typeof value === "boolean") return value ? "Yes" : "No";
  if (Array.isArray(value)) return value.map(answerLabel).join(", ");
  if (typeof value === "object") { if (typeof value.name === "string") return `${value.name}${value.consent === true ? " · consent recorded" : ""}`; return Object.values(value).map(answerLabel).join(", "); }
  return String(value);
}
export function RegistrationForm({ registrationId, form, participantAge, context }: { registrationId: string; form: RegistrationRow; participantAge?: number; context: RegistrationRow }) {
  const uid = useId(); const definition = parseFormDefinition(form.definition); const [answers, setAnswers] = useState<RegistrationRow>(object(form.answers)); const [finalize, setFinalize] = useState(false);
  if (!definition) return <p role="alert">This form could not be displayed. Refresh or ask the program administrator to review it.</p>;
  const active = activeAnswers(definition, answers, participantAge, context); const completed = text(form, "status") === "submitted"; const readonly = completed || !Array.isArray(form.operations) || !form.operations.includes("form.answer");
  const documentChoices = rows(form.document_references); const emergencyChoices = rows(form.emergency_references);
  function update(key: string, value: Json) { setAnswers(current => ({ ...current, [key]: value })); }
  return <section className="registration-panel" aria-label={text(form, "title", "Registration form")}><h3>{text(form, "title", "Registration form")}</h3>
    {readonly ? <><p className="muted">{completed ? "Completed form. Your original answers and form version are preserved." : "This form is available for review. Editing requires family registration authority."}</p><dl className="registration-status-grid">{definition.fields.filter(field => matchesConditions(field.show_if, active, participantAge, context)).map(field => <div key={field.key}><dt>{field.label}</dt><dd style={field.type === "content" ? { whiteSpace: "pre-wrap" } : undefined}>{field.type === "content" ? field.content ?? field.help : ["file_upload", "emergency_contact"].includes(field.type) ? typeof answers[field.key] === "string" ? "Private reference recorded" : "Not answered" : answerLabel(answers[field.key])}</dd></div>)}</dl></> :
      <RegistrationActionForm name={text(form, "title", "Registration form")} label={finalize ? "Complete this form" : "Save form draft"} build={data => ({ operation: "form.answer", input: { registration_id: registrationId, form_version_id: text(form, "form_version_id"), answers: collectFormAnswers(definition, data, participantAge, context), finalize, ...(typeof form.version === "number" ? { expected_version: form.version } : {}) } })}>
        <p className="muted">Save a draft at any time. Complete the form when the required answers and consent are ready.</p>
        {definition.fields.map((field, index) => {
          if (!matchesConditions(field.show_if, active, participantAge, context)) return null;
          const name = `answer:${field.key}`; const id = `${uid}-${field.key}`; const required = requiredField(field, active, participantAge, context); const enforce = required && finalize; const value = answers[field.key];
          const label = `${field.label}${required ? " (required)" : ""}`; const helpId = `${id}-help`;
          const input = { id, name, "aria-describedby": field.help ? helpId : undefined };
          let control;
          if (field.type === "content") control = <div><h4>{field.label}</h4><p style={{ whiteSpace: "pre-wrap" }}>{field.content ?? field.help}</p></div>;
          else if (field.type === "long_text") control = <label className="form-field" htmlFor={id}><span>{label}</span><textarea {...input} rows={4} value={typeof value === "string" ? value : ""} maxLength={field.max_length ?? 4000} required={enforce} onChange={event => update(field.key, event.target.value)} /></label>;
          else if (["dropdown", "yes_no", "file_upload", "emergency_contact"].includes(field.type)) {
            const options = field.type === "yes_no" ? [{ id: "yes", label: "Yes" }, { id: "no", label: "No" }] : field.type === "file_upload" ? documentChoices : field.type === "emergency_contact" ? emergencyChoices : (field.options ?? []).map(option => ({ id: option, label: option }));
            control = <label className="form-field" htmlFor={id}><span>{label}</span><select {...input} required={enforce} value={field.type === "yes_no" ? value === true ? "yes" : value === false ? "no" : "" : typeof value === "string" ? value : ""} onChange={event => update(field.key, field.type === "yes_no" ? event.target.value === "" ? null : event.target.value === "yes" : event.target.value)}><option value="">Choose an answer</option>{options.map(option => <option key={text(option, "id")} value={text(option, "id")}>{text(option, "label")}</option>)}</select>
              {field.type === "file_upload" && <span className="muted">Upload the private document in Documents, then select it here.</span>}{field.type === "emergency_contact" && <span className="muted">Save emergency contacts separately, then select the saved information here.</span>}
            </label>;
          } else if (field.type === "radio" || field.type === "multi_select") control = <fieldset className="registration-field-group" aria-required={enforce}><legend>{label}</legend>{(field.options ?? []).map(option => <label className="registration-check" key={option}><input type={field.type === "radio" ? "radio" : "checkbox"} name={name} value={option} required={field.type === "radio" && enforce} checked={field.type === "radio" ? value === option : Array.isArray(value) && value.includes(option)} onChange={event => update(field.key, field.type === "radio" ? option : event.target.checked ? [...(Array.isArray(value) ? value : []), option] : (Array.isArray(value) ? value : []).filter(item => item !== option))} />{option}</label>)}</fieldset>;
          else if (["checkbox", "acknowledgment"].includes(field.type)) control = <label className="registration-check" htmlFor={id}><input {...input} type="checkbox" required={field.type === "acknowledgment" && enforce} checked={value === true} onChange={event => update(field.key, event.target.checked)} />{label}</label>;
          else if (field.type === "signature") {
            const signature = object(value); control = <fieldset className="registration-field-group"><legend>{label}</legend><label className="form-field"><span>Typed signer name</span><input name={`${name}:name`} value={text(signature, "name")} maxLength={200} required={enforce} onChange={event => update(field.key, { ...signature, name: event.target.value })} /></label><label className="registration-check"><input name={`${name}:consent`} type="checkbox" checked={signature.consent === true} required={enforce || text(signature, "name").length > 0} onChange={event => update(field.key, { ...signature, consent: event.target.checked })} />I consent to use my electronic signature for this form.</label></fieldset>;
          } else if (field.type === "address") {
            const address = object(value); control = <fieldset className="registration-field-group"><legend>{label}</legend><div className="registration-form-grid">{Object.entries({ line1: "Street address", line2: "Apartment or unit", city: "City", region: "State or region", postal_code: "Postal code", country: "Country" }).map(([part, title]) => <label className="form-field" key={part}><span>{title}</span><input name={`${name}:${part}`} value={text(address, part)} maxLength={200} required={enforce && part === "line1"} autoComplete={{ line1: "address-line1", line2: "address-line2", city: "address-level2", region: "address-level1", postal_code: "postal-code", country: "country-name" }[part]} onChange={event => update(field.key, { ...address, [part]: event.target.value })} /></label>)}</div></fieldset>;
          } else control = <label className="form-field" htmlFor={id}><span>{label}</span><input {...input} type={{ email: "email", phone: "tel", number: "number", date: "date" }[field.type] ?? "text"} value={typeof value === "number" || typeof value === "string" ? value : ""} required={enforce} min={field.min} max={field.max} step={field.type === "number" ? "any" : undefined} maxLength={field.max_length ?? 200} onChange={event => update(field.key, field.type === "number" ? event.target.value === "" ? null : Number(event.target.value) : event.target.value)} /></label>;
          return <div key={field.key}>{field.section && (index === 0 || definition.fields[index - 1].section !== field.section) && <h4>{field.section}</h4>}{control}{field.help && field.type !== "content" && <p id={helpId} className="muted">{field.help}</p>}</div>;
        })}
        <label className="registration-check"><input type="checkbox" checked={finalize} onChange={event => setFinalize(event.target.checked)} />Mark this form completed and preserve its answers</label>
      </RegistrationActionForm>}
  </section>;
}

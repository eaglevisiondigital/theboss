import type { Json } from "../supabase/database.types";
import type { FormCondition, FormDefinition, FormField, RegistrationRow } from "./contracts";

export const fieldTypes = ["short_text", "long_text", "email", "phone", "number", "date", "dropdown", "radio", "checkbox", "multi_select", "yes_no", "address", "file_upload", "acknowledgment", "signature", "emergency_contact", "content"] as const;
export const fieldTypeLabels: Record<typeof fieldTypes[number], string> = {
  short_text: "Short text", long_text: "Long text", email: "Email", phone: "Phone", number: "Number", date: "Date", dropdown: "Dropdown", radio: "Single choice",
  checkbox: "Checkbox", multi_select: "Multiple choices", yes_no: "Yes or no", address: "Address", file_upload: "Private document reference", acknowledgment: "Acknowledgment",
  signature: "Signature and consent", emergency_contact: "Emergency contact reference", content: "Instructions",
};
const record = (value: unknown): value is Record<string, unknown> => value !== null && typeof value === "object" && !Array.isArray(value);
const fieldKeys = new Set(["key", "type", "label", "required", "section", "help", "options", "show_if", "required_if", "min", "max", "max_length", "content"]);
const conditionKeys = new Set(["source", "field", "op", "value"]);
const hasControl = (value: string) => [...value].some(character => { const code = character.charCodeAt(0); return code < 32 && ![9, 10, 13].includes(code); });

// This bounded client decoder supports accessible editing. Database validation
// remains the authority for definitions, answers, identity and conditions.
export function parseFormDefinition(value: unknown): FormDefinition | null {
  if (!record(value) || Object.keys(value).some(key => key !== "fields") || !Array.isArray(value.fields) || value.fields.length < 1 || value.fields.length > 100 || new TextEncoder().encode(JSON.stringify(value)).length > 64_000) return null;
  const seen = new Set<string>(); const fields: FormField[] = [];
  for (const field of value.fields) {
    if (!record(field) || Object.keys(field).some(key => !fieldKeys.has(key)) || typeof field.key !== "string" || !/^[a-z][a-z0-9_]{0,59}$/.test(field.key) || seen.has(field.key) || !fieldTypes.includes(field.type as typeof fieldTypes[number]) || typeof field.label !== "string" || field.label.trim().length < 1 || field.label.length > 200) return null;
    if (field.required !== undefined && typeof field.required !== "boolean") return null;
    for (const key of ["section", "help", "content"]) if (field[key] !== undefined && (typeof field[key] !== "string" || String(field[key]).length > (key === "section" ? 200 : 4000) || hasControl(String(field[key])))) return null;
    if (field.max_length !== undefined && (!Number.isInteger(field.max_length) || Number(field.max_length) < 1 || Number(field.max_length) > 4000)) return null;
    for (const key of ["min", "max"]) if (field[key] !== undefined && (field.type !== "number" || typeof field[key] !== "number" || !Number.isFinite(field[key]) || Math.abs(field[key]) > 1_000_000_000)) return null;
    if (typeof field.min === "number" && typeof field.max === "number" && field.min > field.max) return null;
    if (["dropdown", "radio", "multi_select"].includes(String(field.type))) {
      if (!Array.isArray(field.options) || field.options.length < 1 || field.options.length > 50 || field.options.some(option => typeof option !== "string" || option.length < 1 || option.length > 200) || new Set(field.options).size !== field.options.length) return null;
    } else if (field.options !== undefined) return null;
    const parsed: FormField = { key: field.key, type: String(field.type), label: field.label };
    for (const key of ["required", "section", "help", "content", "options", "min", "max", "max_length"] as const) {
      if (field[key] !== undefined) Object.assign(parsed, { [key]: field[key] });
    }
    for (const key of ["show_if", "required_if"] as const) {
      if (field[key] === undefined) continue;
      const conditions = field[key]; if (!Array.isArray(conditions) || conditions.length < 1 || conditions.length > 5) return null;
      const rules: FormCondition[] = [];
      for (const condition of conditions) {
        if (!record(condition) || Object.keys(condition).some(name => !conditionKeys.has(name)) || !["answer", "participant_age", "context"].includes(String(condition.source)) || !["equals", "not_equals", "includes", "lt", "gte"].includes(String(condition.op)) || !["string", "number", "boolean"].includes(typeof condition.value)) return null;
        if (typeof condition.value === "string" && condition.value.length > 200 || typeof condition.value === "number" && !Number.isFinite(condition.value)) return null;
        if (condition.source === "answer" && (typeof condition.field !== "string" || !seen.has(condition.field))) return null;
        if (condition.source === "context" && !["grade", "payment_plan_selected", "travel_team_selected"].includes(String(condition.field))) return null;
        if (condition.source === "participant_age" && (condition.field !== undefined || !["lt", "gte"].includes(String(condition.op)) || typeof condition.value !== "number" || condition.value < 0 || condition.value > 125)) return null;
        if (["lt", "gte"].includes(String(condition.op)) && typeof condition.value !== "number") return null;
        const rule: FormCondition = { source: condition.source as FormCondition["source"], op: condition.op as FormCondition["op"], value: condition.value as FormCondition["value"] };
        if (typeof condition.field === "string") rule.field = condition.field; rules.push(rule);
      }
      parsed[key] = rules;
    }
    seen.add(parsed.key); fields.push(parsed);
  }
  return { fields };
}
export function matchesConditions(rules: FormCondition[] | undefined, answers: RegistrationRow, participantAge: number | undefined, context: RegistrationRow): boolean {
  return !rules || rules.every(rule => {
    const value = rule.source === "participant_age" ? participantAge : rule.source === "context" ? context[rule.field ?? ""] : answers[rule.field ?? ""];
    switch (rule.op) {
      case "equals": return value === rule.value;
      case "not_equals": return value !== undefined && value !== null && value !== rule.value;
      case "includes": return Array.isArray(value) && value.includes(rule.value);
      case "lt": return typeof value === "number" && typeof rule.value === "number" && value < rule.value;
      case "gte": return typeof value === "number" && typeof rule.value === "number" && value >= rule.value;
    }
  });
}
export function activeAnswers(definition: FormDefinition, answers: RegistrationRow, participantAge: number | undefined, context: RegistrationRow): RegistrationRow {
  const result: RegistrationRow = {};
  for (const field of definition.fields) if (field.type !== "content" && matchesConditions(field.show_if, result, participantAge, context) && answers[field.key] !== undefined) result[field.key] = answers[field.key];
  return result;
}
export function requiredField(field: FormField, answers: RegistrationRow, participantAge: number | undefined, context: RegistrationRow): boolean {
  return field.required === true || Boolean(field.required_if && matchesConditions(field.required_if, answers, participantAge, context));
}
export function collectFormAnswers(definition: FormDefinition, data: FormData, participantAge: number | undefined, context: RegistrationRow): RegistrationRow {
  const answers: RegistrationRow = {};
  for (const field of definition.fields) {
    if (field.type === "content" || !matchesConditions(field.show_if, answers, participantAge, context)) continue;
    const name = `answer:${field.key}`; const value = data.get(name);
    if (["checkbox", "acknowledgment"].includes(field.type)) { answers[field.key] = data.has(name); continue; }
    if (field.type === "multi_select") { const choices = data.getAll(name).filter((item): item is string => typeof item === "string"); if (choices.length) answers[field.key] = choices; continue; }
    if (field.type === "signature") {
      const signerName = String(data.get(`${name}:name`) ?? "").trim(); const consent = data.has(`${name}:consent`);
      if (signerName || consent) answers[field.key] = { name: signerName, consent }; continue;
    }
    if (field.type === "address") {
      const address: RegistrationRow = {};
      for (const part of ["line1", "line2", "city", "region", "postal_code", "country"]) {
        const entry = String(data.get(`${name}:${part}`) ?? "").trim(); if (entry) address[part] = entry;
      }
      if (Object.keys(address).length) answers[field.key] = address; continue;
    }
    if (typeof value !== "string" || value.trim() === "") continue;
    if (field.type === "yes_no") answers[field.key] = value === "yes";
    else if (field.type === "number") { const parsed = Number(value); if (Number.isFinite(parsed)) answers[field.key] = parsed; }
    else answers[field.key] = value.trim();
  }
  return answers;
}
export function definitionJson(definition: FormDefinition): Json {
  // The bounded, validated structure consists entirely of JSON primitives.
  return JSON.parse(JSON.stringify(definition)) as Json;
}

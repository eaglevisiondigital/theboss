import assert from "node:assert/strict";
import test from "node:test";
import { activeAnswers, collectFormAnswers, fieldTypes, matchesConditions, parseFormDefinition, requiredField } from "../src/lib/registration/forms";
import type { FormDefinition } from "../src/lib/registration/contracts";

const conditional: FormDefinition = { fields: [
  { key: "medical_condition", type: "yes_no", label: "Medical condition", required: true },
  { key: "details", type: "long_text", label: "Details", show_if: [{ source: "answer", field: "medical_condition", op: "equals", value: true }], required_if: [{ source: "answer", field: "medical_condition", op: "equals", value: true }] },
  { key: "followup", type: "short_text", label: "Followup", show_if: [{ source: "answer", field: "details", op: "equals", value: "yes" }] },
] };
test("form definition accepts all supported field types and preserves their order", () => {
  const fields = fieldTypes.map((type, index) => ({ key: `field_${index}`, type, label: `Field ${index}`, ...(["dropdown", "radio", "multi_select"].includes(type) ? { options: ["A", "B"] } : {}) }));
  assert.equal(parseFormDefinition({ fields })?.fields.length, 17);
});
test("form definitions reject unknown fields, scripts, duplicates and forward condition references", () => {
  assert.equal(parseFormDefinition({ fields: [{ key: "name", type: "short_text", label: "Name", script: "unsafe" }] }), null);
  assert.equal(parseFormDefinition({ fields: [{ key: "name", type: "javascript", label: "Name" }] }), null);
  assert.equal(parseFormDefinition({ fields: [conditional.fields[0], conditional.fields[0]] }), null);
  assert.equal(parseFormDefinition({ fields: [conditional.fields[1], conditional.fields[0]] }), null);
  assert.equal(parseFormDefinition({ fields: [{ key: "name", type: "short_text", label: "Name", show_if: [{ field: "other", value: true }] }] }), null);
});
test("conditional visibility removes stale hidden answers before evaluating later questions", () => {
  assert.deepEqual(activeAnswers(conditional, { medical_condition: false, details: "yes", followup: "should disappear" }, 12, {}), { medical_condition: false });
  assert.deepEqual(activeAnswers(conditional, { medical_condition: true, details: "yes", followup: "visible" }, 12, {}), { medical_condition: true, details: "yes", followup: "visible" });
});
test("age, context and conditional requiredness use typed finite values", () => {
  assert.equal(matchesConditions([{ source: "participant_age", op: "lt", value: 18 }], {}, 12, {}), true);
  assert.equal(matchesConditions([{ source: "participant_age", op: "lt", value: 18 }], {}, undefined, {}), false);
  assert.equal(matchesConditions([{ source: "context", field: "payment_plan_selected", op: "equals", value: true }], {}, 12, { payment_plan_selected: true }), true);
  assert.equal(requiredField(conditional.fields[1], { medical_condition: true }, 12, {}), true);
  assert.equal(requiredField(conditional.fields[1], { medical_condition: false }, 12, {}), false);
  assert.equal(matchesConditions([{ source: "answer", field: "height", op: "lt", value: 60 }], { height: "50" }, 12, {}), false);
});
test("answer collection preserves false answers and excludes hidden stale controls", () => {
  const data = new FormData(); data.set("answer:medical_condition", "no"); data.set("answer:details", "yes"); data.set("answer:followup", "stale");
  assert.deepEqual(collectFormAnswers(conditional, data, 12, {}), { medical_condition: false });
});
test("answer collection supports split fields, typed numbers, signature consent and references", () => {
  const definition: FormDefinition = { fields: [
    { key: "height", type: "number", label: "Height" }, { key: "address", type: "address", label: "Address" }, { key: "consent", type: "signature", label: "Consent" },
    { key: "choices", type: "multi_select", label: "Choices", options: ["A", "B"] }, { key: "document", type: "file_upload", label: "Document" }, { key: "instruction", type: "content", label: "Read this" },
  ] };
  const data = new FormData(); data.set("answer:height", "12.5"); data.set("answer:address:line1", " Test address "); data.set("answer:consent:name", " Test Guardian "); data.set("answer:consent:consent", "on");
  data.append("answer:choices", "A"); data.append("answer:choices", "B"); data.set("answer:document", "12345678-1234-1234-1234-123456789abc"); data.set("answer:instruction", "forged");
  assert.deepEqual(collectFormAnswers(definition, data, 12, {}), { height: 12.5, address: { line1: "Test address" }, consent: { name: "Test Guardian", consent: true }, choices: ["A", "B"], document: "12345678-1234-1234-1234-123456789abc" });
});
test("definition and condition bounds prevent unbounded rendering", () => {
  assert.equal(parseFormDefinition({ fields: Array.from({ length: 101 }, (_, i) => ({ key: `question_${i}`, type: "short_text", label: "Question" })) }), null);
  assert.equal(parseFormDefinition({ fields: [{ key: "first", type: "number", label: "First" }, { key: "second", type: "short_text", label: "Second", show_if: Array.from({ length: 6 }, () => ({ source: "answer", field: "first", op: "lt", value: 5 })) }] }), null);
  assert.equal(parseFormDefinition({ fields: [{ key: "choices", type: "dropdown", label: "Choice", options: ["A", "A"] }] }), null);
});

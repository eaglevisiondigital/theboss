import assert from "node:assert/strict";
import test from "node:test";
import { buildEmergencySaveCommand } from "../src/components/registration/private-data";
import { parseRegistrationCommand } from "../src/lib/registration/input";

const registration = { id: "00000000-0000-4000-8000-000000000004" };
function contactForm() {
  const form = new FormData();
  form.set("contact_name_0", " Controlled contact ");
  form.set("contact_relationship_0", "Guardian");
  form.set("contact_phone_0", "555-0100");
  for (const field of ["contact_email_0", "allergies", "conditions", "medications", "instructions", "physician_name", "physician_phone", "provider", "policy_reference"]) form.set(field, "   ");
  return form;
}

test("contacts-only emergency form sends empty optional sections without blank string members", () => {
  const command = buildEmergencySaveCommand(registration, contactForm(), 1);
  assert.deepEqual(command, { operation: "emergency.save", input: { registration_id: registration.id, contacts: [{ name: "Controlled contact", relationship: "Guardian", phone: "555-0100" }], medical: {}, physician: {}, insurance: {} } });
  assert.ok(parseRegistrationCommand(command));
});

test("emergency edits preserve entered optional data and stored version while clearing omitted fields", () => {
  const form = contactForm();
  form.set("contact_email_0", " contact@example.invalid ");
  form.set("allergies", " Synthetic allergy ");
  form.set("physician_name", " Controlled physician ");
  form.set("provider", " Controlled insurer ");
  const command = buildEmergencySaveCommand(registration, form, 1, { version: 7 });
  assert.deepEqual(command.input, { registration_id: registration.id, expected_version: 7, contacts: [{ name: "Controlled contact", relationship: "Guardian", phone: "555-0100", email: "contact@example.invalid" }], medical: { allergies: "Synthetic allergy" }, physician: { name: "Controlled physician" }, insurance: { provider: "Controlled insurer" } });
  assert.ok(parseRegistrationCommand(command));
});

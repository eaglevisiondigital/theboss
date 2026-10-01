import assert from "node:assert/strict";
import test from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AppRouterContext, type AppRouterInstance } from "next/dist/shared/lib/app-router-context.shared-runtime";
import { SearchParamsContext } from "next/dist/shared/lib/hooks-client-context.shared-runtime";
import { RegistrationConsole } from "../src/components/registration/console";
import { OfferingEditor } from "../src/components/registration/offering-editor";
import { FeesSection } from "../src/components/registration/fees";
import { RegistrationForm } from "../src/components/registration/form-engine";
import { emptyRegistrationData, type RegistrationData, type RegistrationRow } from "../src/lib/registration/contracts";

const org = "00000000-0000-4000-8000-000000000001";
const team = "00000000-0000-4000-8000-000000000002";
const sibling = "00000000-0000-4000-8000-000000000003";
const registrationId = "00000000-0000-4000-8000-000000000004";
const person = "00000000-0000-4000-8000-000000000005";
const child = "00000000-0000-4000-8000-000000000006";
const router: AppRouterInstance = { back() {}, forward() {}, refresh() {}, push() {}, replace() {}, prefetch() {}, bfcacheId: "registration-ui-test" };
function render(node: ReturnType<typeof createElement>) {
  return renderToStaticMarkup(createElement(AppRouterContext.Provider, { value: router }, createElement(SearchParamsContext.Provider, { value: new URLSearchParams() }, node)));
}
function fixture(overrides: Partial<RegistrationData> = {}): RegistrationData {
  return { ...emptyRegistrationData, person: { id: person, label: "Controlled guardian" }, organizationId: org, organizations: [{ id: org, label: "Controlled club" }], features: { registration: true, forms: true, waivers: true, documents: true, fees: true, offline_payments: true }, ...overrides };
}
function registration(overrides: RegistrationRow = {}): RegistrationRow {
  return { id: registrationId, organization_id: org, version: 2, status: "submitted", form_status: "complete", waiver_status: "signed", document_status: "pending", eligibility_status: "pending", approval_status: "pending", roster_status: "unassigned", participant_snapshot: { participant_id: child, person_id: child, display_name: "Controlled athlete" }, offering_snapshot: { offering: { title: "Fall program" } }, operations: [], forms: [], waivers: [], documents: [], charges: [], ...overrides };
}
function form(overrides: RegistrationRow = {}): RegistrationRow {
  return { form_version_id: team, title: "Participant preferences", definition: { fields: [{ key: "preferred_position", type: "short_text", label: "Preferred position", required: true }] }, answers: { preferred_position: "Goalkeeper" }, status: "draft", operations: [], ...overrides };
}
function consoleMarkup(detail: RegistrationRow, view: "family" | "admin" = "family") {
  return render(createElement(RegistrationConsole, { data: fixture({ detail }), query: { view, organization_id: org, registration_id: registrationId } }));
}

test("registration controls follow projected operations in family and staff views", () => {
  const restricted = consoleMarkup(registration({ status: "draft", forms: [form()], operations: [] }), "admin");
  assert.doesNotMatch(restricted, /Save draft details|Submit registration<\/h3>|Record registration decision|Assign to team|Save form draft/);
  assert.match(restricted, /Editing requires family registration authority/);
  const family = consoleMarkup(registration({ status: "draft", operations: ["registration.save", "registration.submit"], forms: [form({ operations: ["form.answer"] })] }));
  assert.match(family, /Save draft details/);
  assert.match(family, /Save form draft/);
  assert.match(family, /Submit registration<\/h3>/);
  assert.doesNotMatch(family, /Record registration decision|Assign to team/);
  const staff = consoleMarkup(registration({ operations: ["registration.decision", "registration.eligibility"] }), "admin");
  assert.match(staff, /Record registration decision/);
  assert.match(staff, /Record eligibility decision/);
  assert.doesNotMatch(staff, /Save draft details|Save form draft/);
});

test("draft review and completed forms render without editable answer controls", () => {
  for (const projected of [form(), form({ status: "submitted", operations: ["form.answer"] })]) {
    const html = render(createElement(RegistrationForm, { registrationId, form: projected, context: {} }));
    assert.match(html, /Goalkeeper/);
    assert.doesNotMatch(html, /name="answer:preferred_position"|Save form draft|Complete this form/);
  }
  const editable = render(createElement(RegistrationForm, { registrationId, form: form({ operations: ["form.answer"] }), context: {} }));
  assert.match(editable, /name="answer:preferred_position"/);
  assert.match(editable, /Mark this form completed/);
  assert.doesNotMatch(editable, /name="answer:preferred_position"[^>]*required/);
});

test("medical answers are absent from ordinary markup until explicit audited access", () => {
  const medical = form({ title: "Restricted health form", needs_sensitive_access: true, sensitivity: "medical", answers: { preferred_position: "PRIVATE_MEDICAL_SENTINEL" }, operations: ["form.access"] });
  const permitted = consoleMarkup(registration({ forms: [medical] }));
  assert.match(permitted, /Open restricted form/);
  assert.doesNotMatch(permitted, /PRIVATE_MEDICAL_SENTINEL|name="answer:preferred_position"|Save form draft/);
  const denied = consoleMarkup(registration({ forms: [{ ...medical, operations: [] }], documents: [{ id: team, title: "Private physical", status: "submitted", operations: [] }] }));
  assert.match(denied, /Restricted answers require document permission/);
  assert.doesNotMatch(denied, /PRIVATE_MEDICAL_SENTINEL|Open restricted form|Download privately|Upload private document|Restricted emergency information/);
});

test("submitted registration preserves independent document, payment and roster states", () => {
  const html = consoleMarkup(registration({ charges: [{ id: team, title: "Participation charge", balance: { currency: "USD", original_amount_minor: 10000, adjustment_amount_minor: -1000, applied_amount_minor: 2000, balance_due_minor: 7000, payment_status: "partially_paid" } }] }));
  assert.match(html, /<dt>Registration<\/dt><dd>submitted<\/dd>/);
  assert.match(html, /<dt>Forms<\/dt><dd>complete<\/dd>/);
  assert.match(html, /<dt>Documents<\/dt><dd>pending<\/dd>/);
  assert.match(html, /<dt>Payment<\/dt><dd>partially paid<\/dd>/);
  assert.match(html, /<dt>Eligibility<\/dt><dd>pending<\/dd>/);
  assert.match(html, /<dt>Approval<\/dt><dd>pending<\/dd>/);
  assert.match(html, /<dt>Team assignment<\/dt><dd>unassigned<\/dd>/);
  assert.match(html, /Balance due<\/dt><dd>\$70\.00/);
  assert.doesNotMatch(html, /Assign to team|Record offline payment/);
});

test("offering edits preserve owning scope and creation advertises only authorized contexts", () => {
  const data = fixture({ organizationScope: null, teams: [{ id: team, label: "Falcons" }, { id: sibling, label: "Sibling team" }] });
  const edited = render(createElement(OfferingEditor, { data, offering: { id: registrationId, title: "Falcons signup", scope_type: "team", scope_id: team, version: 2 } }));
  const scope = edited.match(/<select name="scope"[^>]*>(.*?)<\/select>/)?.[1];
  assert.ok(scope);
  assert.match(scope, /Team: Falcons/);
  assert.doesNotMatch(scope, /Sibling team|Organization|unit:/);
  const create = render(createElement(OfferingEditor, { data: fixture({ teams: [{ id: team, label: "Falcons" }] }) }));
  const createScope = create.match(/<select name="scope"[^>]*>(.*?)<\/select>/)?.[1];
  assert.ok(createScope);
  assert.match(createScope, /Team: Falcons/);
  assert.doesNotMatch(createScope, /Sibling team|organization:/);
});

test("offline financial controls expose cash and check only and require feature plus operation", () => {
  const charge = { id: team, title: "Program charge", status: "active", balance: { currency: "USD", original_amount_minor: 10000, applied_amount_minor: 0, balance_due_minor: 10000, payment_status: "unpaid" } };
  const reg = registration({ charges: [charge], operations: ["payment.record_offline"] });
  const authorized = render(createElement(FeesSection, { registration: reg, data: fixture() }));
  const methods = authorized.match(/<select name="method"[^>]*>(.*?)<\/select>/)?.[1];
  assert.ok(methods);
  assert.match(methods, /value="cash"/);
  assert.match(methods, /value="check"/);
  assert.doesNotMatch(authorized, /value="card"|value="ach"|value="boss_bucks"|Collect payment|Pay online/);
  for (const [detail, data] of [[registration({ charges: [charge] }), fixture()], [reg, fixture({ features: { fees: true, offline_payments: false } })]] as const) {
    const html = render(createElement(FeesSection, { registration: detail, data }));
    assert.match(html, /Balance due/);
    assert.doesNotMatch(html, /name="method"|Record offline payment/);
  }
});

test("family participant choices support multiple children and exclude unavailable authority", () => {
  const offering = { id: registrationId, organization_id: org, title: "Controlled program", status: "published", participant_type: "athlete", operations: ["registration.start"] };
  const data = fixture({ offerings: [offering], participants: [{ id: child, label: "First child", can_register: true, participant_type: "athlete" }, { id: team, label: "Second child", can_register: true, participant_type: "athlete" }, { id: sibling, label: "Restricted child", can_register: false, participant_type: "athlete" }, { id: person, label: "Adult participant", can_register: true, participant_type: "adult" }] });
  const html = render(createElement(RegistrationConsole, { data, query: { view: "family", organization_id: org } }));
  assert.match(html, /First child/);
  assert.match(html, /Second child/);
  assert.doesNotMatch(html, /Restricted child|Adult participant/);
  assert.match(html, /This draft does not create team membership/);
  const denied = render(createElement(RegistrationConsole, { data: { ...data, offerings: [{ ...offering, operations: [] }] }, query: { view: "family", organization_id: org } }));
  assert.doesNotMatch(denied, /name="participant_id"|Save new draft/);
});

test("exact-team emergency access uses the explicit emergency document purpose", () => {
  const html = consoleMarkup(registration({ emergency_access_purpose: "emergency", emergency_teams: [{ id: team, label: "Controlled Falcons" }], operations: ["emergency.access"], documents: [{ id: sibling, title: "Approved emergency physical", status: "approved", access_purpose: "emergency", operations: ["document.access"] }] }), "admin");
  assert.match(html, /Emergency document download/);
  assert.match(html, /Controlled Falcons/);
  assert.match(html, /Open restricted emergency information/);
  assert.doesNotMatch(html, /Ordinary authorized access|Upload private document|Save restricted emergency information|Download privately/);
  const ordinary = consoleMarkup(registration({ emergency_access_purpose: "ordinary", emergency_teams: [{ id: team, label: "Controlled Falcons" }], operations: ["emergency.access"], documents: [] }));
  assert.match(ordinary, /Ordinary authorized access/);
  assert.match(ordinary, /Open restricted emergency information/);
  assert.doesNotMatch(ordinary, /Upload private document|Save restricted emergency information/);
});

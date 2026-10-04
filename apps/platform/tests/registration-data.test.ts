import assert from "node:assert/strict";
import test from "node:test";
import { emptyRegistrationData, type RegistrationQuery } from "../src/lib/registration/contracts";
import { readRegistrationData } from "../src/lib/registration/read";

const organization = "00000000-0000-4000-8000-000000000001";
const registration = "00000000-0000-4000-8000-000000000002";
const otherOrganization = "00000000-0000-4000-8000-000000000003";
const team = "00000000-0000-4000-8000-000000000004";
const initial = { ...emptyRegistrationData, organizations: [{ id: otherOrganization }], detail: { id: registration, organization_id: organization, operations: ["payment.record_offline"] } };

test("authorized direct registration link re-reads the actual organization with existing view and filters", async () => {
  const queries: RegistrationQuery[] = [];
  const query: RegistrationQuery = { view: "admin", registration_id: registration, status: "submitted", query: "Falcons" };
  const result = await readRegistrationData(query, async current => {
    queries.push(current);
    return { error: null, data: queries.length === 1 ? initial : {
      ...initial, organizationId: organization, features: { registration: true, fees: true, offline_payments: true, payment_plans: true }, teams: [{ id: team, label: "Falcons" }],
    } };
  });
  assert.deepEqual(queries, [query, { ...query, organization_id: organization }]);
  assert.equal(query.organization_id, undefined);
  assert.equal(result.organizationId, organization);
  assert.equal(result.features.offline_payments, true);
  assert.equal(result.features.payment_plans, true);
  assert.deepEqual(result.teams, [{ id: team, label: "Falcons" }]);
  assert.equal(result.detail?.id, registration);
});

test("denied direct registration does not infer an organization or retry", async () => {
  let calls = 0;
  const result = await readRegistrationData({ view: "admin", registration_id: registration }, async () => {
    calls++;
    return { data: initial, error: { message: "PRIVATE_DATABASE_DETAIL" } };
  });
  assert.equal(calls, 1);
  assert.equal(result.unavailable, true);
  assert.equal(result.detail, null);
  assert.deepEqual(result.features, {});
  assert.doesNotMatch(JSON.stringify(result), /PRIVATE_DATABASE_DETAIL/);
});

test("missing or mismatched detail cannot supply inferred organization context", async () => {
  for (const data of [emptyRegistrationData, { ...initial, detail: { id: team, organization_id: organization } }, { ...initial, detail: { id: registration, organization_id: "not-an-id" } }]) {
    let calls = 0;
    await readRegistrationData({ view: "family", registration_id: registration }, async () => { calls++; return { data, error: null }; });
    assert.equal(calls, 1);
  }
});

test("revocation or scoped read failure suppresses the previously authorized detail", async () => {
  for (const fail of ["denied", "malformed", "throw"] as const) {
    let calls = 0;
    const result = await readRegistrationData({ view: "admin", registration_id: registration }, async () => {
      if (++calls === 1) return { data: initial, error: null };
      if (fail === "throw") throw new Error("PRIVATE_FAILURE");
      return { data: fail === "malformed" ? {} : null, error: fail === "denied" ? { code: "PT403" } : null };
    });
    assert.equal(calls, 2);
    assert.equal(result.unavailable, true);
    assert.equal(result.detail, null);
    assert.deepEqual(result.features, {});
  }
});

test("explicit organization and all-organization lists retain a single guarded read", async () => {
  for (const query of [{ view: "admin", organization_id: otherOrganization, registration_id: registration }, { view: "family" }] satisfies RegistrationQuery[]) {
    const queries: RegistrationQuery[] = [];
    await readRegistrationData(query, async current => { queries.push(current); return { data: initial, error: null }; });
    assert.deepEqual(queries, [query]);
  }
});

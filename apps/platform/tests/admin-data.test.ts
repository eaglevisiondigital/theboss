import assert from "node:assert/strict";
import test from "node:test";
import { createElement } from "react";
import { renderToStaticMarkup } from "react-dom/server";
import { AdminConsole } from "../src/components/admin/console";
import { emptyAdminView } from "../src/lib/admin/contracts";
import { readAdminView } from "../src/lib/admin/read";

const org = "00000000-0000-4000-8000-000000000001";
const privateData = { ...emptyAdminView, operations: ["household.create"], records: { households: [{ id: org, label: "PRIVATE_RECORD", fields: {} }] } };

test("restricted admin read returns no records or actions and renders access denial instead of an outage", async () => {
  let calls = 0;
  const result = await readAdminView("families", async request => {
    calls++;
    assert.deepEqual(request, { p_view: "families", p_organization_id: org, p_query: null });
    return { data: privateData, error: { code: "PT403", message: "PRIVATE_DATABASE_DETAIL" } };
  }, org);
  assert.equal(calls, 1);
  assert.deepEqual(result, { ...emptyAdminView, accessDenied: true });
  const html = renderToStaticMarkup(createElement(AdminConsole, { view: "families", data: result }));
  assert.match(html, /Family records are restricted in this context/);
  assert.doesNotMatch(html, /temporarily unavailable|Connect your Boss identity|Create household|PRIVATE_/);
});

test("operational and malformed admin failures retain the unavailable state without leaking error details", async () => {
  for (const fail of ["database", "throw", "malformed"] as const) {
    const result = await readAdminView("families", async () => {
      if (fail === "throw") throw new Error("PRIVATE_FAILURE");
      return { data: fail === "malformed" ? {} : privateData, error: fail === "database" ? { code: "57014", message: "PRIVATE_FAILURE" } : null };
    }, org);
    assert.deepEqual(result, { ...emptyAdminView, unavailable: true });
    const html = renderToStaticMarkup(createElement(AdminConsole, { view: "families", data: result }));
    assert.match(html, /Your workspace is temporarily unavailable/);
    assert.doesNotMatch(html, /Family records are restricted|Connect your Boss identity|PRIVATE_/);
  }
});

test("successful admin reads preserve existing projection and bounded query context", async () => {
  const data = { ...emptyAdminView, provisioned: true, organizationId: org, navigation: ["families"], organizations: [{ id: org, label: "Controlled organization", fields: {}, operations: [] }] };
  const result = await readAdminView("families", async request => {
    assert.deepEqual(request, { p_view: "families", p_organization_id: org, p_query: "Controlled" });
    return { data, error: null };
  }, org, " Controlled ");
  assert.deepEqual(result, data);
  assert.equal(result.accessDenied, undefined);
  assert.equal(result.unavailable, undefined);
});

test("invalid admin filters never issue a read or become authorization denial", async () => {
  let calls = 0;
  for (const [organizationId, query] of [["invalid", undefined], [org, "x".repeat(101)], [org, ["invalid"]]]) {
    const result = await readAdminView("families", async () => { calls++; return { data: emptyAdminView, error: null }; }, organizationId, query);
    assert.deepEqual(result, { ...emptyAdminView, unavailable: true });
  }
  assert.equal(calls, 0);
});

test("other restricted workspaces render denial without advertising identity provisioning", async () => {
  const data = await readAdminView("teams", async () => ({ data: null, error: { code: "PT403" } }), org);
  const html = renderToStaticMarkup(createElement(AdminConsole, { view: "teams", data }));
  assert.match(html, /You do not have access to this workspace in the selected context/);
  assert.doesNotMatch(html, /temporarily unavailable|Connect your Boss identity/);
});

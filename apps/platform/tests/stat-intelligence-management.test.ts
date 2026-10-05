import test from "node:test";
import assert from "node:assert/strict";
import { emptyAdminView } from "../src/lib/admin/contracts";
import { canRebuildStatScope } from "../src/lib/stat-intelligence/management";

const organizationId = "b32d6dbd-46a4-4aaf-982b-54c78f3361e3";
const other = "8d196b33-ad04-4402-99ef-9f983dee4ce2";
// Match boss_admin_read: creation/module operations at the top level, update
// authority on the exact organization record returned in the current context.
const administrator = { ...emptyAdminView, provisioned: true, organizationId,
  operations: ["module.set", "team.create"], organizations: [{ id: organizationId,
    label: "CONTROLLED TEST", fields: {}, operations: ["organization.update"] }] };
test("canonical scoped administrator projection exposes statistics rebuild", () => {
  assert.equal(canRebuildStatScope(administrator, organizationId), true);
});
test("top-level operation or another organization cannot grant rebuild UI", () => {
  assert.equal(canRebuildStatScope({ ...administrator, operations: ["organization.update"],
    organizations: [{ ...administrator.organizations[0], operations: [] }] }, organizationId), false);
  assert.equal(canRebuildStatScope(administrator, other), false);
  assert.equal(canRebuildStatScope({ ...administrator, organizationId: other }, organizationId), false);
});
test("guardian, unprovisioned and denied projections do not expose rebuild", () => {
  for (const admin of [emptyAdminView, { ...administrator, provisioned: false },
    { ...administrator, accessDenied: true }, { ...administrator, unavailable: true },
    { ...administrator, organizations: [] }]) assert.equal(canRebuildStatScope(admin, organizationId), false);
});

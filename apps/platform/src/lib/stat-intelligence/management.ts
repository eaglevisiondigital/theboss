import type { AdminViewData } from "../admin/contracts";

// Organization update authority is projected on its scoped record, not in the
// top-level list of creation operations. SQL still authorizes every rebuild.
export function canRebuildStatScope(admin: AdminViewData, organizationId?: string): boolean {
  return !!organizationId && admin.provisioned && !admin.unavailable && !admin.accessDenied &&
    admin.organizationId === organizationId && admin.organizations.some(record =>
      record.id === organizationId && record.operations?.includes("organization.update"));
}

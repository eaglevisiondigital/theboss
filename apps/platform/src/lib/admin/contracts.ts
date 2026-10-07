import type { Json } from "../supabase/database.types";

export const adminViews = ["home", "organizations", "people", "families", "teams", "access", "audit", "account"] as const;
export type AdminView = typeof adminViews[number];
export type AdminNavigation = Exclude<AdminView, "home" | "account">;
export const guardianCapabilityKeys = ["can_register", "can_sign_waivers", "can_view_documents", "can_manage_payments", "can_manage_profile", "can_respond_attendance", "can_manage_fundraising", "can_manage_boss_bucks"] as const;
export type GuardianCapability = typeof guardianCapabilityKeys[number];
export type AdminRecord = {
  id: string;
  label: string;
  status?: string;
  operations?: string[];
  fields: Record<string, string | number | boolean | null | string[]>;
};
export type AdminViewData = {
  provisioned: boolean;
  person: { id: string; label: string } | null;
  organizations: AdminRecord[];
  organizationId: string | null;
  operations: string[];
  navigation: AdminNavigation[];
  records: Record<string, AdminRecord[]>;
  unavailable?: boolean;
  accessDenied?: boolean;
};
export type AdminCommand = { operation: string; input: Record<string, Json>; ref?: string };
export type AdminMutationResult = { resource_type: string; resource_id: string; ref?: string };

export const emptyAdminView: AdminViewData = {
  provisioned: false, person: null, organizations: [], organizationId: null,
  operations: [], navigation: [], records: {},
};

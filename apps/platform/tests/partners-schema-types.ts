// Compile-only bridge: the catalog-verified supplemental contract must agree
// with the canonical types used by application RPCs. Runtime behavior is unchanged.
import type { Database } from "../src/lib/supabase/database.types";
import type { PartnerFoundationTables, PartnerFoundationFunctions } from "../src/lib/partners/database.types";

type Same<A, B> = [A] extends [B] ? [B] extends [A] ? true : false : false;
type NormalizeArgs<A> = [A] extends [never] ? Record<string, never> : Required<A>;
type AssertTables<T extends { [K in keyof PartnerFoundationTables]: true }> = T;
type AssertFunctions<T extends { [K in keyof PartnerFoundationFunctions]: true }> = T;

export type VerifiedPartnerTableTypes = AssertTables<{
  [K in keyof PartnerFoundationTables]: Same<PartnerFoundationTables[K], Database["public"]["Tables"][K]["Row"]>;
}>;
export type VerifiedPartnerFunctionTypes = AssertFunctions<{
  [K in keyof PartnerFoundationFunctions]: Same<
    PartnerFoundationFunctions[K],
    { Args: NormalizeArgs<Database["public"]["Functions"][K]["Args"]>; Returns: Database["public"]["Functions"][K]["Returns"] }
  >;
}>;

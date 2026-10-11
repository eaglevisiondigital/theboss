// Local grouped proposal contract generated from disposable PostgreSQL; canonical types remain at 119 migrations until release approval.
import type { Json } from "../supabase/database.types";
export type MoneyBoardProposalTables = {
 money_board_cart_history: {
  id: string;
  cart_id: string;
  action: string;
  request_id: string;
  created_at: string;
 };
 money_board_cart_items: {
  cart_id: string;
  tile_id: string;
  amount_minor: number;
  provenance: Json;
  added_at: string;
  removed_at: string | null;
 };
 money_board_cart_policies: {
  revision: number;
  max_tiles: number;
  max_total_minor: number;
  session_seconds: number;
  created_by: string | null;
  created_at: string;
 };
 money_board_carts: {
  id: string;
  organization_id: string;
  campaign_id: string;
  board_id: string;
  generation_id: string;
  fundraiser_id: string | null;
  path_digest: string;
  capability_digest: string;
  actor_person_id: string | null;
  currency: string;
  context: Json;
  policy_revision: number;
  created_at: string;
  expires_at: string;
 };
 money_board_checkout_preparations: {
  group_id: string;
  intent_id: string;
  request_id: string;
  created_at: string;
 };
 money_board_correction_plans: {
  event_id: string;
  allocations: Json;
  created_at: string;
 };
 money_board_group_commits: {
  checkout_id: string;
  group_id: string;
  snapshot: Json;
  committed_at: string;
 };
 money_board_group_items: {
  group_id: string;
  tile_id: string;
  reservation_id: string;
  amount_minor: number;
  provenance: Json;
 };
 money_board_groups: {
  id: string;
  cart_id: string;
  request_id: string;
  amount_minor: number;
  currency: string;
  policy_revision: number;
  starts_at: string;
  expires_at: string;
 };
 money_board_tile_claims: {
  tile_id: string;
  evidence_id: string;
  group_id: string | null;
  amount_minor: number;
  provenance: Json;
  claimed_at: string;
 };
 money_board_tile_corrections: {
  correction_id: string;
  tile_id: string;
  amount_minor: number;
  algorithm: string;
  original_minor: number;
  tie_order: number;
 };
};
export type MoneyBoardProposalFunctions = {
 boss_money_board_candidate: { Args: { path: string, excluded: string[] }; Returns: Json };
 boss_money_board_cart: { Args: { command: Json, session_capability: string }; Returns: Json };
 boss_money_board_policy: { Args: { command: Json }; Returns: Json };
 boss_money_board_public: { Args: { path: string, after_ordinal: number }; Returns: Json };
};

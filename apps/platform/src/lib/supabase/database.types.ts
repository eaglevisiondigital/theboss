export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.18"
  }
  public: {
    Tables: {
      audit_events: {
        Row: {
          action: string
          actor_auth_user_id: string | null
          actor_person_id: string | null
          after_data: Json | null
          before_data: Json | null
          created_at: string
          household_id: string | null
          id: string
          organization_id: string | null
          organization_unit_id: string | null
          request_id: string | null
          resource_id: string | null
          resource_type: string
          scope_id: string | null
          scope_person_id: string | null
          scope_type: string
          team_id: string | null
        }
        Insert: {
          action: string
          actor_auth_user_id?: string | null
          actor_person_id?: string | null
          after_data?: Json | null
          before_data?: Json | null
          created_at?: string
          household_id?: string | null
          id?: string
          organization_id?: string | null
          organization_unit_id?: string | null
          request_id?: string | null
          resource_id?: string | null
          resource_type: string
          scope_id?: string | null
          scope_person_id?: string | null
          scope_type?: string
          team_id?: string | null
        }
        Update: {
          action?: string
          actor_auth_user_id?: string | null
          actor_person_id?: string | null
          after_data?: Json | null
          before_data?: Json | null
          created_at?: string
          household_id?: string | null
          id?: string
          organization_id?: string | null
          organization_unit_id?: string | null
          request_id?: string | null
          resource_id?: string | null
          resource_type?: string
          scope_id?: string | null
          scope_person_id?: string | null
          scope_type?: string
          team_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_events_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_events_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_events_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_events_scope_person_id_fkey"
            columns: ["scope_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "audit_events_team_fk"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "audit_events_unit_fk"
            columns: ["organization_id", "organization_unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      charge_adjustments: {
        Row: {
          adjustment_type: string
          amount_minor: number
          charge_id: string
          created_at: string
          id: string
          organization_id: string
          reason: string
          recorded_by_person_id: string
          source_coupon_id: string | null
        }
        Insert: {
          adjustment_type: string
          amount_minor: number
          charge_id: string
          created_at?: string
          id?: string
          organization_id: string
          reason: string
          recorded_by_person_id: string
          source_coupon_id?: string | null
        }
        Update: {
          adjustment_type?: string
          amount_minor?: number
          charge_id?: string
          created_at?: string
          id?: string
          organization_id?: string
          reason?: string
          recorded_by_person_id?: string
          source_coupon_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "charge_adjustments_organization_id_charge_id_fkey"
            columns: ["organization_id", "charge_id"]
            isOneToOne: false
            referencedRelation: "charges"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "charge_adjustments_organization_id_source_coupon_id_fkey"
            columns: ["organization_id", "source_coupon_id"]
            isOneToOne: false
            referencedRelation: "registration_coupons"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "charge_adjustments_recorded_by_person_id_fkey"
            columns: ["recorded_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      charges: {
        Row: {
          charge_type: string
          created_at: string
          created_by_person_id: string
          currency: string
          due_on: string | null
          event_id: string | null
          fee_rule_id: string | null
          household_id: string | null
          id: string
          organization_id: string
          original_amount_minor: number
          participant_id: string
          registration_id: string
          status: string
          title: string
        }
        Insert: {
          charge_type: string
          created_at?: string
          created_by_person_id: string
          currency: string
          due_on?: string | null
          event_id?: string | null
          fee_rule_id?: string | null
          household_id?: string | null
          id?: string
          organization_id: string
          original_amount_minor: number
          participant_id: string
          registration_id: string
          status?: string
          title: string
        }
        Update: {
          charge_type?: string
          created_at?: string
          created_by_person_id?: string
          currency?: string
          due_on?: string | null
          event_id?: string | null
          fee_rule_id?: string | null
          household_id?: string | null
          id?: string
          organization_id?: string
          original_amount_minor?: number
          participant_id?: string
          registration_id?: string
          status?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "charges_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "charges_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "charges_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "charges_organization_id_fee_rule_id_fkey"
            columns: ["organization_id", "fee_rule_id"]
            isOneToOne: false
            referencedRelation: "registration_fee_rules"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "charges_organization_id_registration_id_participant_id_fkey"
            columns: ["organization_id", "registration_id", "participant_id"]
            isOneToOne: false
            referencedRelation: "registrations"
            referencedColumns: ["organization_id", "id", "participant_id"]
          },
        ]
      }
      document_requirements: {
        Row: {
          allowed_mime_types: string[]
          classification: string
          created_at: string
          created_by_person_id: string
          emergency_access: boolean
          id: string
          key: string
          max_bytes: number
          organization_id: string
          required: boolean
          title: string
          validity_days: number | null
          version_number: number
        }
        Insert: {
          allowed_mime_types?: string[]
          classification?: string
          created_at?: string
          created_by_person_id: string
          emergency_access?: boolean
          id?: string
          key: string
          max_bytes?: number
          organization_id: string
          required?: boolean
          title: string
          validity_days?: number | null
          version_number: number
        }
        Update: {
          allowed_mime_types?: string[]
          classification?: string
          created_at?: string
          created_by_person_id?: string
          emergency_access?: boolean
          id?: string
          key?: string
          max_bytes?: number
          organization_id?: string
          required?: boolean
          title?: string
          validity_days?: number | null
          version_number?: number
        }
        Relationships: [
          {
            foreignKeyName: "document_requirements_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "document_requirements_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      document_upload_intents: {
        Row: {
          actor_person_id: string
          auth_session_id: string
          consumed_at: string | null
          created_at: string
          document_id: string
          expires_at: string
          id: string
          mime_type: string
          object_name: string
          organization_id: string
          sha256: string | null
          size_bytes: number
        }
        Insert: {
          actor_person_id: string
          auth_session_id: string
          consumed_at?: string | null
          created_at?: string
          document_id: string
          expires_at: string
          id?: string
          mime_type: string
          object_name: string
          organization_id: string
          sha256?: string | null
          size_bytes: number
        }
        Update: {
          actor_person_id?: string
          auth_session_id?: string
          consumed_at?: string | null
          created_at?: string
          document_id?: string
          expires_at?: string
          id?: string
          mime_type?: string
          object_name?: string
          organization_id?: string
          sha256?: string | null
          size_bytes?: number
        }
        Relationships: [
          {
            foreignKeyName: "document_upload_intents_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "document_upload_intents_organization_id_document_id_fkey"
            columns: ["organization_id", "document_id"]
            isOneToOne: false
            referencedRelation: "registration_documents"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      entitlements: {
        Row: {
          configuration: Json
          created_at: string
          ends_at: string | null
          entitlement_key: string
          entitlement_type: string
          household_id: string | null
          household_membership_id: string | null
          id: string
          membership_kind: string | null
          organization_id: string | null
          organization_membership_id: string | null
          person_id: string | null
          source_id: string | null
          source_type: string | null
          starts_at: string
          status: string
          subject_id: string
          subject_type: string
          team_membership_id: string | null
          updated_at: string
        }
        Insert: {
          configuration?: Json
          created_at?: string
          ends_at?: string | null
          entitlement_key: string
          entitlement_type: string
          household_id?: string | null
          household_membership_id?: string | null
          id?: string
          membership_kind?: string | null
          organization_id?: string | null
          organization_membership_id?: string | null
          person_id?: string | null
          source_id?: string | null
          source_type?: string | null
          starts_at?: string
          status?: string
          subject_id: string
          subject_type: string
          team_membership_id?: string | null
          updated_at?: string
        }
        Update: {
          configuration?: Json
          created_at?: string
          ends_at?: string | null
          entitlement_key?: string
          entitlement_type?: string
          household_id?: string | null
          household_membership_id?: string | null
          id?: string
          membership_kind?: string | null
          organization_id?: string | null
          organization_membership_id?: string | null
          person_id?: string | null
          source_id?: string | null
          source_type?: string | null
          starts_at?: string
          status?: string
          subject_id?: string
          subject_type?: string
          team_membership_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "entitlements_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "entitlements_household_membership_id_fkey"
            columns: ["household_membership_id"]
            isOneToOne: false
            referencedRelation: "household_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "entitlements_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "entitlements_organization_membership_id_fkey"
            columns: ["organization_membership_id"]
            isOneToOne: false
            referencedRelation: "organization_memberships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "entitlements_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "entitlements_team_membership_id_fkey"
            columns: ["team_membership_id"]
            isOneToOne: false
            referencedRelation: "team_memberships"
            referencedColumns: ["id"]
          },
        ]
      }
      event_game_details: {
        Row: {
          event_id: string
          external_opponent_name: string | null
          game_status: string
          home_away: string
          opponent_team_id: string | null
          organization_id: string
        }
        Insert: {
          event_id: string
          external_opponent_name?: string | null
          game_status?: string
          home_away?: string
          opponent_team_id?: string | null
          organization_id: string
        }
        Update: {
          event_id?: string
          external_opponent_name?: string | null
          game_status?: string
          home_away?: string
          opponent_team_id?: string | null
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_game_details_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "event_game_details_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_game_details_organization_id_opponent_team_id_fkey"
            columns: ["organization_id", "opponent_team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      event_occurrence_exceptions: {
        Row: {
          created_at: string
          created_by_person_id: string
          event_id: string
          id: string
          instructions: string | null
          is_active: boolean
          occurrence_key: string
          organization_id: string
          override_arrival_at: string | null
          override_end_at: string | null
          override_start_at: string | null
          status: string | null
          title: string | null
          updated_at: string
          updated_by_person_id: string
          version: number
        }
        Insert: {
          created_at?: string
          created_by_person_id: string
          event_id: string
          id?: string
          instructions?: string | null
          is_active?: boolean
          occurrence_key: string
          organization_id: string
          override_arrival_at?: string | null
          override_end_at?: string | null
          override_start_at?: string | null
          status?: string | null
          title?: string | null
          updated_at?: string
          updated_by_person_id: string
          version?: number
        }
        Update: {
          created_at?: string
          created_by_person_id?: string
          event_id?: string
          id?: string
          instructions?: string | null
          is_active?: boolean
          occurrence_key?: string
          organization_id?: string
          override_arrival_at?: string | null
          override_end_at?: string | null
          override_start_at?: string | null
          status?: string | null
          title?: string | null
          updated_at?: string
          updated_by_person_id?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "event_occurrence_exceptions_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_occurrence_exceptions_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "event_occurrence_exceptions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_occurrence_exceptions_updated_by_person_id_fkey"
            columns: ["updated_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      event_reminders: {
        Row: {
          audience: string[]
          enabled: boolean
          event_id: string
          id: string
          minutes_before: number
          organization_id: string
        }
        Insert: {
          audience: string[]
          enabled?: boolean
          event_id: string
          id?: string
          minutes_before: number
          organization_id: string
        }
        Update: {
          audience?: string[]
          enabled?: boolean
          event_id?: string
          id?: string
          minutes_before?: number
          organization_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "event_reminders_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "event_reminders_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      event_targets: {
        Row: {
          created_at: string
          event_id: string
          id: string
          organization_id: string
          target_id: string
          target_type: string
          team_id: string | null
          unit_id: string | null
        }
        Insert: {
          created_at?: string
          event_id: string
          id?: string
          organization_id: string
          target_id: string
          target_type: string
          team_id?: string | null
          unit_id?: string | null
        }
        Update: {
          created_at?: string
          event_id?: string
          id?: string
          organization_id?: string
          target_id?: string
          target_type?: string
          team_id?: string | null
          unit_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "event_targets_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "event_targets_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "event_targets_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "event_targets_organization_id_unit_id_fkey"
            columns: ["organization_id", "unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      event_types: {
        Row: {
          created_at: string
          description: string | null
          key: string
          name: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          key: string
          name: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          key?: string
          name?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      events: {
        Row: {
          all_day: boolean
          archived_at: string | null
          arrival_at: string | null
          audience: string[]
          created_at: string
          created_by_person_id: string
          description: string | null
          end_at: string
          event_type_key: string
          id: string
          instructions: string | null
          organization_id: string
          publication_state: string
          published_at: string | null
          recurrence: Json | null
          recurrence_end_at: string | null
          resource_id: string | null
          rsvp_mode: string
          start_at: string
          status: string
          timezone: string
          title: string
          updated_at: string
          updated_by_person_id: string
          venue_id: string | null
          version: number
          visibility: string
        }
        Insert: {
          all_day?: boolean
          archived_at?: string | null
          arrival_at?: string | null
          audience?: string[]
          created_at?: string
          created_by_person_id: string
          description?: string | null
          end_at: string
          event_type_key: string
          id?: string
          instructions?: string | null
          organization_id: string
          publication_state?: string
          published_at?: string | null
          recurrence?: Json | null
          recurrence_end_at?: string | null
          resource_id?: string | null
          rsvp_mode?: string
          start_at: string
          status?: string
          timezone?: string
          title: string
          updated_at?: string
          updated_by_person_id: string
          venue_id?: string | null
          version?: number
          visibility?: string
        }
        Update: {
          all_day?: boolean
          archived_at?: string | null
          arrival_at?: string | null
          audience?: string[]
          created_at?: string
          created_by_person_id?: string
          description?: string | null
          end_at?: string
          event_type_key?: string
          id?: string
          instructions?: string | null
          organization_id?: string
          publication_state?: string
          published_at?: string | null
          recurrence?: Json | null
          recurrence_end_at?: string | null
          resource_id?: string | null
          rsvp_mode?: string
          start_at?: string
          status?: string
          timezone?: string
          title?: string
          updated_at?: string
          updated_by_person_id?: string
          venue_id?: string | null
          version?: number
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "events_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "events_event_type_key_fkey"
            columns: ["event_type_key"]
            isOneToOne: false
            referencedRelation: "event_types"
            referencedColumns: ["key"]
          },
          {
            foreignKeyName: "events_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "events_organization_id_venue_id_fkey"
            columns: ["organization_id", "venue_id"]
            isOneToOne: false
            referencedRelation: "venues"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "events_organization_id_venue_id_resource_id_fkey"
            columns: ["organization_id", "venue_id", "resource_id"]
            isOneToOne: false
            referencedRelation: "venue_resources"
            referencedColumns: ["organization_id", "venue_id", "id"]
          },
          {
            foreignKeyName: "events_updated_by_person_id_fkey"
            columns: ["updated_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      feature_flag_overrides: {
        Row: {
          configuration: Json
          created_at: string
          enabled: boolean
          ends_at: string | null
          feature_flag_id: string
          id: string
          organization_id: string | null
          person_id: string | null
          scope_id: string | null
          scope_type: string
          starts_at: string
          status: string
          updated_at: string
        }
        Insert: {
          configuration?: Json
          created_at?: string
          enabled: boolean
          ends_at?: string | null
          feature_flag_id: string
          id?: string
          organization_id?: string | null
          person_id?: string | null
          scope_id?: string | null
          scope_type: string
          starts_at?: string
          status?: string
          updated_at?: string
        }
        Update: {
          configuration?: Json
          created_at?: string
          enabled?: boolean
          ends_at?: string | null
          feature_flag_id?: string
          id?: string
          organization_id?: string | null
          person_id?: string | null
          scope_id?: string | null
          scope_type?: string
          starts_at?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "feature_flag_overrides_feature_flag_id_fkey"
            columns: ["feature_flag_id"]
            isOneToOne: false
            referencedRelation: "feature_flags"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "feature_flag_overrides_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "feature_flag_overrides_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      feature_flags: {
        Row: {
          configuration: Json
          created_at: string
          description: string | null
          enabled: boolean
          id: string
          key: string
          name: string
          rollout_type: string
          status: string
          updated_at: string
        }
        Insert: {
          configuration?: Json
          created_at?: string
          description?: string | null
          enabled?: boolean
          id?: string
          key: string
          name: string
          rollout_type?: string
          status?: string
          updated_at?: string
        }
        Update: {
          configuration?: Json
          created_at?: string
          description?: string | null
          enabled?: boolean
          id?: string
          key?: string
          name?: string
          rollout_type?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      guardian_relationships: {
        Row: {
          authority_status: string
          can_manage_payments: boolean
          can_manage_profile: boolean
          can_register: boolean
          can_sign_waivers: boolean
          can_view_documents: boolean
          created_at: string
          dependent_person_id: string
          ends_at: string | null
          guardian_person_id: string
          id: string
          relationship_type: string
          starts_at: string
          updated_at: string
          verified_at: string | null
        }
        Insert: {
          authority_status?: string
          can_manage_payments?: boolean
          can_manage_profile?: boolean
          can_register?: boolean
          can_sign_waivers?: boolean
          can_view_documents?: boolean
          created_at?: string
          dependent_person_id: string
          ends_at?: string | null
          guardian_person_id: string
          id?: string
          relationship_type?: string
          starts_at?: string
          updated_at?: string
          verified_at?: string | null
        }
        Update: {
          authority_status?: string
          can_manage_payments?: boolean
          can_manage_profile?: boolean
          can_register?: boolean
          can_sign_waivers?: boolean
          can_view_documents?: boolean
          created_at?: string
          dependent_person_id?: string
          ends_at?: string | null
          guardian_person_id?: string
          id?: string
          relationship_type?: string
          starts_at?: string
          updated_at?: string
          verified_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "guardian_relationships_dependent_person_id_fkey"
            columns: ["dependent_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "guardian_relationships_guardian_person_id_fkey"
            columns: ["guardian_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      household_memberships: {
        Row: {
          created_at: string
          ends_at: string | null
          household_id: string
          id: string
          is_primary_contact: boolean
          person_id: string
          relationship_type: string
          starts_at: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          ends_at?: string | null
          household_id: string
          id?: string
          is_primary_contact?: boolean
          person_id: string
          relationship_type?: string
          starts_at?: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          ends_at?: string | null
          household_id?: string
          id?: string
          is_primary_contact?: boolean
          person_id?: string
          relationship_type?: string
          starts_at?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "household_memberships_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "household_memberships_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      households: {
        Row: {
          created_at: string
          id: string
          name: string | null
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          name?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      modules: {
        Row: {
          created_at: string
          description: string | null
          id: string
          key: string
          name: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          key: string
          name: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          key?: string
          name?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      organization_memberships: {
        Row: {
          created_at: string
          ends_at: string | null
          id: string
          membership_type: string
          organization_id: string
          person_id: string
          starts_at: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          ends_at?: string | null
          id?: string
          membership_type?: string
          organization_id: string
          person_id: string
          starts_at?: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          ends_at?: string | null
          id?: string
          membership_type?: string
          organization_id?: string
          person_id?: string
          starts_at?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_memberships_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organization_memberships_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      organization_modules: {
        Row: {
          configuration: Json
          created_at: string
          ends_at: string | null
          id: string
          module_id: string
          organization_id: string
          source: string | null
          starts_at: string
          status: string
          updated_at: string
        }
        Insert: {
          configuration?: Json
          created_at?: string
          ends_at?: string | null
          id?: string
          module_id: string
          organization_id: string
          source?: string | null
          starts_at?: string
          status?: string
          updated_at?: string
        }
        Update: {
          configuration?: Json
          created_at?: string
          ends_at?: string | null
          id?: string
          module_id?: string
          organization_id?: string
          source?: string | null
          starts_at?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_modules_module_id_fkey"
            columns: ["module_id"]
            isOneToOne: false
            referencedRelation: "modules"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organization_modules_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      organization_units: {
        Row: {
          created_at: string
          id: string
          name: string
          organization_id: string
          parent_unit_id: string | null
          slug: string
          sort_order: number
          status: string
          unit_type: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          organization_id: string
          parent_unit_id?: string | null
          slug: string
          sort_order?: number
          status?: string
          unit_type: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          organization_id?: string
          parent_unit_id?: string | null
          slug?: string
          sort_order?: number
          status?: string
          unit_type?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "organization_units_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "organization_units_parent_fk"
            columns: ["organization_id", "parent_unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      organizations: {
        Row: {
          country: string | null
          created_at: string
          default_currency: string | null
          id: string
          legal_name: string | null
          name: string
          organization_type: string
          slug: string
          status: string
          timezone: string
          updated_at: string
        }
        Insert: {
          country?: string | null
          created_at?: string
          default_currency?: string | null
          id?: string
          legal_name?: string | null
          name: string
          organization_type?: string
          slug: string
          status?: string
          timezone?: string
          updated_at?: string
        }
        Update: {
          country?: string | null
          created_at?: string
          default_currency?: string | null
          id?: string
          legal_name?: string | null
          name?: string
          organization_type?: string
          slug?: string
          status?: string
          timezone?: string
          updated_at?: string
        }
        Relationships: []
      }
      participant_emergency_records: {
        Row: {
          contacts: Json
          id: string
          insurance: Json
          medical: Json
          organization_id: string
          participant_id: string
          physician: Json
          registration_id: string
          updated_at: string
          updated_by_person_id: string
          version: number
        }
        Insert: {
          contacts?: Json
          id?: string
          insurance?: Json
          medical?: Json
          organization_id: string
          participant_id: string
          physician?: Json
          registration_id: string
          updated_at?: string
          updated_by_person_id: string
          version?: number
        }
        Update: {
          contacts?: Json
          id?: string
          insurance?: Json
          medical?: Json
          organization_id?: string
          participant_id?: string
          physician?: Json
          registration_id?: string
          updated_at?: string
          updated_by_person_id?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "participant_emergency_records_organization_id_registration_fkey"
            columns: ["organization_id", "registration_id", "participant_id"]
            isOneToOne: false
            referencedRelation: "registrations"
            referencedColumns: ["organization_id", "id", "participant_id"]
          },
          {
            foreignKeyName: "participant_emergency_records_updated_by_person_id_fkey"
            columns: ["updated_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      participants: {
        Row: {
          created_at: string
          id: string
          participant_type: string
          person_id: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          id?: string
          participant_type?: string
          person_id: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          id?: string
          participant_type?: string
          person_id?: string
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "participants_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: true
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      payment_allocations: {
        Row: {
          amount_minor: number
          charge_id: string
          created_at: string
          id: string
          organization_id: string
          payment_id: string
          reversal_of_id: string | null
          status: string
        }
        Insert: {
          amount_minor: number
          charge_id: string
          created_at?: string
          id?: string
          organization_id: string
          payment_id: string
          reversal_of_id?: string | null
          status?: string
        }
        Update: {
          amount_minor?: number
          charge_id?: string
          created_at?: string
          id?: string
          organization_id?: string
          payment_id?: string
          reversal_of_id?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_allocations_organization_id_charge_id_fkey"
            columns: ["organization_id", "charge_id"]
            isOneToOne: false
            referencedRelation: "charges"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payment_allocations_organization_id_payment_id_fkey"
            columns: ["organization_id", "payment_id"]
            isOneToOne: false
            referencedRelation: "payments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payment_allocations_organization_id_reversal_of_id_fkey"
            columns: ["organization_id", "reversal_of_id"]
            isOneToOne: false
            referencedRelation: "payment_allocations"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      payment_installments: {
        Row: {
          amount_minor: number
          charge_id: string
          created_at: string
          due_on: string
          id: string
          organization_id: string
          payment_plan_id: string
          sequence_number: number
        }
        Insert: {
          amount_minor: number
          charge_id: string
          created_at?: string
          due_on: string
          id?: string
          organization_id: string
          payment_plan_id: string
          sequence_number: number
        }
        Update: {
          amount_minor?: number
          charge_id?: string
          created_at?: string
          due_on?: string
          id?: string
          organization_id?: string
          payment_plan_id?: string
          sequence_number?: number
        }
        Relationships: [
          {
            foreignKeyName: "payment_installments_organization_id_charge_id_fkey"
            columns: ["organization_id", "charge_id"]
            isOneToOne: false
            referencedRelation: "charges"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payment_installments_organization_id_payment_plan_id_fkey"
            columns: ["organization_id", "payment_plan_id"]
            isOneToOne: false
            referencedRelation: "payment_plans"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      payment_plans: {
        Row: {
          charge_id: string
          created_at: string
          created_by_person_id: string
          id: string
          organization_id: string
          registration_id: string
          status: string
          title: string
        }
        Insert: {
          charge_id: string
          created_at?: string
          created_by_person_id: string
          id?: string
          organization_id: string
          registration_id: string
          status?: string
          title: string
        }
        Update: {
          charge_id?: string
          created_at?: string
          created_by_person_id?: string
          id?: string
          organization_id?: string
          registration_id?: string
          status?: string
          title?: string
        }
        Relationships: [
          {
            foreignKeyName: "payment_plans_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payment_plans_organization_id_charge_id_fkey"
            columns: ["organization_id", "charge_id"]
            isOneToOne: false
            referencedRelation: "charges"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payment_plans_organization_id_registration_id_fkey"
            columns: ["organization_id", "registration_id"]
            isOneToOne: false
            referencedRelation: "registrations"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      payments: {
        Row: {
          amount_minor: number
          created_at: string
          currency: string
          id: string
          method: string
          note: string | null
          organization_id: string
          payer_person_id: string
          received_at: string
          recorded_by_person_id: string
          reference: string | null
          reversal_of_id: string | null
          source_reference: string | null
          status: string
        }
        Insert: {
          amount_minor: number
          created_at?: string
          currency: string
          id?: string
          method: string
          note?: string | null
          organization_id: string
          payer_person_id: string
          received_at: string
          recorded_by_person_id: string
          reference?: string | null
          reversal_of_id?: string | null
          source_reference?: string | null
          status?: string
        }
        Update: {
          amount_minor?: number
          created_at?: string
          currency?: string
          id?: string
          method?: string
          note?: string | null
          organization_id?: string
          payer_person_id?: string
          received_at?: string
          recorded_by_person_id?: string
          reference?: string | null
          reversal_of_id?: string | null
          source_reference?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "payments_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_organization_id_reversal_of_id_fkey"
            columns: ["organization_id", "reversal_of_id"]
            isOneToOne: false
            referencedRelation: "payments"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "payments_payer_person_id_fkey"
            columns: ["payer_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "payments_recorded_by_person_id_fkey"
            columns: ["recorded_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      people: {
        Row: {
          created_at: string
          date_of_birth: string | null
          display_name: string | null
          first_name: string | null
          id: string
          last_name: string | null
          middle_name: string | null
          preferred_name: string | null
          primary_email: string | null
          primary_phone: string | null
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          date_of_birth?: string | null
          display_name?: string | null
          first_name?: string | null
          id?: string
          last_name?: string | null
          middle_name?: string | null
          preferred_name?: string | null
          primary_email?: string | null
          primary_phone?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          date_of_birth?: string | null
          display_name?: string | null
          first_name?: string | null
          id?: string
          last_name?: string | null
          middle_name?: string | null
          preferred_name?: string | null
          primary_email?: string | null
          primary_phone?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      permissions: {
        Row: {
          created_at: string
          description: string | null
          id: string
          key: string
          name: string
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          key: string
          name: string
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          key?: string
          name?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      registration_coupons: {
        Row: {
          adjustment_type: string
          amount_minor: number | null
          closes_at: string | null
          code: string
          created_at: string
          created_by_person_id: string
          id: string
          max_uses: number | null
          offering_id: string
          opens_at: string | null
          organization_id: string
          percent_bps: number | null
          status: string
          title: string
          used_count: number
          version: number
        }
        Insert: {
          adjustment_type: string
          amount_minor?: number | null
          closes_at?: string | null
          code: string
          created_at?: string
          created_by_person_id: string
          id?: string
          max_uses?: number | null
          offering_id: string
          opens_at?: string | null
          organization_id: string
          percent_bps?: number | null
          status?: string
          title: string
          used_count?: number
          version?: number
        }
        Update: {
          adjustment_type?: string
          amount_minor?: number | null
          closes_at?: string | null
          code?: string
          created_at?: string
          created_by_person_id?: string
          id?: string
          max_uses?: number | null
          offering_id?: string
          opens_at?: string | null
          organization_id?: string
          percent_bps?: number | null
          status?: string
          title?: string
          used_count?: number
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "registration_coupons_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "registration_coupons_organization_id_offering_id_fkey"
            columns: ["organization_id", "offering_id"]
            isOneToOne: false
            referencedRelation: "registration_offerings"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      registration_documents: {
        Row: {
          created_at: string
          expires_on: string | null
          id: string
          object_name: string | null
          organization_id: string
          participant_id: string
          registration_id: string
          renewal_due_on: string | null
          requirement_id: string
          review_reason: string | null
          reviewed_at: string | null
          reviewed_by_person_id: string | null
          snapshot: Json
          status: string
          updated_at: string
          upload_mime_type: string | null
          upload_sha256: string | null
          upload_size_bytes: number | null
          uploaded_at: string | null
          uploaded_by_person_id: string | null
          version: number
        }
        Insert: {
          created_at?: string
          expires_on?: string | null
          id?: string
          object_name?: string | null
          organization_id: string
          participant_id: string
          registration_id: string
          renewal_due_on?: string | null
          requirement_id: string
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by_person_id?: string | null
          snapshot: Json
          status?: string
          updated_at?: string
          upload_mime_type?: string | null
          upload_sha256?: string | null
          upload_size_bytes?: number | null
          uploaded_at?: string | null
          uploaded_by_person_id?: string | null
          version?: number
        }
        Update: {
          created_at?: string
          expires_on?: string | null
          id?: string
          object_name?: string | null
          organization_id?: string
          participant_id?: string
          registration_id?: string
          renewal_due_on?: string | null
          requirement_id?: string
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by_person_id?: string | null
          snapshot?: Json
          status?: string
          updated_at?: string
          upload_mime_type?: string | null
          upload_sha256?: string | null
          upload_size_bytes?: number | null
          uploaded_at?: string | null
          uploaded_by_person_id?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "registration_documents_organization_id_registration_id_par_fkey"
            columns: ["organization_id", "registration_id", "participant_id"]
            isOneToOne: false
            referencedRelation: "registrations"
            referencedColumns: ["organization_id", "id", "participant_id"]
          },
          {
            foreignKeyName: "registration_documents_organization_id_requirement_id_fkey"
            columns: ["organization_id", "requirement_id"]
            isOneToOne: false
            referencedRelation: "document_requirements"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "registration_documents_reviewed_by_person_id_fkey"
            columns: ["reviewed_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "registration_documents_uploaded_by_person_id_fkey"
            columns: ["uploaded_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      registration_fee_rules: {
        Row: {
          amount_minor: number
          charge_type: string
          currency: string
          due_on: string | null
          id: string
          offering_id: string
          organization_id: string
          required: boolean
          status: string
          title: string
          version: number
        }
        Insert: {
          amount_minor: number
          charge_type?: string
          currency: string
          due_on?: string | null
          id?: string
          offering_id: string
          organization_id: string
          required?: boolean
          status?: string
          title: string
          version?: number
        }
        Update: {
          amount_minor?: number
          charge_type?: string
          currency?: string
          due_on?: string | null
          id?: string
          offering_id?: string
          organization_id?: string
          required?: boolean
          status?: string
          title?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "registration_fee_rules_organization_id_offering_id_fkey"
            columns: ["organization_id", "offering_id"]
            isOneToOne: false
            referencedRelation: "registration_offerings"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      registration_form_answers: {
        Row: {
          answers: Json
          completed_at: string | null
          created_at: string
          form_version_id: string
          id: string
          organization_id: string
          registration_id: string
          respondent_person_id: string
          status: string
          updated_at: string
          version: number
        }
        Insert: {
          answers?: Json
          completed_at?: string | null
          created_at?: string
          form_version_id: string
          id?: string
          organization_id: string
          registration_id: string
          respondent_person_id: string
          status?: string
          updated_at?: string
          version?: number
        }
        Update: {
          answers?: Json
          completed_at?: string | null
          created_at?: string
          form_version_id?: string
          id?: string
          organization_id?: string
          registration_id?: string
          respondent_person_id?: string
          status?: string
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "registration_form_answers_organization_id_form_version_id_fkey"
            columns: ["organization_id", "form_version_id"]
            isOneToOne: false
            referencedRelation: "registration_form_versions"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "registration_form_answers_organization_id_registration_id_fkey"
            columns: ["organization_id", "registration_id"]
            isOneToOne: false
            referencedRelation: "registrations"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "registration_form_answers_respondent_person_id_fkey"
            columns: ["respondent_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      registration_form_versions: {
        Row: {
          definition: Json
          form_key: string
          id: string
          organization_id: string
          published_at: string
          published_by_person_id: string
          sensitivity: string
          title: string
          version_number: number
        }
        Insert: {
          definition: Json
          form_key: string
          id?: string
          organization_id: string
          published_at?: string
          published_by_person_id: string
          sensitivity?: string
          title: string
          version_number: number
        }
        Update: {
          definition?: Json
          form_key?: string
          id?: string
          organization_id?: string
          published_at?: string
          published_by_person_id?: string
          sensitivity?: string
          title?: string
          version_number?: number
        }
        Relationships: [
          {
            foreignKeyName: "registration_form_versions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "registration_form_versions_published_by_person_id_fkey"
            columns: ["published_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      registration_offering_documents: {
        Row: {
          document_requirement_id: string
          offering_id: string
          organization_id: string
          required: boolean
          sort_order: number
        }
        Insert: {
          document_requirement_id: string
          offering_id: string
          organization_id: string
          required?: boolean
          sort_order?: number
        }
        Update: {
          document_requirement_id?: string
          offering_id?: string
          organization_id?: string
          required?: boolean
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "registration_offering_documen_organization_id_document_req_fkey"
            columns: ["organization_id", "document_requirement_id"]
            isOneToOne: false
            referencedRelation: "document_requirements"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "registration_offering_document_organization_id_offering_id_fkey"
            columns: ["organization_id", "offering_id"]
            isOneToOne: false
            referencedRelation: "registration_offerings"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      registration_offering_forms: {
        Row: {
          form_version_id: string
          offering_id: string
          organization_id: string
          required: boolean
          sort_order: number
        }
        Insert: {
          form_version_id: string
          offering_id: string
          organization_id: string
          required?: boolean
          sort_order?: number
        }
        Update: {
          form_version_id?: string
          offering_id?: string
          organization_id?: string
          required?: boolean
          sort_order?: number
        }
        Relationships: [
          {
            foreignKeyName: "registration_offering_forms_organization_id_form_version_i_fkey"
            columns: ["organization_id", "form_version_id"]
            isOneToOne: false
            referencedRelation: "registration_form_versions"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "registration_offering_forms_organization_id_offering_id_fkey"
            columns: ["organization_id", "offering_id"]
            isOneToOne: false
            referencedRelation: "registration_offerings"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      registration_offering_waivers: {
        Row: {
          offering_id: string
          organization_id: string
          required: boolean
          sort_order: number
          waiver_version_id: string
        }
        Insert: {
          offering_id: string
          organization_id: string
          required?: boolean
          sort_order?: number
          waiver_version_id: string
        }
        Update: {
          offering_id?: string
          organization_id?: string
          required?: boolean
          sort_order?: number
          waiver_version_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "registration_offering_waivers_organization_id_offering_id_fkey"
            columns: ["organization_id", "offering_id"]
            isOneToOne: false
            referencedRelation: "registration_offerings"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "registration_offering_waivers_organization_id_waiver_versi_fkey"
            columns: ["organization_id", "waiver_version_id"]
            isOneToOne: false
            referencedRelation: "registration_waiver_versions"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      registration_offerings: {
        Row: {
          age_max: number | null
          age_min: number | null
          approval_required: boolean
          capacity: number | null
          closes_at: string | null
          created_at: string
          created_by_person_id: string
          description: string | null
          event_id: string | null
          grade_max: number | null
          grade_min: number | null
          id: string
          opens_at: string | null
          organization_id: string
          participant_type: string
          registration_type: string
          returning_behavior: string
          scope_id: string
          scope_type: string
          season_id: string | null
          status: string
          team_assignment_policy: Json
          team_id: string | null
          title: string
          unit_id: string | null
          updated_at: string
          updated_by_person_id: string
          version: number
          visibility: string
          waitlist_enabled: boolean
        }
        Insert: {
          age_max?: number | null
          age_min?: number | null
          approval_required?: boolean
          capacity?: number | null
          closes_at?: string | null
          created_at?: string
          created_by_person_id: string
          description?: string | null
          event_id?: string | null
          grade_max?: number | null
          grade_min?: number | null
          id?: string
          opens_at?: string | null
          organization_id: string
          participant_type?: string
          registration_type?: string
          returning_behavior?: string
          scope_id: string
          scope_type: string
          season_id?: string | null
          status?: string
          team_assignment_policy?: Json
          team_id?: string | null
          title: string
          unit_id?: string | null
          updated_at?: string
          updated_by_person_id: string
          version?: number
          visibility?: string
          waitlist_enabled?: boolean
        }
        Update: {
          age_max?: number | null
          age_min?: number | null
          approval_required?: boolean
          capacity?: number | null
          closes_at?: string | null
          created_at?: string
          created_by_person_id?: string
          description?: string | null
          event_id?: string | null
          grade_max?: number | null
          grade_min?: number | null
          id?: string
          opens_at?: string | null
          organization_id?: string
          participant_type?: string
          registration_type?: string
          returning_behavior?: string
          scope_id?: string
          scope_type?: string
          season_id?: string | null
          status?: string
          team_assignment_policy?: Json
          team_id?: string | null
          title?: string
          unit_id?: string | null
          updated_at?: string
          updated_by_person_id?: string
          version?: number
          visibility?: string
          waitlist_enabled?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "registration_offerings_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "registration_offerings_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "registration_offerings_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "registration_offerings_organization_id_season_id_fkey"
            columns: ["organization_id", "season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "registration_offerings_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "registration_offerings_organization_id_unit_id_fkey"
            columns: ["organization_id", "unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "registration_offerings_updated_by_person_id_fkey"
            columns: ["updated_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      registration_waiver_versions: {
        Row: {
          body: string
          effective_from: string
          effective_until: string | null
          id: string
          organization_id: string
          published_at: string
          published_by_person_id: string
          signer_type: string
          title: string
          version_number: number
          waiver_key: string
        }
        Insert: {
          body: string
          effective_from?: string
          effective_until?: string | null
          id?: string
          organization_id: string
          published_at?: string
          published_by_person_id: string
          signer_type?: string
          title: string
          version_number: number
          waiver_key: string
        }
        Update: {
          body?: string
          effective_from?: string
          effective_until?: string | null
          id?: string
          organization_id?: string
          published_at?: string
          published_by_person_id?: string
          signer_type?: string
          title?: string
          version_number?: number
          waiver_key?: string
        }
        Relationships: [
          {
            foreignKeyName: "registration_waiver_versions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "registration_waiver_versions_published_by_person_id_fkey"
            columns: ["published_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      registrations: {
        Row: {
          approval_status: string
          assigned_team_id: string | null
          context: Json
          created_at: string
          document_status: string
          eligibility_status: string
          family_snapshot: Json
          form_status: string
          household_id: string | null
          id: string
          offering_id: string
          offering_snapshot: Json
          organization_id: string
          participant_id: string
          participant_snapshot: Json
          review_reason: string | null
          reviewed_at: string | null
          reviewed_by_person_id: string | null
          roster_status: string
          status: string
          submitted_at: string | null
          submitted_by_person_id: string
          updated_at: string
          version: number
          waitlist_position: number | null
          waiver_status: string
        }
        Insert: {
          approval_status?: string
          assigned_team_id?: string | null
          context?: Json
          created_at?: string
          document_status?: string
          eligibility_status?: string
          family_snapshot?: Json
          form_status?: string
          household_id?: string | null
          id?: string
          offering_id: string
          offering_snapshot: Json
          organization_id: string
          participant_id: string
          participant_snapshot: Json
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by_person_id?: string | null
          roster_status?: string
          status?: string
          submitted_at?: string | null
          submitted_by_person_id: string
          updated_at?: string
          version?: number
          waitlist_position?: number | null
          waiver_status?: string
        }
        Update: {
          approval_status?: string
          assigned_team_id?: string | null
          context?: Json
          created_at?: string
          document_status?: string
          eligibility_status?: string
          family_snapshot?: Json
          form_status?: string
          household_id?: string | null
          id?: string
          offering_id?: string
          offering_snapshot?: Json
          organization_id?: string
          participant_id?: string
          participant_snapshot?: Json
          review_reason?: string | null
          reviewed_at?: string | null
          reviewed_by_person_id?: string | null
          roster_status?: string
          status?: string
          submitted_at?: string | null
          submitted_by_person_id?: string
          updated_at?: string
          version?: number
          waitlist_position?: number | null
          waiver_status?: string
        }
        Relationships: [
          {
            foreignKeyName: "registrations_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "registrations_organization_id_assigned_team_id_fkey"
            columns: ["organization_id", "assigned_team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "registrations_organization_id_offering_id_fkey"
            columns: ["organization_id", "offering_id"]
            isOneToOne: false
            referencedRelation: "registration_offerings"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "registrations_participant_id_fkey"
            columns: ["participant_id"]
            isOneToOne: false
            referencedRelation: "participants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "registrations_reviewed_by_person_id_fkey"
            columns: ["reviewed_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "registrations_submitted_by_person_id_fkey"
            columns: ["submitted_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      role_assignments: {
        Row: {
          created_at: string
          ends_at: string | null
          granted_by_person_id: string | null
          id: string
          organization_id: string | null
          organization_unit_id: string | null
          person_id: string
          role_id: string
          scope_id: string | null
          scope_type: string
          starts_at: string
          status: string
          team_id: string | null
          updated_at: string
        }
        Insert: {
          created_at?: string
          ends_at?: string | null
          granted_by_person_id?: string | null
          id?: string
          organization_id?: string | null
          organization_unit_id?: string | null
          person_id: string
          role_id: string
          scope_id?: string | null
          scope_type: string
          starts_at?: string
          status?: string
          team_id?: string | null
          updated_at?: string
        }
        Update: {
          created_at?: string
          ends_at?: string | null
          granted_by_person_id?: string | null
          id?: string
          organization_id?: string | null
          organization_unit_id?: string | null
          person_id?: string
          role_id?: string
          scope_id?: string | null
          scope_type?: string
          starts_at?: string
          status?: string
          team_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "role_assignments_granted_by_person_id_fkey"
            columns: ["granted_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_assignments_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_assignments_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_assignments_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_assignments_team_fk"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "role_assignments_unit_fk"
            columns: ["organization_id", "organization_unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      role_permissions: {
        Row: {
          created_at: string
          permission_id: string
          role_id: string
        }
        Insert: {
          created_at?: string
          permission_id: string
          role_id: string
        }
        Update: {
          created_at?: string
          permission_id?: string
          role_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "role_permissions_permission_id_fkey"
            columns: ["permission_id"]
            isOneToOne: false
            referencedRelation: "permissions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "role_permissions_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      roles: {
        Row: {
          allowed_scope_types: string[]
          created_at: string
          description: string | null
          id: string
          key: string
          name: string
          status: string
          updated_at: string
        }
        Insert: {
          allowed_scope_types: string[]
          created_at?: string
          description?: string | null
          id?: string
          key: string
          name: string
          status?: string
          updated_at?: string
        }
        Update: {
          allowed_scope_types?: string[]
          created_at?: string
          description?: string | null
          id?: string
          key?: string
          name?: string
          status?: string
          updated_at?: string
        }
        Relationships: []
      }
      seasons: {
        Row: {
          created_at: string
          ends_on: string | null
          id: string
          name: string
          organization_id: string
          parent_unit_id: string | null
          registration_closes_at: string | null
          registration_opens_at: string | null
          starts_on: string | null
          status: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          ends_on?: string | null
          id?: string
          name: string
          organization_id: string
          parent_unit_id?: string | null
          registration_closes_at?: string | null
          registration_opens_at?: string | null
          starts_on?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          ends_on?: string | null
          id?: string
          name?: string
          organization_id?: string
          parent_unit_id?: string | null
          registration_closes_at?: string | null
          registration_opens_at?: string | null
          starts_on?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "seasons_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "seasons_parent_unit_fk"
            columns: ["organization_id", "parent_unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      team_memberships: {
        Row: {
          created_at: string
          ends_at: string | null
          id: string
          jersey_number: string | null
          membership_type: string
          organization_id: string
          participant_id: string | null
          person_id: string
          position_label: string | null
          starts_at: string
          status: string
          team_id: string
          updated_at: string
        }
        Insert: {
          created_at?: string
          ends_at?: string | null
          id?: string
          jersey_number?: string | null
          membership_type?: string
          organization_id: string
          participant_id?: string | null
          person_id: string
          position_label?: string | null
          starts_at?: string
          status?: string
          team_id: string
          updated_at?: string
        }
        Update: {
          created_at?: string
          ends_at?: string | null
          id?: string
          jersey_number?: string | null
          membership_type?: string
          organization_id?: string
          participant_id?: string | null
          person_id?: string
          position_label?: string | null
          starts_at?: string
          status?: string
          team_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "team_memberships_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_memberships_participant_fk"
            columns: ["participant_id", "person_id"]
            isOneToOne: false
            referencedRelation: "participants"
            referencedColumns: ["id", "person_id"]
          },
          {
            foreignKeyName: "team_memberships_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "team_memberships_team_fk"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      teams: {
        Row: {
          created_at: string
          id: string
          name: string
          organization_id: string
          parent_unit_id: string | null
          season_id: string | null
          short_name: string | null
          slug: string
          status: string
          updated_at: string
          visibility: string
        }
        Insert: {
          created_at?: string
          id?: string
          name: string
          organization_id: string
          parent_unit_id?: string | null
          season_id?: string | null
          short_name?: string | null
          slug: string
          status?: string
          updated_at?: string
          visibility?: string
        }
        Update: {
          created_at?: string
          id?: string
          name?: string
          organization_id?: string
          parent_unit_id?: string | null
          season_id?: string | null
          short_name?: string | null
          slug?: string
          status?: string
          updated_at?: string
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "teams_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "teams_parent_unit_fk"
            columns: ["organization_id", "parent_unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "teams_season_fk"
            columns: ["organization_id", "season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      user_accounts: {
        Row: {
          account_status: string
          auth_user_id: string | null
          created_at: string
          id: string
          last_login_at: string | null
          person_id: string
          updated_at: string
        }
        Insert: {
          account_status?: string
          auth_user_id?: string | null
          created_at?: string
          id?: string
          last_login_at?: string | null
          person_id: string
          updated_at?: string
        }
        Update: {
          account_status?: string
          auth_user_id?: string | null
          created_at?: string
          id?: string
          last_login_at?: string | null
          person_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_accounts_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      venue_resources: {
        Row: {
          created_at: string
          created_by_person_id: string
          id: string
          is_public: boolean
          name: string
          organization_id: string
          resource_type: string
          status: string
          updated_at: string
          updated_by_person_id: string
          venue_id: string
          version: number
        }
        Insert: {
          created_at?: string
          created_by_person_id: string
          id?: string
          is_public?: boolean
          name: string
          organization_id: string
          resource_type?: string
          status?: string
          updated_at?: string
          updated_by_person_id: string
          venue_id: string
          version?: number
        }
        Update: {
          created_at?: string
          created_by_person_id?: string
          id?: string
          is_public?: boolean
          name?: string
          organization_id?: string
          resource_type?: string
          status?: string
          updated_at?: string
          updated_by_person_id?: string
          venue_id?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "venue_resources_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "venue_resources_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "venue_resources_organization_id_venue_id_fkey"
            columns: ["organization_id", "venue_id"]
            isOneToOne: false
            referencedRelation: "venues"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "venue_resources_updated_by_person_id_fkey"
            columns: ["updated_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      venues: {
        Row: {
          address_line1: string | null
          address_line2: string | null
          city: string | null
          country_code: string | null
          created_at: string
          created_by_person_id: string
          id: string
          instructions: string | null
          is_public: boolean
          name: string
          organization_id: string
          postal_code: string | null
          region: string | null
          status: string
          timezone: string
          updated_at: string
          updated_by_person_id: string
          version: number
        }
        Insert: {
          address_line1?: string | null
          address_line2?: string | null
          city?: string | null
          country_code?: string | null
          created_at?: string
          created_by_person_id: string
          id?: string
          instructions?: string | null
          is_public?: boolean
          name: string
          organization_id: string
          postal_code?: string | null
          region?: string | null
          status?: string
          timezone?: string
          updated_at?: string
          updated_by_person_id: string
          version?: number
        }
        Update: {
          address_line1?: string | null
          address_line2?: string | null
          city?: string | null
          country_code?: string | null
          created_at?: string
          created_by_person_id?: string
          id?: string
          instructions?: string | null
          is_public?: boolean
          name?: string
          organization_id?: string
          postal_code?: string | null
          region?: string | null
          status?: string
          timezone?: string
          updated_at?: string
          updated_by_person_id?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "venues_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "venues_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "venues_updated_by_person_id_fkey"
            columns: ["updated_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      waiver_signatures: {
        Row: {
          consent: boolean
          id: string
          organization_id: string
          participant_id: string
          registration_id: string
          request_context: Json
          signed_at: string
          signer_name: string
          signer_person_id: string
          status: string
          version_snapshot: Json
          waiver_version_id: string
        }
        Insert: {
          consent: boolean
          id?: string
          organization_id: string
          participant_id: string
          registration_id: string
          request_context?: Json
          signed_at?: string
          signer_name: string
          signer_person_id: string
          status?: string
          version_snapshot: Json
          waiver_version_id: string
        }
        Update: {
          consent?: boolean
          id?: string
          organization_id?: string
          participant_id?: string
          registration_id?: string
          request_context?: Json
          signed_at?: string
          signer_name?: string
          signer_person_id?: string
          status?: string
          version_snapshot?: Json
          waiver_version_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "waiver_signatures_organization_id_registration_id_particip_fkey"
            columns: ["organization_id", "registration_id", "participant_id"]
            isOneToOne: false
            referencedRelation: "registrations"
            referencedColumns: ["organization_id", "id", "participant_id"]
          },
          {
            foreignKeyName: "waiver_signatures_organization_id_waiver_version_id_fkey"
            columns: ["organization_id", "waiver_version_id"]
            isOneToOne: false
            referencedRelation: "registration_waiver_versions"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "waiver_signatures_signer_person_id_fkey"
            columns: ["signer_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      boss_admin_mutate: {
        Args: { p_commands: Json; p_request_id: string }
        Returns: Json
      }
      boss_admin_read: {
        Args: { p_organization_id?: string; p_query?: string; p_view: string }
        Returns: Json
      }
      boss_calendar_mutate: {
        Args: { p_command: Json; p_request_id: string }
        Returns: Json
      }
      boss_calendar_preview: { Args: { p_command: Json }; Returns: Json }
      boss_calendar_public_read: { Args: { p_query: Json }; Returns: Json }
      boss_calendar_read: { Args: { p_query: Json }; Returns: Json }
      boss_registration_mutate: {
        Args: { p_command: Json; p_request_id: string }
        Returns: Json
      }
      boss_registration_read: { Args: { p_query?: Json }; Returns: Json }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends (DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never) = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends (DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never) = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends (PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never) = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {},
  },
} as const

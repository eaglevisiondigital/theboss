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
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      [_ in never]: never
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

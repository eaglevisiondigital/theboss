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
      attendance_checkin_history: {
        Row: {
          actor_person_id: string
          checkin_id: string
          created_at: string
          id: string
          organization_id: string
          request_id: string
          state: string
          version: number
        }
        Insert: {
          actor_person_id: string
          checkin_id: string
          created_at?: string
          id?: string
          organization_id: string
          request_id: string
          state: string
          version: number
        }
        Update: {
          actor_person_id?: string
          checkin_id?: string
          created_at?: string
          id?: string
          organization_id?: string
          request_id?: string
          state?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "attendance_checkin_history_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_checkin_history_organization_id_checkin_id_fkey"
            columns: ["organization_id", "checkin_id"]
            isOneToOne: false
            referencedRelation: "attendance_checkins"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      attendance_checkins: {
        Row: {
          actor_person_id: string
          created_at: string
          event_id: string
          id: string
          occurrence_key: string
          occurrence_mode: string
          organization_id: string
          participant_id: string | null
          person_id: string
          state: string
          subject_kind: string
          updated_at: string
          version: number
        }
        Insert: {
          actor_person_id: string
          created_at?: string
          event_id: string
          id?: string
          occurrence_key: string
          occurrence_mode: string
          organization_id: string
          participant_id?: string | null
          person_id: string
          state: string
          subject_kind: string
          updated_at?: string
          version?: number
        }
        Update: {
          actor_person_id?: string
          created_at?: string
          event_id?: string
          id?: string
          occurrence_key?: string
          occurrence_mode?: string
          organization_id?: string
          participant_id?: string | null
          person_id?: string
          state?: string
          subject_kind?: string
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "attendance_checkins_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_checkins_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "attendance_checkins_participant_id_person_id_fkey"
            columns: ["participant_id", "person_id"]
            isOneToOne: false
            referencedRelation: "participants"
            referencedColumns: ["id", "person_id"]
          },
          {
            foreignKeyName: "attendance_checkins_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      attendance_requests: {
        Row: {
          context_fingerprint: string
          created_at: string
          event_id: string
          id: string
          kind: string
          occurrence_key: string
          organization_id: string
          revision: string
        }
        Insert: {
          context_fingerprint: string
          created_at?: string
          event_id: string
          id?: string
          kind: string
          occurrence_key: string
          organization_id: string
          revision: string
        }
        Update: {
          context_fingerprint?: string
          created_at?: string
          event_id?: string
          id?: string
          kind?: string
          occurrence_key?: string
          organization_id?: string
          revision?: string
        }
        Relationships: [
          {
            foreignKeyName: "attendance_requests_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      attendance_response_history: {
        Row: {
          actor_person_id: string | null
          change_kind: string
          created_at: string
          event_id: string
          id: string
          occurrence_key: string
          organization_id: string
          person_id: string
          request_id: string | null
          response_id: string
          snapshot: Json
          subject_kind: string
          version: number
        }
        Insert: {
          actor_person_id?: string | null
          change_kind: string
          created_at?: string
          event_id: string
          id?: string
          occurrence_key: string
          organization_id: string
          person_id: string
          request_id?: string | null
          response_id: string
          snapshot: Json
          subject_kind: string
          version: number
        }
        Update: {
          actor_person_id?: string | null
          change_kind?: string
          created_at?: string
          event_id?: string
          id?: string
          occurrence_key?: string
          organization_id?: string
          person_id?: string
          request_id?: string | null
          response_id?: string
          snapshot?: Json
          subject_kind?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "attendance_response_history_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_response_history_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "attendance_response_history_organization_id_response_id_fkey"
            columns: ["organization_id", "response_id"]
            isOneToOne: false
            referencedRelation: "attendance_responses"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "attendance_response_history_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      attendance_responses: {
        Row: {
          arrival_difference_minutes: number | null
          context_fingerprint: string
          created_at: string
          departure_difference_minutes: number | null
          event_id: string
          guardian_relationship_id: string | null
          household_id: string | null
          id: string
          is_late: boolean
          needs_reconfirmation: boolean
          note: string | null
          occurrence_key: string
          occurrence_mode: string
          organization_id: string
          participant_id: string | null
          person_id: string
          reason: string | null
          responder_person_id: string
          status: string
          subject_kind: string
          updated_at: string
          version: number
        }
        Insert: {
          arrival_difference_minutes?: number | null
          context_fingerprint: string
          created_at?: string
          departure_difference_minutes?: number | null
          event_id: string
          guardian_relationship_id?: string | null
          household_id?: string | null
          id?: string
          is_late?: boolean
          needs_reconfirmation?: boolean
          note?: string | null
          occurrence_key: string
          occurrence_mode: string
          organization_id: string
          participant_id?: string | null
          person_id: string
          reason?: string | null
          responder_person_id: string
          status: string
          subject_kind: string
          updated_at?: string
          version?: number
        }
        Update: {
          arrival_difference_minutes?: number | null
          context_fingerprint?: string
          created_at?: string
          departure_difference_minutes?: number | null
          event_id?: string
          guardian_relationship_id?: string | null
          household_id?: string | null
          id?: string
          is_late?: boolean
          needs_reconfirmation?: boolean
          note?: string | null
          occurrence_key?: string
          occurrence_mode?: string
          organization_id?: string
          participant_id?: string | null
          person_id?: string
          reason?: string | null
          responder_person_id?: string
          status?: string
          subject_kind?: string
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "attendance_responses_guardian_relationship_id_fkey"
            columns: ["guardian_relationship_id"]
            isOneToOne: false
            referencedRelation: "guardian_relationships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_responses_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_responses_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "attendance_responses_participant_id_person_id_fkey"
            columns: ["participant_id", "person_id"]
            isOneToOne: false
            referencedRelation: "participants"
            referencedColumns: ["id", "person_id"]
          },
          {
            foreignKeyName: "attendance_responses_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "attendance_responses_responder_person_id_fkey"
            columns: ["responder_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
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
      communication_attachments: {
        Row: {
          actor_person_id: string
          completed_at: string | null
          content_sha256: string
          created_at: string
          file_name: string
          id: string
          message_id: string | null
          mime_type: string
          object_name: string
          organization_id: string
          size_bytes: number
          status: string
          thread_id: string
        }
        Insert: {
          actor_person_id: string
          completed_at?: string | null
          content_sha256: string
          created_at?: string
          file_name: string
          id?: string
          message_id?: string | null
          mime_type: string
          object_name: string
          organization_id: string
          size_bytes: number
          status?: string
          thread_id: string
        }
        Update: {
          actor_person_id?: string
          completed_at?: string | null
          content_sha256?: string
          created_at?: string
          file_name?: string
          id?: string
          message_id?: string | null
          mime_type?: string
          object_name?: string
          organization_id?: string
          size_bytes?: number
          status?: string
          thread_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "communication_attachments_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communication_attachments_organization_id_thread_id_fkey"
            columns: ["organization_id", "thread_id"]
            isOneToOne: false
            referencedRelation: "communication_threads"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "communication_attachments_thread_id_message_id_fkey"
            columns: ["thread_id", "message_id"]
            isOneToOne: false
            referencedRelation: "communication_messages"
            referencedColumns: ["thread_id", "id"]
          },
        ]
      }
      communication_audiences: {
        Row: {
          created_at: string
          id: string
          organization_id: string
          role_id: string | null
          scope_id: string
          scope_type: string
          team_id: string | null
          thread_id: string
          unit_id: string | null
          volunteer_shift_id: string | null
        }
        Insert: {
          created_at?: string
          id?: string
          organization_id: string
          role_id?: string | null
          scope_id: string
          scope_type: string
          team_id?: string | null
          thread_id: string
          unit_id?: string | null
          volunteer_shift_id?: string | null
        }
        Update: {
          created_at?: string
          id?: string
          organization_id?: string
          role_id?: string | null
          scope_id?: string
          scope_type?: string
          team_id?: string | null
          thread_id?: string
          unit_id?: string | null
          volunteer_shift_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "communication_audiences_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "communication_audiences_organization_id_thread_id_fkey"
            columns: ["organization_id", "thread_id"]
            isOneToOne: false
            referencedRelation: "communication_threads"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "communication_audiences_organization_id_unit_id_fkey"
            columns: ["organization_id", "unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "communication_audiences_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communication_audiences_volunteer_shift_fkey"
            columns: ["organization_id", "volunteer_shift_id"]
            isOneToOne: false
            referencedRelation: "volunteer_shifts"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      communication_message_revisions: {
        Row: {
          actor_person_id: string
          body: string
          created_at: string
          id: string
          message_id: string
          organization_id: string
          version: number
        }
        Insert: {
          actor_person_id: string
          body: string
          created_at?: string
          id?: string
          message_id: string
          organization_id: string
          version: number
        }
        Update: {
          actor_person_id?: string
          body?: string
          created_at?: string
          id?: string
          message_id?: string
          organization_id?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "communication_message_revisions_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communication_message_revisions_organization_id_message_id_fkey"
            columns: ["organization_id", "message_id"]
            isOneToOne: false
            referencedRelation: "communication_messages"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      communication_messages: {
        Row: {
          author_person_id: string
          body: string
          created_at: string
          edited_at: string | null
          id: string
          organization_id: string
          pinned_at: string | null
          removed_at: string | null
          sequence_number: number
          status: string
          thread_id: string
          version: number
        }
        Insert: {
          author_person_id: string
          body: string
          created_at?: string
          edited_at?: string | null
          id?: string
          organization_id: string
          pinned_at?: string | null
          removed_at?: string | null
          sequence_number: number
          status?: string
          thread_id: string
          version?: number
        }
        Update: {
          author_person_id?: string
          body?: string
          created_at?: string
          edited_at?: string | null
          id?: string
          organization_id?: string
          pinned_at?: string | null
          removed_at?: string | null
          sequence_number?: number
          status?: string
          thread_id?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "communication_messages_author_person_id_fkey"
            columns: ["author_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communication_messages_organization_id_thread_id_fkey"
            columns: ["organization_id", "thread_id"]
            isOneToOne: false
            referencedRelation: "communication_threads"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      communication_read_state: {
        Row: {
          organization_id: string
          person_id: string
          read_at: string
          thread_id: string
          through_sequence: number
        }
        Insert: {
          organization_id: string
          person_id: string
          read_at?: string
          thread_id: string
          through_sequence?: number
        }
        Update: {
          organization_id?: string
          person_id?: string
          read_at?: string
          thread_id?: string
          through_sequence?: number
        }
        Relationships: [
          {
            foreignKeyName: "communication_read_state_organization_id_thread_id_fkey"
            columns: ["organization_id", "thread_id"]
            isOneToOne: false
            referencedRelation: "communication_threads"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "communication_read_state_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      communication_reports: {
        Row: {
          created_at: string
          detail: string | null
          id: string
          message_id: string
          moderation_reason: string | null
          moderator_person_id: string | null
          organization_id: string
          reason: string
          reporter_person_id: string
          reviewed_at: string | null
          status: string
        }
        Insert: {
          created_at?: string
          detail?: string | null
          id?: string
          message_id: string
          moderation_reason?: string | null
          moderator_person_id?: string | null
          organization_id: string
          reason: string
          reporter_person_id: string
          reviewed_at?: string | null
          status?: string
        }
        Update: {
          created_at?: string
          detail?: string | null
          id?: string
          message_id?: string
          moderation_reason?: string | null
          moderator_person_id?: string | null
          organization_id?: string
          reason?: string
          reporter_person_id?: string
          reviewed_at?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "communication_reports_moderator_person_id_fkey"
            columns: ["moderator_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communication_reports_organization_id_message_id_fkey"
            columns: ["organization_id", "message_id"]
            isOneToOne: false
            referencedRelation: "communication_messages"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "communication_reports_reporter_person_id_fkey"
            columns: ["reporter_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      communication_thread_members: {
        Row: {
          created_at: string
          ends_at: string | null
          organization_id: string
          person_id: string
          starts_at: string
          status: string
          thread_id: string
        }
        Insert: {
          created_at?: string
          ends_at?: string | null
          organization_id: string
          person_id: string
          starts_at?: string
          status?: string
          thread_id: string
        }
        Update: {
          created_at?: string
          ends_at?: string | null
          organization_id?: string
          person_id?: string
          starts_at?: string
          status?: string
          thread_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "communication_thread_members_organization_id_thread_id_fkey"
            columns: ["organization_id", "thread_id"]
            isOneToOne: false
            referencedRelation: "communication_threads"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "communication_thread_members_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      communication_threads: {
        Row: {
          created_at: string
          created_by_person_id: string
          household_id: string | null
          id: string
          kind: string
          next_sequence: number
          organization_id: string
          scope_id: string
          scope_type: string
          status: string
          team_id: string | null
          title: string
          unit_id: string | null
          updated_at: string
          version: number
          visibility: string
        }
        Insert: {
          created_at?: string
          created_by_person_id: string
          household_id?: string | null
          id?: string
          kind: string
          next_sequence?: number
          organization_id: string
          scope_id: string
          scope_type: string
          status?: string
          team_id?: string | null
          title: string
          unit_id?: string | null
          updated_at?: string
          version?: number
          visibility?: string
        }
        Update: {
          created_at?: string
          created_by_person_id?: string
          household_id?: string | null
          id?: string
          kind?: string
          next_sequence?: number
          organization_id?: string
          scope_id?: string
          scope_type?: string
          status?: string
          team_id?: string | null
          title?: string
          unit_id?: string | null
          updated_at?: string
          version?: number
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "communication_threads_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communication_threads_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communication_threads_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "communication_threads_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "communication_threads_organization_id_unit_id_fkey"
            columns: ["organization_id", "unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
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
      event_attendance_settings: {
        Row: {
          audience: string[]
          change_policy: string
          deadline_offset_minutes: number | null
          deadline_policy: string
          event_id: string
          organization_id: string
          response_deadline_at: string | null
          updated_at: string
          updated_by_person_id: string
          version: number
        }
        Insert: {
          audience?: string[]
          change_policy?: string
          deadline_offset_minutes?: number | null
          deadline_policy?: string
          event_id: string
          organization_id: string
          response_deadline_at?: string | null
          updated_at?: string
          updated_by_person_id: string
          version?: number
        }
        Update: {
          audience?: string[]
          change_policy?: string
          deadline_offset_minutes?: number | null
          deadline_policy?: string
          event_id?: string
          organization_id?: string
          response_deadline_at?: string | null
          updated_at?: string
          updated_by_person_id?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "event_attendance_settings_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "event_attendance_settings_updated_by_person_id_fkey"
            columns: ["updated_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
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
      game_finalizations: {
        Row: {
          actor_person_id: string
          created_at: string
          epoch: number
          game_id: string
          id: string
          operation_sequence: number
          opponent_score: number
          organization_id: string
          primary_score: number
          roster_hash: string
          roster_revision: number
          tied: boolean
          winner_side: string | null
        }
        Insert: {
          actor_person_id: string
          created_at?: string
          epoch: number
          game_id: string
          id?: string
          operation_sequence: number
          opponent_score: number
          organization_id: string
          primary_score: number
          roster_hash: string
          roster_revision: number
          tied: boolean
          winner_side?: string | null
        }
        Update: {
          actor_person_id?: string
          created_at?: string
          epoch?: number
          game_id?: string
          id?: string
          operation_sequence?: number
          opponent_score?: number
          organization_id?: string
          primary_score?: number
          roster_hash?: string
          roster_revision?: number
          tied?: boolean
          winner_side?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "game_finalizations_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_finalizations_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      game_operations: {
        Row: {
          actor_person_id: string
          audit_event_id: string
          correction_of: string | null
          created_at: string
          game_id: string
          id: string
          logical_game_time: Json | null
          next_state: Json
          operation: string
          organization_id: string
          prior_state: Json
          request_id: string | null
          sequence: number
          version: number
        }
        Insert: {
          actor_person_id: string
          audit_event_id: string
          correction_of?: string | null
          created_at?: string
          game_id: string
          id?: string
          logical_game_time?: Json | null
          next_state: Json
          operation: string
          organization_id: string
          prior_state: Json
          request_id?: string | null
          sequence: number
          version: number
        }
        Update: {
          actor_person_id?: string
          audit_event_id?: string
          correction_of?: string | null
          created_at?: string
          game_id?: string
          id?: string
          logical_game_time?: Json | null
          next_state?: Json
          operation?: string
          organization_id?: string
          prior_state?: Json
          request_id?: string | null
          sequence?: number
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "game_operations_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_operations_audit_event_id_fkey"
            columns: ["audit_event_id"]
            isOneToOne: false
            referencedRelation: "audit_events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_operations_organization_id_game_id_correction_of_fkey"
            columns: ["organization_id", "game_id", "correction_of"]
            isOneToOne: false
            referencedRelation: "game_operations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_operations_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      game_operator_assignments: {
        Row: {
          assigned_by_person_id: string
          created_at: string
          ends_at: string
          function_key: string
          game_id: string
          id: string
          organization_id: string
          person_id: string
          role_assignment_id: string
          starts_at: string
          status: string
          team_id: string
          updated_at: string
        }
        Insert: {
          assigned_by_person_id: string
          created_at?: string
          ends_at: string
          function_key: string
          game_id: string
          id?: string
          organization_id: string
          person_id: string
          role_assignment_id: string
          starts_at?: string
          status?: string
          team_id: string
          updated_at?: string
        }
        Update: {
          assigned_by_person_id?: string
          created_at?: string
          ends_at?: string
          function_key?: string
          game_id?: string
          id?: string
          organization_id?: string
          person_id?: string
          role_assignment_id?: string
          starts_at?: string
          status?: string
          team_id?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_operator_assignments_assigned_by_person_id_fkey"
            columns: ["assigned_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_operator_assignments_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_operator_assignments_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_operator_assignments_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_operator_assignments_role_assignment_id_fkey"
            columns: ["role_assignment_id"]
            isOneToOne: false
            referencedRelation: "role_assignments"
            referencedColumns: ["id"]
          },
        ]
      }
      game_roster_snapshots: {
        Row: {
          active: boolean
          availability: string
          captain: boolean
          captured_by_person_id: string
          checkin_state: string | null
          created_at: string
          display_name: string
          game_id: string
          id: string
          jersey_number: string | null
          organization_id: string
          participant_id: string
          person_id: string
          position_label: string | null
          revision: number
          starter: boolean
          team_id: string
        }
        Insert: {
          active?: boolean
          availability: string
          captain?: boolean
          captured_by_person_id: string
          checkin_state?: string | null
          created_at?: string
          display_name: string
          game_id: string
          id?: string
          jersey_number?: string | null
          organization_id: string
          participant_id: string
          person_id: string
          position_label?: string | null
          revision: number
          starter?: boolean
          team_id: string
        }
        Update: {
          active?: boolean
          availability?: string
          captain?: boolean
          captured_by_person_id?: string
          checkin_state?: string | null
          created_at?: string
          display_name?: string
          game_id?: string
          id?: string
          jersey_number?: string | null
          organization_id?: string
          participant_id?: string
          person_id?: string
          position_label?: string | null
          revision?: number
          starter?: boolean
          team_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_roster_snapshots_captured_by_person_id_fkey"
            columns: ["captured_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_roster_snapshots_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_roster_snapshots_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_roster_snapshots_participant_id_person_id_fkey"
            columns: ["participant_id", "person_id"]
            isOneToOne: false
            referencedRelation: "participants"
            referencedColumns: ["id", "person_id"]
          },
          {
            foreignKeyName: "game_roster_snapshots_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      game_sports: {
        Row: {
          key: string
          name: string
          status: string
        }
        Insert: {
          key: string
          name: string
          status?: string
        }
        Update: {
          key?: string
          name?: string
          status?: string
        }
        Relationships: []
      }
      games: {
        Row: {
          competition_type: string
          created_at: string
          created_by_person_id: string
          event_id: string
          external_opponent_name: string | null
          final_opponent_score: number | null
          final_primary_score: number | null
          finalization_count: number
          finalized_at: string | null
          finalized_by_person_id: string | null
          home_away: string
          id: string
          last_sequence: number
          occurrence_key: string
          occurrence_mode: string
          opponent_score: number
          opponent_team_id: string | null
          organization_id: string
          parent_unit_id: string | null
          primary_score: number
          primary_team_id: string
          publication_state: string
          reopened_at: string | null
          roster_revision: number
          schedule_status: string
          scheduled_end_at: string
          scheduled_start_at: string
          season_id: string | null
          sport_key: string
          started_at: string | null
          status: string
          tied: boolean | null
          updated_at: string
          updated_by_person_id: string
          venue_id: string | null
          version: number
          visibility: string
          winner_side: string | null
        }
        Insert: {
          competition_type?: string
          created_at?: string
          created_by_person_id: string
          event_id: string
          external_opponent_name?: string | null
          final_opponent_score?: number | null
          final_primary_score?: number | null
          finalization_count?: number
          finalized_at?: string | null
          finalized_by_person_id?: string | null
          home_away: string
          id?: string
          last_sequence?: number
          occurrence_key: string
          occurrence_mode: string
          opponent_score?: number
          opponent_team_id?: string | null
          organization_id: string
          parent_unit_id?: string | null
          primary_score?: number
          primary_team_id: string
          publication_state?: string
          reopened_at?: string | null
          roster_revision?: number
          schedule_status: string
          scheduled_end_at: string
          scheduled_start_at: string
          season_id?: string | null
          sport_key: string
          started_at?: string | null
          status?: string
          tied?: boolean | null
          updated_at?: string
          updated_by_person_id: string
          venue_id?: string | null
          version?: number
          visibility: string
          winner_side?: string | null
        }
        Update: {
          competition_type?: string
          created_at?: string
          created_by_person_id?: string
          event_id?: string
          external_opponent_name?: string | null
          final_opponent_score?: number | null
          final_primary_score?: number | null
          finalization_count?: number
          finalized_at?: string | null
          finalized_by_person_id?: string | null
          home_away?: string
          id?: string
          last_sequence?: number
          occurrence_key?: string
          occurrence_mode?: string
          opponent_score?: number
          opponent_team_id?: string | null
          organization_id?: string
          parent_unit_id?: string | null
          primary_score?: number
          primary_team_id?: string
          publication_state?: string
          reopened_at?: string | null
          roster_revision?: number
          schedule_status?: string
          scheduled_end_at?: string
          scheduled_start_at?: string
          season_id?: string | null
          sport_key?: string
          started_at?: string | null
          status?: string
          tied?: boolean | null
          updated_at?: string
          updated_by_person_id?: string
          venue_id?: string | null
          version?: number
          visibility?: string
          winner_side?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "games_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "games_finalized_by_person_id_fkey"
            columns: ["finalized_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "games_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "games_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "games_organization_id_opponent_team_id_fkey"
            columns: ["organization_id", "opponent_team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "games_organization_id_parent_unit_id_fkey"
            columns: ["organization_id", "parent_unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "games_organization_id_primary_team_id_fkey"
            columns: ["organization_id", "primary_team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "games_organization_id_season_id_fkey"
            columns: ["organization_id", "season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "games_organization_id_venue_id_fkey"
            columns: ["organization_id", "venue_id"]
            isOneToOne: false
            referencedRelation: "venues"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "games_sport_key_fkey"
            columns: ["sport_key"]
            isOneToOne: false
            referencedRelation: "game_sports"
            referencedColumns: ["key"]
          },
          {
            foreignKeyName: "games_updated_by_person_id_fkey"
            columns: ["updated_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      guardian_relationships: {
        Row: {
          authority_status: string
          can_manage_payments: boolean
          can_manage_profile: boolean
          can_receive_communications: boolean
          can_register: boolean
          can_respond_attendance: boolean
          can_send_communications: boolean
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
          can_receive_communications?: boolean
          can_register?: boolean
          can_respond_attendance?: boolean
          can_send_communications?: boolean
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
          can_receive_communications?: boolean
          can_register?: boolean
          can_respond_attendance?: boolean
          can_send_communications?: boolean
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
      notification_deliveries: {
        Row: {
          attempts: number
          channel: string
          claim_generation: number
          created_at: string
          delivered_at: string | null
          failure_category: string | null
          id: string
          next_attempt_at: string
          notification_id: string
          organization_id: string
          processing_until: string | null
          provider_message_reference: string | null
          sent_at: string | null
          status: string
          updated_at: string
        }
        Insert: {
          attempts?: number
          channel: string
          claim_generation?: number
          created_at?: string
          delivered_at?: string | null
          failure_category?: string | null
          id?: string
          next_attempt_at?: string
          notification_id: string
          organization_id: string
          processing_until?: string | null
          provider_message_reference?: string | null
          sent_at?: string | null
          status?: string
          updated_at?: string
        }
        Update: {
          attempts?: number
          channel?: string
          claim_generation?: number
          created_at?: string
          delivered_at?: string | null
          failure_category?: string | null
          id?: string
          next_attempt_at?: string
          notification_id?: string
          organization_id?: string
          processing_until?: string | null
          provider_message_reference?: string | null
          sent_at?: string | null
          status?: string
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_deliveries_organization_id_notification_id_fkey"
            columns: ["organization_id", "notification_id"]
            isOneToOne: false
            referencedRelation: "notifications"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      notification_events: {
        Row: {
          created_at: string
          event_type: string
          id: string
          occurred_at: string
          organization_id: string
          safe_data: Json
          scheduled_at: string
          source_id: string
          source_module: string
          source_revision: string
          source_type: string
          status: string
        }
        Insert: {
          created_at?: string
          event_type: string
          id?: string
          occurred_at?: string
          organization_id: string
          safe_data?: Json
          scheduled_at?: string
          source_id: string
          source_module: string
          source_revision: string
          source_type: string
          status?: string
        }
        Update: {
          created_at?: string
          event_type?: string
          id?: string
          occurred_at?: string
          organization_id?: string
          safe_data?: Json
          scheduled_at?: string
          source_id?: string
          source_module?: string
          source_revision?: string
          source_type?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_events_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      notification_preferences: {
        Row: {
          category: string
          channel: string
          created_at: string
          enabled: boolean
          id: string
          organization_id: string | null
          person_id: string
          team_id: string | null
          updated_at: string
        }
        Insert: {
          category: string
          channel: string
          created_at?: string
          enabled: boolean
          id?: string
          organization_id?: string | null
          person_id: string
          team_id?: string | null
          updated_at?: string
        }
        Update: {
          category?: string
          channel?: string
          created_at?: string
          enabled?: boolean
          id?: string
          organization_id?: string | null
          person_id?: string
          team_id?: string | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "notification_preferences_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "notification_preferences_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "notification_preferences_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      notifications: {
        Row: {
          contexts: Json
          created_at: string
          id: string
          notification_event_id: string
          organization_id: string
          read_at: string | null
          recipient_person_id: string
        }
        Insert: {
          contexts?: Json
          created_at?: string
          id?: string
          notification_event_id: string
          organization_id: string
          read_at?: string | null
          recipient_person_id: string
        }
        Update: {
          contexts?: Json
          created_at?: string
          id?: string
          notification_event_id?: string
          organization_id?: string
          read_at?: string | null
          recipient_person_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "notifications_organization_id_notification_event_id_fkey"
            columns: ["organization_id", "notification_event_id"]
            isOneToOne: false
            referencedRelation: "notification_events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "notifications_recipient_person_id_fkey"
            columns: ["recipient_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
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
          version: number
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
          version?: number
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
          version?: number
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
      volunteer_assignment_history: {
        Row: {
          action: string
          actor_person_id: string
          assignment_id: string
          assignment_version: number
          created_at: string
          id: string
          organization_id: string
          prior_status: string | null
          request_id: string
          status: string
        }
        Insert: {
          action: string
          actor_person_id: string
          assignment_id: string
          assignment_version: number
          created_at?: string
          id?: string
          organization_id: string
          prior_status?: string | null
          request_id: string
          status: string
        }
        Update: {
          action?: string
          actor_person_id?: string
          assignment_id?: string
          assignment_version?: number
          created_at?: string
          id?: string
          organization_id?: string
          prior_status?: string | null
          request_id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "volunteer_assignment_history_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "volunteer_assignment_history_organization_id_assignment_id_fkey"
            columns: ["organization_id", "assignment_id"]
            isOneToOne: false
            referencedRelation: "volunteer_assignments"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      volunteer_assignments: {
        Row: {
          assigned_by_person_id: string
          canceled_at: string | null
          canceled_by_person_id: string | null
          created_at: string
          id: string
          organization_id: string
          person_id: string
          shift_id: string
          source: string
          status: string
          updated_at: string
          version: number
        }
        Insert: {
          assigned_by_person_id: string
          canceled_at?: string | null
          canceled_by_person_id?: string | null
          created_at?: string
          id?: string
          organization_id: string
          person_id: string
          shift_id: string
          source: string
          status?: string
          updated_at?: string
          version?: number
        }
        Update: {
          assigned_by_person_id?: string
          canceled_at?: string | null
          canceled_by_person_id?: string | null
          created_at?: string
          id?: string
          organization_id?: string
          person_id?: string
          shift_id?: string
          source?: string
          status?: string
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "volunteer_assignments_assigned_by_person_id_fkey"
            columns: ["assigned_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "volunteer_assignments_canceled_by_person_id_fkey"
            columns: ["canceled_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "volunteer_assignments_organization_id_shift_id_fkey"
            columns: ["organization_id", "shift_id"]
            isOneToOne: false
            referencedRelation: "volunteer_shifts"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "volunteer_assignments_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      volunteer_role_definitions: {
        Row: {
          created_at: string
          created_by_person_id: string
          description: string | null
          id: string
          name: string
          organization_id: string
          status: string
          updated_at: string
          updated_by_person_id: string
          version: number
        }
        Insert: {
          created_at?: string
          created_by_person_id: string
          description?: string | null
          id?: string
          name: string
          organization_id: string
          status?: string
          updated_at?: string
          updated_by_person_id: string
          version?: number
        }
        Update: {
          created_at?: string
          created_by_person_id?: string
          description?: string | null
          id?: string
          name?: string
          organization_id?: string
          status?: string
          updated_at?: string
          updated_by_person_id?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "volunteer_role_definitions_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "volunteer_role_definitions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "volunteer_role_definitions_updated_by_person_id_fkey"
            columns: ["updated_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      volunteer_shifts: {
        Row: {
          capacity: number
          created_at: string
          created_by_person_id: string
          end_at: string
          event_context_stamp: string | null
          event_id: string | null
          id: string
          instructions: string | null
          location: string | null
          occurrence_key: string | null
          organization_id: string
          organization_unit_id: string | null
          reminder_minutes_before: number
          role_id: string
          scope_id: string
          scope_type: string
          signup_deadline: string | null
          start_at: string
          status: string
          team_id: string | null
          title: string
          updated_at: string
          updated_by_person_id: string
          version: number
          visibility: string
        }
        Insert: {
          capacity: number
          created_at?: string
          created_by_person_id: string
          end_at: string
          event_context_stamp?: string | null
          event_id?: string | null
          id?: string
          instructions?: string | null
          location?: string | null
          occurrence_key?: string | null
          organization_id: string
          organization_unit_id?: string | null
          reminder_minutes_before?: number
          role_id: string
          scope_id: string
          scope_type: string
          signup_deadline?: string | null
          start_at: string
          status?: string
          team_id?: string | null
          title: string
          updated_at?: string
          updated_by_person_id: string
          version?: number
          visibility?: string
        }
        Update: {
          capacity?: number
          created_at?: string
          created_by_person_id?: string
          end_at?: string
          event_context_stamp?: string | null
          event_id?: string | null
          id?: string
          instructions?: string | null
          location?: string | null
          occurrence_key?: string | null
          organization_id?: string
          organization_unit_id?: string | null
          reminder_minutes_before?: number
          role_id?: string
          scope_id?: string
          scope_type?: string
          signup_deadline?: string | null
          start_at?: string
          status?: string
          team_id?: string | null
          title?: string
          updated_at?: string
          updated_by_person_id?: string
          version?: number
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "volunteer_shifts_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "volunteer_shifts_organization_id_event_id_fkey"
            columns: ["organization_id", "event_id"]
            isOneToOne: false
            referencedRelation: "events"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "volunteer_shifts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "volunteer_shifts_organization_id_organization_unit_id_fkey"
            columns: ["organization_id", "organization_unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "volunteer_shifts_organization_id_role_id_fkey"
            columns: ["organization_id", "role_id"]
            isOneToOne: false
            referencedRelation: "volunteer_role_definitions"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "volunteer_shifts_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "volunteer_shifts_updated_by_person_id_fkey"
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
      boss_attendance_mutate: {
        Args: { p_command: Json; p_request_id: string }
        Returns: Json
      }
      boss_attendance_read: { Args: { p_query: Json }; Returns: Json }
      boss_calendar_mutate: {
        Args: { p_command: Json; p_request_id: string }
        Returns: Json
      }
      boss_calendar_preview: { Args: { p_command: Json }; Returns: Json }
      boss_calendar_public_read: { Args: { p_query: Json }; Returns: Json }
      boss_calendar_read: { Args: { p_query: Json }; Returns: Json }
      boss_communications_mutate: {
        Args: { p_command: Json; p_request_id: string }
        Returns: Json
      }
      boss_communications_read: { Args: { p_query?: Json }; Returns: Json }
      boss_games_mutate: {
        Args: { p_command: Json; p_request_id: string }
        Returns: Json
      }
      boss_games_read: { Args: { p_query?: Json }; Returns: Json }
      boss_notifications_mutate: {
        Args: { p_command: Json; p_request_id: string }
        Returns: Json
      }
      boss_notifications_read: { Args: { p_query?: Json }; Returns: Json }
      boss_registration_mutate: {
        Args: { p_command: Json; p_request_id: string }
        Returns: Json
      }
      boss_registration_read: { Args: { p_query?: Json }; Returns: Json }
      boss_volunteers_mutate: {
        Args: { p_command: Json; p_request_id: string }
        Returns: Json
      }
      boss_volunteers_read: { Args: { p_query?: Json }; Returns: Json }
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

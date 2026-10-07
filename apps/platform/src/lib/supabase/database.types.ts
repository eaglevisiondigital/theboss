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
      achievement_competition_closures: {
        Row: {
          actor_person_id: string
          champion_entry_id: string
          created_at: string
          generation: number
          id: string
          reason: string
          scope_id: string
          source_hash: string
        }
        Insert: {
          actor_person_id: string
          champion_entry_id: string
          created_at?: string
          generation: number
          id?: string
          reason: string
          scope_id: string
          source_hash: string
        }
        Update: {
          actor_person_id?: string
          champion_entry_id?: string
          created_at?: string
          generation?: number
          id?: string
          reason?: string
          scope_id?: string
          source_hash?: string
        }
        Relationships: [
          {
            foreignKeyName: "achievement_competition_closures_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_competition_closures_champion_entry_id_fkey"
            columns: ["champion_entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_competition_closures_scope_id_fkey"
            columns: ["scope_id"]
            isOneToOne: false
            referencedRelation: "ranking_scopes"
            referencedColumns: ["id"]
          },
        ]
      }
      achievement_definition_revisions: {
        Row: {
          actor_person_id: string
          approval_required: boolean
          athlete_championship_policy: string
          badge_icon: string
          bracket_id: string | null
          category: string
          created_at: string
          definition_id: string
          description: string
          effective_at: string
          historical_evaluation: boolean
          id: string
          metric_key: string | null
          name: string
          placement: number | null
          ranking_definition_id: string | null
          revision: number
          season_id: string | null
          showcase_eligible: boolean
          source_kind: string
          sport_key: string | null
          standings_scope_id: string | null
          subject_type: string
          team_id: string | null
          threshold: number | null
          tier: string | null
        }
        Insert: {
          actor_person_id: string
          approval_required?: boolean
          athlete_championship_policy?: string
          badge_icon?: string
          bracket_id?: string | null
          category: string
          created_at?: string
          definition_id: string
          description?: string
          effective_at?: string
          historical_evaluation?: boolean
          id?: string
          metric_key?: string | null
          name: string
          placement?: number | null
          ranking_definition_id?: string | null
          revision: number
          season_id?: string | null
          showcase_eligible?: boolean
          source_kind: string
          sport_key?: string | null
          standings_scope_id?: string | null
          subject_type: string
          team_id?: string | null
          threshold?: number | null
          tier?: string | null
        }
        Update: {
          actor_person_id?: string
          approval_required?: boolean
          athlete_championship_policy?: string
          badge_icon?: string
          bracket_id?: string | null
          category?: string
          created_at?: string
          definition_id?: string
          description?: string
          effective_at?: string
          historical_evaluation?: boolean
          id?: string
          metric_key?: string | null
          name?: string
          placement?: number | null
          ranking_definition_id?: string | null
          revision?: number
          season_id?: string | null
          showcase_eligible?: boolean
          source_kind?: string
          sport_key?: string | null
          standings_scope_id?: string | null
          subject_type?: string
          team_id?: string | null
          threshold?: number | null
          tier?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "achievement_definition_revisions_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_definition_revisions_bracket_id_fkey"
            columns: ["bracket_id"]
            isOneToOne: false
            referencedRelation: "tournament_brackets"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_definition_revisions_definition_id_fkey"
            columns: ["definition_id"]
            isOneToOne: false
            referencedRelation: "achievement_definitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_definition_revisions_ranking_definition_id_fkey"
            columns: ["ranking_definition_id"]
            isOneToOne: false
            referencedRelation: "ranking_definitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_definition_revisions_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_definition_revisions_sport_key_fkey"
            columns: ["sport_key"]
            isOneToOne: false
            referencedRelation: "game_sports"
            referencedColumns: ["key"]
          },
          {
            foreignKeyName: "achievement_definition_revisions_standings_scope_id_fkey"
            columns: ["standings_scope_id"]
            isOneToOne: false
            referencedRelation: "ranking_scopes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_definition_revisions_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
        ]
      }
      achievement_definitions: {
        Row: {
          created_at: string
          created_by_person_id: string
          current_revision_id: string | null
          definition_key: string
          id: string
          organization_id: string | null
          owner_kind: string
          status: string
          version: number
        }
        Insert: {
          created_at?: string
          created_by_person_id: string
          current_revision_id?: string | null
          definition_key: string
          id?: string
          organization_id?: string | null
          owner_kind: string
          status?: string
          version?: number
        }
        Update: {
          created_at?: string
          created_by_person_id?: string
          current_revision_id?: string | null
          definition_key?: string
          id?: string
          organization_id?: string | null
          owner_kind?: string
          status?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "achievement_definition_current_fk"
            columns: ["id", "current_revision_id"]
            isOneToOne: false
            referencedRelation: "achievement_definition_revisions"
            referencedColumns: ["definition_id", "id"]
          },
          {
            foreignKeyName: "achievement_definitions_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_definitions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      achievement_display_choices: {
        Row: {
          actor_person_id: string
          athlete_achievement_id: string
          profile_id: string
          show_on_profile: boolean
          show_on_showcase: boolean
          updated_at: string
        }
        Insert: {
          actor_person_id: string
          athlete_achievement_id: string
          profile_id: string
          show_on_profile?: boolean
          show_on_showcase?: boolean
          updated_at?: string
        }
        Update: {
          actor_person_id?: string
          athlete_achievement_id?: string
          profile_id?: string
          show_on_profile?: boolean
          show_on_showcase?: boolean
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "achievement_display_choices_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_display_choices_athlete_achievement_id_fkey"
            columns: ["athlete_achievement_id"]
            isOneToOne: true
            referencedRelation: "athlete_achievements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_display_choices_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "athlete_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      achievement_history: {
        Row: {
          actor_person_id: string | null
          created_at: string
          event_type: string
          id: string
          recognition_id: string
          source_generation: number
          source_id: string
          source_manifest: Json
          state: string
          version: number
        }
        Insert: {
          actor_person_id?: string | null
          created_at?: string
          event_type: string
          id?: string
          recognition_id: string
          source_generation: number
          source_id: string
          source_manifest: Json
          state: string
          version: number
        }
        Update: {
          actor_person_id?: string | null
          created_at?: string
          event_type?: string
          id?: string
          recognition_id?: string
          source_generation?: number
          source_id?: string
          source_manifest?: Json
          state?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "achievement_history_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_history_recognition_id_fkey"
            columns: ["recognition_id"]
            isOneToOne: false
            referencedRelation: "achievement_recognitions"
            referencedColumns: ["id"]
          },
        ]
      }
      achievement_recognitions: {
        Row: {
          achieved_at: string
          athlete_achievement_id: string | null
          co_holder: boolean
          context_key: string
          current_holder: boolean
          definition_revision_id: string
          entity_achievement_id: string | null
          id: string
          organization_id: string
          person_id: string | null
          profile_id: string | null
          recognized_at: string
          season_id: string | null
          source_generation: number
          source_hash: string
          source_id: string
          source_manifest: Json
          source_type: string
          sport_key: string | null
          state: string
          subject_key: string
          team_id: string | null
          version: number
        }
        Insert: {
          achieved_at: string
          athlete_achievement_id?: string | null
          co_holder?: boolean
          context_key: string
          current_holder?: boolean
          definition_revision_id: string
          entity_achievement_id?: string | null
          id?: string
          organization_id: string
          person_id?: string | null
          profile_id?: string | null
          recognized_at?: string
          season_id?: string | null
          source_generation: number
          source_hash: string
          source_id: string
          source_manifest: Json
          source_type: string
          sport_key?: string | null
          state: string
          subject_key: string
          team_id?: string | null
          version?: number
        }
        Update: {
          achieved_at?: string
          athlete_achievement_id?: string | null
          co_holder?: boolean
          context_key?: string
          current_holder?: boolean
          definition_revision_id?: string
          entity_achievement_id?: string | null
          id?: string
          organization_id?: string
          person_id?: string | null
          profile_id?: string | null
          recognized_at?: string
          season_id?: string | null
          source_generation?: number
          source_hash?: string
          source_id?: string
          source_manifest?: Json
          source_type?: string
          sport_key?: string | null
          state?: string
          subject_key?: string
          team_id?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "achievement_recognitions_athlete_achievement_id_fkey"
            columns: ["athlete_achievement_id"]
            isOneToOne: true
            referencedRelation: "athlete_achievements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_recognitions_definition_revision_id_fkey"
            columns: ["definition_revision_id"]
            isOneToOne: false
            referencedRelation: "achievement_definition_revisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_recognitions_entity_achievement_id_fkey"
            columns: ["entity_achievement_id"]
            isOneToOne: true
            referencedRelation: "entity_achievements"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_recognitions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_recognitions_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "achievement_recognitions_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_recognitions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "athlete_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_recognitions_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_recognitions_sport_key_fkey"
            columns: ["sport_key"]
            isOneToOne: false
            referencedRelation: "game_sports"
            referencedColumns: ["key"]
          },
        ]
      }
      achievement_refresh_work: {
        Row: {
          cursor: string | null
          definition_revision_id: string
          organization_id: string
          published_generation: number
          state: string
          target_generation: number
          updated_at: string
        }
        Insert: {
          cursor?: string | null
          definition_revision_id: string
          organization_id: string
          published_generation?: number
          state?: string
          target_generation?: number
          updated_at?: string
        }
        Update: {
          cursor?: string | null
          definition_revision_id?: string
          organization_id?: string
          published_generation?: number
          state?: string
          target_generation?: number
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "achievement_refresh_work_definition_revision_id_fkey"
            columns: ["definition_revision_id"]
            isOneToOne: false
            referencedRelation: "achievement_definition_revisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "achievement_refresh_work_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      athlete_achievements: {
        Row: {
          achieved_on: string | null
          achievement_type: string
          actor_person_id: string
          created_at: string
          definition_revision_id: string | null
          id: string
          organization_id: string | null
          profile_id: string
          season_id: string | null
          source_ranking_candidate_id: string | null
          source_record_event_id: string | null
          sport_key: string | null
          title: string
          verification_level: string
          visibility: string
        }
        Insert: {
          achieved_on?: string | null
          achievement_type: string
          actor_person_id: string
          created_at?: string
          definition_revision_id?: string | null
          id?: string
          organization_id?: string | null
          profile_id: string
          season_id?: string | null
          source_ranking_candidate_id?: string | null
          source_record_event_id?: string | null
          sport_key?: string | null
          title: string
          verification_level: string
          visibility?: string
        }
        Update: {
          achieved_on?: string | null
          achievement_type?: string
          actor_person_id?: string
          created_at?: string
          definition_revision_id?: string | null
          id?: string
          organization_id?: string | null
          profile_id?: string
          season_id?: string | null
          source_ranking_candidate_id?: string | null
          source_record_event_id?: string | null
          sport_key?: string | null
          title?: string
          verification_level?: string
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "athlete_achievements_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_achievements_definition_revision_id_fkey"
            columns: ["definition_revision_id"]
            isOneToOne: false
            referencedRelation: "achievement_definition_revisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_achievements_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_achievements_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "athlete_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_achievements_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_achievements_source_ranking_candidate_id_fkey"
            columns: ["source_ranking_candidate_id"]
            isOneToOne: false
            referencedRelation: "ranking_candidates"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_achievements_source_record_event_id_fkey"
            columns: ["source_record_event_id"]
            isOneToOne: false
            referencedRelation: "record_events"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_achievements_sport_key_fkey"
            columns: ["sport_key"]
            isOneToOne: false
            referencedRelation: "game_sports"
            referencedColumns: ["key"]
          },
        ]
      }
      athlete_measurables: {
        Row: {
          actor_person_id: string
          created_at: string
          id: string
          measured_on: string
          metric_key: string
          organization_id: string | null
          profile_id: string
          provenance: string
          source_label: string | null
          sport_key: string
          team_id: string | null
          unit: string
          value: number
          verification_state: string
          visibility: string
        }
        Insert: {
          actor_person_id: string
          created_at?: string
          id?: string
          measured_on: string
          metric_key: string
          organization_id?: string | null
          profile_id: string
          provenance: string
          source_label?: string | null
          sport_key: string
          team_id?: string | null
          unit: string
          value: number
          verification_state: string
          visibility?: string
        }
        Update: {
          actor_person_id?: string
          created_at?: string
          id?: string
          measured_on?: string
          metric_key?: string
          organization_id?: string | null
          profile_id?: string
          provenance?: string
          source_label?: string | null
          sport_key?: string
          team_id?: string | null
          unit?: string
          value?: number
          verification_state?: string
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "athlete_measurables_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_measurables_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_measurables_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "athlete_measurables_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "athlete_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_measurables_sport_key_fkey"
            columns: ["sport_key"]
            isOneToOne: false
            referencedRelation: "game_sports"
            referencedColumns: ["key"]
          },
        ]
      }
      athlete_media_links: {
        Row: {
          actor_person_id: string
          created_at: string
          id: string
          media_type: string
          profile_id: string
          rights_state: string
          source: string
          sport_key: string | null
          title: string
          url: string
          visibility: string
        }
        Insert: {
          actor_person_id: string
          created_at?: string
          id?: string
          media_type: string
          profile_id: string
          rights_state: string
          source: string
          sport_key?: string | null
          title: string
          url: string
          visibility?: string
        }
        Update: {
          actor_person_id?: string
          created_at?: string
          id?: string
          media_type?: string
          profile_id?: string
          rights_state?: string
          source?: string
          sport_key?: string | null
          title?: string
          url?: string
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "athlete_media_links_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_media_links_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "athlete_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_media_links_sport_key_fkey"
            columns: ["sport_key"]
            isOneToOne: false
            referencedRelation: "game_sports"
            referencedColumns: ["key"]
          },
        ]
      }
      athlete_profile_revisions: {
        Row: {
          actor_person_id: string
          created_at: string
          entered_by: string
          id: string
          profile_id: string
          revision: number
          safe_fields: Json
        }
        Insert: {
          actor_person_id: string
          created_at?: string
          entered_by: string
          id?: string
          profile_id: string
          revision: number
          safe_fields?: Json
        }
        Update: {
          actor_person_id?: string
          created_at?: string
          entered_by?: string
          id?: string
          profile_id?: string
          revision?: number
          safe_fields?: Json
        }
        Relationships: [
          {
            foreignKeyName: "athlete_profile_revisions_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_profile_revisions_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "athlete_profiles"
            referencedColumns: ["id"]
          },
        ]
      }
      athlete_profile_verifications: {
        Row: {
          actor_person_id: string
          created_at: string
          field_digest: string
          field_key: string
          id: string
          organization_id: string
          profile_id: string
          profile_revision_id: string
          team_id: string | null
          verification_state: string
        }
        Insert: {
          actor_person_id: string
          created_at?: string
          field_digest: string
          field_key: string
          id?: string
          organization_id: string
          profile_id: string
          profile_revision_id: string
          team_id?: string | null
          verification_state: string
        }
        Update: {
          actor_person_id?: string
          created_at?: string
          field_digest?: string
          field_key?: string
          id?: string
          organization_id?: string
          profile_id?: string
          profile_revision_id?: string
          team_id?: string | null
          verification_state?: string
        }
        Relationships: [
          {
            foreignKeyName: "athlete_profile_verifications_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_profile_verifications_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_profile_verifications_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "athlete_profile_verifications_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "athlete_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_profile_verifications_profile_id_profile_revision__fkey"
            columns: ["profile_id", "profile_revision_id"]
            isOneToOne: false
            referencedRelation: "athlete_profile_revisions"
            referencedColumns: ["profile_id", "id"]
          },
        ]
      }
      athlete_profiles: {
        Row: {
          created_at: string
          created_by_person_id: string
          current_revision_id: string | null
          id: string
          participant_id: string
          person_id: string
          status: string
          updated_at: string
          version: number
          visibility: string
        }
        Insert: {
          created_at?: string
          created_by_person_id: string
          current_revision_id?: string | null
          id?: string
          participant_id: string
          person_id: string
          status?: string
          updated_at?: string
          version?: number
          visibility?: string
        }
        Update: {
          created_at?: string
          created_by_person_id?: string
          current_revision_id?: string | null
          id?: string
          participant_id?: string
          person_id?: string
          status?: string
          updated_at?: string
          version?: number
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "athlete_profiles_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "athlete_profiles_current_revision_fk"
            columns: ["id", "current_revision_id"]
            isOneToOne: false
            referencedRelation: "athlete_profile_revisions"
            referencedColumns: ["profile_id", "id"]
          },
          {
            foreignKeyName: "athlete_profiles_participant_id_person_id_fkey"
            columns: ["participant_id", "person_id"]
            isOneToOne: false
            referencedRelation: "participants"
            referencedColumns: ["id", "person_id"]
          },
        ]
      }
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
      award_decisions: {
        Row: {
          actor_person_id: string
          created_at: string
          decision: string
          id: string
          nomination_id: string
          private_note: string
          version: number
        }
        Insert: {
          actor_person_id: string
          created_at?: string
          decision: string
          id?: string
          nomination_id: string
          private_note: string
          version: number
        }
        Update: {
          actor_person_id?: string
          created_at?: string
          decision?: string
          id?: string
          nomination_id?: string
          private_note?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "award_decisions_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "award_decisions_nomination_id_fkey"
            columns: ["nomination_id"]
            isOneToOne: false
            referencedRelation: "award_nominations"
            referencedColumns: ["id"]
          },
        ]
      }
      award_nominations: {
        Row: {
          achieved_at: string
          created_at: string
          definition_revision_id: string
          id: string
          nominated_by_person_id: string
          organization_id: string
          profile_id: string | null
          recognition_id: string | null
          season_id: string | null
          state: string
          subject_key: string
          subject_type: string
          team_id: string | null
          version: number
        }
        Insert: {
          achieved_at: string
          created_at?: string
          definition_revision_id: string
          id?: string
          nominated_by_person_id: string
          organization_id: string
          profile_id?: string | null
          recognition_id?: string | null
          season_id?: string | null
          state?: string
          subject_key: string
          subject_type: string
          team_id?: string | null
          version?: number
        }
        Update: {
          achieved_at?: string
          created_at?: string
          definition_revision_id?: string
          id?: string
          nominated_by_person_id?: string
          organization_id?: string
          profile_id?: string | null
          recognition_id?: string | null
          season_id?: string | null
          state?: string
          subject_key?: string
          subject_type?: string
          team_id?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "award_nominations_definition_revision_id_fkey"
            columns: ["definition_revision_id"]
            isOneToOne: false
            referencedRelation: "achievement_definition_revisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "award_nominations_nominated_by_person_id_fkey"
            columns: ["nominated_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "award_nominations_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "award_nominations_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "award_nominations_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: false
            referencedRelation: "athlete_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "award_nominations_recognition_id_fkey"
            columns: ["recognition_id"]
            isOneToOne: false
            referencedRelation: "achievement_recognitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "award_nominations_season_id_fkey"
            columns: ["season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["id"]
          },
        ]
      }
      boss_bucks_access: {
        Row: {
          access_kind: string
          created_at: string
          ends_at: string | null
          guardian_relationship_id: string
          id: string
          organization_id: string
          person_id: string
          starts_at: string
          status: string
          wallet_id: string
        }
        Insert: {
          access_kind: string
          created_at?: string
          ends_at?: string | null
          guardian_relationship_id: string
          id?: string
          organization_id: string
          person_id: string
          starts_at?: string
          status?: string
          wallet_id: string
        }
        Update: {
          access_kind?: string
          created_at?: string
          ends_at?: string | null
          guardian_relationship_id?: string
          id?: string
          organization_id?: string
          person_id?: string
          starts_at?: string
          status?: string
          wallet_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "boss_bucks_access_guardian_relationship_id_fkey"
            columns: ["guardian_relationship_id"]
            isOneToOne: false
            referencedRelation: "guardian_relationships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_access_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_access_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_access_wallet_id_fkey"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "boss_bucks_wallets"
            referencedColumns: ["id"]
          },
        ]
      }
      boss_bucks_accounts: {
        Row: {
          created_at: string
          currency: string
          household_id: string | null
          id: string
          kind: string
          organization_id: string
          wallet_id: string | null
        }
        Insert: {
          created_at?: string
          currency: string
          household_id?: string | null
          id?: string
          kind: string
          organization_id: string
          wallet_id?: string | null
        }
        Update: {
          created_at?: string
          currency?: string
          household_id?: string | null
          id?: string
          kind?: string
          organization_id?: string
          wallet_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "boss_bucks_accounts_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_accounts_wallet_id_household_id_currency_fkey"
            columns: ["wallet_id", "household_id", "currency"]
            isOneToOne: false
            referencedRelation: "boss_bucks_wallets"
            referencedColumns: ["id", "household_id", "currency"]
          },
        ]
      }
      boss_bucks_fundraiser_bindings: {
        Row: {
          authorized_by: string
          created_at: string
          fundraiser_id: string
          guardian_relationship_id: string
          household_id: string
        }
        Insert: {
          authorized_by: string
          created_at?: string
          fundraiser_id: string
          guardian_relationship_id: string
          household_id: string
        }
        Update: {
          authorized_by?: string
          created_at?: string
          fundraiser_id?: string
          guardian_relationship_id?: string
          household_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "boss_bucks_fundraiser_bindings_authorized_by_fkey"
            columns: ["authorized_by"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_fundraiser_bindings_fundraiser_id_fkey"
            columns: ["fundraiser_id"]
            isOneToOne: true
            referencedRelation: "fundraising_fundraisers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_fundraiser_bindings_guardian_relationship_id_fkey"
            columns: ["guardian_relationship_id"]
            isOneToOne: false
            referencedRelation: "guardian_relationships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_fundraiser_bindings_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
        ]
      }
      boss_bucks_grants: {
        Row: {
          account_id: string
          amount_minor: number
          available_at: string
          campaign_id: string
          created_at: string
          currency: string
          evidence_id: string
          expires_at: string | null
          fundraiser_id: string
          household_id: string
          id: string
          intent_id: string
          organization_id: string
          participant_id: string
          person_id: string
          policy_revision_id: string
          provenance: Json
          team_id: string | null
          unit_id: string | null
          wallet_id: string
        }
        Insert: {
          account_id: string
          amount_minor: number
          available_at: string
          campaign_id: string
          created_at?: string
          currency: string
          evidence_id: string
          expires_at?: string | null
          fundraiser_id: string
          household_id: string
          id?: string
          intent_id: string
          organization_id: string
          participant_id: string
          person_id: string
          policy_revision_id: string
          provenance: Json
          team_id?: string | null
          unit_id?: string | null
          wallet_id: string
        }
        Update: {
          account_id?: string
          amount_minor?: number
          available_at?: string
          campaign_id?: string
          created_at?: string
          currency?: string
          evidence_id?: string
          expires_at?: string | null
          fundraiser_id?: string
          household_id?: string
          id?: string
          intent_id?: string
          organization_id?: string
          participant_id?: string
          person_id?: string
          policy_revision_id?: string
          provenance?: Json
          team_id?: string | null
          unit_id?: string | null
          wallet_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "boss_bucks_grants_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "boss_bucks_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_grants_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "fundraising_campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_grants_evidence_id_fkey"
            columns: ["evidence_id"]
            isOneToOne: true
            referencedRelation: "fundraising_success_evidence"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_grants_fundraiser_id_fkey"
            columns: ["fundraiser_id"]
            isOneToOne: false
            referencedRelation: "fundraising_fundraisers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_grants_intent_id_fkey"
            columns: ["intent_id"]
            isOneToOne: false
            referencedRelation: "boss_bucks_source_snapshots"
            referencedColumns: ["intent_id"]
          },
          {
            foreignKeyName: "boss_bucks_grants_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_grants_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "boss_bucks_grants_organization_id_unit_id_fkey"
            columns: ["organization_id", "unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "boss_bucks_grants_participant_id_person_id_fkey"
            columns: ["participant_id", "person_id"]
            isOneToOne: false
            referencedRelation: "participants"
            referencedColumns: ["id", "person_id"]
          },
          {
            foreignKeyName: "boss_bucks_grants_policy_revision_id_fkey"
            columns: ["policy_revision_id"]
            isOneToOne: false
            referencedRelation: "boss_bucks_policy_revisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_grants_wallet_id_household_id_currency_fkey"
            columns: ["wallet_id", "household_id", "currency"]
            isOneToOne: false
            referencedRelation: "boss_bucks_wallets"
            referencedColumns: ["id", "household_id", "currency"]
          },
        ]
      }
      boss_bucks_history: {
        Row: {
          action: string
          actor_person_id: string | null
          created_at: string
          details: Json
          grant_id: string | null
          id: string
          organization_id: string | null
          request_id: string | null
          wallet_id: string | null
        }
        Insert: {
          action: string
          actor_person_id?: string | null
          created_at?: string
          details?: Json
          grant_id?: string | null
          id?: string
          organization_id?: string | null
          request_id?: string | null
          wallet_id?: string | null
        }
        Update: {
          action?: string
          actor_person_id?: string | null
          created_at?: string
          details?: Json
          grant_id?: string | null
          id?: string
          organization_id?: string | null
          request_id?: string | null
          wallet_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "boss_bucks_history_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_history_grant_id_fkey"
            columns: ["grant_id"]
            isOneToOne: false
            referencedRelation: "boss_bucks_grants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_history_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_history_wallet_id_fkey"
            columns: ["wallet_id"]
            isOneToOne: false
            referencedRelation: "boss_bucks_wallets"
            referencedColumns: ["id"]
          },
        ]
      }
      boss_bucks_journals: {
        Row: {
          created_at: string
          currency: string
          grant_id: string
          id: string
          kind: string
          original_journal_id: string | null
          reason: string
        }
        Insert: {
          created_at?: string
          currency: string
          grant_id: string
          id?: string
          kind: string
          original_journal_id?: string | null
          reason: string
        }
        Update: {
          created_at?: string
          currency?: string
          grant_id?: string
          id?: string
          kind?: string
          original_journal_id?: string | null
          reason?: string
        }
        Relationships: [
          {
            foreignKeyName: "boss_bucks_journals_grant_id_fkey"
            columns: ["grant_id"]
            isOneToOne: false
            referencedRelation: "boss_bucks_grants"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_journals_original_journal_id_fkey"
            columns: ["original_journal_id"]
            isOneToOne: false
            referencedRelation: "boss_bucks_journals"
            referencedColumns: ["id"]
          },
        ]
      }
      boss_bucks_owner_resolutions: {
        Row: {
          authorized_by: string
          created_at: string
          guardian_relationship_id: string
          household_id: string
          intent_id: string
        }
        Insert: {
          authorized_by: string
          created_at?: string
          guardian_relationship_id: string
          household_id: string
          intent_id: string
        }
        Update: {
          authorized_by?: string
          created_at?: string
          guardian_relationship_id?: string
          household_id?: string
          intent_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "boss_bucks_owner_resolutions_authorized_by_fkey"
            columns: ["authorized_by"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_owner_resolutions_guardian_relationship_id_fkey"
            columns: ["guardian_relationship_id"]
            isOneToOne: false
            referencedRelation: "guardian_relationships"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_owner_resolutions_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_owner_resolutions_intent_id_fkey"
            columns: ["intent_id"]
            isOneToOne: true
            referencedRelation: "boss_bucks_source_snapshots"
            referencedColumns: ["intent_id"]
          },
        ]
      }
      boss_bucks_policy_revisions: {
        Row: {
          availability_seconds: number
          basis_points: number
          campaign_id: string
          channels: string[]
          created_at: string
          created_by: string
          currency: string
          expiry_seconds: number | null
          id: string
          mode: string
          organization_id: string
          request_id: string
          revision: number
        }
        Insert: {
          availability_seconds?: number
          basis_points: number
          campaign_id: string
          channels: string[]
          created_at?: string
          created_by: string
          currency: string
          expiry_seconds?: number | null
          id?: string
          mode: string
          organization_id: string
          request_id: string
          revision: number
        }
        Update: {
          availability_seconds?: number
          basis_points?: number
          campaign_id?: string
          channels?: string[]
          created_at?: string
          created_by?: string
          currency?: string
          expiry_seconds?: number | null
          id?: string
          mode?: string
          organization_id?: string
          request_id?: string
          revision?: number
        }
        Relationships: [
          {
            foreignKeyName: "boss_bucks_policy_revisions_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "fundraising_campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_policy_revisions_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_policy_revisions_organization_id_campaign_id_fkey"
            columns: ["organization_id", "campaign_id"]
            isOneToOne: false
            referencedRelation: "fundraising_campaigns"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "boss_bucks_policy_revisions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      boss_bucks_postings: {
        Row: {
          account_id: string
          amount_minor: number
          created_at: string
          currency: string
          id: string
          journal_id: string
        }
        Insert: {
          account_id: string
          amount_minor: number
          created_at?: string
          currency: string
          id?: string
          journal_id: string
        }
        Update: {
          account_id?: string
          amount_minor?: number
          created_at?: string
          currency?: string
          id?: string
          journal_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "boss_bucks_postings_account_id_fkey"
            columns: ["account_id"]
            isOneToOne: false
            referencedRelation: "boss_bucks_accounts"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_postings_journal_id_fkey"
            columns: ["journal_id"]
            isOneToOne: false
            referencedRelation: "boss_bucks_journals"
            referencedColumns: ["id"]
          },
        ]
      }
      boss_bucks_source_snapshots: {
        Row: {
          created_at: string
          household_id: string | null
          intent_id: string
          organization_id: string
          policy_revision_id: string | null
        }
        Insert: {
          created_at?: string
          household_id?: string | null
          intent_id: string
          organization_id: string
          policy_revision_id?: string | null
        }
        Update: {
          created_at?: string
          household_id?: string | null
          intent_id?: string
          organization_id?: string
          policy_revision_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "boss_bucks_source_snapshots_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_source_snapshots_intent_id_fkey"
            columns: ["intent_id"]
            isOneToOne: true
            referencedRelation: "fundraising_intents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_source_snapshots_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "boss_bucks_source_snapshots_policy_revision_id_fkey"
            columns: ["policy_revision_id"]
            isOneToOne: false
            referencedRelation: "boss_bucks_policy_revisions"
            referencedColumns: ["id"]
          },
        ]
      }
      boss_bucks_wallets: {
        Row: {
          created_at: string
          currency: string
          household_id: string
          id: string
          status: string
        }
        Insert: {
          created_at?: string
          currency: string
          household_id: string
          id?: string
          status?: string
        }
        Update: {
          created_at?: string
          currency?: string
          household_id?: string
          id?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "boss_bucks_wallets_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
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
      competition_access_assignments: {
        Row: {
          competition_id: string
          created_at: string
          edition_id: string | null
          ends_at: string | null
          granted_by_person_id: string
          id: string
          person_id: string
          role_id: string
          starts_at: string
          status: string
        }
        Insert: {
          competition_id: string
          created_at?: string
          edition_id?: string | null
          ends_at?: string | null
          granted_by_person_id: string
          id?: string
          person_id: string
          role_id: string
          starts_at?: string
          status?: string
        }
        Update: {
          competition_id?: string
          created_at?: string
          edition_id?: string | null
          ends_at?: string | null
          granted_by_person_id?: string
          id?: string
          person_id?: string
          role_id?: string
          starts_at?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "competition_access_assignments_competition_id_edition_id_fkey"
            columns: ["competition_id", "edition_id"]
            isOneToOne: false
            referencedRelation: "competition_editions"
            referencedColumns: ["competition_id", "id"]
          },
          {
            foreignKeyName: "competition_access_assignments_competition_id_fkey"
            columns: ["competition_id"]
            isOneToOne: false
            referencedRelation: "competitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_access_assignments_granted_by_person_id_fkey"
            columns: ["granted_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_access_assignments_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_access_assignments_role_id_fkey"
            columns: ["role_id"]
            isOneToOne: false
            referencedRelation: "roles"
            referencedColumns: ["id"]
          },
        ]
      }
      competition_editions: {
        Row: {
          athlete_cross_organization: boolean
          competition_id: string
          created_at: string
          cross_organization: boolean
          ends_at: string | null
          generation: number
          id: string
          name: string
          organization_id: string
          publication_state: string
          season_id: string | null
          sport_key: string
          standings_policy_id: string | null
          starts_at: string | null
          status: string
          team_result_audience: string
          version: number
        }
        Insert: {
          athlete_cross_organization?: boolean
          competition_id: string
          created_at?: string
          cross_organization?: boolean
          ends_at?: string | null
          generation?: number
          id?: string
          name: string
          organization_id: string
          publication_state?: string
          season_id?: string | null
          sport_key: string
          standings_policy_id?: string | null
          starts_at?: string | null
          status?: string
          team_result_audience?: string
          version?: number
        }
        Update: {
          athlete_cross_organization?: boolean
          competition_id?: string
          created_at?: string
          cross_organization?: boolean
          ends_at?: string | null
          generation?: number
          id?: string
          name?: string
          organization_id?: string
          publication_state?: string
          season_id?: string | null
          sport_key?: string
          standings_policy_id?: string | null
          starts_at?: string | null
          status?: string
          team_result_audience?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "competition_editions_organization_id_competition_id_fkey"
            columns: ["organization_id", "competition_id"]
            isOneToOne: false
            referencedRelation: "competitions"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "competition_editions_organization_id_season_id_fkey"
            columns: ["organization_id", "season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "competition_editions_sport_key_fkey"
            columns: ["sport_key"]
            isOneToOne: false
            referencedRelation: "game_sports"
            referencedColumns: ["key"]
          },
          {
            foreignKeyName: "edition_policy_fk"
            columns: ["id", "standings_policy_id"]
            isOneToOne: false
            referencedRelation: "standings_policy_revisions"
            referencedColumns: ["edition_id", "id"]
          },
        ]
      }
      competition_entries: {
        Row: {
          approved_by_person_id: string | null
          created_at: string
          edition_id: string
          ended_at: string | null
          entered_at: string
          id: string
          season_id: string | null
          status: string
          team_id: string
          team_organization_id: string
          version: number
        }
        Insert: {
          approved_by_person_id?: string | null
          created_at?: string
          edition_id: string
          ended_at?: string | null
          entered_at?: string
          id?: string
          season_id?: string | null
          status?: string
          team_id: string
          team_organization_id: string
          version?: number
        }
        Update: {
          approved_by_person_id?: string | null
          created_at?: string
          edition_id?: string
          ended_at?: string | null
          entered_at?: string
          id?: string
          season_id?: string | null
          status?: string
          team_id?: string
          team_organization_id?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "competition_entries_approved_by_person_id_fkey"
            columns: ["approved_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_entries_edition_id_fkey"
            columns: ["edition_id"]
            isOneToOne: false
            referencedRelation: "competition_editions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_entries_team_organization_id_season_id_fkey"
            columns: ["team_organization_id", "season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "competition_entries_team_organization_id_team_id_fkey"
            columns: ["team_organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      competition_entry_groups: {
        Row: {
          edition_id: string
          ends_at: string | null
          entry_id: string
          group_id: string
          id: string
          starts_at: string
          status: string
        }
        Insert: {
          edition_id: string
          ends_at?: string | null
          entry_id: string
          group_id: string
          id?: string
          starts_at?: string
          status?: string
        }
        Update: {
          edition_id?: string
          ends_at?: string | null
          entry_id?: string
          group_id?: string
          id?: string
          starts_at?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "competition_entry_groups_edition_id_entry_id_fkey"
            columns: ["edition_id", "entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "competition_entry_groups_edition_id_group_id_fkey"
            columns: ["edition_id", "group_id"]
            isOneToOne: false
            referencedRelation: "competition_groups"
            referencedColumns: ["edition_id", "id"]
          },
        ]
      }
      competition_game_assignment_groups: {
        Row: {
          assignment_id: string
          edition_id: string
          group_id: string
        }
        Insert: {
          assignment_id: string
          edition_id: string
          group_id: string
        }
        Update: {
          assignment_id?: string
          edition_id?: string
          group_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "competition_game_assignment_group_edition_id_assignment_id_fkey"
            columns: ["edition_id", "assignment_id"]
            isOneToOne: false
            referencedRelation: "competition_game_assignments"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "competition_game_assignment_groups_edition_id_group_id_fkey"
            columns: ["edition_id", "group_id"]
            isOneToOne: false
            referencedRelation: "competition_groups"
            referencedColumns: ["edition_id", "id"]
          },
        ]
      }
      competition_game_assignments: {
        Row: {
          actor_person_id: string
          counts_for_standings: boolean
          created_at: string
          edition_id: string
          game_id: string
          game_type: string
          group_id: string | null
          id: string
          opponent_entry_id: string
          primary_entry_id: string
          reason: string
          source_consent_by_person_id: string
          source_organization_id: string
          status: string
          version: number
        }
        Insert: {
          actor_person_id: string
          counts_for_standings: boolean
          created_at?: string
          edition_id: string
          game_id: string
          game_type: string
          group_id?: string | null
          id?: string
          opponent_entry_id: string
          primary_entry_id: string
          reason: string
          source_consent_by_person_id: string
          source_organization_id: string
          status?: string
          version: number
        }
        Update: {
          actor_person_id?: string
          counts_for_standings?: boolean
          created_at?: string
          edition_id?: string
          game_id?: string
          game_type?: string
          group_id?: string | null
          id?: string
          opponent_entry_id?: string
          primary_entry_id?: string
          reason?: string
          source_consent_by_person_id?: string
          source_organization_id?: string
          status?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "competition_game_assignments_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_game_assignments_edition_id_fkey"
            columns: ["edition_id"]
            isOneToOne: false
            referencedRelation: "competition_editions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_game_assignments_edition_id_group_id_fkey"
            columns: ["edition_id", "group_id"]
            isOneToOne: false
            referencedRelation: "competition_groups"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "competition_game_assignments_edition_id_opponent_entry_id_fkey"
            columns: ["edition_id", "opponent_entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "competition_game_assignments_edition_id_primary_entry_id_fkey"
            columns: ["edition_id", "primary_entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "competition_game_assignments_source_consent_by_person_id_fkey"
            columns: ["source_consent_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_game_assignments_source_organization_id_game_i_fkey"
            columns: ["source_organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      competition_groups: {
        Row: {
          created_at: string
          edition_id: string
          id: string
          kind: string
          name: string
          organization_id: string
          organization_unit_id: string | null
          status: string
        }
        Insert: {
          created_at?: string
          edition_id: string
          id?: string
          kind: string
          name: string
          organization_id: string
          organization_unit_id?: string | null
          status?: string
        }
        Update: {
          created_at?: string
          edition_id?: string
          id?: string
          kind?: string
          name?: string
          organization_id?: string
          organization_unit_id?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "competition_groups_edition_id_fkey"
            columns: ["edition_id"]
            isOneToOne: false
            referencedRelation: "competition_editions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_groups_organization_id_edition_id_fkey"
            columns: ["organization_id", "edition_id"]
            isOneToOne: false
            referencedRelation: "competition_editions"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "competition_groups_organization_id_organization_unit_id_fkey"
            columns: ["organization_id", "organization_unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      competition_rulings: {
        Row: {
          actor_person_id: string
          amount: number | null
          assignment_id: string | null
          created_at: string
          edition_id: string
          effective_at: string
          group_id: string | null
          id: string
          kind: string
          opponent_entry_id: string | null
          outcome: string | null
          primary_entry_id: string
          reason: string
          reversal_of_id: string | null
          standings_opponent_score: number | null
          standings_primary_score: number | null
        }
        Insert: {
          actor_person_id: string
          amount?: number | null
          assignment_id?: string | null
          created_at?: string
          edition_id: string
          effective_at?: string
          group_id?: string | null
          id?: string
          kind: string
          opponent_entry_id?: string | null
          outcome?: string | null
          primary_entry_id: string
          reason: string
          reversal_of_id?: string | null
          standings_opponent_score?: number | null
          standings_primary_score?: number | null
        }
        Update: {
          actor_person_id?: string
          amount?: number | null
          assignment_id?: string | null
          created_at?: string
          edition_id?: string
          effective_at?: string
          group_id?: string | null
          id?: string
          kind?: string
          opponent_entry_id?: string | null
          outcome?: string | null
          primary_entry_id?: string
          reason?: string
          reversal_of_id?: string | null
          standings_opponent_score?: number | null
          standings_primary_score?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "competition_rulings_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_rulings_edition_id_assignment_id_fkey"
            columns: ["edition_id", "assignment_id"]
            isOneToOne: false
            referencedRelation: "competition_game_assignments"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "competition_rulings_edition_id_fkey"
            columns: ["edition_id"]
            isOneToOne: false
            referencedRelation: "competition_editions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competition_rulings_edition_id_group_id_fkey"
            columns: ["edition_id", "group_id"]
            isOneToOne: false
            referencedRelation: "competition_groups"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "competition_rulings_edition_id_opponent_entry_id_fkey"
            columns: ["edition_id", "opponent_entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "competition_rulings_edition_id_primary_entry_id_fkey"
            columns: ["edition_id", "primary_entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "competition_rulings_edition_id_reversal_of_id_fkey"
            columns: ["edition_id", "reversal_of_id"]
            isOneToOne: false
            referencedRelation: "competition_rulings"
            referencedColumns: ["edition_id", "id"]
          },
        ]
      }
      competitions: {
        Row: {
          created_at: string
          created_by_person_id: string
          id: string
          name: string
          organization_id: string
          parent_unit_id: string | null
          status: string
          version: number
        }
        Insert: {
          created_at?: string
          created_by_person_id: string
          id?: string
          name: string
          organization_id: string
          parent_unit_id?: string | null
          status?: string
          version?: number
        }
        Update: {
          created_at?: string
          created_by_person_id?: string
          id?: string
          name?: string
          organization_id?: string
          parent_unit_id?: string | null
          status?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "competitions_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competitions_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "competitions_organization_id_parent_unit_id_fkey"
            columns: ["organization_id", "parent_unit_id"]
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
      entity_achievements: {
        Row: {
          achieved_at: string
          actor_person_id: string
          definition_revision_id: string
          id: string
          organization_id: string
          recognized_at: string
          subject_type: string
          team_id: string | null
          title: string
          verification_level: string
        }
        Insert: {
          achieved_at: string
          actor_person_id: string
          definition_revision_id: string
          id?: string
          organization_id: string
          recognized_at?: string
          subject_type: string
          team_id?: string | null
          title: string
          verification_level: string
        }
        Update: {
          achieved_at?: string
          actor_person_id?: string
          definition_revision_id?: string
          id?: string
          organization_id?: string
          recognized_at?: string
          subject_type?: string
          team_id?: string | null
          title?: string
          verification_level?: string
        }
        Relationships: [
          {
            foreignKeyName: "entity_achievements_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "entity_achievements_definition_revision_id_fkey"
            columns: ["definition_revision_id"]
            isOneToOne: false
            referencedRelation: "achievement_definition_revisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "entity_achievements_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "entity_achievements_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
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
      fundraising_campaigns: {
        Row: {
          allow_adult_self_sharing: boolean
          allow_anonymous: boolean
          allow_fee_cover: boolean
          allow_recurring: boolean
          allow_team_sharing: boolean
          branding: Json
          channels: string[]
          created_at: string
          created_by: string
          currency: string
          description: string
          ends_at: string
          goal_minor: number
          id: string
          indexable: boolean
          launch_at: string | null
          leaderboard_visibility: string
          name: string
          organization_id: string
          public_path: string
          public_visible: boolean
          reward_policy: Json
          scope: string
          starts_at: string
          status: string
          updated_at: string
          version: number
        }
        Insert: {
          allow_adult_self_sharing?: boolean
          allow_anonymous?: boolean
          allow_fee_cover?: boolean
          allow_recurring?: boolean
          allow_team_sharing?: boolean
          branding?: Json
          channels?: string[]
          created_at?: string
          created_by: string
          currency: string
          description?: string
          ends_at: string
          goal_minor: number
          id?: string
          indexable?: boolean
          launch_at?: string | null
          leaderboard_visibility?: string
          name: string
          organization_id: string
          public_path?: string
          public_visible?: boolean
          reward_policy?: Json
          scope: string
          starts_at: string
          status?: string
          updated_at?: string
          version?: number
        }
        Update: {
          allow_adult_self_sharing?: boolean
          allow_anonymous?: boolean
          allow_fee_cover?: boolean
          allow_recurring?: boolean
          allow_team_sharing?: boolean
          branding?: Json
          channels?: string[]
          created_at?: string
          created_by?: string
          currency?: string
          description?: string
          ends_at?: string
          goal_minor?: number
          id?: string
          indexable?: boolean
          launch_at?: string | null
          leaderboard_visibility?: string
          name?: string
          organization_id?: string
          public_path?: string
          public_visible?: boolean
          reward_policy?: Json
          scope?: string
          starts_at?: string
          status?: string
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "fundraising_campaigns_created_by_fkey"
            columns: ["created_by"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_campaigns_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
        ]
      }
      fundraising_donors: {
        Row: {
          created_at: string
          display_name: string
          email: string | null
          id: string
          mobile: string | null
        }
        Insert: {
          created_at?: string
          display_name: string
          email?: string | null
          id?: string
          mobile?: string | null
        }
        Update: {
          created_at?: string
          display_name?: string
          email?: string | null
          id?: string
          mobile?: string | null
        }
        Relationships: []
      }
      fundraising_fundraisers: {
        Row: {
          campaign_id: string
          created_at: string
          ends_at: string | null
          goal_minor: number | null
          household_id: string | null
          id: string
          leaderboard_opt_in: boolean
          organization_id: string
          participant_id: string
          person_id: string
          public_display_name: string | null
          starts_at: string
          status: string
          team_id: string | null
          unit_id: string | null
          version: number
        }
        Insert: {
          campaign_id: string
          created_at?: string
          ends_at?: string | null
          goal_minor?: number | null
          household_id?: string | null
          id?: string
          leaderboard_opt_in?: boolean
          organization_id: string
          participant_id: string
          person_id: string
          public_display_name?: string | null
          starts_at?: string
          status?: string
          team_id?: string | null
          unit_id?: string | null
          version?: number
        }
        Update: {
          campaign_id?: string
          created_at?: string
          ends_at?: string | null
          goal_minor?: number | null
          household_id?: string | null
          id?: string
          leaderboard_opt_in?: boolean
          organization_id?: string
          participant_id?: string
          person_id?: string
          public_display_name?: string | null
          starts_at?: string
          status?: string
          team_id?: string | null
          unit_id?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "fundraising_fundraisers_household_id_fkey"
            columns: ["household_id"]
            isOneToOne: false
            referencedRelation: "households"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_fundraisers_organization_id_campaign_id_fkey"
            columns: ["organization_id", "campaign_id"]
            isOneToOne: false
            referencedRelation: "fundraising_campaigns"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "fundraising_fundraisers_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "fundraising_fundraisers_organization_id_unit_id_fkey"
            columns: ["organization_id", "unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "fundraising_fundraisers_participant_id_person_id_fkey"
            columns: ["participant_id", "person_id"]
            isOneToOne: false
            referencedRelation: "participants"
            referencedColumns: ["id", "person_id"]
          },
        ]
      }
      fundraising_history: {
        Row: {
          action: string
          actor_person_id: string | null
          campaign_id: string
          created_at: string
          details: Json
          fundraiser_id: string | null
          id: string
          request_id: string | null
        }
        Insert: {
          action: string
          actor_person_id?: string | null
          campaign_id: string
          created_at?: string
          details?: Json
          fundraiser_id?: string | null
          id?: string
          request_id?: string | null
        }
        Update: {
          action?: string
          actor_person_id?: string | null
          campaign_id?: string
          created_at?: string
          details?: Json
          fundraiser_id?: string | null
          id?: string
          request_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fundraising_history_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_history_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "fundraising_campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_history_fundraiser_id_fkey"
            columns: ["fundraiser_id"]
            isOneToOne: false
            referencedRelation: "fundraising_fundraisers"
            referencedColumns: ["id"]
          },
        ]
      }
      fundraising_intent_events: {
        Row: {
          amount_minor: number | null
          created_at: string
          id: string
          intent_id: string
          source_event_id: string | null
          source_reference: string | null
          state: string
        }
        Insert: {
          amount_minor?: number | null
          created_at?: string
          id?: string
          intent_id: string
          source_event_id?: string | null
          source_reference?: string | null
          state: string
        }
        Update: {
          amount_minor?: number | null
          created_at?: string
          id?: string
          intent_id?: string
          source_event_id?: string | null
          source_reference?: string | null
          state?: string
        }
        Relationships: [
          {
            foreignKeyName: "fundraising_intent_events_intent_id_fkey"
            columns: ["intent_id"]
            isOneToOne: false
            referencedRelation: "fundraising_intents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_intent_events_source_event_id_fkey"
            columns: ["source_event_id"]
            isOneToOne: false
            referencedRelation: "fundraising_intent_events"
            referencedColumns: ["id"]
          },
        ]
      }
      fundraising_intents: {
        Row: {
          amount_minor: number
          anonymous: boolean
          board_id: string | null
          campaign_id: string
          capability_digest: string
          created_at: string
          currency: string
          donor_id: string
          expires_at: string
          fee_cover: boolean
          fundraiser_id: string | null
          id: string
          provenance: Json
          request_id: string
          reservation_id: string | null
          reward_policy: Json
          share_id: string | null
          source_kind: string
          tile_id: string | null
        }
        Insert: {
          amount_minor: number
          anonymous: boolean
          board_id?: string | null
          campaign_id: string
          capability_digest: string
          created_at?: string
          currency: string
          donor_id: string
          expires_at: string
          fee_cover: boolean
          fundraiser_id?: string | null
          id?: string
          provenance: Json
          request_id: string
          reservation_id?: string | null
          reward_policy: Json
          share_id?: string | null
          source_kind: string
          tile_id?: string | null
        }
        Update: {
          amount_minor?: number
          anonymous?: boolean
          board_id?: string | null
          campaign_id?: string
          capability_digest?: string
          created_at?: string
          currency?: string
          donor_id?: string
          expires_at?: string
          fee_cover?: boolean
          fundraiser_id?: string | null
          id?: string
          provenance?: Json
          request_id?: string
          reservation_id?: string | null
          reward_policy?: Json
          share_id?: string | null
          source_kind?: string
          tile_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fundraising_intents_board_id_fkey"
            columns: ["board_id"]
            isOneToOne: false
            referencedRelation: "money_boards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_intents_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "fundraising_campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_intents_donor_id_fkey"
            columns: ["donor_id"]
            isOneToOne: false
            referencedRelation: "fundraising_donors"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_intents_fundraiser_id_fkey"
            columns: ["fundraiser_id"]
            isOneToOne: false
            referencedRelation: "fundraising_fundraisers"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_intents_reservation_id_fkey"
            columns: ["reservation_id"]
            isOneToOne: false
            referencedRelation: "money_board_reservations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_intents_share_id_fkey"
            columns: ["share_id"]
            isOneToOne: false
            referencedRelation: "fundraising_shares"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_intents_tile_id_fkey"
            columns: ["tile_id"]
            isOneToOne: false
            referencedRelation: "money_board_tiles"
            referencedColumns: ["id"]
          },
        ]
      }
      fundraising_recurring_commitments: {
        Row: {
          amount_minor: number
          created_at: string
          id: string
          intent_id: string
          months: number
          starts_on: string
          status: string
        }
        Insert: {
          amount_minor: number
          created_at?: string
          id?: string
          intent_id: string
          months: number
          starts_on: string
          status?: string
        }
        Update: {
          amount_minor?: number
          created_at?: string
          id?: string
          intent_id?: string
          months?: number
          starts_on?: string
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "fundraising_recurring_commitments_intent_id_fkey"
            columns: ["intent_id"]
            isOneToOne: true
            referencedRelation: "fundraising_intents"
            referencedColumns: ["id"]
          },
        ]
      }
      fundraising_recurring_occurrences: {
        Row: {
          amount_minor: number
          commitment_id: string
          due_on: string
          ordinal: number
        }
        Insert: {
          amount_minor: number
          commitment_id: string
          due_on: string
          ordinal: number
        }
        Update: {
          amount_minor?: number
          commitment_id?: string
          due_on?: string
          ordinal?: number
        }
        Relationships: [
          {
            foreignKeyName: "fundraising_recurring_occurrences_commitment_id_fkey"
            columns: ["commitment_id"]
            isOneToOne: false
            referencedRelation: "fundraising_recurring_commitments"
            referencedColumns: ["id"]
          },
        ]
      }
      fundraising_reward_qualifications: {
        Row: {
          created_at: string
          evidence_id: string
          id: string
          policy: Json
          provenance: Json
          qualified: boolean
          status: string
          trial_days: number | null
        }
        Insert: {
          created_at?: string
          evidence_id: string
          id?: string
          policy: Json
          provenance: Json
          qualified: boolean
          status: string
          trial_days?: number | null
        }
        Update: {
          created_at?: string
          evidence_id?: string
          id?: string
          policy?: Json
          provenance?: Json
          qualified?: boolean
          status?: string
          trial_days?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "fundraising_reward_qualifications_evidence_id_fkey"
            columns: ["evidence_id"]
            isOneToOne: true
            referencedRelation: "fundraising_success_evidence"
            referencedColumns: ["id"]
          },
        ]
      }
      fundraising_shares: {
        Row: {
          authorized_by: string
          created_at: string
          fundraiser_id: string
          id: string
          path: string
          revoked_at: string | null
          status: string
        }
        Insert: {
          authorized_by: string
          created_at?: string
          fundraiser_id: string
          id?: string
          path?: string
          revoked_at?: string | null
          status?: string
        }
        Update: {
          authorized_by?: string
          created_at?: string
          fundraiser_id?: string
          id?: string
          path?: string
          revoked_at?: string | null
          status?: string
        }
        Relationships: [
          {
            foreignKeyName: "fundraising_shares_authorized_by_fkey"
            columns: ["authorized_by"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_shares_fundraiser_id_fkey"
            columns: ["fundraiser_id"]
            isOneToOne: false
            referencedRelation: "fundraising_fundraisers"
            referencedColumns: ["id"]
          },
        ]
      }
      fundraising_success_evidence: {
        Row: {
          amount_minor: number
          created_at: string
          currency: string
          id: string
          intent_id: string
          provenance: Json
          settled_at: string
          source_reference: string
          source_system: string
          tile_id: string | null
        }
        Insert: {
          amount_minor: number
          created_at?: string
          currency: string
          id?: string
          intent_id: string
          provenance: Json
          settled_at: string
          source_reference: string
          source_system: string
          tile_id?: string | null
        }
        Update: {
          amount_minor?: number
          created_at?: string
          currency?: string
          id?: string
          intent_id?: string
          provenance?: Json
          settled_at?: string
          source_reference?: string
          source_system?: string
          tile_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fundraising_success_evidence_intent_id_fkey"
            columns: ["intent_id"]
            isOneToOne: true
            referencedRelation: "fundraising_intents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_success_evidence_tile_id_fkey"
            columns: ["tile_id"]
            isOneToOne: true
            referencedRelation: "money_board_tiles"
            referencedColumns: ["id"]
          },
        ]
      }
      fundraising_targets: {
        Row: {
          campaign_id: string
          goal_minor: number | null
          id: string
          organization_id: string
          team_id: string | null
          unit_id: string | null
        }
        Insert: {
          campaign_id: string
          goal_minor?: number | null
          id?: string
          organization_id: string
          team_id?: string | null
          unit_id?: string | null
        }
        Update: {
          campaign_id?: string
          goal_minor?: number | null
          id?: string
          organization_id?: string
          team_id?: string | null
          unit_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fundraising_targets_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "fundraising_campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "fundraising_targets_organization_id_campaign_id_fkey"
            columns: ["organization_id", "campaign_id"]
            isOneToOne: false
            referencedRelation: "fundraising_campaigns"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "fundraising_targets_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "fundraising_targets_organization_id_unit_id_fkey"
            columns: ["organization_id", "unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      game_basketball_events: {
        Row: {
          actor_person_id: string
          clock_ms: number
          correction_of: string | null
          created_at: string
          event_type: string
          game_id: string
          id: string
          operation_id: string
          organization_id: string
          period_number: number
          points: number
          reason: string | null
          request_id: string
          roster_id: string | null
          scoring_event_id: string | null
          secondary_roster_id: string | null
          sequence: number
          side: string | null
        }
        Insert: {
          actor_person_id: string
          clock_ms: number
          correction_of?: string | null
          created_at?: string
          event_type: string
          game_id: string
          id?: string
          operation_id: string
          organization_id: string
          period_number: number
          points: number
          reason?: string | null
          request_id: string
          roster_id?: string | null
          scoring_event_id?: string | null
          secondary_roster_id?: string | null
          sequence: number
          side?: string | null
        }
        Update: {
          actor_person_id?: string
          clock_ms?: number
          correction_of?: string | null
          created_at?: string
          event_type?: string
          game_id?: string
          id?: string
          operation_id?: string
          organization_id?: string
          period_number?: number
          points?: number
          reason?: string | null
          request_id?: string
          roster_id?: string | null
          scoring_event_id?: string | null
          secondary_roster_id?: string | null
          sequence?: number
          side?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "game_basketball_events_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_basketball_events_organization_id_game_id_correction__fkey"
            columns: ["organization_id", "game_id", "correction_of"]
            isOneToOne: false
            referencedRelation: "game_basketball_events"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_basketball_events_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_basketball_events_organization_id_game_id_operation_i_fkey"
            columns: ["organization_id", "game_id", "operation_id"]
            isOneToOne: false
            referencedRelation: "game_operations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_basketball_events_organization_id_game_id_roster_id_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_basketball_events_organization_id_game_id_scoring_eve_fkey"
            columns: ["organization_id", "game_id", "scoring_event_id"]
            isOneToOne: false
            referencedRelation: "game_basketball_events"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_basketball_events_organization_id_game_id_secondary_r_fkey"
            columns: ["organization_id", "game_id", "secondary_roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_basketball_final_stats: {
        Row: {
          assists: number
          blocks: number
          defensive_rebounds: number
          fga: number
          fgm: number
          finalization_id: string
          fta: number
          ftm: number
          game_id: string
          id: string
          offensive_rebounds: number
          organization_id: string
          personal_fouls: number
          points: number
          rebounds: number
          roster_id: string | null
          side: string
          steals: number
          tpa: number
          tpm: number
          turnovers: number
        }
        Insert: {
          assists: number
          blocks: number
          defensive_rebounds: number
          fga: number
          fgm: number
          finalization_id: string
          fta: number
          ftm: number
          game_id: string
          id?: string
          offensive_rebounds: number
          organization_id: string
          personal_fouls: number
          points: number
          rebounds: number
          roster_id?: string | null
          side: string
          steals: number
          tpa: number
          tpm: number
          turnovers: number
        }
        Update: {
          assists?: number
          blocks?: number
          defensive_rebounds?: number
          fga?: number
          fgm?: number
          finalization_id?: string
          fta?: number
          ftm?: number
          game_id?: string
          id?: string
          offensive_rebounds?: number
          organization_id?: string
          personal_fouls?: number
          points?: number
          rebounds?: number
          roster_id?: string | null
          side?: string
          steals?: number
          tpa?: number
          tpm?: number
          turnovers?: number
        }
        Relationships: [
          {
            foreignKeyName: "game_basketball_final_stats_organization_id_game_id_finali_fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_basketball_finalizations"
            referencedColumns: ["organization_id", "game_id", "finalization_id"]
          },
          {
            foreignKeyName: "game_basketball_final_stats_organization_id_game_id_roster_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_basketball_finalizations: {
        Row: {
          engine_version: string
          epoch: number
          event_sequence: number
          finalization_id: string
          game_id: string
          organization_id: string
          period_number: number
          roster_revision: number
          state: Json
        }
        Insert: {
          engine_version: string
          epoch: number
          event_sequence: number
          finalization_id: string
          game_id: string
          organization_id: string
          period_number: number
          roster_revision: number
          state: Json
        }
        Update: {
          engine_version?: string
          epoch?: number
          event_sequence?: number
          finalization_id?: string
          game_id?: string
          organization_id?: string
          period_number?: number
          roster_revision?: number
          state?: Json
        }
        Relationships: [
          {
            foreignKeyName: "game_basketball_finalizations_organization_id_game_id_fina_fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_finalizations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_basketball_lineup_history: {
        Row: {
          event_id: string
          game_id: string
          organization_id: string
          roster_id: string
          side: string
          slot: number
        }
        Insert: {
          event_id: string
          game_id: string
          organization_id: string
          roster_id: string
          side: string
          slot: number
        }
        Update: {
          event_id?: string
          game_id?: string
          organization_id?: string
          roster_id?: string
          side?: string
          slot?: number
        }
        Relationships: [
          {
            foreignKeyName: "game_basketball_lineup_histor_organization_id_game_id_even_fkey"
            columns: ["organization_id", "game_id", "event_id"]
            isOneToOne: false
            referencedRelation: "game_basketball_events"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_basketball_lineup_histor_organization_id_game_id_rost_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_basketball_lineup_history_event_id_fkey"
            columns: ["event_id"]
            isOneToOne: false
            referencedRelation: "game_basketball_events"
            referencedColumns: ["id"]
          },
        ]
      }
      game_basketball_lineups: {
        Row: {
          game_id: string
          organization_id: string
          roster_id: string
          side: string
          slot: number
        }
        Insert: {
          game_id: string
          organization_id: string
          roster_id: string
          side: string
          slot: number
        }
        Update: {
          game_id?: string
          organization_id?: string
          roster_id?: string
          side?: string
          slot?: number
        }
        Relationships: [
          {
            foreignKeyName: "game_basketball_lineups_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_basketball_lineups_organization_id_game_id_roster_id_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_basketball_states: {
        Row: {
          clock_anchor: string | null
          clock_remaining_ms: number
          clock_running: boolean
          enforce_lineup: boolean
          engine_version: string
          game_id: string
          lineup_size: number
          organization_id: string
          overtime_seconds: number
          period_number: number
          period_seconds: number
          period_status: string
          regulation_periods: number
          roster_revision: number
        }
        Insert: {
          clock_anchor?: string | null
          clock_remaining_ms?: number
          clock_running?: boolean
          enforce_lineup: boolean
          engine_version?: string
          game_id: string
          lineup_size: number
          organization_id: string
          overtime_seconds: number
          period_number?: number
          period_seconds: number
          period_status?: string
          regulation_periods: number
          roster_revision: number
        }
        Update: {
          clock_anchor?: string | null
          clock_remaining_ms?: number
          clock_running?: boolean
          enforce_lineup?: boolean
          engine_version?: string
          game_id?: string
          lineup_size?: number
          organization_id?: string
          overtime_seconds?: number
          period_number?: number
          period_seconds?: number
          period_status?: string
          regulation_periods?: number
          roster_revision?: number
        }
        Relationships: [
          {
            foreignKeyName: "game_basketball_states_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      game_diamond_events: {
        Row: {
          actor_person_id: string
          correction_of: string | null
          created_at: string
          event_type: string
          game_id: string
          id: string
          operation_id: string
          organization_id: string
          origin_sequence: number
          payload: Json
          reason: string | null
          request_id: string
          sequence: number
        }
        Insert: {
          actor_person_id: string
          correction_of?: string | null
          created_at?: string
          event_type: string
          game_id: string
          id?: string
          operation_id: string
          organization_id: string
          origin_sequence: number
          payload: Json
          reason?: string | null
          request_id: string
          sequence: number
        }
        Update: {
          actor_person_id?: string
          correction_of?: string | null
          created_at?: string
          event_type?: string
          game_id?: string
          id?: string
          operation_id?: string
          organization_id?: string
          origin_sequence?: number
          payload?: Json
          reason?: string | null
          request_id?: string
          sequence?: number
        }
        Relationships: [
          {
            foreignKeyName: "game_diamond_events_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_diamond_events_organization_id_game_id_correction_of_fkey"
            columns: ["organization_id", "game_id", "correction_of"]
            isOneToOne: false
            referencedRelation: "game_diamond_events"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_diamond_events_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_diamond_events_organization_id_game_id_operation_id_fkey"
            columns: ["organization_id", "game_id", "operation_id"]
            isOneToOne: false
            referencedRelation: "game_operations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_diamond_final_stats: {
        Row: {
          finalization_id: string
          game_id: string
          id: string
          organization_id: string
          roster_id: string | null
          side: string
          stats: Json
        }
        Insert: {
          finalization_id: string
          game_id: string
          id?: string
          organization_id: string
          roster_id?: string | null
          side: string
          stats: Json
        }
        Update: {
          finalization_id?: string
          game_id?: string
          id?: string
          organization_id?: string
          roster_id?: string | null
          side?: string
          stats?: Json
        }
        Relationships: [
          {
            foreignKeyName: "game_diamond_final_stats_organization_id_game_id_finalizat_fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_diamond_finalizations"
            referencedColumns: ["organization_id", "game_id", "finalization_id"]
          },
          {
            foreignKeyName: "game_diamond_final_stats_organization_id_game_id_roster_id_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_diamond_finalizations: {
        Row: {
          engine_version: string
          epoch: number
          event_sequence: number
          finalization_id: string
          game_id: string
          organization_id: string
          roster_revision: number
          sport_key: string
          state: Json
        }
        Insert: {
          engine_version: string
          epoch: number
          event_sequence: number
          finalization_id: string
          game_id: string
          organization_id: string
          roster_revision: number
          sport_key: string
          state: Json
        }
        Update: {
          engine_version?: string
          epoch?: number
          event_sequence?: number
          finalization_id?: string
          game_id?: string
          organization_id?: string
          roster_revision?: number
          sport_key?: string
          state?: Json
        }
        Relationships: [
          {
            foreignKeyName: "game_diamond_finalizations_organization_id_game_id_finaliz_fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_finalizations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_diamond_plate_appearances: {
        Row: {
          batter_roster_id: string | null
          game_id: string
          id: string
          organization_id: string
          pitcher_roster_id: string | null
          side: string
          start_event_id: string
          start_sequence: number
          start_state: Json
        }
        Insert: {
          batter_roster_id?: string | null
          game_id: string
          id: string
          organization_id: string
          pitcher_roster_id?: string | null
          side: string
          start_event_id: string
          start_sequence: number
          start_state: Json
        }
        Update: {
          batter_roster_id?: string | null
          game_id?: string
          id?: string
          organization_id?: string
          pitcher_roster_id?: string | null
          side?: string
          start_event_id?: string
          start_sequence?: number
          start_state?: Json
        }
        Relationships: [
          {
            foreignKeyName: "game_diamond_plate_appearance_organization_id_game_id_batt_fkey"
            columns: ["organization_id", "game_id", "batter_roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_diamond_plate_appearance_organization_id_game_id_pitc_fkey"
            columns: ["organization_id", "game_id", "pitcher_roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_diamond_plate_appearance_organization_id_game_id_star_fkey"
            columns: ["organization_id", "game_id", "start_event_id"]
            isOneToOne: false
            referencedRelation: "game_diamond_events"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_diamond_states: {
        Row: {
          configuration: Json
          engine_version: string
          game_id: string
          organization_id: string
          roster_revision: number
          sport_key: string
          state: Json
        }
        Insert: {
          configuration: Json
          engine_version?: string
          game_id: string
          organization_id: string
          roster_revision: number
          sport_key: string
          state: Json
        }
        Update: {
          configuration?: Json
          engine_version?: string
          game_id?: string
          organization_id?: string
          roster_revision?: number
          sport_key?: string
          state?: Json
        }
        Relationships: [
          {
            foreignKeyName: "game_diamond_states_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      game_finalization_tracking_seals: {
        Row: {
          coverage: Json
          cutoff: number
          finalization_id: string
          game_id: string
          organization_id: string
          side: string
          snapshot_id: string
        }
        Insert: {
          coverage: Json
          cutoff: number
          finalization_id: string
          game_id: string
          organization_id: string
          side: string
          snapshot_id: string
        }
        Update: {
          coverage?: Json
          cutoff?: number
          finalization_id?: string
          game_id?: string
          organization_id?: string
          side?: string
          snapshot_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_finalization_tracking_se_organization_id_game_id_fina_fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_finalizations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_finalization_tracking_se_organization_id_game_id_snap_fkey"
            columns: ["organization_id", "game_id", "snapshot_id"]
            isOneToOne: false
            referencedRelation: "game_tracking_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
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
      game_football_events: {
        Row: {
          actor_person_id: string
          after_field: Json
          before_field: Json
          clock_ms: number
          correction_of: string | null
          created_at: string
          event_type: string
          game_id: string
          id: string
          operation_id: string
          organization_id: string
          origin_sequence: number
          payload: Json
          period_number: number
          reason: string | null
          request_id: string
          roster_id: string | null
          sequence: number
          side: string | null
        }
        Insert: {
          actor_person_id: string
          after_field?: Json
          before_field?: Json
          clock_ms: number
          correction_of?: string | null
          created_at?: string
          event_type: string
          game_id: string
          id?: string
          operation_id: string
          organization_id: string
          origin_sequence: number
          payload?: Json
          period_number: number
          reason?: string | null
          request_id: string
          roster_id?: string | null
          sequence: number
          side?: string | null
        }
        Update: {
          actor_person_id?: string
          after_field?: Json
          before_field?: Json
          clock_ms?: number
          correction_of?: string | null
          created_at?: string
          event_type?: string
          game_id?: string
          id?: string
          operation_id?: string
          organization_id?: string
          origin_sequence?: number
          payload?: Json
          period_number?: number
          reason?: string | null
          request_id?: string
          roster_id?: string | null
          sequence?: number
          side?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "game_football_events_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_football_events_organization_id_game_id_correction_of_fkey"
            columns: ["organization_id", "game_id", "correction_of"]
            isOneToOne: false
            referencedRelation: "game_football_events"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_football_events_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_football_events_organization_id_game_id_operation_id_fkey"
            columns: ["organization_id", "game_id", "operation_id"]
            isOneToOne: false
            referencedRelation: "game_operations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_football_events_organization_id_game_id_roster_id_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_football_final_stats: {
        Row: {
          finalization_id: string
          game_id: string
          id: string
          organization_id: string
          roster_id: string | null
          side: string
          stats: Json
        }
        Insert: {
          finalization_id: string
          game_id: string
          id?: string
          organization_id: string
          roster_id?: string | null
          side: string
          stats: Json
        }
        Update: {
          finalization_id?: string
          game_id?: string
          id?: string
          organization_id?: string
          roster_id?: string | null
          side?: string
          stats?: Json
        }
        Relationships: [
          {
            foreignKeyName: "game_football_final_stats_organization_id_game_id_finaliza_fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_football_finalizations"
            referencedColumns: ["organization_id", "game_id", "finalization_id"]
          },
          {
            foreignKeyName: "game_football_final_stats_organization_id_game_id_roster_i_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_football_finalizations: {
        Row: {
          engine_version: string
          epoch: number
          event_sequence: number
          finalization_id: string
          game_id: string
          organization_id: string
          roster_revision: number
          state: Json
        }
        Insert: {
          engine_version: string
          epoch: number
          event_sequence: number
          finalization_id: string
          game_id: string
          organization_id: string
          roster_revision: number
          state: Json
        }
        Update: {
          engine_version?: string
          epoch?: number
          event_sequence?: number
          finalization_id?: string
          game_id?: string
          organization_id?: string
          roster_revision?: number
          state?: Json
        }
        Relationships: [
          {
            foreignKeyName: "game_football_finalizations_organization_id_game_id_finali_fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_finalizations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_football_lineups: {
        Row: {
          game_id: string
          organization_id: string
          roster_id: string
          side: string
          slot: number
        }
        Insert: {
          game_id: string
          organization_id: string
          roster_id: string
          side: string
          slot: number
        }
        Update: {
          game_id?: string
          organization_id?: string
          roster_id?: string
          side?: string
          slot?: number
        }
        Relationships: [
          {
            foreignKeyName: "game_football_lineups_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_football_lineups_organization_id_game_id_roster_id_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_football_states: {
        Row: {
          clock_anchor: string | null
          clock_remaining_ms: number
          clock_running: boolean
          enforce_lineup: boolean
          engine_version: string
          field_state: Json
          game_id: string
          kneel_counts_as_rush: boolean
          lineup_size: number
          max_overtime_periods: number
          organization_id: string
          overtime_format: string
          overtime_seconds: number
          period_number: number
          period_status: string
          play_clock_seconds: number | null
          quarter_seconds: number
          roster_revision: number
        }
        Insert: {
          clock_anchor?: string | null
          clock_remaining_ms?: number
          clock_running?: boolean
          enforce_lineup: boolean
          engine_version?: string
          field_state?: Json
          game_id: string
          kneel_counts_as_rush: boolean
          lineup_size: number
          max_overtime_periods: number
          organization_id: string
          overtime_format: string
          overtime_seconds: number
          period_number?: number
          period_status?: string
          play_clock_seconds?: number | null
          quarter_seconds: number
          roster_revision: number
        }
        Update: {
          clock_anchor?: string | null
          clock_remaining_ms?: number
          clock_running?: boolean
          enforce_lineup?: boolean
          engine_version?: string
          field_state?: Json
          game_id?: string
          kneel_counts_as_rush?: boolean
          lineup_size?: number
          max_overtime_periods?: number
          organization_id?: string
          overtime_format?: string
          overtime_seconds?: number
          period_number?: number
          period_status?: string
          play_clock_seconds?: number | null
          quarter_seconds?: number
          roster_revision?: number
        }
        Relationships: [
          {
            foreignKeyName: "game_football_states_organization_id_game_id_fkey"
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
      game_soccer_events: {
        Row: {
          actor_person_id: string
          clock_ms: number
          correction_of: string | null
          created_at: string
          display_clock_ms: number
          event_type: string
          game_id: string
          goalkeeper_roster_id: string | null
          id: string
          lineup_roster_ids: string[] | null
          operation_id: string
          organization_id: string
          origin_sequence: number
          playing_ms: number
          prior_goalkeeper_roster_id: string | null
          prior_lineup_roster_ids: string[] | null
          reason: string | null
          request_id: string
          roster_id: string | null
          scoring_event_id: string | null
          secondary_roster_id: string | null
          segment_number: number
          sequence: number
          side: string | null
          was_on_field: boolean
        }
        Insert: {
          actor_person_id: string
          clock_ms: number
          correction_of?: string | null
          created_at?: string
          display_clock_ms: number
          event_type: string
          game_id: string
          goalkeeper_roster_id?: string | null
          id?: string
          lineup_roster_ids?: string[] | null
          operation_id: string
          organization_id: string
          origin_sequence: number
          playing_ms: number
          prior_goalkeeper_roster_id?: string | null
          prior_lineup_roster_ids?: string[] | null
          reason?: string | null
          request_id: string
          roster_id?: string | null
          scoring_event_id?: string | null
          secondary_roster_id?: string | null
          segment_number: number
          sequence: number
          side?: string | null
          was_on_field?: boolean
        }
        Update: {
          actor_person_id?: string
          clock_ms?: number
          correction_of?: string | null
          created_at?: string
          display_clock_ms?: number
          event_type?: string
          game_id?: string
          goalkeeper_roster_id?: string | null
          id?: string
          lineup_roster_ids?: string[] | null
          operation_id?: string
          organization_id?: string
          origin_sequence?: number
          playing_ms?: number
          prior_goalkeeper_roster_id?: string | null
          prior_lineup_roster_ids?: string[] | null
          reason?: string | null
          request_id?: string
          roster_id?: string | null
          scoring_event_id?: string | null
          secondary_roster_id?: string | null
          segment_number?: number
          sequence?: number
          side?: string | null
          was_on_field?: boolean
        }
        Relationships: [
          {
            foreignKeyName: "game_soccer_events_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_soccer_events_organization_id_game_id_correction_of_fkey"
            columns: ["organization_id", "game_id", "correction_of"]
            isOneToOne: false
            referencedRelation: "game_soccer_events"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_soccer_events_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_soccer_events_organization_id_game_id_goalkeeper_rost_fkey"
            columns: ["organization_id", "game_id", "goalkeeper_roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_soccer_events_organization_id_game_id_operation_id_fkey"
            columns: ["organization_id", "game_id", "operation_id"]
            isOneToOne: false
            referencedRelation: "game_operations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_soccer_events_organization_id_game_id_prior_goalkeepe_fkey"
            columns: [
              "organization_id",
              "game_id",
              "prior_goalkeeper_roster_id",
            ]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_soccer_events_organization_id_game_id_roster_id_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_soccer_events_organization_id_game_id_scoring_event_i_fkey"
            columns: ["organization_id", "game_id", "scoring_event_id"]
            isOneToOne: false
            referencedRelation: "game_soccer_events"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_soccer_events_organization_id_game_id_secondary_roste_fkey"
            columns: ["organization_id", "game_id", "secondary_roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_soccer_final_stats: {
        Row: {
          assists: number
          clean_sheet: boolean | null
          finalization_id: string
          fouls: number
          game_id: string
          goals: number
          goals_allowed: number | null
          id: string
          minutes: number | null
          organization_id: string
          own_goals: number
          red_cards: number
          roster_id: string | null
          saves: number
          shots: number
          shots_on_goal: number
          side: string
          yellow_cards: number
        }
        Insert: {
          assists: number
          clean_sheet?: boolean | null
          finalization_id: string
          fouls: number
          game_id: string
          goals: number
          goals_allowed?: number | null
          id?: string
          minutes?: number | null
          organization_id: string
          own_goals: number
          red_cards: number
          roster_id?: string | null
          saves: number
          shots: number
          shots_on_goal: number
          side: string
          yellow_cards: number
        }
        Update: {
          assists?: number
          clean_sheet?: boolean | null
          finalization_id?: string
          fouls?: number
          game_id?: string
          goals?: number
          goals_allowed?: number | null
          id?: string
          minutes?: number | null
          organization_id?: string
          own_goals?: number
          red_cards?: number
          roster_id?: string | null
          saves?: number
          shots?: number
          shots_on_goal?: number
          side?: string
          yellow_cards?: number
        }
        Relationships: [
          {
            foreignKeyName: "game_soccer_final_stats_organization_id_game_id_finalizati_fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_soccer_finalizations"
            referencedColumns: ["organization_id", "game_id", "finalization_id"]
          },
          {
            foreignKeyName: "game_soccer_final_stats_organization_id_game_id_roster_id_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_soccer_finalizations: {
        Row: {
          engine_version: string
          epoch: number
          event_sequence: number
          finalization_id: string
          game_id: string
          organization_id: string
          roster_revision: number
          segment_number: number
          state: Json
        }
        Insert: {
          engine_version: string
          epoch: number
          event_sequence: number
          finalization_id: string
          game_id: string
          organization_id: string
          roster_revision: number
          segment_number: number
          state: Json
        }
        Update: {
          engine_version?: string
          epoch?: number
          event_sequence?: number
          finalization_id?: string
          game_id?: string
          organization_id?: string
          roster_revision?: number
          segment_number?: number
          state?: Json
        }
        Relationships: [
          {
            foreignKeyName: "game_soccer_finalizations_organization_id_game_id_finaliza_fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_finalizations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_soccer_lineups: {
        Row: {
          dismissed: boolean
          game_id: string
          goalkeeper: boolean
          organization_id: string
          roster_id: string
          side: string
          slot: number
        }
        Insert: {
          dismissed?: boolean
          game_id: string
          goalkeeper?: boolean
          organization_id: string
          roster_id: string
          side: string
          slot: number
        }
        Update: {
          dismissed?: boolean
          game_id?: string
          goalkeeper?: boolean
          organization_id?: string
          roster_id?: string
          side?: string
          slot?: number
        }
        Relationships: [
          {
            foreignKeyName: "game_soccer_lineups_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_soccer_lineups_organization_id_game_id_roster_id_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_soccer_states: {
        Row: {
          added_time_seconds: number
          allow_reentry: boolean
          clock_anchor: string | null
          clock_elapsed_ms: number
          clock_running: boolean
          enforce_lineup: boolean
          engine_version: string
          extra_time_seconds: number
          extra_time_segments: number
          game_id: string
          lineup_size: number
          max_substitutions: number | null
          organization_id: string
          participation_complete: boolean
          regulation_segments: number
          roster_revision: number
          segment_base_ms: number
          segment_number: number
          segment_seconds: number
          segment_status: string
        }
        Insert: {
          added_time_seconds?: number
          allow_reentry: boolean
          clock_anchor?: string | null
          clock_elapsed_ms?: number
          clock_running?: boolean
          enforce_lineup: boolean
          engine_version?: string
          extra_time_seconds: number
          extra_time_segments: number
          game_id: string
          lineup_size: number
          max_substitutions?: number | null
          organization_id: string
          participation_complete?: boolean
          regulation_segments: number
          roster_revision: number
          segment_base_ms?: number
          segment_number?: number
          segment_seconds: number
          segment_status?: string
        }
        Update: {
          added_time_seconds?: number
          allow_reentry?: boolean
          clock_anchor?: string | null
          clock_elapsed_ms?: number
          clock_running?: boolean
          enforce_lineup?: boolean
          engine_version?: string
          extra_time_seconds?: number
          extra_time_segments?: number
          game_id?: string
          lineup_size?: number
          max_substitutions?: number | null
          organization_id?: string
          participation_complete?: boolean
          regulation_segments?: number
          roster_revision?: number
          segment_base_ms?: number
          segment_number?: number
          segment_seconds?: number
          segment_status?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_soccer_states_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
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
      game_stat_catalog_items: {
        Row: {
          catalog_version: string
          definition: Json
          key: string
          sport_key: string
        }
        Insert: {
          catalog_version: string
          definition: Json
          key: string
          sport_key: string
        }
        Update: {
          catalog_version?: string
          definition?: Json
          key?: string
          sport_key?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_stat_catalog_items_sport_key_catalog_version_fkey"
            columns: ["sport_key", "catalog_version"]
            isOneToOne: false
            referencedRelation: "game_stat_catalog_versions"
            referencedColumns: ["sport_key", "version"]
          },
        ]
      }
      game_stat_catalog_versions: {
        Row: {
          sport_key: string
          version: string
        }
        Insert: {
          sport_key: string
          version: string
        }
        Update: {
          sport_key?: string
          version?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_stat_catalog_versions_sport_key_fkey"
            columns: ["sport_key"]
            isOneToOne: false
            referencedRelation: "game_sports"
            referencedColumns: ["key"]
          },
        ]
      }
      game_stat_coverage_intervals: {
        Row: {
          enabled: boolean
          game_id: string
          organization_id: string
          snapshot_id: string
          stat_key: string
        }
        Insert: {
          enabled: boolean
          game_id: string
          organization_id: string
          snapshot_id: string
          stat_key: string
        }
        Update: {
          enabled?: boolean
          game_id?: string
          organization_id?: string
          snapshot_id?: string
          stat_key?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_stat_coverage_intervals_organization_id_game_id_snaps_fkey"
            columns: ["organization_id", "game_id", "snapshot_id"]
            isOneToOne: false
            referencedRelation: "game_tracking_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_tracking_profile_revisions: {
        Row: {
          actor_person_id: string | null
          catalog_version: string
          created_at: string
          id: string
          profile_id: string
          request_id: string | null
          selection: Json
          sport_key: string
          version: number
        }
        Insert: {
          actor_person_id?: string | null
          catalog_version: string
          created_at?: string
          id?: string
          profile_id: string
          request_id?: string | null
          selection: Json
          sport_key: string
          version: number
        }
        Update: {
          actor_person_id?: string | null
          catalog_version?: string
          created_at?: string
          id?: string
          profile_id?: string
          request_id?: string | null
          selection?: Json
          sport_key?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "game_tracking_profile_revisions_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_tracking_profile_revisions_profile_id_sport_key_fkey"
            columns: ["profile_id", "sport_key"]
            isOneToOne: false
            referencedRelation: "game_tracking_profiles"
            referencedColumns: ["id", "sport_key"]
          },
          {
            foreignKeyName: "game_tracking_profile_revisions_sport_key_catalog_version_fkey"
            columns: ["sport_key", "catalog_version"]
            isOneToOne: false
            referencedRelation: "game_stat_catalog_versions"
            referencedColumns: ["sport_key", "version"]
          },
        ]
      }
      game_tracking_profiles: {
        Row: {
          ends_at: string | null
          game_id: string | null
          id: string
          organization_id: string | null
          scope_type: string
          season_id: string | null
          side: string | null
          sport_key: string
          starts_at: string
          status: string
          team_id: string | null
          unit_id: string | null
          version: number
        }
        Insert: {
          ends_at?: string | null
          game_id?: string | null
          id?: string
          organization_id?: string | null
          scope_type: string
          season_id?: string | null
          side?: string | null
          sport_key: string
          starts_at?: string
          status?: string
          team_id?: string | null
          unit_id?: string | null
          version?: number
        }
        Update: {
          ends_at?: string | null
          game_id?: string | null
          id?: string
          organization_id?: string | null
          scope_type?: string
          season_id?: string | null
          side?: string | null
          sport_key?: string
          starts_at?: string
          status?: string
          team_id?: string | null
          unit_id?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "game_tracking_profiles_organization_id_fkey"
            columns: ["organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_tracking_profiles_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_tracking_profiles_organization_id_season_id_fkey"
            columns: ["organization_id", "season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_tracking_profiles_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_tracking_profiles_organization_id_unit_id_fkey"
            columns: ["organization_id", "unit_id"]
            isOneToOne: false
            referencedRelation: "organization_units"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_tracking_profiles_sport_key_fkey"
            columns: ["sport_key"]
            isOneToOne: false
            referencedRelation: "game_sports"
            referencedColumns: ["key"]
          },
        ]
      }
      game_tracking_snapshots: {
        Row: {
          catalog_version: string
          created_at: string
          effective_sequence: number
          game_id: string
          id: string
          organization_id: string
          provenance: Json
          roster_revision: number
          selection: Json
          side: string
          sport_key: string
        }
        Insert: {
          catalog_version: string
          created_at?: string
          effective_sequence: number
          game_id: string
          id?: string
          organization_id: string
          provenance: Json
          roster_revision: number
          selection: Json
          side: string
          sport_key: string
        }
        Update: {
          catalog_version?: string
          created_at?: string
          effective_sequence?: number
          game_id?: string
          id?: string
          organization_id?: string
          provenance?: Json
          roster_revision?: number
          selection?: Json
          side?: string
          sport_key?: string
        }
        Relationships: [
          {
            foreignKeyName: "game_tracking_snapshots_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_tracking_snapshots_sport_key_catalog_version_fkey"
            columns: ["sport_key", "catalog_version"]
            isOneToOne: false
            referencedRelation: "game_stat_catalog_versions"
            referencedColumns: ["sport_key", "version"]
          },
        ]
      }
      game_volleyball_events: {
        Row: {
          actor_person_id: string
          correction_of: string | null
          created_at: string
          event_type: string
          game_id: string
          id: string
          operation_id: string
          organization_id: string
          origin_sequence: number
          payload: Json
          reason: string | null
          request_id: string
          sequence: number
          side: string | null
        }
        Insert: {
          actor_person_id: string
          correction_of?: string | null
          created_at?: string
          event_type: string
          game_id: string
          id?: string
          operation_id: string
          organization_id: string
          origin_sequence: number
          payload: Json
          reason?: string | null
          request_id: string
          sequence: number
          side?: string | null
        }
        Update: {
          actor_person_id?: string
          correction_of?: string | null
          created_at?: string
          event_type?: string
          game_id?: string
          id?: string
          operation_id?: string
          organization_id?: string
          origin_sequence?: number
          payload?: Json
          reason?: string | null
          request_id?: string
          sequence?: number
          side?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "game_volleyball_events_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "game_volleyball_events_organization_id_game_id_correction__fkey"
            columns: ["organization_id", "game_id", "correction_of"]
            isOneToOne: false
            referencedRelation: "game_volleyball_events"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "game_volleyball_events_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "game_volleyball_events_organization_id_game_id_operation_i_fkey"
            columns: ["organization_id", "game_id", "operation_id"]
            isOneToOne: false
            referencedRelation: "game_operations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_volleyball_final_stats: {
        Row: {
          finalization_id: string
          game_id: string
          id: string
          organization_id: string
          roster_id: string | null
          side: string
          stats: Json
        }
        Insert: {
          finalization_id: string
          game_id: string
          id?: string
          organization_id: string
          roster_id?: string | null
          side: string
          stats: Json
        }
        Update: {
          finalization_id?: string
          game_id?: string
          id?: string
          organization_id?: string
          roster_id?: string | null
          side?: string
          stats?: Json
        }
        Relationships: [
          {
            foreignKeyName: "game_volleyball_final_stats_organization_id_game_id_finali_fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_volleyball_finalizations"
            referencedColumns: ["organization_id", "game_id", "finalization_id"]
          },
          {
            foreignKeyName: "game_volleyball_final_stats_organization_id_game_id_roster_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_volleyball_finalizations: {
        Row: {
          engine_version: string
          epoch: number
          event_sequence: number
          finalization_id: string
          game_id: string
          organization_id: string
          roster_revision: number
          state: Json
        }
        Insert: {
          engine_version: string
          epoch: number
          event_sequence: number
          finalization_id: string
          game_id: string
          organization_id: string
          roster_revision: number
          state: Json
        }
        Update: {
          engine_version?: string
          epoch?: number
          event_sequence?: number
          finalization_id?: string
          game_id?: string
          organization_id?: string
          roster_revision?: number
          state?: Json
        }
        Relationships: [
          {
            foreignKeyName: "game_volleyball_finalizations_organization_id_game_id_fina_fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_finalizations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
        ]
      }
      game_volleyball_states: {
        Row: {
          configuration: Json
          engine_version: string
          game_id: string
          organization_id: string
          roster_revision: number
          state: Json
        }
        Insert: {
          configuration: Json
          engine_version?: string
          game_id: string
          organization_id: string
          roster_revision: number
          state: Json
        }
        Update: {
          configuration?: Json
          engine_version?: string
          game_id?: string
          organization_id?: string
          roster_revision?: number
          state?: Json
        }
        Relationships: [
          {
            foreignKeyName: "game_volleyball_states_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
        ]
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
          can_manage_boss_bucks: boolean
          can_manage_fundraising: boolean
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
          can_manage_boss_bucks?: boolean
          can_manage_fundraising?: boolean
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
          can_manage_boss_bucks?: boolean
          can_manage_fundraising?: boolean
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
      money_board_generations: {
        Row: {
          board_id: string
          created_at: string
          generation: number
          id: string
          increment_minor: number
          start_minor: number
          tile_count: number
        }
        Insert: {
          board_id: string
          created_at?: string
          generation: number
          id?: string
          increment_minor: number
          start_minor: number
          tile_count: number
        }
        Update: {
          board_id?: string
          created_at?: string
          generation?: number
          id?: string
          increment_minor?: number
          start_minor?: number
          tile_count?: number
        }
        Relationships: [
          {
            foreignKeyName: "money_board_generations_board_id_fkey"
            columns: ["board_id"]
            isOneToOne: false
            referencedRelation: "money_boards"
            referencedColumns: ["id"]
          },
        ]
      }
      money_board_reservations: {
        Row: {
          capability_digest: string
          expires_at: string
          id: string
          release_reason: string | null
          released_at: string | null
          request_id: string
          starts_at: string
          tile_id: string
        }
        Insert: {
          capability_digest: string
          expires_at: string
          id?: string
          release_reason?: string | null
          released_at?: string | null
          request_id: string
          starts_at?: string
          tile_id: string
        }
        Update: {
          capability_digest?: string
          expires_at?: string
          id?: string
          release_reason?: string | null
          released_at?: string | null
          request_id?: string
          starts_at?: string
          tile_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "money_board_reservations_tile_id_fkey"
            columns: ["tile_id"]
            isOneToOne: false
            referencedRelation: "money_board_tiles"
            referencedColumns: ["id"]
          },
        ]
      }
      money_board_tiles: {
        Row: {
          amount_minor: number
          board_id: string
          created_at: string
          generation_id: string
          id: string
          ordinal: number
        }
        Insert: {
          amount_minor: number
          board_id: string
          created_at?: string
          generation_id: string
          id?: string
          ordinal: number
        }
        Update: {
          amount_minor?: number
          board_id?: string
          created_at?: string
          generation_id?: string
          id?: string
          ordinal?: number
        }
        Relationships: [
          {
            foreignKeyName: "money_board_tiles_board_id_fkey"
            columns: ["board_id"]
            isOneToOne: false
            referencedRelation: "money_boards"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "money_board_tiles_generation_id_fkey"
            columns: ["generation_id"]
            isOneToOne: false
            referencedRelation: "money_board_generations"
            referencedColumns: ["id"]
          },
        ]
      }
      money_boards: {
        Row: {
          campaign_id: string
          created_at: string
          fundraiser_id: string | null
          goal_minor: number
          id: string
          increment_minor: number
          public_path: string
          reservation_seconds: number
          start_minor: number
          status: string
          team_id: string | null
          tile_count: number
          title: string
          version: number
          visibility: string
        }
        Insert: {
          campaign_id: string
          created_at?: string
          fundraiser_id?: string | null
          goal_minor: number
          id?: string
          increment_minor: number
          public_path?: string
          reservation_seconds?: number
          start_minor: number
          status?: string
          team_id?: string | null
          tile_count: number
          title: string
          version?: number
          visibility?: string
        }
        Update: {
          campaign_id?: string
          created_at?: string
          fundraiser_id?: string | null
          goal_minor?: number
          id?: string
          increment_minor?: number
          public_path?: string
          reservation_seconds?: number
          start_minor?: number
          status?: string
          team_id?: string | null
          tile_count?: number
          title?: string
          version?: number
          visibility?: string
        }
        Relationships: [
          {
            foreignKeyName: "money_boards_campaign_id_fkey"
            columns: ["campaign_id"]
            isOneToOne: false
            referencedRelation: "fundraising_campaigns"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "money_boards_campaign_id_fundraiser_id_fkey"
            columns: ["campaign_id", "fundraiser_id"]
            isOneToOne: false
            referencedRelation: "fundraising_fundraisers"
            referencedColumns: ["campaign_id", "id"]
          },
          {
            foreignKeyName: "money_boards_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
        ]
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
      ranking_candidates: {
        Row: {
          achieved_at: string | null
          built_generation: number
          coverage: Json
          id: string
          person_id: string | null
          qualification: Json
          qualification_state: string
          rank: number | null
          scope_id: string
          source_manifest: Json
          subject_key: string
          summary: Json
          team_id: string | null
          value: number | null
        }
        Insert: {
          achieved_at?: string | null
          built_generation?: number
          coverage: Json
          id?: string
          person_id?: string | null
          qualification: Json
          qualification_state: string
          rank?: number | null
          scope_id: string
          source_manifest: Json
          subject_key: string
          summary: Json
          team_id?: string | null
          value?: number | null
        }
        Update: {
          achieved_at?: string | null
          built_generation?: number
          coverage?: Json
          id?: string
          person_id?: string | null
          qualification?: Json
          qualification_state?: string
          rank?: number | null
          scope_id?: string
          source_manifest?: Json
          subject_key?: string
          summary?: Json
          team_id?: string | null
          value?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "ranking_candidates_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ranking_candidates_scope_id_fkey"
            columns: ["scope_id"]
            isOneToOne: false
            referencedRelation: "ranking_scopes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ranking_candidates_team_id_fkey"
            columns: ["team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["id"]
          },
        ]
      }
      ranking_definitions: {
        Row: {
          actor_person_id: string
          allow_partial: boolean
          competition_only: boolean
          created_at: string
          direction: string
          edition_id: string
          id: string
          metric_key: string
          metric_kind: string
          name: string
          product: string
          qualification: Json
          season_id: string | null
          source_kind: string
          source_organization_id: string
          stat_definition_version: string
          status: string
          team_id: string | null
          version: number
        }
        Insert: {
          actor_person_id: string
          allow_partial?: boolean
          competition_only?: boolean
          created_at?: string
          direction: string
          edition_id: string
          id?: string
          metric_key: string
          metric_kind: string
          name: string
          product: string
          qualification?: Json
          season_id?: string | null
          source_kind: string
          source_organization_id: string
          stat_definition_version?: string
          status?: string
          team_id?: string | null
          version?: number
        }
        Update: {
          actor_person_id?: string
          allow_partial?: boolean
          competition_only?: boolean
          created_at?: string
          direction?: string
          edition_id?: string
          id?: string
          metric_key?: string
          metric_kind?: string
          name?: string
          product?: string
          qualification?: Json
          season_id?: string | null
          source_kind?: string
          source_organization_id?: string
          stat_definition_version?: string
          status?: string
          team_id?: string | null
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "ranking_definitions_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ranking_definitions_edition_id_fkey"
            columns: ["edition_id"]
            isOneToOne: false
            referencedRelation: "competition_editions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ranking_definitions_source_organization_id_fkey"
            columns: ["source_organization_id"]
            isOneToOne: false
            referencedRelation: "organizations"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ranking_definitions_source_organization_id_season_id_fkey"
            columns: ["source_organization_id", "season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "ranking_definitions_source_organization_id_team_id_fkey"
            columns: ["source_organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      ranking_refresh_work: {
        Row: {
          attempts: number
          claimed_until: string | null
          created_at: string
          scope_id: string
          target_generation: number
        }
        Insert: {
          attempts?: number
          claimed_until?: string | null
          created_at?: string
          scope_id: string
          target_generation: number
        }
        Update: {
          attempts?: number
          claimed_until?: string | null
          created_at?: string
          scope_id?: string
          target_generation?: number
        }
        Relationships: [
          {
            foreignKeyName: "ranking_refresh_work_scope_id_fkey"
            columns: ["scope_id"]
            isOneToOne: true
            referencedRelation: "ranking_scopes"
            referencedColumns: ["id"]
          },
        ]
      }
      ranking_scopes: {
        Row: {
          build_cursor: string | null
          definition_id: string | null
          edition_id: string
          group_id: string | null
          id: string
          product: string
          published_generation: number
          reason: string | null
          refreshed_at: string | null
          source_hash: string | null
          source_manifest: Json
          state: string
          target_generation: number
          valid_until: string | null
        }
        Insert: {
          build_cursor?: string | null
          definition_id?: string | null
          edition_id: string
          group_id?: string | null
          id?: string
          product: string
          published_generation?: number
          reason?: string | null
          refreshed_at?: string | null
          source_hash?: string | null
          source_manifest?: Json
          state?: string
          target_generation?: number
          valid_until?: string | null
        }
        Update: {
          build_cursor?: string | null
          definition_id?: string | null
          edition_id?: string
          group_id?: string | null
          id?: string
          product?: string
          published_generation?: number
          reason?: string | null
          refreshed_at?: string | null
          source_hash?: string | null
          source_manifest?: Json
          state?: string
          target_generation?: number
          valid_until?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "ranking_scopes_definition_id_fkey"
            columns: ["definition_id"]
            isOneToOne: false
            referencedRelation: "ranking_definitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ranking_scopes_edition_id_definition_id_fkey"
            columns: ["edition_id", "definition_id"]
            isOneToOne: false
            referencedRelation: "ranking_definitions"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "ranking_scopes_edition_id_fkey"
            columns: ["edition_id"]
            isOneToOne: false
            referencedRelation: "competition_editions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "ranking_scopes_edition_id_group_id_fkey"
            columns: ["edition_id", "group_id"]
            isOneToOne: false
            referencedRelation: "competition_groups"
            referencedColumns: ["edition_id", "id"]
          },
        ]
      }
      record_current_holders: {
        Row: {
          candidate_id: string
          definition_id: string
          event_id: string
          scope_id: string
          subject_key: string
        }
        Insert: {
          candidate_id: string
          definition_id: string
          event_id: string
          scope_id: string
          subject_key: string
        }
        Update: {
          candidate_id?: string
          definition_id?: string
          event_id?: string
          scope_id?: string
          subject_key?: string
        }
        Relationships: [
          {
            foreignKeyName: "record_current_holders_definition_id_fkey"
            columns: ["definition_id"]
            isOneToOne: false
            referencedRelation: "ranking_definitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "record_current_holders_scope_id_candidate_id_fkey"
            columns: ["scope_id", "candidate_id"]
            isOneToOne: false
            referencedRelation: "ranking_candidates"
            referencedColumns: ["scope_id", "id"]
          },
          {
            foreignKeyName: "record_current_holders_scope_id_definition_id_fkey"
            columns: ["scope_id", "definition_id"]
            isOneToOne: false
            referencedRelation: "ranking_scopes"
            referencedColumns: ["id", "definition_id"]
          },
          {
            foreignKeyName: "record_current_holders_scope_id_subject_key_event_id_fkey"
            columns: ["scope_id", "subject_key", "event_id"]
            isOneToOne: false
            referencedRelation: "record_events"
            referencedColumns: ["scope_id", "subject_key", "id"]
          },
        ]
      }
      record_events: {
        Row: {
          achieved_at: string
          definition_id: string
          event_key: string
          event_type: string
          generation: number
          id: string
          previous_event_id: string | null
          qualification: Json
          recognized_at: string
          scope_id: string
          source_manifest: Json
          subject_key: string
          value: number
        }
        Insert: {
          achieved_at: string
          definition_id: string
          event_key: string
          event_type: string
          generation: number
          id?: string
          previous_event_id?: string | null
          qualification: Json
          recognized_at?: string
          scope_id: string
          source_manifest: Json
          subject_key: string
          value: number
        }
        Update: {
          achieved_at?: string
          definition_id?: string
          event_key?: string
          event_type?: string
          generation?: number
          id?: string
          previous_event_id?: string | null
          qualification?: Json
          recognized_at?: string
          scope_id?: string
          source_manifest?: Json
          subject_key?: string
          value?: number
        }
        Relationships: [
          {
            foreignKeyName: "record_events_definition_id_fkey"
            columns: ["definition_id"]
            isOneToOne: false
            referencedRelation: "ranking_definitions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "record_events_scope_id_definition_id_fkey"
            columns: ["scope_id", "definition_id"]
            isOneToOne: false
            referencedRelation: "ranking_scopes"
            referencedColumns: ["id", "definition_id"]
          },
          {
            foreignKeyName: "record_events_scope_id_previous_event_id_fkey"
            columns: ["scope_id", "previous_event_id"]
            isOneToOne: false
            referencedRelation: "record_events"
            referencedColumns: ["scope_id", "id"]
          },
        ]
      }
      recruiting_consents: {
        Row: {
          actor_kind: string
          actor_person_id: string
          approved_categories: string[]
          consent_version: number
          expires_at: string | null
          granted_at: string
          id: string
          revoked_at: string | null
          showcase_id: string
          showcase_revision_id: string
          status: string
          subject_person_id: string
        }
        Insert: {
          actor_kind: string
          actor_person_id: string
          approved_categories: string[]
          consent_version: number
          expires_at?: string | null
          granted_at?: string
          id?: string
          revoked_at?: string | null
          showcase_id: string
          showcase_revision_id: string
          status?: string
          subject_person_id: string
        }
        Update: {
          actor_kind?: string
          actor_person_id?: string
          approved_categories?: string[]
          consent_version?: number
          expires_at?: string | null
          granted_at?: string
          id?: string
          revoked_at?: string | null
          showcase_id?: string
          showcase_revision_id?: string
          status?: string
          subject_person_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "recruiting_consents_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recruiting_consents_showcase_id_fkey"
            columns: ["showcase_id"]
            isOneToOne: false
            referencedRelation: "recruiting_showcases"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recruiting_consents_showcase_id_showcase_revision_id_fkey"
            columns: ["showcase_id", "showcase_revision_id"]
            isOneToOne: false
            referencedRelation: "recruiting_showcase_revisions"
            referencedColumns: ["showcase_id", "id"]
          },
          {
            foreignKeyName: "recruiting_consents_subject_person_id_fkey"
            columns: ["subject_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
        ]
      }
      recruiting_share_links: {
        Row: {
          access_count: number
          created_at: string
          created_by_person_id: string
          expires_at: string | null
          id: string
          last_accessed_at: string | null
          revoked_at: string | null
          showcase_id: string
          status: string
          token_digest: string
          token_prefix: string
        }
        Insert: {
          access_count?: number
          created_at?: string
          created_by_person_id: string
          expires_at?: string | null
          id?: string
          last_accessed_at?: string | null
          revoked_at?: string | null
          showcase_id: string
          status?: string
          token_digest: string
          token_prefix: string
        }
        Update: {
          access_count?: number
          created_at?: string
          created_by_person_id?: string
          expires_at?: string | null
          id?: string
          last_accessed_at?: string | null
          revoked_at?: string | null
          showcase_id?: string
          status?: string
          token_digest?: string
          token_prefix?: string
        }
        Relationships: [
          {
            foreignKeyName: "recruiting_share_links_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recruiting_share_links_showcase_id_fkey"
            columns: ["showcase_id"]
            isOneToOne: false
            referencedRelation: "recruiting_showcases"
            referencedColumns: ["id"]
          },
        ]
      }
      recruiting_showcase_revisions: {
        Row: {
          actor_person_id: string
          created_at: string
          id: string
          presentation: Json
          profile_revision_id: string
          revision: number
          showcase_id: string
          sport_keys: string[]
          stat_metric_keys: string[]
          visible_categories: string[]
        }
        Insert: {
          actor_person_id: string
          created_at?: string
          id?: string
          presentation?: Json
          profile_revision_id: string
          revision: number
          showcase_id: string
          sport_keys?: string[]
          stat_metric_keys?: string[]
          visible_categories?: string[]
        }
        Update: {
          actor_person_id?: string
          created_at?: string
          id?: string
          presentation?: Json
          profile_revision_id?: string
          revision?: number
          showcase_id?: string
          sport_keys?: string[]
          stat_metric_keys?: string[]
          visible_categories?: string[]
        }
        Relationships: [
          {
            foreignKeyName: "recruiting_showcase_revisions_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recruiting_showcase_revisions_profile_revision_id_fkey"
            columns: ["profile_revision_id"]
            isOneToOne: false
            referencedRelation: "athlete_profile_revisions"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recruiting_showcase_revisions_showcase_id_fkey"
            columns: ["showcase_id"]
            isOneToOne: false
            referencedRelation: "recruiting_showcases"
            referencedColumns: ["id"]
          },
        ]
      }
      recruiting_showcases: {
        Row: {
          created_at: string
          created_by_person_id: string
          current_consent_id: string | null
          current_revision_id: string | null
          id: string
          profile_id: string
          published_revision_id: string | null
          state: string
          updated_at: string
          version: number
        }
        Insert: {
          created_at?: string
          created_by_person_id: string
          current_consent_id?: string | null
          current_revision_id?: string | null
          id?: string
          profile_id: string
          published_revision_id?: string | null
          state?: string
          updated_at?: string
          version?: number
        }
        Update: {
          created_at?: string
          created_by_person_id?: string
          current_consent_id?: string | null
          current_revision_id?: string | null
          id?: string
          profile_id?: string
          published_revision_id?: string | null
          state?: string
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "recruiting_showcases_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recruiting_showcases_current_consent_fk"
            columns: ["current_consent_id"]
            isOneToOne: false
            referencedRelation: "recruiting_consents"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recruiting_showcases_current_revision_fk"
            columns: ["id", "current_revision_id"]
            isOneToOne: false
            referencedRelation: "recruiting_showcase_revisions"
            referencedColumns: ["showcase_id", "id"]
          },
          {
            foreignKeyName: "recruiting_showcases_profile_id_fkey"
            columns: ["profile_id"]
            isOneToOne: true
            referencedRelation: "athlete_profiles"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "recruiting_showcases_published_revision_fk"
            columns: ["id", "published_revision_id"]
            isOneToOne: false
            referencedRelation: "recruiting_showcase_revisions"
            referencedColumns: ["showcase_id", "id"]
          },
        ]
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
      standings_policy_revisions: {
        Row: {
          actor_person_id: string
          configuration: Json
          created_at: string
          edition_id: string
          id: string
          reason: string
          version: number
        }
        Insert: {
          actor_person_id: string
          configuration: Json
          created_at?: string
          edition_id: string
          id?: string
          reason: string
          version: number
        }
        Update: {
          actor_person_id?: string
          configuration?: Json
          created_at?: string
          edition_id?: string
          id?: string
          reason?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "standings_policy_revisions_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "standings_policy_revisions_edition_id_fkey"
            columns: ["edition_id"]
            isOneToOne: false
            referencedRelation: "competition_editions"
            referencedColumns: ["id"]
          },
        ]
      }
      standings_rows: {
        Row: {
          entry_id: string
          explanation: Json
          games_played: number
          losses: number
          metrics: Json
          points: number | null
          rank: number
          scope_id: string
          scoring_against: number | null
          scoring_for: number | null
          ties: number
          win_percentage: number | null
          wins: number
        }
        Insert: {
          entry_id: string
          explanation: Json
          games_played: number
          losses: number
          metrics: Json
          points?: number | null
          rank: number
          scope_id: string
          scoring_against?: number | null
          scoring_for?: number | null
          ties: number
          win_percentage?: number | null
          wins: number
        }
        Update: {
          entry_id?: string
          explanation?: Json
          games_played?: number
          losses?: number
          metrics?: Json
          points?: number | null
          rank?: number
          scope_id?: string
          scoring_against?: number | null
          scoring_for?: number | null
          ties?: number
          win_percentage?: number | null
          wins?: number
        }
        Relationships: [
          {
            foreignKeyName: "standings_rows_entry_id_fkey"
            columns: ["entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "standings_rows_scope_id_fkey"
            columns: ["scope_id"]
            isOneToOne: false
            referencedRelation: "ranking_scopes"
            referencedColumns: ["id"]
          },
        ]
      }
      stat_competition_classifications: {
        Row: {
          actor_person_id: string
          applies_epoch: number
          classification: string
          created_at: string
          definition_version: string
          game_id: string
          id: string
          organization_id: string
          reason: string
          version: number
        }
        Insert: {
          actor_person_id: string
          applies_epoch: number
          classification: string
          created_at?: string
          definition_version?: string
          game_id: string
          id?: string
          organization_id: string
          reason: string
          version: number
        }
        Update: {
          actor_person_id?: string
          applies_epoch?: number
          classification?: string
          created_at?: string
          definition_version?: string
          game_id?: string
          id?: string
          organization_id?: string
          reason?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "stat_competition_classifications_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stat_competition_classifications_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      stat_game_contributions: {
        Row: {
          classification: string
          classification_id: string | null
          components: Json
          coverage: Json
          created_at: string
          definition_version: string
          engine_version: string
          epoch: number
          era_basis_innings: number | null
          finalization_id: string
          game_id: string
          id: string
          organization_id: string
          participant_id: string | null
          participation: Json
          person_id: string | null
          roster_id: string | null
          roster_revision: number
          season_id: string | null
          side: string
          source_stat_id: string
          sport_key: string
          team_id: string | null
          tracking_snapshot_id: string | null
        }
        Insert: {
          classification: string
          classification_id?: string | null
          components: Json
          coverage: Json
          created_at?: string
          definition_version?: string
          engine_version: string
          epoch: number
          era_basis_innings?: number | null
          finalization_id: string
          game_id: string
          id?: string
          organization_id: string
          participant_id?: string | null
          participation: Json
          person_id?: string | null
          roster_id?: string | null
          roster_revision: number
          season_id?: string | null
          side: string
          source_stat_id: string
          sport_key: string
          team_id?: string | null
          tracking_snapshot_id?: string | null
        }
        Update: {
          classification?: string
          classification_id?: string | null
          components?: Json
          coverage?: Json
          created_at?: string
          definition_version?: string
          engine_version?: string
          epoch?: number
          era_basis_innings?: number | null
          finalization_id?: string
          game_id?: string
          id?: string
          organization_id?: string
          participant_id?: string | null
          participation?: Json
          person_id?: string | null
          roster_id?: string | null
          roster_revision?: number
          season_id?: string | null
          side?: string
          source_stat_id?: string
          sport_key?: string
          team_id?: string | null
          tracking_snapshot_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "stat_game_contributions_organization_id_game_id_classifica_fkey"
            columns: ["organization_id", "game_id", "classification_id"]
            isOneToOne: false
            referencedRelation: "stat_competition_classifications"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "stat_game_contributions_organization_id_game_id_finalizati_fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_finalizations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "stat_game_contributions_organization_id_game_id_roster_id_fkey"
            columns: ["organization_id", "game_id", "roster_id"]
            isOneToOne: false
            referencedRelation: "game_roster_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "stat_game_contributions_organization_id_game_id_tracking_s_fkey"
            columns: ["organization_id", "game_id", "tracking_snapshot_id"]
            isOneToOne: false
            referencedRelation: "game_tracking_snapshots"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "stat_game_contributions_organization_id_season_id_fkey"
            columns: ["organization_id", "season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "stat_game_contributions_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "stat_game_contributions_participant_id_person_id_fkey"
            columns: ["participant_id", "person_id"]
            isOneToOne: false
            referencedRelation: "participants"
            referencedColumns: ["id", "person_id"]
          },
          {
            foreignKeyName: "stat_game_contributions_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stat_game_contributions_sport_key_fkey"
            columns: ["sport_key"]
            isOneToOne: false
            referencedRelation: "game_sports"
            referencedColumns: ["key"]
          },
        ]
      }
      stat_game_selections: {
        Row: {
          changed_at: string
          finalization_id: string | null
          game_id: string
          generation: number
          organization_id: string
          refreshed_at: string | null
          refreshed_generation: number
        }
        Insert: {
          changed_at?: string
          finalization_id?: string | null
          game_id: string
          generation?: number
          organization_id: string
          refreshed_at?: string | null
          refreshed_generation?: number
        }
        Update: {
          changed_at?: string
          finalization_id?: string | null
          game_id?: string
          generation?: number
          organization_id?: string
          refreshed_at?: string | null
          refreshed_generation?: number
        }
        Relationships: [
          {
            foreignKeyName: "stat_game_selections_organization_id_game_id_finalization__fkey"
            columns: ["organization_id", "game_id", "finalization_id"]
            isOneToOne: false
            referencedRelation: "game_finalizations"
            referencedColumns: ["organization_id", "game_id", "id"]
          },
          {
            foreignKeyName: "stat_game_selections_organization_id_game_id_fkey"
            columns: ["organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      stat_origin_summaries: {
        Row: {
          definition_version: string
          generation: number
          id: string
          is_current: boolean
          organization_id: string
          person_id: string | null
          refreshed_at: string | null
          season_id: string | null
          source_watermark: string | null
          sport_key: string
          summary: Json
          team_id: string
        }
        Insert: {
          definition_version?: string
          generation?: number
          id?: string
          is_current?: boolean
          organization_id: string
          person_id?: string | null
          refreshed_at?: string | null
          season_id?: string | null
          source_watermark?: string | null
          sport_key: string
          summary?: Json
          team_id: string
        }
        Update: {
          definition_version?: string
          generation?: number
          id?: string
          is_current?: boolean
          organization_id?: string
          person_id?: string | null
          refreshed_at?: string | null
          season_id?: string | null
          source_watermark?: string | null
          sport_key?: string
          summary?: Json
          team_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "stat_origin_summaries_organization_id_season_id_fkey"
            columns: ["organization_id", "season_id"]
            isOneToOne: false
            referencedRelation: "seasons"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "stat_origin_summaries_organization_id_team_id_fkey"
            columns: ["organization_id", "team_id"]
            isOneToOne: false
            referencedRelation: "teams"
            referencedColumns: ["organization_id", "id"]
          },
          {
            foreignKeyName: "stat_origin_summaries_person_id_fkey"
            columns: ["person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "stat_origin_summaries_sport_key_fkey"
            columns: ["sport_key"]
            isOneToOne: false
            referencedRelation: "game_sports"
            referencedColumns: ["key"]
          },
        ]
      }
      stat_refresh_work: {
        Row: {
          attempts: number
          created_at: string
          game_id: string
          target_generation: number
        }
        Insert: {
          attempts?: number
          created_at?: string
          game_id: string
          target_generation: number
        }
        Update: {
          attempts?: number
          created_at?: string
          game_id?: string
          target_generation?: number
        }
        Relationships: [
          {
            foreignKeyName: "stat_refresh_work_game_id_fkey"
            columns: ["game_id"]
            isOneToOne: true
            referencedRelation: "stat_game_selections"
            referencedColumns: ["game_id"]
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
      tournament_advancements: {
        Row: {
          actor_person_id: string
          advancement_kind: string
          bracket_id: string
          created_at: string
          destination_match_id: string | null
          destination_side: string | null
          edition_id: string
          generation: number
          id: string
          loser_entry_id: string | null
          reason: string
          revision_id: string
          source_finalization_count: number | null
          source_game_id: string | null
          source_match_id: string
          status: string
          supersedes_id: string | null
          winner_entry_id: string
        }
        Insert: {
          actor_person_id: string
          advancement_kind: string
          bracket_id: string
          created_at?: string
          destination_match_id?: string | null
          destination_side?: string | null
          edition_id: string
          generation: number
          id?: string
          loser_entry_id?: string | null
          reason: string
          revision_id: string
          source_finalization_count?: number | null
          source_game_id?: string | null
          source_match_id: string
          status?: string
          supersedes_id?: string | null
          winner_entry_id: string
        }
        Update: {
          actor_person_id?: string
          advancement_kind?: string
          bracket_id?: string
          created_at?: string
          destination_match_id?: string | null
          destination_side?: string | null
          edition_id?: string
          generation?: number
          id?: string
          loser_entry_id?: string | null
          reason?: string
          revision_id?: string
          source_finalization_count?: number | null
          source_game_id?: string | null
          source_match_id?: string
          status?: string
          supersedes_id?: string | null
          winner_entry_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "tournament_advancements_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tournament_advancements_bracket_id_destination_match_id_fkey"
            columns: ["bracket_id", "destination_match_id"]
            isOneToOne: false
            referencedRelation: "tournament_matches"
            referencedColumns: ["bracket_id", "id"]
          },
          {
            foreignKeyName: "tournament_advancements_bracket_id_revision_id_fkey"
            columns: ["bracket_id", "revision_id"]
            isOneToOne: false
            referencedRelation: "tournament_bracket_revisions"
            referencedColumns: ["bracket_id", "id"]
          },
          {
            foreignKeyName: "tournament_advancements_bracket_id_source_match_id_fkey"
            columns: ["bracket_id", "source_match_id"]
            isOneToOne: false
            referencedRelation: "tournament_matches"
            referencedColumns: ["bracket_id", "id"]
          },
          {
            foreignKeyName: "tournament_advancements_bracket_id_supersedes_id_fkey"
            columns: ["bracket_id", "supersedes_id"]
            isOneToOne: false
            referencedRelation: "tournament_advancements"
            referencedColumns: ["bracket_id", "id"]
          },
          {
            foreignKeyName: "tournament_advancements_edition_id_bracket_id_fkey"
            columns: ["edition_id", "bracket_id"]
            isOneToOne: false
            referencedRelation: "tournament_brackets"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "tournament_advancements_edition_id_loser_entry_id_fkey"
            columns: ["edition_id", "loser_entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "tournament_advancements_edition_id_winner_entry_id_fkey"
            columns: ["edition_id", "winner_entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
        ]
      }
      tournament_bracket_revisions: {
        Row: {
          actor_person_id: string
          bracket_id: string
          created_at: string
          edition_id: string
          id: string
          reason: string
          revision: number
          source_kind: string
          source_manifest: Json
          structure_digest: string
        }
        Insert: {
          actor_person_id: string
          bracket_id: string
          created_at?: string
          edition_id: string
          id?: string
          reason: string
          revision: number
          source_kind: string
          source_manifest: Json
          structure_digest: string
        }
        Update: {
          actor_person_id?: string
          bracket_id?: string
          created_at?: string
          edition_id?: string
          id?: string
          reason?: string
          revision?: number
          source_kind?: string
          source_manifest?: Json
          structure_digest?: string
        }
        Relationships: [
          {
            foreignKeyName: "tournament_bracket_revisions_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tournament_bracket_revisions_edition_id_bracket_id_fkey"
            columns: ["edition_id", "bracket_id"]
            isOneToOne: false
            referencedRelation: "tournament_brackets"
            referencedColumns: ["edition_id", "id"]
          },
        ]
      }
      tournament_brackets: {
        Row: {
          bracket_size: number
          bracket_type: string
          champion_entry_id: string | null
          configuration: Json
          created_at: string
          created_by_person_id: string
          current_revision: number
          edition_id: string
          id: string
          include_third_place: boolean
          name: string
          status: string
          updated_at: string
          version: number
        }
        Insert: {
          bracket_size: number
          bracket_type?: string
          champion_entry_id?: string | null
          configuration?: Json
          created_at?: string
          created_by_person_id: string
          current_revision?: number
          edition_id: string
          id?: string
          include_third_place?: boolean
          name: string
          status?: string
          updated_at?: string
          version?: number
        }
        Update: {
          bracket_size?: number
          bracket_type?: string
          champion_entry_id?: string | null
          configuration?: Json
          created_at?: string
          created_by_person_id?: string
          current_revision?: number
          edition_id?: string
          id?: string
          include_third_place?: boolean
          name?: string
          status?: string
          updated_at?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "tournament_brackets_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tournament_brackets_edition_id_champion_entry_id_fkey"
            columns: ["edition_id", "champion_entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "tournament_brackets_edition_id_fkey"
            columns: ["edition_id"]
            isOneToOne: false
            referencedRelation: "competition_editions"
            referencedColumns: ["id"]
          },
        ]
      }
      tournament_matches: {
        Row: {
          bracket_id: string
          created_at: string
          edition_id: string
          finalization_count: number | null
          game_id: string | null
          id: string
          label: string
          match_number: number
          opponent_entry_id: string | null
          opponent_source_kind: string
          opponent_source_match_id: string | null
          primary_entry_id: string | null
          primary_source_kind: string
          primary_source_match_id: string | null
          revision_id: string
          round_number: number
          source_organization_id: string | null
          stage_id: string
          status: string
          version: number
        }
        Insert: {
          bracket_id: string
          created_at?: string
          edition_id: string
          finalization_count?: number | null
          game_id?: string | null
          id?: string
          label: string
          match_number: number
          opponent_entry_id?: string | null
          opponent_source_kind: string
          opponent_source_match_id?: string | null
          primary_entry_id?: string | null
          primary_source_kind: string
          primary_source_match_id?: string | null
          revision_id: string
          round_number: number
          source_organization_id?: string | null
          stage_id: string
          status?: string
          version?: number
        }
        Update: {
          bracket_id?: string
          created_at?: string
          edition_id?: string
          finalization_count?: number | null
          game_id?: string | null
          id?: string
          label?: string
          match_number?: number
          opponent_entry_id?: string | null
          opponent_source_kind?: string
          opponent_source_match_id?: string | null
          primary_entry_id?: string | null
          primary_source_kind?: string
          primary_source_match_id?: string | null
          revision_id?: string
          round_number?: number
          source_organization_id?: string | null
          stage_id?: string
          status?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "tournament_matches_bracket_id_opponent_source_match_id_fkey"
            columns: ["bracket_id", "opponent_source_match_id"]
            isOneToOne: false
            referencedRelation: "tournament_matches"
            referencedColumns: ["bracket_id", "id"]
          },
          {
            foreignKeyName: "tournament_matches_bracket_id_primary_source_match_id_fkey"
            columns: ["bracket_id", "primary_source_match_id"]
            isOneToOne: false
            referencedRelation: "tournament_matches"
            referencedColumns: ["bracket_id", "id"]
          },
          {
            foreignKeyName: "tournament_matches_bracket_id_revision_id_fkey"
            columns: ["bracket_id", "revision_id"]
            isOneToOne: false
            referencedRelation: "tournament_bracket_revisions"
            referencedColumns: ["bracket_id", "id"]
          },
          {
            foreignKeyName: "tournament_matches_edition_id_bracket_id_fkey"
            columns: ["edition_id", "bracket_id"]
            isOneToOne: false
            referencedRelation: "tournament_brackets"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "tournament_matches_edition_id_opponent_entry_id_fkey"
            columns: ["edition_id", "opponent_entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "tournament_matches_edition_id_primary_entry_id_fkey"
            columns: ["edition_id", "primary_entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "tournament_matches_edition_id_stage_id_fkey"
            columns: ["edition_id", "stage_id"]
            isOneToOne: false
            referencedRelation: "tournament_stages"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "tournament_matches_source_organization_id_game_id_fkey"
            columns: ["source_organization_id", "game_id"]
            isOneToOne: false
            referencedRelation: "games"
            referencedColumns: ["organization_id", "id"]
          },
        ]
      }
      tournament_rulings: {
        Row: {
          actor_person_id: string
          bracket_id: string
          created_at: string
          edition_id: string
          id: string
          kind: string
          loser_entry_id: string | null
          match_id: string
          reason: string
          reversal_of_id: string | null
          winner_entry_id: string | null
        }
        Insert: {
          actor_person_id: string
          bracket_id: string
          created_at?: string
          edition_id: string
          id?: string
          kind: string
          loser_entry_id?: string | null
          match_id: string
          reason: string
          reversal_of_id?: string | null
          winner_entry_id?: string | null
        }
        Update: {
          actor_person_id?: string
          bracket_id?: string
          created_at?: string
          edition_id?: string
          id?: string
          kind?: string
          loser_entry_id?: string | null
          match_id?: string
          reason?: string
          reversal_of_id?: string | null
          winner_entry_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "tournament_rulings_actor_person_id_fkey"
            columns: ["actor_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tournament_rulings_bracket_id_match_id_fkey"
            columns: ["bracket_id", "match_id"]
            isOneToOne: false
            referencedRelation: "tournament_matches"
            referencedColumns: ["bracket_id", "id"]
          },
          {
            foreignKeyName: "tournament_rulings_bracket_id_reversal_of_id_fkey"
            columns: ["bracket_id", "reversal_of_id"]
            isOneToOne: false
            referencedRelation: "tournament_rulings"
            referencedColumns: ["bracket_id", "id"]
          },
          {
            foreignKeyName: "tournament_rulings_edition_id_bracket_id_fkey"
            columns: ["edition_id", "bracket_id"]
            isOneToOne: false
            referencedRelation: "tournament_brackets"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "tournament_rulings_edition_id_loser_entry_id_fkey"
            columns: ["edition_id", "loser_entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "tournament_rulings_edition_id_winner_entry_id_fkey"
            columns: ["edition_id", "winner_entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
        ]
      }
      tournament_seeds: {
        Row: {
          bracket_id: string
          created_at: string
          edition_id: string
          entry_id: string
          id: string
          override_reason: string | null
          revision_id: string
          seed: number
          source_generation: number | null
          source_rank: number | null
          source_scope_id: string | null
        }
        Insert: {
          bracket_id: string
          created_at?: string
          edition_id: string
          entry_id: string
          id?: string
          override_reason?: string | null
          revision_id: string
          seed: number
          source_generation?: number | null
          source_rank?: number | null
          source_scope_id?: string | null
        }
        Update: {
          bracket_id?: string
          created_at?: string
          edition_id?: string
          entry_id?: string
          id?: string
          override_reason?: string | null
          revision_id?: string
          seed?: number
          source_generation?: number | null
          source_rank?: number | null
          source_scope_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "tournament_seeds_bracket_id_revision_id_fkey"
            columns: ["bracket_id", "revision_id"]
            isOneToOne: false
            referencedRelation: "tournament_bracket_revisions"
            referencedColumns: ["bracket_id", "id"]
          },
          {
            foreignKeyName: "tournament_seeds_edition_id_bracket_id_fkey"
            columns: ["edition_id", "bracket_id"]
            isOneToOne: false
            referencedRelation: "tournament_brackets"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "tournament_seeds_edition_id_entry_id_fkey"
            columns: ["edition_id", "entry_id"]
            isOneToOne: false
            referencedRelation: "competition_entries"
            referencedColumns: ["edition_id", "id"]
          },
          {
            foreignKeyName: "tournament_seeds_source_scope_id_fkey"
            columns: ["source_scope_id"]
            isOneToOne: false
            referencedRelation: "ranking_scopes"
            referencedColumns: ["id"]
          },
        ]
      }
      tournament_stages: {
        Row: {
          configuration: Json
          created_at: string
          created_by_person_id: string
          edition_id: string
          id: string
          name: string
          stage_order: number
          stage_type: string
          status: string
          version: number
        }
        Insert: {
          configuration?: Json
          created_at?: string
          created_by_person_id: string
          edition_id: string
          id?: string
          name: string
          stage_order: number
          stage_type: string
          status?: string
          version?: number
        }
        Update: {
          configuration?: Json
          created_at?: string
          created_by_person_id?: string
          edition_id?: string
          id?: string
          name?: string
          stage_order?: number
          stage_type?: string
          status?: string
          version?: number
        }
        Relationships: [
          {
            foreignKeyName: "tournament_stages_created_by_person_id_fkey"
            columns: ["created_by_person_id"]
            isOneToOne: false
            referencedRelation: "people"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "tournament_stages_edition_id_fkey"
            columns: ["edition_id"]
            isOneToOne: false
            referencedRelation: "competition_editions"
            referencedColumns: ["id"]
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
      boss_achievement_mutate: { Args: { p_command: Json }; Returns: Json }
      boss_achievement_read: { Args: { p_query?: Json }; Returns: Json }
      boss_admin_mutate: {
        Args: { p_commands: Json; p_request_id: string }
        Returns: Json
      }
      boss_admin_read: {
        Args: { p_organization_id?: string; p_query?: string; p_view: string }
        Returns: Json
      }
      boss_athlete_career_read: { Args: { p_query?: Json }; Returns: Json }
      boss_athlete_history_read: { Args: { p_query?: Json }; Returns: Json }
      boss_athlete_profile_mutate: { Args: { command: Json }; Returns: Json }
      boss_athlete_profile_navigation: { Args: never; Returns: boolean }
      boss_athlete_profile_read: {
        Args: { p_participant_id?: string; p_profile_id?: string }
        Returns: Json
      }
      boss_athlete_season_read: { Args: { p_query?: Json }; Returns: Json }
      boss_attendance_mutate: {
        Args: { p_command: Json; p_request_id: string }
        Returns: Json
      }
      boss_attendance_read: { Args: { p_query: Json }; Returns: Json }
      boss_bucks_mutate: { Args: { command: Json }; Returns: Json }
      boss_bucks_read: { Args: { query?: Json }; Returns: Json }
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
      boss_fundraising_mutate: { Args: { command: Json }; Returns: Json }
      boss_fundraising_navigation: { Args: never; Returns: boolean }
      boss_fundraising_public: {
        Args: { offset_ordinal?: number; path: string }
        Returns: Json
      }
      boss_fundraising_read: { Args: { query: Json }; Returns: Json }
      boss_fundraising_support: { Args: { command: Json }; Returns: Json }
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
      boss_ranking_mutate: { Args: { p_command: Json }; Returns: Json }
      boss_ranking_read: { Args: { p_query?: Json }; Returns: Json }
      boss_recruiting_showcase_read: {
        Args: { p_token_digest: string }
        Returns: Json
      }
      boss_registration_mutate: {
        Args: { p_command: Json; p_request_id: string }
        Returns: Json
      }
      boss_registration_read: { Args: { p_query?: Json }; Returns: Json }
      boss_stat_competition_classify: {
        Args: {
          p_class: string
          p_game: string
          p_reason: string
          p_request: string
        }
        Returns: Json
      }
      boss_stat_rebuild: {
        Args: { p_after_game?: string; p_kind: string; p_query: Json }
        Returns: Json
      }
      boss_team_season_read: { Args: { p_query?: Json }; Returns: Json }
      boss_tournament_mutate: { Args: { p_command: Json }; Returns: Json }
      boss_tournament_read: { Args: { p_query?: Json }; Returns: Json }
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

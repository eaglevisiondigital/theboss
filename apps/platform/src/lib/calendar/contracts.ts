export type CalendarDisplay = "month" | "week" | "day" | "agenda";
export type CalendarScope = "personal" | "organization" | "team";
export type TargetType = "organization" | "unit" | "team";
export type EventStatus = "draft" | "scheduled" | "confirmed" | "canceled" | "postponed" | "completed" | "archived";
export type EventVisibility = "public" | "authenticated" | "member" | "restricted" | "private";
export type CalendarTarget = { target_type: TargetType; target_id: string; label: string };
export type Recurrence = { frequency: "daily" | "weekly" | "monthly"; interval: number; weekdays?: number[]; count?: number; until?: string };
export type Reminder = { minutes_before: number; audience: string[]; enabled: boolean };
export type Game = { opponent_team_id: string | null; external_opponent_name: string | null; home_away: "home" | "away" | "neutral"; game_status: "scheduled" | "postponed" | "canceled" | "completed" };
export type CalendarFeatures = { organization_calendar: boolean; team_calendar: boolean; recurrence: boolean; public_schedules: boolean; conflicts: boolean; head_coach_management: boolean; attendance: boolean; conflict_overrides?: boolean };
export type Occurrence = {
  event_id: string; organization_id: string; occurrence_key: string; start_at: string; end_at: string;
  arrival_at: string | null; timezone: string; all_day: boolean; title: string; description: string | null;
  event_type_key: string; status: EventStatus; visibility: EventVisibility; publication_state: "unpublished" | "published";
  rsvp_mode: "not_required" | "optional" | "required"; instructions: string | null; audience: string[];
  venue_id: string | null; resource_id: string | null; targets: CalendarTarget[]; game: Game | null;
  reminders: Reminder[]; recurrence: Recurrence | null; is_exception: boolean; exception_id: string | null; version: number;
  series_start_at: string | null; series_end_at: string | null; series_arrival_at: string | null;
  series_title: string | null; series_instructions: string | null; series_status: EventStatus | null;
  capabilities: { manage: boolean; publish: boolean; override_conflict: boolean };
};
export type Venue = { id: string; organization_id: string; name: string; timezone: string; instructions: string | null; address_line1: string | null; address_line2: string | null; city: string | null; region: string | null; postal_code: string | null; country_code: string | null; is_public: boolean; version?: number; status?: "active" | "inactive" | "archived" };
export type CalendarData = {
  range: { from: string; to: string };
  organizations: { id: string; name: string; timezone: string }[];
  units: { id: string; organization_id: string; name: string }[];
  teams: { id: string; organization_id: string; parent_unit_id: string | null; season_id: string | null; name: string }[];
  seasons: { id: string; organization_id: string; name: string }[];
  children: { id: string; name: string }[]; event_types: { key: string; name: string }[];
  venues: Venue[]; resources: { id: string; organization_id: string; venue_id: string; name: string; resource_type: string; is_public: boolean; version?: number; status?: "active" | "inactive" | "archived" }[];
  features: CalendarFeatures;
  capabilities: { create: boolean; manage_venues: boolean; configure: boolean; publish: boolean; override_conflict: boolean; create_targets: CalendarTarget[] };
  occurrences: Occurrence[]; options_limited?: boolean; unavailable?: boolean;
};
export type CalendarQuery = { from: string; to: string; view: CalendarScope; organization_id?: string; unit_id?: string; team_id?: string; season_id?: string; child_id?: string; event_type_key?: string; location_id?: string };
export type CalendarSelection = { display: CalendarDisplay; date: string; timezone: string; query: CalendarQuery; invalid?: boolean };
export type EventInput = {
  organization_id: string; title: string; description: string | null; event_type_key: string; start_at: string; end_at: string; timezone: string;
  all_day: boolean; arrival_at: string | null; status: EventStatus; visibility: EventVisibility; publication_state: "unpublished" | "published";
  venue_id: string | null; resource_id: string | null; instructions: string | null; rsvp_mode: "not_required" | "optional" | "required";
  audience: string[]; recurrence: Recurrence | null; targets: { target_type: TargetType; target_id: string }[]; reminders: Reminder[]; game: Game | null;
  override_conflicts: boolean; reset_exceptions?: boolean; event_id?: string; expected_version?: number;
};
export type ExceptionInput = { event_id: string; expected_version: number; occurrence_key: string; override_start_at?: string; override_end_at?: string; override_arrival_at?: string | null; status?: Exclude<EventStatus, "draft" | "archived">; title?: string; instructions?: string | null; override_conflicts?: boolean };
export type VenueInput = { organization_id: string; name: string; timezone: string; address_line1: string | null; address_line2: string | null; city: string | null; region: string | null; postal_code: string | null; country_code: string | null; instructions: string | null; status: "active" | "inactive"; is_public: boolean; venue_id?: string; expected_version?: number };
export type ResourceInput = { organization_id: string; venue_id: string; name: string; resource_type: string; status: "active" | "inactive"; is_public: boolean; resource_id?: string; expected_version?: number };
export type CalendarCommand =
  | { operation: "event.create" | "event.update"; input: EventInput }
  | { operation: "event.exception"; input: ExceptionInput }
  | { operation: "venue.create" | "venue.update"; input: VenueInput }
  | { operation: "resource.create" | "resource.update"; input: ResourceInput }
  | { operation: "calendar.configure"; input: { organization_id: string; features: Partial<CalendarFeatures> } };
export type CalendarConflict = { kind: "resource" | "team" | "coach" | "participant"; event_id: string | null; title: string; start_at: string; end_at: string };
export type CalendarPreview = { conflicts: CalendarConflict[]; has_conflicts: boolean; can_override: boolean };
export type CalendarMutationResult = { request_id: string; resource_type: string; resource_id: string; version: number };
export const defaultFeatures: CalendarFeatures = { organization_calendar: true, team_calendar: true, recurrence: true, conflicts: true, public_schedules: false, head_coach_management: false, conflict_overrides: false, attendance: false };
export function emptyCalendar(query: CalendarQuery, unavailable = false): CalendarData {
  return { range: { from: query.from, to: query.to }, organizations: [], units: [], teams: [], seasons: [], children: [], event_types: [], venues: [], resources: [], occurrences: [], features: Object.fromEntries(Object.keys(defaultFeatures).map(key => [key, false])) as CalendarFeatures, capabilities: { create: false, manage_venues: false, configure: false, publish: false, override_conflict: false, create_targets: [] }, unavailable };
}

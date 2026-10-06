import { isRecord } from "../coordination/input";
import { statUuid } from "../stat-intelligence/input";
import type { AthleteProfileData, AthleteProfileView, AthleteSubject, RecruitingShowcase } from "./contracts";
const records = (value: unknown) => Array.isArray(value) ? value.filter(isRecord) : [];
export function projectAthleteProfiles(value: unknown): AthleteProfileData | null {
  if (!isRecord(value) || !Array.isArray(value.subjects) || value.subjects.length > 50) return null;
  const rawSubjects = records(value.subjects); if (rawSubjects.length !== value.subjects.length || rawSubjects.some(v => !statUuid(v.profile_id) || !statUuid(v.participant_id) || !statUuid(v.person_id) || typeof v.display_name !== "string")) return null;
  const subjects = rawSubjects as AthleteSubject[];
  if (value.profile === null) return { subjects, profile: null, restricted: false, unavailable: value.unavailable === true };
  if (!isRecord(value.profile) || !isRecord(value.profile.profile) || !statUuid(value.profile.profile.id) || !isRecord(value.profile.authority)) return null;
  return { subjects, profile: value.profile as unknown as AthleteProfileView, restricted: false, unavailable: false };
}
export function projectShowcase(value: unknown): RecruitingShowcase | null {
  if (!isRecord(value) || typeof value.available !== "boolean") return null;
  if (!value.available) return { available: false };
  if (!statUuid(value.showcase_id) || !isRecord(value.athlete) || !Array.isArray(value.sports) || !isRecord(value.privacy) || value.privacy.searchable !== false || value.privacy.contact_details_exposed !== false) return null;
  return value as unknown as RecruitingShowcase;
}
export function athleteProfileId(value: unknown) { return typeof value === "string" && statUuid(value) ? value : undefined; }

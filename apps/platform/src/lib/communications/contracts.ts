import type { Json } from "../supabase/database.types";

export const threadKinds = ["organization_staff", "program", "team_chat", "coach_staff", "direct", "group", "family"] as const;
export type ThreadKind = typeof threadKinds[number];
export const communicationOperations = ["thread.create", "thread.update", "message.send", "message.edit", "message.remove", "message.pin", "announcement.send", "read.message", "read.thread", "report.create", "report.moderate", "communications.configure", "guardian.configure", "attachment.intent", "attachment.complete", "attachment.access"] as const;
export type CommunicationOperation = typeof communicationOperations[number];
export type CommunicationCommand = { operation: CommunicationOperation; input: Record<string, Json | undefined> };
export type CommunicationQuery = { view: "messages" | "announcements" | "summary"; organization_id?: string; thread_id?: string; team_id?: string; before_sequence?: number; query?: string };
export type Choice = { id: string; label: string; organization_id?: string; operations: CommunicationOperation[] };
export type CommunicationTarget = { scope_type: "organization" | "unit" | "team"; scope_id: string; label: string; operations: CommunicationOperation[]; thread_kinds: ThreadKind[] };
export type CommunicationThread = { id: string; organization_id: string; title: string; kind: string; scope_type: string; scope_id: string | null; status: string; version: number; unread_count: number; latest_at: string | null; operations: CommunicationOperation[]; members: Choice[] };
export type CommunicationAttachment = { id: string; filename: string; mime_type: string; size_bytes: number; status: string; operations: CommunicationOperation[] };
export type CommunicationMessage = { id: string; body: string | null; author_name: string; author_person_id: string | null; sequence: number; version: number; created_at: string; edited_at: string | null; status: string; pinned: boolean; operations: CommunicationOperation[]; attachments: CommunicationAttachment[] };
export type CommunicationReport = { id: string; message_id: string; reason: string; status: string; created_at: string; operations: CommunicationOperation[] };
export type CommunicationGuardian = { id: string; guardian_name: string; dependent_name: string; can_receive_communications: boolean; can_send_communications: boolean; operations: CommunicationOperation[] };
export type CommunicationData = { person: Choice | null; organizations: Choice[]; organizationId: string | null; features: Record<string, boolean | number>; operations: CommunicationOperation[]; threads: CommunicationThread[]; detail: { thread: CommunicationThread; messages: CommunicationMessage[] } | null; candidates: Choice[]; teams: Choice[]; units: Choice[]; targets: CommunicationTarget[]; audienceRoles: { key: string; label: string; allowed_scope_types: string[] }[]; households: Choice[]; reports: CommunicationReport[]; guardians: CommunicationGuardian[]; unread: { messages: number; channels: number }; more: boolean; cursor: number | null; unavailable?: boolean };
export type CommunicationResult = { request_id: string; operation: CommunicationOperation; resource_id: string; version: number };
export const emptyCommunications: CommunicationData = { person: null, organizations: [], organizationId: null, features: {}, operations: [], threads: [], detail: null, candidates: [], teams: [], units: [], targets: [], audienceRoles: [], households: [], reports: [], guardians: [], unread: { messages: 0, channels: 0 }, more: false, cursor: null };

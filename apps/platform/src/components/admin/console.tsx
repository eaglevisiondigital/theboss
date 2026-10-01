"use client";

import Link from "next/link";
import { useState } from "react";
import type { AdminCommand, AdminField, AdminRecord, AdminView, AdminViewData } from "./types";
import { editFields, guardianFlags, organizationFields, personFields, seasonFields, select, status, teamFields, text, unitFields, windowFields } from "./fields";
import { MutationForm } from "./mutation-form";
import { OrganizationContext } from "./context-switcher";
import { RecordList } from "./record-list";

const viewCopy: Record<AdminView, { title: string; description: string }> = {
  home: { title: "Your Boss workspace.", description: "Build the connections that make your organization work." },
  organizations: { title: "Organizations.", description: "Organization settings, modules, units and seasons in one place." },
  people: { title: "People.", description: "Find an existing Boss person before creating a new identity." },
  families: { title: "Families.", description: "Connect people through explicit household and guardian relationships." },
  teams: { title: "Teams.", description: "Build teams and their foundational participant and staff memberships." },
  access: { title: "Access.", description: "Manage memberships and assign only the scoped capabilities you can grant." },
  audit: { title: "Audit history.", description: "A read-only record of authorized changes in your accessible context." },
  account: { title: "Your Boss account.", description: "One persistent identity for your Boss connections." },
};

function rows(data: AdminViewData, collection: string): AdminRecord[] {
  return (data.records[collection] ?? []).map((record) => {
    const fields = { ...record.fields };
    const relationships: [string, string, string][] = [["parent_unit_id", "units", "parent_label"], ["season_id", "seasons", "season_label"], ["person_id", "people", "person_label"], ["guardian_person_id", "people", "guardian_label"], ["dependent_person_id", "people", "dependent_label"], ["household_id", "households", "household_label"], ["team_id", "teams", "team_label"], ["role_id", "roles", "role_label"]];
    for (const [idKey, source, labelKey] of relationships) {
      const related = data.records[source]?.find((row) => row.id === fields[idKey]);
      if (related) fields[labelKey] = related.label;
    }
    if (fields.scope_type === "platform") fields.scope_label = "Platform";
    else if (typeof fields.scope_id === "string") {
      const scopeSource = fields.scope_type === "organization" ? data.organizations : fields.scope_type === "organization_unit" ? data.records.units : data.records.teams;
      fields.scope_label = scopeSource?.find((row) => row.id === fields.scope_id)?.label ?? "Scoped resource";
    }
    return { ...record, fields };
  });
}
function can(data: AdminViewData, operation: string): boolean { return data.operations.includes(operation); }
function rowCan(record: AdminRecord, operation: string): boolean { return record.operations?.includes(operation) === true; }
function safeValue(record: AdminRecord, key: string): string {
  const value = record.fields[key];
  return typeof value === "string" || typeof value === "number" ? String(value) : "";
}

function Section({ title, description, children }: { title: string; description?: string; children: React.ReactNode }) {
  return <section className="admin-section"><div className="section-heading"><h2>{title}</h2>{description && <p>{description}</p>}</div>{children}</section>;
}

function Create({ title, children }: { title: string; children: React.ReactNode }) {
  return <details className="create-card"><summary><span className="plus-mark" aria-hidden="true">+</span>{title}</summary><div className="create-card-content">{children}</div></details>;
}

function Edit({ record, operation, title, fields, context = {} }: { data: AdminViewData; record: AdminRecord; operation: string; title: string; fields: AdminField[]; context?: Record<string, unknown> }) {
  if (!rowCan(record, operation)) return null;
  return <details className="record-edit"><summary>{title}</summary><MutationForm title={title} operation={operation} initialInput={{ id: record.id, ...context }} fields={editFields(fields, record)} /></details>;
}

function SummaryFields({ record, fields }: { record: AdminRecord; fields: [string, string][] }) {
  const visible = fields.filter(([key]) => safeValue(record, key));
  return visible.length ? <dl className="record-meta">{visible.map(([key, label]) => <div key={key}><dt>{label}</dt><dd>{safeValue(record, key)}</dd></div>)}</dl> : null;
}

function Search({ data, label, query, preserveContext = true }: { data: AdminViewData; label: string; query?: string; preserveContext?: boolean }) {
  return <form method="get" className="record-search"><label htmlFor="record-search">{label}</label><div>{preserveContext && data.organizationId && <input type="hidden" name="org" value={data.organizationId} />}<input id="record-search" name="q" type="search" maxLength={80} defaultValue={query ?? ""} placeholder="Search by name" /><button className="button button-outline button-small" type="submit">Search</button></div></form>;
}

export function AdminConsole(props: { view: AdminView; data: AdminViewData; query?: string }) {
  return <ConsoleContent key={`${props.view}:${props.data.organizationId ?? "platform"}`} {...props} />;
}

function ConsoleContent({ view, data, query }: { view: AdminView; data: AdminViewData; query?: string }) {
  const copy = viewCopy[view];
  return <>
    <div className="page-heading admin-page-heading"><p className="eyebrow muted">{view === "home" ? "Your workspace" : view}</p><h1>{copy.title}</h1><p>{copy.description}</p></div>
    {data.unavailable ? <div className="form-notice" role="status">Your workspace is temporarily unavailable. Refresh the page to try again.</div> : !data.provisioned ? <Provisioning /> : <>
      {view !== "account" && <OrganizationContext organizations={data.organizations} selected={data.organizationId} />}
      {view === "home" && <Home data={data} />}
      {view === "organizations" && <Organizations data={data} query={query} />}
      {view === "people" && <People data={data} query={query} />}
      {view === "families" && <Families data={data} query={query} />}
      {view === "teams" && <Teams data={data} />}
      {view === "access" && <Access data={data} />}
      {view === "audit" && <Audit data={data} />}
      {view === "account" && <Account data={data} />}
    </>}
  </>;
}

function Provisioning() {
  return <Section title="Connect your Boss identity" description="Create your canonical Boss person to use this account. If you already have a Boss person record, ask an authorized administrator to link it first.">
    <MutationForm title="Create your Boss identity" operation="identity.provision_self" fields={[text("display_name", "Display name", true)]} buttonLabel="Connect my account" description="Creating an identity does not grant administrative permissions." />
  </Section>;
}

function Home({ data }: { data: AdminViewData }) {
  const destinations = data.navigation.filter((item) => item !== "audit");
  const labels: Record<string, string> = { organizations: "Organizations", people: "People", families: "Families", teams: "Teams", access: "Access" };
  const descriptions: Record<string, string> = { organizations: "Configure an organization, its units and seasons.", people: "Find people and manage participant identities.", families: "Connect households and verify guardian authority.", teams: "Manage teams and their foundational rosters.", access: "Manage memberships and scoped roles." };
  return <>
    <section className="workspace-intro"><div><p className="eyebrow"><span className="eyebrow-mark" aria-hidden="true" />Boss operational core</p><h2>Welcome, {data.person?.label ?? "Boss member"}.</h2><p>Your available tools follow your current permissions and relationships.</p></div><span className="workspace-word" aria-hidden="true">BOSS.</span></section>
    {destinations.length ? <div className="workspace-cards">{destinations.map((view) => <Link className="workspace-card" href={`/app/${view}${data.organizationId ? `?org=${data.organizationId}` : ""}`} key={view}><span className="eyebrow muted">Your tools</span><h2>{labels[view]}</h2><p>{descriptions[view]}</p><span className="card-link">Open {labels[view].toLowerCase()} <span aria-hidden="true">↗</span></span></Link>)}</div> : <p className="empty-state">Your Boss identity is connected. Administrative tools appear when you have an authorized role.</p>}
    {data.navigation.includes("organizations") && <Section title="Start with the foundation" description="Work through organization setup before adding team relationships."><ol className="workflow-steps"><li>Create an organization</li><li>Activate Sports configuration</li><li>Create a unit and season</li><li>Create a team</li><li>Add people and participants</li><li>Assign explicit memberships and roles</li></ol></Section>}
  </>;
}

function Organizations({ data, query }: { data: AdminViewData; query?: string }) {
  const orgInput = data.organizationId ? { organization_id: data.organizationId } : {};
  return <>
    <Section title="Organization records">
      <Search data={data} label="Find an organization" query={query} preserveContext={false} />
      {can(data, "organization.create") && <OrganizationCreate data={data} />}
      <RecordList records={rows(data, "organizations").filter((record) => !data.organizationId || record.id === data.organizationId)} empty="No organization records are available in this context.">{(record) => <><SummaryFields record={record} fields={[["organization_type", "Type"], ["timezone", "Timezone"], ["country", "Country"], ["slug", "Slug"]]} /><Edit data={data} record={record} operation="organization.update" title="Edit organization" fields={organizationFields} /></>}</RecordList>
    </Section>
    {data.organizationId && <>
      <Section title="Modules" description="Activate the modules available to your organization. Calendar is independent from Sports.">
        <div className="module-grid">{rows(data, "modules").map((module) => {
          const activation = module.fields.activation_status === "active" ? "active" : "inactive";
          return <article className="module-card" key={module.id}><div className="record-heading"><h3>{module.label}</h3><span className={`status-pill status-${activation}`}>{activation}</span></div><p className="module-future">{module.fields.module_key === "calendar" ? "Events and calendar are available when this module is active." : "Future product capabilities are not implemented."}</p>{module.fields.module_key === "calendar" && activation === "active" && <Link className="button button-outline button-small" href={`/app/calendar?org=${data.organizationId}`}>Open calendar</Link>}{(rowCan(module, "module.set") || can(data, "module.set")) && <MutationForm title={`Set ${module.label} activation`} operation="module.set" initialInput={{ ...orgInput, module_id: typeof module.fields.module_id === "string" ? module.fields.module_id : module.id }} fields={[{ name: "status", label: "Activation", type: "select", required: true, value: activation, options: [{ value: "active", label: "Active" }, { value: "inactive", label: "Inactive" }] }]} buttonLabel="Save activation" />}</article>;
        })}</div>
      </Section>
      <Section title="Organization units" description="A hierarchy organizes records. Access remains scoped to the exact assigned unit.">
        {can(data, "unit.create") && <Create title="Create unit"><MutationForm title="New organization unit" operation="unit.create" initialInput={orgInput} fields={unitFields(data)} buttonLabel="Create unit" /></Create>}
        <RecordList records={rows(data, "units")} empty="No units are available.">{(record) => <><SummaryFields record={record} fields={[["unit_type", "Type"], ["parent_label", "Parent"], ["slug", "Slug"]]} /><Edit data={data} record={record} operation="unit.update" title="Edit unit" fields={unitFields(data).map((field) => field.name === "parent_unit_id" ? { ...field, options: field.options?.filter((option) => option.value !== record.id) } : field)} /></>}</RecordList>
      </Section>
      <Section title="Seasons">
        <ScopedCreate data={data} operation="season.create" title="Create season" fields={seasonFields(data)} />
        <RecordList records={rows(data, "seasons")} empty="No seasons are available.">{(record) => <><SummaryFields record={record} fields={[["parent_label", "Unit"], ["starts_on", "Starts"], ["ends_on", "Ends"]]} /><Edit data={data} record={record} operation="season.update" title="Edit season" fields={seasonFields(data, true)} /></>}</RecordList>
      </Section>
    </>}
  </>;
}

function OrganizationCreate({ data }: { data: AdminViewData }) {
  const [includeMember, setIncludeMember] = useState(false);
  const organizationRoles = rows(data, "roles").filter((role) => Array.isArray(role.fields.allowed_scope_types) && role.fields.allowed_scope_types.includes("organization"));
  return <Create title="Create organization">
    {can(data, "organization_membership.add") && <div className="workflow-option"><label><input type="checkbox" checked={includeMember} onChange={(event) => setIncludeMember(event.currentTarget.checked)} />Include an initial organization member in this transaction</label></div>}
    <MutationForm title="New organization" sections={[{ fields: organizationFields }, ...(includeMember ? [{ title: "Explicit initial membership", fields: [select("initial_person_id", "Existing canonical person", rows(data, "people")), { ...text("initial_membership_type", "Membership type", true), value: "member" }, ...(can(data, "role_assignment.add") ? [select("initial_role_id", "Optional organization role", organizationRoles, false)] : [])] }] : [])]} buildCommands={(values) => {
      const input = Object.fromEntries(organizationFields.filter((field) => values[field.name] !== undefined).map((field) => [field.name, values[field.name]]));
      const commands: AdminCommand[] = [{ operation: "organization.create", ref: "new_organization", input }];
      if (includeMember) {
        commands.push({ operation: "organization_membership.add", input: { organization_id: { $ref: "new_organization" }, person_id: values.initial_person_id, membership_type: values.initial_membership_type, status: "active" } });
        if (values.initial_role_id) commands.push({ operation: "role_assignment.add", input: { organization_id: { $ref: "new_organization" }, scope_id: { $ref: "new_organization" }, scope_type: "organization", person_id: values.initial_person_id, role_id: values.initial_role_id, status: "active" } });
      }
      return commands;
    }} buttonLabel="Create organization" />
  </Create>;
}

function ScopedCreate({ data, operation, title, fields }: { data: AdminViewData; operation: string; title: string; fields: AdminField[] }) {
  const availableUnits = rows(data, "units").filter((unit) => rowCan(unit, operation));
  const global = can(data, operation);
  if (!data.organizationId || (!global && !availableUnits.length)) return null;
  const scopedFields = global ? fields : fields.map((field) => field.name === "parent_unit_id" ? { ...field, required: true, options: availableUnits.map((unit) => ({ value: unit.id, label: unit.label })) } : field);
  return <Create title={title}><MutationForm title={title} operation={operation} initialInput={{ organization_id: data.organizationId }} fields={scopedFields} buttonLabel={title} /></Create>;
}

function People({ data, query }: { data: AdminViewData; query?: string }) {
  const participantPeople = rows(data, "people").filter((person) => person.status === "active" && rowCan(person, "participant.create") && !rows(data, "participants").some((participant) => participant.fields.person_id === person.id));
  return <>
    <Section title="Canonical people" description="Names alone do not establish a match. Use the existing person when linking a relationship.">
      {(data.organizationId || can(data, "person.create")) && <Search data={data} label="Find a person" query={query} />}
      {can(data, "person.create") && <Create title="Create person"><MutationForm title="New person" description="This record does not create an Auth account." operation="person.create" fields={personFields} buttonLabel="Create person" /></Create>}
      <RecordList records={rows(data, "people")} empty="No people match in your authorized context.">{(record) => <Edit data={data} record={record} operation="person.update" title="Edit non-sensitive profile" fields={can(data, "person.create") ? personFields : personFields.filter((field) => field.name !== "status")} />}</RecordList>
    </Section>
    <Section title="Participants" description="A participant is a persistent person identity and does not require an Auth account.">
      {participantPeople.length > 0 && <Create title="Create participant"><MutationForm title="New participant" operation="participant.create" initialInput={data.organizationId ? { organization_id: data.organizationId } : {}} fields={[select("person_id", "Existing person", participantPeople), { ...text("participant_type", "Participant type", true), value: "participant" }, status()]} buttonLabel="Create participant" /></Create>}
      <RecordList records={rows(data, "participants")} empty="No participant records are available.">{(record) => <><SummaryFields record={record} fields={[["participant_type", "Type"], ["person_label", "Person"]]} /><Edit data={data} record={record} operation="participant.update" title="Edit participant" context={data.organizationId ? { organization_id: data.organizationId } : {}} fields={[text("participant_type", "Participant type", true), status()]} /></>}</RecordList>
    </Section>
  </>;
}

function Families({ data, query }: { data: AdminViewData; query?: string }) {
  return <>
    <Section title="Households" description="Household membership and guardian authority are separate relationships.">
      <Search data={data} label="Find a household" query={query} />
      {can(data, "household.create") && <Create title="Create household"><MutationForm title="New household" operation="household.create" fields={[text("name", "Household name", true), status()]} buttonLabel="Create household" /></Create>}
      <RecordList records={rows(data, "households")} empty="No households are available in your authorized context.">{(record) => <Edit data={data} record={record} operation="household.update" title="Edit household" fields={[text("name", "Household name", true), status()]} />}</RecordList>
    </Section>
    <Section title="Household members">
      {can(data, "household_membership.add") && <Create title="Add existing person"><MutationForm title="Add household member" operation="household_membership.add" fields={[select("household_id", "Household", rows(data, "households")), select("person_id", "Person", rows(data, "people")), { ...text("relationship_type", "Relationship type", true), value: "member" }, { name: "is_primary_contact", label: "Primary contact", type: "checkbox" }, ...windowFields(), status()]} buttonLabel="Add member" /></Create>}
      <RecordList records={rows(data, "household_memberships")} empty="No household memberships are available.">{(record) => <><SummaryFields record={record} fields={[["household_label", "Household"], ["person_label", "Person"], ["relationship_type", "Relationship"], ["ends_at", "Ends"]]} />{record.fields.is_primary_contact === true && <p className="record-note">Primary contact</p>}<Edit data={data} record={record} operation="household_membership.update" title="Change membership status" fields={[{ name: "is_primary_contact", label: "Primary contact", type: "checkbox" }, ...windowFields(false), status()]} /></>}</RecordList>
    </Section>
    {can(data, "person.create") && can(data, "participant.create") && can(data, "household_membership.add") && <FamilyWorkflow data={data} />}
    <Section title="Guardian authority" description="Verification and capability flags are explicit. Registration, waivers, documents and payment product workflows are future capabilities.">
      {can(data, "guardian.create") && <Create title="Create guardian relationship"><MutationForm title="New guardian relationship" operation="guardian.create" fields={[select("guardian_person_id", "Guardian", rows(data, "people")), select("dependent_person_id", "Dependent", rows(data, "people")), { ...text("relationship_type", "Relationship type", true), value: "guardian" }, { ...status("authority_status"), value: "pending" }, ...windowFields(), ...guardianFlags]} buttonLabel="Create relationship" /></Create>}
      <RecordList records={rows(data, "guardians")} empty="No guardian relationships are available.">{(record) => <><SummaryFields record={record} fields={[["guardian_label", "Guardian"], ["dependent_label", "Dependent"], ["relationship_type", "Relationship"]]} /><p className="record-note">{record.fields.verified_at ? "Verified relationship" : "Awaiting verification"}</p><Edit data={data} record={record} operation="guardian.update" title="Manage guardian capabilities" fields={[status("authority_status"), ...windowFields(false), ...guardianFlags]} />{rowCan(record, "guardian.verify") && !record.fields.verified_at && <details className="record-edit"><summary>Verify relationship</summary><MutationForm title="Verify guardian authority" description="Confirm that this explicit relationship has been reviewed before verification." operation="guardian.verify" initialInput={{ id: record.id }} buttonLabel="Verify relationship" /></details>}</>}</RecordList>
    </Section>
  </>;
}

function FamilyWorkflow({ data }: { data: AdminViewData }) {
  return <Section title="Add a new family participant" description="Create the person, participant and household relationship together. Every record is saved in one transaction."><Create title="Create participant and household link"><MutationForm title="New family participant" sections={[{ title: "Canonical person", fields: [text("first_name", "First name"), text("last_name", "Last name"), text("display_name", "Display name", true)] }, { title: "Household connection", fields: [select("household_id", "Existing household", rows(data, "households")), { ...text("relationship_type", "Household relationship", true), value: "child" }, { ...text("participant_type", "Participant type", true), value: "athlete" }] }, ...(can(data, "guardian.create") ? [{ title: "Optional explicit guardian", fields: [select("guardian_person_id", "Guardian", rows(data, "people"), false), ...guardianFlags] }] : [])]} buildCommands={(values) => {
      const commands: AdminCommand[] = [
        { operation: "person.create", ref: "new_person", input: { first_name: values.first_name, last_name: values.last_name, display_name: values.display_name, status: "active" } },
        { operation: "participant.create", ref: "new_participant", input: { person_id: { $ref: "new_person" }, participant_type: values.participant_type, status: "active", ...(data.organizationId ? { organization_id: data.organizationId } : {}) } },
        { operation: "household_membership.add", input: { household_id: values.household_id, person_id: { $ref: "new_person" }, relationship_type: values.relationship_type, status: "active" } },
      ];
      if (values.guardian_person_id && can(data, "guardian.create")) commands.push({ operation: "guardian.create", input: { guardian_person_id: values.guardian_person_id, dependent_person_id: { $ref: "new_person" }, relationship_type: "guardian", authority_status: "pending", ...Object.fromEntries(guardianFlags.map((field) => [field.name, values[field.name] === true])) } });
      return commands;
    }} buttonLabel="Create family participant" /></Create></Section>;
}

function Teams({ data }: { data: AdminViewData }) {
  if (!data.organizationId) return <p className="empty-state">Choose an organization to view teams and their memberships.</p>;
  const manageableTeams = rows(data, "teams").filter((team) => rowCan(team, "team_membership.add"));
  return <>
    <Section title="Team records">
      <TeamCreate data={data} />
      <RecordList records={rows(data, "teams")} empty="No teams are available in this organization.">{(record) => <><SummaryFields record={record} fields={[["parent_label", "Unit"], ["season_label", "Season"], ["visibility", "Visibility"]]} /><Edit data={data} record={record} operation="team.update" title="Edit team" fields={teamFields(data, true)} /></>}</RecordList>
    </Section>
    <Section title="Team memberships" description="Membership labels organize the roster. Administrative authority comes from an explicit role.">
      {(can(data, "team_membership.add") || manageableTeams.length > 0) && <TeamMemberCreate data={data} manageableTeams={manageableTeams} />}
      <RecordList records={rows(data, "team_memberships")} empty="No team memberships are available.">{(record) => <><SummaryFields record={record} fields={[["team_label", "Team"], ["person_label", "Person"], ["membership_type", "Type"], ["jersey_number", "Jersey"], ["position_label", "Position"]]} /><Edit data={data} record={record} operation="team_membership.update" title="Edit membership" fields={[text("jersey_number", "Jersey number"), text("position_label", "Position label"), ...windowFields(false), status()]} /></>}</RecordList>
    </Section>
    {(can(data, "team_membership.add") || manageableTeams.length > 0) && can(data, "role_assignment.add") && <TeamRoleWorkflow data={data} manageableTeams={manageableTeams} />}
  </>;
}

function TeamCreate({ data }: { data: AdminViewData }) {
  const [parent, setParent] = useState("");
  const global = can(data, "team.create");
  const units = rows(data, "units").filter((unit) => unit.status === "active" && (global || rowCan(unit, "team.create")));
  if (!global && !units.length) return null;
  const seasons = rows(data, "seasons").filter((season) => season.status === "active" && (!season.fields.parent_unit_id || season.fields.parent_unit_id === parent));
  const fields = teamFields(data).map((field) => field.name === "parent_unit_id" ? { ...select("parent_unit_id", "Organization unit", units, !global), onValueChange: setParent } : field.name === "season_id" ? select("season_id", "Compatible season", seasons, false) : field);
  return <Create title="Create team"><MutationForm title="New team" operation="team.create" initialInput={{ organization_id: data.organizationId }} fields={fields} buttonLabel="Create team" /></Create>;
}

function TeamMemberCreate({ data, manageableTeams }: { data: AdminViewData; manageableTeams: AdminRecord[] }) {
  const [mode, setMode] = useState("athlete");
  const participants = rows(data, "participants").filter((participant) => participant.status === "active");
  const fields = [select("team_id", "Team", can(data, "team_membership.add") ? rows(data, "teams") : manageableTeams),
    ...(mode === "athlete" ? [select("participant_id", "Existing participant", participants)] : [select("person_id", "Staff person", rows(data, "people")), { ...text("membership_type", "Membership type", true), value: "staff" }]),
    text("jersey_number", "Jersey number"), text("position_label", "Position label"), ...windowFields(), status()];
  return <Create title="Add participant or staff member"><div className="scope-choice"><label htmlFor="team-member-kind">Membership connection</label><select id="team-member-kind" value={mode} onChange={(event) => setMode(event.currentTarget.value)}><option value="athlete">Athlete with participant identity</option><option value="staff">Staff or coach person</option></select></div><MutationForm key={mode} title="Add team member" fields={fields} buildCommands={(values) => [{ operation: "team_membership.add", input: mode === "athlete" ? { ...values, membership_type: "athlete", person_id: participants.find((participant) => participant.id === values.participant_id)?.fields.person_id } : values }]} buttonLabel="Add team member" /></Create>;
}

function TeamRoleWorkflow({ data, manageableTeams }: { data: AdminViewData; manageableTeams: AdminRecord[] }) {
  const teamRoles = rows(data, "roles").filter((role) => Array.isArray(role.fields.allowed_scope_types) && role.fields.allowed_scope_types.includes("team"));
  return <Section title="Add staff with an explicit team role" description="The membership and requested role are created together, or neither is saved."><Create title="Add staff and assign team role"><MutationForm title="Team staff and role" fields={[select("team_id", "Team", can(data, "team_membership.add") ? rows(data, "teams") : manageableTeams), select("person_id", "Staff person", rows(data, "people")), { ...text("membership_type", "Membership type", true), value: "coach" }, select("role_id", "Scoped team role", teamRoles), ...windowFields()]} buildCommands={(values) => [
    { operation: "team_membership.add", input: { team_id: values.team_id, person_id: values.person_id, membership_type: values.membership_type, status: "active", ...(values.starts_at ? { starts_at: values.starts_at } : {}), ...(values.ends_at ? { ends_at: values.ends_at } : {}) } },
    { operation: "role_assignment.add", input: { person_id: values.person_id, role_id: values.role_id, scope_type: "team", scope_id: values.team_id, organization_id: data.organizationId, status: "active", ...(values.starts_at ? { starts_at: values.starts_at } : {}), ...(values.ends_at ? { ends_at: values.ends_at } : {}) } },
  ]} buttonLabel="Add staff and role" /></Create></Section>;
}

function Access({ data }: { data: AdminViewData }) {
  return <>
    {data.organizationId && <Section title="Organization memberships" description="Membership type is a relationship label. It does not grant administrative permission.">
      {can(data, "organization_membership.add") && <Create title="Add organization member"><MutationForm title="Add organization membership" operation="organization_membership.add" initialInput={{ organization_id: data.organizationId }} fields={[select("person_id", "Person", rows(data, "people")), { ...text("membership_type", "Membership type", true), value: "member" }, ...windowFields(), status()]} buttonLabel="Add membership" /></Create>}
      <RecordList records={rows(data, "organization_memberships")} empty="No organization memberships are available.">{(record) => <><SummaryFields record={record} fields={[["person_label", "Person"], ["membership_type", "Type"], ["starts_at", "Starts"], ["ends_at", "Ends"]]} /><Edit data={data} record={record} operation="organization_membership.update" title="Change membership status" fields={[...windowFields(false), status()]} /></>}</RecordList>
    </Section>}
    <Section title="Scoped role assignments" description="Each assignment is limited to its explicit scope. A role cannot grant capabilities you are not authorized to delegate.">
      {can(data, "role_assignment.add") && <RoleForm data={data} />}
      <RecordList records={rows(data, "role_assignments")} empty="No role assignments are available in your authorized context.">{(record) => <><SummaryFields record={record} fields={[["person_label", "Person"], ["role_label", "Role"], ["scope_type", "Scope"], ["scope_label", "Resource"], ["ends_at", "Ends"]]} /><Edit data={data} record={record} operation="role_assignment.update" title="Change assignment status" fields={[...windowFields(false), status()]} /></>}</RecordList>
    </Section>
    {can(data, "account.link") && <Section title="Canonical account linking" description="An authorized operator must confirm the exact canonical person and managed Auth identity. Existing mappings cannot be rebound."><Create title="Link existing Auth account"><MutationForm title="Link Auth account to canonical person" operation="account.link" fields={[select("person_id", "Canonical person", rows(data, "people")), text("auth_user_id", "Managed Auth identifier", true, "Use the exact verified identifier from the trusted Auth administration workflow.")]} buttonLabel="Link account" /></Create></Section>}
  </>;
}

function RoleForm({ data }: { data: AdminViewData }) {
  const [scope, setScope] = useState(data.organizationId ? "organization" : "platform");
  const roleRecords = rows(data, "roles").filter((role) => Array.isArray(role.fields.allowed_scope_types) && role.fields.allowed_scope_types.includes(scope));
  const scopeRecords = scope === "organization_unit" ? rows(data, "units") : rows(data, "teams");
  return <Create title="Assign scoped role"><div className="scope-choice"><label htmlFor="role-scope">Assignment scope</label><select id="role-scope" value={scope} onChange={(event) => setScope(event.currentTarget.value)}>{!data.organizationId && <option value="platform">Platform</option>}{data.organizationId && <><option value="organization">Organization</option><option value="organization_unit">Exact unit</option><option value="team">Exact team</option></>}</select></div><MutationForm key={scope} title="New role assignment" operation="role_assignment.add" initialInput={{ scope_type: scope, ...(scope === "organization" ? { scope_id: data.organizationId } : {}), ...(scope !== "platform" ? { organization_id: data.organizationId } : {}) }} fields={[select("person_id", "Person", rows(data, "people")), select("role_id", "Role", roleRecords), ...(scope === "team" || scope === "organization_unit" ? [select("scope_id", scope === "team" ? "Team" : "Organization unit", scopeRecords)] : []), ...windowFields(), status()]} buttonLabel="Assign role" /></Create>;
}

function Audit({ data }: { data: AdminViewData }) {
  const audit = rows(data, "audit").map((record) => ({ ...record, fields: { ...record.fields, context_label: data.organizations.find((organization) => organization.id === record.fields.organization_id)?.label ?? (record.fields.scope_type === "platform" ? "Platform" : String(record.fields.scope_type ?? "Scoped resource")) } }));
  return <Section title="Recorded changes"><RecordList records={audit} empty="No audit events are available in your authorized context.">{(record) => <SummaryFields record={record} fields={[["actor", "Actor"], ["action", "Action"], ["resource_type", "Resource"], ["occurred_at", "Recorded"], ["context_label", "Context"]]} />}</RecordList></Section>;
}

function Account({ data }: { data: AdminViewData }) {
  return <section className="account-panel" aria-labelledby="session-title"><div className="account-panel-heading"><span className="session-indicator" aria-hidden="true" /><div><h2 id="session-title">{data.person?.label ?? "Your Boss identity"}</h2><p>Your canonical identity is connected. You are signed in on this browser.</p></div></div><div className="account-panel-action"><p>Sign out when you are finished, especially on a shared device.</p><form action="/auth/logout" method="post"><button className="button button-outline" type="submit">Sign out</button></form></div></section>;
}

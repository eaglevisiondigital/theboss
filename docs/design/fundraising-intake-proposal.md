# Start a Fundraiser: revised intake proposal

Status: approved October 2, 2026. User explicitly authorized implementation after reviewing the mockup. Route: /fundraising/get-started. This is the next public-page design milestone. No public form changes or real submission made during inspection.

## Findings

Live page and source inspected. The hero is an intentional CSS gradient with no image reference, not a failed image download. It uses legacy SiteHeader branding instead of ApprovedHeader. SiteFooter is imported but never rendered. Existing goal field is optional/unvalidated free text. Organization name/type, participant count, desired date and purpose already exist. Existing checkboxes permit simultaneous digital card, physical card and Money Board selections; all three were checked successfully in the browser without submitting. NetlifyForm appends all FormData entries, retaining repeated selections in the encoded request, but downstream stored submission and notification delivery have not been verified.

Missing information: campaign versus annual goal context, annual frequency, scope across teams/groups, sports/program selection and counts, flexible launch timing, deadline and readiness context. Checkbox styling inherits full-sized text-input layout, making choices harder to scan. Need approved footer, accessible field groups, conditional questions and clear sending/success/error states.

## Design

Use exact approved THE BOSS/B+ header and footer. Compact photographic hero, black left text and a distinct realistic scene of an adult female community organizer and adult male coach planning together at a community sports center on the right. Avoid reusing prior hero families. Headline: "Your goal. Our tools. Let’s make it happen." Eyebrow START A FUNDRAISER. Supporting copy: "Tell us about your organization, your fundraising goals and the tools you’re interested in. We’ll help you plan your next step."

Single page with five clearly numbered sections, two-column fields on desktop and one on phones. Calm white form cards, orange accents, visible checkbox squares and large clickable choice cards. No carousel, no auto-advance, no fake success or live account creation. Required indicators and instruction "Fields marked * are required." Ask only aggregate counts, not participant/child personal information.

## Field specification

### 1. Your contact information
- First and last name: required.
- Email: required, email validation.
- Phone: required, telephone keyboard, flexible international formatting.
- Role/title: required; organizer, coach, athletic director, administrator, pastor/ministry leader, parent/volunteer, other. Other reveals a short text field.
- Preferred contact method: optional, email or phone. No implied SMS consent.

### 2. Your organization
- Organization name: required.
- Organization type: required. Sports team; athletic organization/league; school; band/arts program; cheer program; church/ministry; youth/community organization; nonprofit; missions team; camp; other. Other reveals required short description.
- City and state: required. Website: optional.
- Scope: required single choice: One team/group; Multiple teams/groups; Organization-wide; Not sure yet.
- Approximate number of participants: optional positive integer, mark estimate welcome.
- Number of teams/groups: shown when multiple or organization-wide; optional positive integer.
- Sports or programs involved: multi-select, basketball, football, volleyball, soccer, baseball, softball, cheer, band/arts, church/youth ministry, missions, camps, other. Show as applicable; do not force non-sports organizations to select a sport. Other short text available.
- Teams/groups details: optional textarea with example "Varsity and JV basketball, two volleyball teams, youth ministry." This supports multiple teams within one sport as well as multiple sports.

### 3. Goals and timing
- Fundraising goal for this campaign: required positive USD amount OR explicit "Help me set a goal" choice. Currency label; no mandatory invented estimate.
- Annual fundraising goal: optional positive USD amount. Explain this is separate from this campaign's goal.
- What will the funds support?: required textarea, e.g. fees, equipment, camps, travel, ministry or organization needs.
- How often do you plan to fundraise?: required single choice: Once a year; Multiple times a year; Year-round; Not sure yet.
- If multiple times: optional planned number of fundraisers per year, integer 2+.
- When would you like to launch?: required single choice: As soon as possible; I have a date; Within 1–3 months; Just exploring. Date picker required only for "I have a date"; no date forced for unsure respondents.
- Funds-needed-by date: optional, validate not before selected launch date. Keep distinct from launch date.

### 4. Choose your fundraising options

Instruction: "Select all that interest you. You can combine multiple options."
Independent checkboxes, no preselected choices on real form:
- Digital Money Board
- Digital Boss Bucks cards
- Physical Boss Bucks cards
- Direct donations
- Team/organization merchandise (interest only; availability varies)
- Help me choose

Require at least one selection, allowing Help me choose alone or alongside specific interests. Do not make every checkbox required. Three cards selected in visual mockup demonstrate multi-select only, not defaults. Card descriptions remain concise. Preserve every selected value in stored intake and notification; verify end-to-end after implementation. Physical availability is subject to program confirmation, not a guarantee from selection.

### 5. Next steps
- Readiness: required single choice: Ready to get started; I’d like a demo; I need more information.
- Additional details: optional textarea.
- CTA: "Submit Fundraising Interest".
- Contact notice: "By submitting, you’re asking The Boss team to contact you about this inquiry."
- What happens next: "We’ll review your goals and selected options, then follow up to discuss a plan that fits your organization." No guaranteed turnaround invented.

## Implementation acceptance after visual approval

Use ApprovedHeader/ApprovedFooter and new route-specific styles without unexpectedly restyling other forms. Build semantic labels, fieldsets and legends with keyboard-operable native inputs. Correct checkbox sizing and focus appearance. Clear errors adjacent to fields, retain all values on request failure, prevent duplicate submits and announce sending/status. Do not send hidden conditional fields from irrelevant branches. Update public/__forms.html to capture every added field. Preserve existing Netlify form name and legacy field mappings when practical. Audit generic /get-started routing so fundraiser inquiries are clearly directed to this detailed intake. Verify required fields, amount/date validation, multi-select payload, conditional fields, successful storage and intended delivery, and confirmation page. Test only authorized synthetic details and label any test submission clearly. Marketing notification enrollment, payments, wallet operations and automatic campaign creation are outside this intake.

## Visual proposal notes

Built-in image generation produced fundraising-intake-desktop-proposed.png from the approved Fundraising page as brand reference. Prompt requested compact photographic planning hero, five numbered form sections, campaign and annual goals, multiple-team/program details, yearly frequency, launch timing and six independent fundraiser choices with three visibly selected examples.

The mockup is a visual layout contract, with the field specification above governing implementation. Correct these generated-text differences during implementation: preferred contact method, counts and program selections remain optional as specified; planned yearly count is conditional and optional. Card descriptions must say discounts at participating businesses, with coverage varying by membership/program, rather than implying local and national coverage for all cards. Do not preselect real form choices. Render the required-field explanation and full approved footer links. Keep phone formatting flexible. No website changes published in this proposal turn.

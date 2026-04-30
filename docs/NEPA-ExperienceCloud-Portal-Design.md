# NEPA Public Permitting Portal — Experience Cloud Design

**Version:** 1.0  
**Date:** 2026-04-30  
**Standards:** USWDS 3.13 · Lightning Web Runtime (LWR) · Lightning Web Security (LWS) · WCAG 2.1 AA  
**Scope:** Public-facing Experience Cloud site surface only. LWC component implementation lives in a separate project.

---

## Table of Contents

1. [Design Intent](#1-design-intent)
2. [Audience and Human-Centered Design Principles](#2-audience-and-human-centered-design-principles)
3. [Technical Architecture Constraints](#3-technical-architecture-constraints)
4. [Information Architecture](#4-information-architecture)
5. [USWDS Component Inventory](#5-uswds-component-inventory)
6. [Color, Typography, and Token Decisions](#6-color-typography-and-token-decisions)
7. [Page Designs](#7-page-designs)
8. [Accessibility Requirements](#8-accessibility-requirements)
9. [LWR and LWS Compliance Notes](#9-lwr-and-lws-compliance-notes)
10. [Component Implementation Guidance](#10-component-implementation-guidance)
11. [Open Items](#11-open-items)

---

## 1. Design Intent

The NEPA Public Permitting Portal gives applicants, members of the public, and agency staff a single, accessible front door for:

- Checking the status of a NEPA review process
- Submitting public comments during open comment periods
- Understanding what type of NEPA review applies (CE screener result)
- Accessing administrative record documents for an active project
- Receiving notifications at key process milestones

The portal is not a replacement for agency internal workflows — it is a read-mostly public surface backed by the PSS data model. Write operations are limited to comment submission and notification opt-in.

---

## 2. Audience and Human-Centered Design Principles

### Primary user segments

| Segment | Goal | Key pain point |
|---|---|---|
| **Applicant / project sponsor** | Track process status, understand next steps, upload required documents | Opacity — doesn't know where the process is or what's blocking it |
| **Interested member of the public** | Find projects near them, read documents, submit comments | Discoverability — can't find their project or the comment period dates |
| **Environmental / advocacy organization** | Monitor multiple projects by geography or sector, track comment periods | Volume — manages many projects simultaneously |
| **Agency permit manager** (internal, authenticated) | Review submitted comments, update process stage | Not in scope for public portal — handled via internal Salesforce UI |

### HCD principles applied

1. **Answer the first question first.** Every page answers "what is this?" in the first viewport without requiring scroll. Users should understand what they can do here within 5 seconds.

2. **Reduce jargon at the entry point.** CE, EA, EIS acronyms are explained inline on first use. Plain-language labels ("Environmental Review Type") are used in navigation; technical labels are available as tooltip expansions.

3. **Progressive disclosure.** Project list → project overview → process detail → document detail. Users drill down only as far as they need. Each level surfaces the most important status signal (risk tier, process stage, comment deadline) above the fold.

4. **Status is always visible.** The process stage, timeline risk tier, and any open comment period deadline are always rendered near the top of any project-specific page. A user should never need to scroll to learn "what is happening right now."

5. **Comment submission is one path, not a buried form.** Comment CTAs appear in the site alert, in the project card, and in the process detail header. The comment form is a dedicated page, not a modal, to support screen readers and mobile users.

6. **Accessible by default, not by accommodation.** All interactive elements are keyboard navigable. No information is conveyed by color alone. All icons are paired with visible text or `aria-label`. Touch targets meet the 44×44px minimum.

---

## 3. Technical Architecture Constraints

### Lightning Web Runtime (LWR)

- Site uses the **LWR site engine** (not Aura/Classic). All components are LWCs with `@salesforce/apex` wire adapters or `@wire(getRecord)`.
- LWR compiles routes at build time. Each portal page is a separate route mapped to a URL path.
- No Visualforce pages. No iframes except for the USWDS map embed (which requires explicit CSP allowlisting).
- Static assets (USWDS CSS, fonts, icons) are hosted as Experience Cloud static resources. USWDS `sprite.svg` is referenced relative to the static resource path.

### Lightning Web Security (LWS)

LWS runs each component in a per-namespace sandbox. The following apply specifically to USWDS integration:

- **No direct `document` or `window` manipulation from LWC templates.** USWDS JavaScript (accordion toggle, banner expand, modal, date picker) cannot be loaded as a global script and mutate the DOM. Each USWDS component that requires JS behavior must be either:
  - **Re-implemented in LWC** using `@api`, `@track`, and `connectedCallback` / `disconnectedCallback`, OR
  - **Loaded via a static resource** and initialized in `connectedCallback` using `loadScript` from `lightning/platformResourceLoader` with careful scoping to `this.template.querySelector`.
- **No inline event handlers with `onclick="..."` string attributes.** Use `addEventListener` in the component's JS class.
- **`eval` and `Function()` constructor are blocked.** USWDS JS that uses these internally (e.g. some accordion implementations) must be replaced with LWC-native toggle logic.
- **CSS scoping:** LWC shadow DOM scopes styles. USWDS CSS must either be loaded as a global Experience Cloud stylesheet (preferred for tokens and utilities), or injected via `:host` and `::slotted` in component-scoped stylesheets.

### Guest user access

The portal is accessible without login. Experience Cloud guest user profile grants read access to:
- `Program` (project) — all fields except internal scoring fields
- `IndividualApplication` (process) — `nepa_review_type__c`, `nepa_process_status__c`, `nepa_process_stage__c`, `nepa_public_comment_period_start__c`, `nepa_public_comment_period_end_date__c`, `nepa_federal_unique_id__c`
- `ContentVersion` — `nepa_document_type__c`, `nepa_status__c`, `nepa_public_access__c` (filtered to `nepa_public_access__c = true`)
- `PublicComplaint` — submit only; no read of other users' comments
- `nepa_engagement__c` — all fields where `nepa_public_access__c = true`

Risk scoring fields (`nepa_risk_score__c`, `nepa_risk_tier__c`, `nepa_defensibility_*`) are **not** exposed to guest users.

---

## 4. Information Architecture

```
/ (Home)
├── /projects                          Project search and list
│   └── /projects/[federal-unique-id]  Project overview
│       └── /projects/[id]/process     Process detail (NEPA review)
│           ├── /projects/[id]/process/documents    Document library
│           └── /projects/[id]/process/comments     Comment submission
├── /learn                             How NEPA works (static content)
│   ├── /learn/what-is-nepa
│   ├── /learn/review-types            CE / EA / EIS explained
│   └── /learn/comment-guide           How to submit effective comments
└── /about                             Portal mission and contact
```

### URL strategy

- URLs use the `nepa_federal_unique_id__c` (UUID) field, not the Salesforce record ID, for stability and shareability.
- All project pages support deep-linking. Sharing a link to `/projects/[uuid]/process/documents` takes the recipient directly to that project's document library.

---

## 5. USWDS Component Inventory

The following USWDS 3.13 components are used. Each entry maps the component to its page and notes LWC-specific considerations.

### Global (all pages)

| Component | USWDS class | LWC notes |
|---|---|---|
| **Official Government Banner** | `usa-banner` | Statically rendered in the Experience Cloud header slot. Accordion expand/collapse implemented as LWC toggle (no USWDS JS). |
| **Header — Basic** | `usa-header usa-header--basic` | LWC `nepaHeader`. Nav items are `@api`-configurable. Mobile hamburger toggle via LWC `@track isMenuOpen`. |
| **Skip navigation** | `usa-skipnav` | First element in DOM. `href="#main-content"`. Required for keyboard/screen-reader users. |
| **Primary navigation** | `usa-nav`, `usa-nav__primary` | Links to /projects, /learn, /about. Active state driven by `pageReference` comparison. |
| **Breadcrumb** | `usa-breadcrumb` | LWC `nepaBreadcrumb`. Receives `crumbs` array via `@api`. `aria-label="Breadcrumb"`. |
| **Footer — Slim** | `usa-footer usa-footer--slim` | Agency name, contact email, legal links, `usa-identifier` below. |
| **Identifier** | `usa-identifier` | Renders the parent agency logo, domain declaration, and required government links (Accessibility, Privacy Policy, FOIA, No Fear Act). |
| **Site alert** | `usa-site-alert` | Conditionally rendered when a comment period is open for any project. Managed by a wire adapter querying active comment periods. |

### Home page

| Component | USWDS class | Purpose |
|---|---|---|
| **Hero** | `usa-hero` | "Find and track NEPA environmental reviews" — one-sentence mission, Search CTA |
| **Search (large)** | `usa-search usa-search--big` | Project search by name, location, or federal ID |
| **Process list** | `usa-process-list` | "How it works" — 3 steps: Search → Track → Comment |
| **Card group** | `usa-card-group` | Featured recently-opened comment periods (3 cards max) |
| **Summary box** | `usa-summary-box` | "About this portal" — links to /learn and /about |

### Project search and list (`/projects`)

| Component | USWDS class | Purpose |
|---|---|---|
| **Search (medium)** | `usa-search` | Persistent search within project list |
| **Tag group** | `usa-tag` | Review type filters: CE · EA · EIS · All |
| **Table (sortable)** | `usa-table usa-table--sortable usa-table--stacked` | Project results: Title, Agency, Review Type, Stage, Comment Deadline |
| **Pagination** | `usa-pagination` | 20 results per page |
| **Select** | `usa-select` | Sort-by dropdown (Date, Alphabet, Deadline) |
| **Alert** | `usa-alert usa-alert--info` | Empty state: "No projects match your search." |

### Project overview (`/projects/[id]`)

| Component | USWDS class | Purpose |
|---|---|---|
| **Breadcrumb** | `usa-breadcrumb` | Home › Projects › [Project Title] |
| **Summary box** | `usa-summary-box` | Project at-a-glance: Title, Agency, Location, Federal ID, Sector |
| **Site alert (warning)** | `usa-site-alert usa-site-alert--warning` | Shown only if comment period ends within 7 days |
| **Tag** | `usa-tag` | Review type badge (CE / EA / EIS) |
| **Step indicator** | `usa-step-indicator` | NEPA process stage progression: Pre-Application → Scoping → Draft EIS → Final EIS → ROD |
| **Card group** | `usa-card-group` | Sub-cards: Process Detail, Document Library, Comment Submission |
| **In-page navigation** | `usa-in-page-navigation` | Anchors: Overview · Process · Documents · Engagement · Comments |
| **Collection** | `usa-collection` | Upcoming engagement events list |

### Process detail (`/projects/[id]/process`)

| Component | USWDS class | Purpose |
|---|---|---|
| **Breadcrumb** | `usa-breadcrumb` | Home › Projects › [Project] › Process |
| **Step indicator** | `usa-step-indicator` | Current stage highlighted |
| **Summary box** | `usa-summary-box` | Comment period dates, deadline countdown |
| **Alert (success/warning/info)** | `usa-alert` | Dynamic: "Comment period closes in X days" / "Comment period closed" / "No open comment period" |
| **Table** | `usa-table` | Process timeline: Stage, Start Date, End Date, Status |
| **Accordion** | `usa-accordion` | Collapsible sections: Regulatory Citation, Purpose and Need, Classification Basis |
| **Process list** | `usa-process-list` | Next steps list for applicant (if authenticated) |
| **Button** | `usa-button` | Primary CTA: "Submit a Comment" (only visible during open period) |

### Document library (`/projects/[id]/process/documents`)

| Component | USWDS class | Purpose |
|---|---|---|
| **Breadcrumb** | `usa-breadcrumb` | Home › Projects › [Project] › Documents |
| **Tag group** | `usa-tag` | Document type filters: NOI · Draft EIS · Final EIS · FONSI · ROD · Other |
| **Table (stacked, sortable)** | `usa-table usa-table--stacked usa-table--sortable` | Document Name, Type, Published Date, Status; download link column |
| **Pagination** | `usa-pagination` | 25 documents per page |
| **File input / download link** | `usa-link` with icon | Download column links to ContentVersion `VersionData` |
| **Alert** | `usa-alert usa-alert--info` | "Documents are public record. Contact [agency] to request inaccessible formats." |

### Comment submission (`/projects/[id]/process/comments`)

| Component | USWDS class | Purpose |
|---|---|---|
| **Breadcrumb** | `usa-breadcrumb` | Home › Projects › [Project] › Submit Comment |
| **Alert (warning)** | `usa-alert usa-alert--warning` | Deadline countdown banner |
| **Summary box** | `usa-summary-box` | Comment guidance: what makes a comment substantive |
| **Form** | `usa-form` | Full comment form (see below) |
| **Form group** | `usa-form-group` | Wraps each field with label, hint, and error |
| **Label** | `usa-label` | Accessible form labels |
| **Hint** | `usa-hint` | Field guidance text below label |
| **Input** | `usa-input` | Name, organization, email |
| **Textarea** | `usa-textarea` | Comment body (max 5,000 characters) |
| **Character count** | `usa-character-count` | Live counter on textarea |
| **Select** | `usa-select` | Comment category (General · Alternatives · Impacts · Mitigation · Other) |
| **Checkbox** | `usa-checkbox` | "I want to receive updates on this project" |
| **File input** | `usa-file-input` | Optional supporting document (PDF, max 10MB) |
| **Button** | `usa-button` | "Submit Comment" (primary) · "Cancel" (unstyled) |
| **Modal** | `usa-modal` | Confirmation dialog before final submission |
| **Alert (success)** | `usa-alert usa-alert--success` | Post-submit: "Your comment was received. Reference ID: [uuid]" |
| **Error message** | `usa-error-message` | Inline validation errors per field |
| **Validation** | `usa-validation` | Form-level error summary at top on submit attempt with failures |

### Learn section (`/learn/*`)

| Component | USWDS class | Purpose |
|---|---|---|
| **Sidenav** | `usa-sidenav` | Section navigation: What is NEPA · Review Types · How to Comment |
| **Process list** | `usa-process-list` | NEPA review sequence walkthrough |
| **Accordion** | `usa-accordion` | FAQ: expandable Q&A pairs |
| **Summary box** | `usa-summary-box` | "Key terms" callout with glossary links |
| **In-page navigation** | `usa-in-page-navigation` | Auto-generated from `<h2>` headings on long content pages |
| **Table** | `usa-table` | Review type comparison: CE vs EA vs EIS thresholds |
| **Icon list** | `usa-icon-list` | Benefits / checklist style callouts |

---

## 6. Color, Typography, and Token Decisions

### Color palette

The portal uses USWDS default theme tokens with one override: `$theme-color-primary` is set to `"blue-warm-60v"` (a slightly warmer blue that maintains AA contrast on white) to align with typical federal agency brand while staying within the USWDS token system.

```scss
// _uswds-theme.scss  (in the LWC project's static resource)
@use "uswds-core" with (
  $theme-color-primary-family:   "blue-warm",
  $theme-color-primary:          "blue-warm-60v",
  $theme-color-primary-dark:     "blue-warm-70v",
  $theme-color-primary-darker:   "blue-warm-80v",
  $theme-color-base-family:      "gray-cool",
  $theme-color-accent-cool:      "cyan-30v",
  $theme-font-type-body:         "public-sans",
  $theme-font-type-heading:      "public-sans",
  $theme-font-type-ui:           "public-sans"
);
```

| Role | Token | Hex (approx) | Usage |
|---|---|---|---|
| Primary | `blue-warm-60v` | `#0050d8` | Buttons, links, active nav |
| Primary dark | `blue-warm-70v` | `#1a4480` | Hover states, header bg |
| Base ink | `gray-90` | `#1b1b1b` | Body text |
| Base light | `gray-cool-30` | `#a9aeb1` | Disabled states, borders |
| Success | `green-cool-50v` | `#00a91c` | Success alert, complete step |
| Warning | `gold-20v` | `#ffbe2e` | Warning alert, deadline countdown |
| Error | `red-60v` | `#b50909` | Error alert, validation |
| Info | `cyan-30v` | `#00bde3` | Info alert, tag accent |
| Background | `white` / `gray-5` | `#ffffff` / `#f0f0f0` | Page bg / section dividers |

All foreground/background pairs meet WCAG AA 4.5:1 (text) and 3:1 (large text / UI components).

### Typography

| Element | USWDS token | Size |
|---|---|---|
| Page heading (h1) | `font-size: 2xl` | 2rem (32px) |
| Section heading (h2) | `font-size: xl` | 1.75rem (28px) |
| Subsection heading (h3) | `font-size: lg` | 1.375rem (22px) |
| Body text | `font-size: sm` | 1rem (16px) |
| Small / hint | `font-size: xs` | 0.875rem (14px) |
| Font family | Public Sans (USWDS default) | — |
| Line height | `line-height: 5` (1.62) | Body |

### Spacing

USWDS 8px spacing units are used throughout (`1 unit = 8px`). Key values:

- Section padding: `padding: 4` (32px top/bottom)
- Card internal padding: `padding: 3` (24px)
- Form field spacing: `margin-top: 3` between fields
- Grid gap: `grid-gap: 4` on two-column layouts

---

## 7. Page Designs

### 7.1 Home page

```
┌─────────────────────────────────────────────────────────┐
│ [Skip navigation link — visually hidden, first in DOM]  │
├─────────────────────────────────────────────────────────┤
│ usa-banner  "An official website of the United States"  │
├─────────────────────────────────────────────────────────┤
│ usa-header--basic                                       │
│  ○ Agency logo / name          [Search] [Projects]      │
│                                [Learn]  [About]         │
├─────────────────────────────────────────────────────────┤
│ usa-site-alert (conditional — open comment periods)     │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  usa-hero  ════════════════════════════════════════     │
│  "Find and track NEPA environmental reviews"            │
│   [usa-search--big  ___________________________[Search]]│
│                                                         │
├─────────────────────────────────────────────────────────┤
│  usa-section  "How this portal works"                   │
│  usa-process-list                                       │
│   1. Search for a project by name, location, or ID      │
│   2. Follow the NEPA review process and key dates       │
│   3. Submit public comments during open periods         │
├─────────────────────────────────────────────────────────┤
│  usa-section  "Open comment periods"                    │
│  usa-card-group  [Card] [Card] [Card]                   │
│   Each card: Project name · Deadline tag · Comment CTA  │
├─────────────────────────────────────────────────────────┤
│  usa-section  usa-dark-background                       │
│  usa-summary-box  "About the NEPA Permitting Portal"    │
│   Links: Learn how NEPA works · Contact us              │
├─────────────────────────────────────────────────────────┤
│  usa-footer--slim                                       │
│  usa-identifier                                         │
└─────────────────────────────────────────────────────────┘
```

### 7.2 Project list (`/projects`)

```
┌─────────────────────────────────────────────────────────┐
│ [header / banner / breadcrumb: Home › Projects]         │
├─────────────────────────────────────────────────────────┤
│  h1: "NEPA Projects"                                    │
│  usa-search  [____________________________ [Search] ]   │
│                                                         │
│  Filters:  Review type                  Sort by         │
│  usa-tag [All] [CE] [EA] [EIS]          usa-select ▾    │
│                                                         │
│  usa-alert--info  (conditional empty state)             │
│                                                         │
│  usa-table usa-table--stacked usa-table--sortable       │
│  ┌──────────────┬────────┬─────────┬──────┬──────────┐  │
│  │ Project Title│ Agency │ Review  │Stage │ Comment  │  │
│  │              │        │ Type    │      │ Deadline │  │
│  ├──────────────┼────────┼─────────┼──────┼──────────┤  │
│  │ [link] Solar │ BLM    │ usa-tag │ Sco- │ Jun 15   │  │
│  │  Project X   │        │  EIS    │ ping │ 2026     │  │
│  │ ...          │ ...    │  ...    │ ...  │ ...      │  │
│  └──────────────┴────────┴─────────┴──────┴──────────┘  │
│                                                         │
│  usa-pagination  ← 1 2 3 ... 12 →                       │
├─────────────────────────────────────────────────────────┤
│ [footer / identifier]                                   │
└─────────────────────────────────────────────────────────┘
```

**Stacked table behavior (mobile):** At < 640px, the `usa-table--stacked` modifier renders each row as a labeled block. Column headers become inline labels before each cell value.

### 7.3 Project overview (`/projects/[id]`)

```
┌─────────────────────────────────────────────────────────┐
│ [banner · header]                                       │
│ usa-breadcrumb: Home › Projects › Solar Project X       │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  h1: "Solar Project X"                                  │
│  usa-tag: EIS  │  usa-tag: Energy Production            │
│                                                         │
│  usa-site-alert--warning (if comment deadline ≤ 7 days) │
│  "Comment period closes [date]. Submit your comment."   │
│                                                         │
├──────────────────────┬──────────────────────────────────┤
│                      │  usa-in-page-navigation          │
│  usa-summary-box     │  On this page:                   │
│  Key information:    │  • Project Overview              │
│  • Federal ID        │  • NEPA Process                  │
│  • Lead Agency: BLM  │  • Documents                     │
│  • Location          │  • Engagement Events             │
│  • Sector            │  • Submit a Comment              │
│  • Started: [date]   │                                  │
│                      │                                  │
│  ── NEPA Process ─── │                                  │
│  usa-step-indicator  │                                  │
│  ● Pre-App  ● Scoping│                                  │
│  ◐ Draft EIS  ○ Final│                                  │
│  ○ ROD               │                                  │
│                      │                                  │
│  Current: Draft EIS  │                                  │
│                      │                                  │
│  ── Documents ──     │                                  │
│  usa-collection      │                                  │
│  [Recent docs list]  │                                  │
│  [View all docs →]   │                                  │
│                      │                                  │
│  ── Submit Comment ──│                                  │
│  usa-alert--info     │                                  │
│  "Comment period     │                                  │
│  opens [date]"       │                                  │
│  OR                  │                                  │
│  usa-button          │                                  │
│  "Submit a Comment"  │                                  │
│                      │                                  │
└──────────────────────┴──────────────────────────────────┘
│ [footer · identifier]                                   │
└─────────────────────────────────────────────────────────┘
```

**Responsive behavior:** At < 1024px the in-page navigation collapses to a sticky "On this page" dropdown at the top of the content area. The two-column layout becomes single column.

### 7.4 Comment submission form (`/projects/[id]/process/comments`)

```
┌─────────────────────────────────────────────────────────┐
│ [banner · header]                                       │
│ usa-breadcrumb: Home › Projects › [Project] › Comment   │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  h1: "Submit a Public Comment"                          │
│  Subhead: "Solar Project X · Comment period closes      │
│            [date] at 11:59 PM ET"                       │
│                                                         │
│  usa-alert--warning  "[X] days remaining"               │
│                                                         │
│  usa-summary-box  "What makes an effective comment"     │
│  • Be specific — reference page numbers or alternatives │
│  • Focus on environmental impacts and alternatives      │
│  • Attach supporting data if available                  │
│                                                         │
│  ─────────────────────────────────────────────────────  │
│  usa-form                                               │
│                                                         │
│  usa-validation  [Error summary — shown on failed submit]│
│                                                         │
│  usa-form-group                                         │
│   usa-label  First and last name *                      │
│   usa-input  [_______________________________]          │
│                                                         │
│  usa-form-group                                         │
│   usa-label  Organization (optional)                    │
│   usa-input  [_______________________________]          │
│                                                         │
│  usa-form-group                                         │
│   usa-label  Email address *                            │
│   usa-hint   We'll send a confirmation to this address  │
│   usa-input  [_______________________________]          │
│   usa-error-message  (conditional)                      │
│                                                         │
│  usa-form-group                                         │
│   usa-label  Comment category *                         │
│   usa-select ▾  [General / Alternatives / Impacts /    │
│                  Mitigation / Other]                    │
│                                                         │
│  usa-form-group                                         │
│   usa-label  Your comment *                             │
│   usa-hint   Maximum 5,000 characters. Be specific.     │
│   usa-textarea  [                               ]       │
│                 [                               ]       │
│   usa-character-count  "4,850 characters remaining"     │
│                                                         │
│  usa-form-group                                         │
│   usa-label  Supporting document (optional)             │
│   usa-hint   PDF only · max 10 MB                       │
│   usa-file-input                                        │
│                                                         │
│  usa-checkbox                                           │
│   □ Notify me of updates on this project                │
│                                                         │
│  [usa-button primary  "Review and Submit"]              │
│  [usa-button unstyled "Cancel"]                         │
│                                                         │
│  ── usa-modal (confirm before submit) ──────────────    │
│  "Review your comment"                                  │
│  [Comment preview — read-only]                          │
│  [usa-button "Submit Comment"]                          │
│  [usa-button unstyled "Go back and edit"]               │
│                                                         │
├─────────────────────────────────────────────────────────┤
│ [footer · identifier]                                   │
└─────────────────────────────────────────────────────────┘
```

---

## 8. Accessibility Requirements

### WCAG 2.1 AA checkpoints

| Checkpoint | Requirement | Implementation |
|---|---|---|
| 1.1.1 Non-text Content | All images have alt text | All `<img>` elements have `alt`. Decorative images use `alt=""` and `aria-hidden="true"` |
| 1.3.1 Info and Relationships | Structure conveyed programmatically | Semantic HTML5 (`<main>`, `<nav>`, `<header>`, `<footer>`, `<section>`, `<article>`). USWDS components use correct heading hierarchy |
| 1.3.3 Sensory Characteristics | No instruction relies on shape/color/sound alone | Status tags always include text label, never color only. Icons always paired with visible or `aria-label` text |
| 1.4.1 Use of Color | Color not used as sole information carrier | Step indicator uses shape + color + text. Table sort direction uses icon + `aria-sort` attribute |
| 1.4.3 Contrast (Minimum) | 4.5:1 normal text; 3:1 large text | All USWDS token pairings verified above; custom combinations documented in §6 |
| 1.4.10 Reflow | Content viewable at 320px width without horizontal scroll | USWDS responsive grid; stacked table at mobile; no fixed-width elements |
| 1.4.11 Non-text Contrast | UI components 3:1 against adjacent color | USWDS input borders, button outlines, focus rings all meet 3:1 |
| 1.4.12 Text Spacing | Text remains readable when spacing increased | No fixed-height containers that clip text |
| 2.1.1 Keyboard | All functionality keyboard accessible | No mouse-only event handlers. Modal traps focus correctly |
| 2.1.2 No Keyboard Trap | Users can leave every component | Modal includes Escape key dismissal. Focus returns to trigger element on close |
| 2.4.1 Bypass Blocks | Skip navigation link | First element in DOM: `<a class="usa-skipnav" href="#main-content">Skip to main content</a>` |
| 2.4.3 Focus Order | Logical focus order | DOM order matches visual order. Modal receives focus on open |
| 2.4.4 Link Purpose | Links are descriptive | No bare "click here" or "read more" links. Table download links include project name in `aria-label` |
| 2.4.6 Headings | Descriptive headings | H1 on every page. No skipped heading levels. Step indicator and table captions use `aria-labelledby` |
| 2.4.7 Focus Visible | Focus indicator visible | USWDS default 4px `outline: 0.25rem solid` focus ring; not overridden |
| 3.1.1 Language of Page | `lang` attribute set | Experience Cloud theme sets `<html lang="en">` |
| 3.2.2 On Input | No unexpected context change on field input | Character count and inline validation do not cause focus change or page refresh |
| 3.3.1 Error Identification | Errors described in text | Validation summary at form top + inline error message per field |
| 3.3.2 Labels or Instructions | All fields labeled | `usa-label` with `for` matching input `id`. `usa-hint` for format guidance |
| 4.1.2 Name, Role, Value | All UI components have accessible name, role, state | All interactive elements use semantic HTML or explicit ARIA |
| 4.1.3 Status Messages | Status messages conveyed to AT | Success/error alerts use `role="alert"` or `aria-live="polite"` depending on urgency |

### Screen reader testing targets

- NVDA + Chrome (Windows) — primary
- JAWS + Chrome (Windows) — federal agency standard
- VoiceOver + Safari (macOS / iOS) — secondary
- TalkBack + Chrome (Android) — mobile secondary

### ARIA usage rules

- **Prefer native HTML semantics** over ARIA roles. Use `<button>` not `<div role="button">`.
- ARIA `role`, `aria-expanded`, `aria-controls`, `aria-current` are used on the accordion, nav, and step indicator to supplement USWDS markup where LWC shadow DOM might obscure implicit roles.
- `aria-live="polite"` on the character count region so screen reader users hear the count update without interruption.
- `role="alert"` on the post-submit success/error message so it is announced immediately.
- `aria-describedby` on form inputs where a hint element exists.

---

## 9. LWR and LWS Compliance Notes

### Component architecture

Each page is composed of route-mapped LWC page components that assemble smaller LWC leaf components. USWDS markup is owned by the LWC templates — there are no global USWDS JS imports.

```
nepaProjectList (page component)
├── nepaBanner
├── nepaHeader
├── nepaSearchBar        ← wraps usa-search markup + LWC submit handler
├── nepaProjectTable     ← wraps usa-table markup + wire(getProjects)
│   └── nepaReviewTypeTag  ← wraps usa-tag
└── nepaPagination       ← wraps usa-pagination + @api currentPage / totalPages
```

### LWS-safe patterns

**Accordion (usa-accordion):** Re-implemented in LWC. `@track isExpanded = false` drives `aria-expanded` and conditional CSS class `usa-accordion__content--hidden`. No USWDS accordion JS loaded.

**Modal (usa-modal):** LWC manages `@track isModalOpen`. `connectedCallback` adds an `keydown` listener on `this.template` for Escape. `disconnectedCallback` removes it. Focus is moved with `this.template.querySelector('.usa-modal').focus()`.

**Banner expand/collapse:** LWC toggle pattern identical to accordion above.

**Date formatting:** `Intl.DateTimeFormat` (available in LWS sandbox) is used for rendering comment deadlines. No external date library.

**Static resource paths:** USWDS fonts, icons, and images are deployed as a single `uswds_assets` static resource. URLs are resolved using `@salesforce/resourceUrl/uswds_assets` and passed to components via `@api` or a shared utility module.

```js
// utils/uswdsAssets.js
import USWDS_ASSETS from '@salesforce/resourceUrl/uswds_assets';
export const uswdsSpriteUrl = `${USWDS_ASSETS}/img/sprite.svg`;
export const uswdsFlagUrl   = `${USWDS_ASSETS}/img/us_flag_small.png`;
```

**CSS loading strategy:** USWDS core CSS (tokens, utilities, layout grid) is deployed as a separate static resource and loaded as an Experience Cloud global stylesheet in the site configuration. This makes USWDS utility classes (`grid-col`, `margin-top-3`, etc.) available globally without breaking LWC style scoping. Component-specific USWDS classes that need shadow DOM access use `:host` selectors in component `.css` files.

**No `eval`, no `innerHTML`:** Template rendering is entirely via LWC `if:true`, `for:each`, and `iterator` directives. String interpolation never touches the DOM directly.

**Content Security Policy:** The Experience Cloud site CSP is configured to:
- Allow `font-src` for Public Sans from USWDS static resource (self-hosted, no Google Fonts)
- Block `script-src 'unsafe-inline'` — all LWC behavior is in component JS files
- Allow `connect-src` for the Salesforce Apex endpoint only

---

## 10. Component Implementation Guidance

The following is the handoff specification for the separate LWC project.

### Component list and priority

| Priority | LWC Component | USWDS basis | Data source |
|---|---|---|---|
| P0 | `nepaBanner` | `usa-banner` | Static |
| P0 | `nepaHeader` | `usa-header--basic` | Static nav config |
| P0 | `nepaProjectSearch` | `usa-search--big`, `usa-search` | URL param, Apex |
| P0 | `nepaProjectTable` | `usa-table--sortable --stacked` | `@wire(getProjectList)` |
| P0 | `nepaPagination` | `usa-pagination` | `@api` props |
| P0 | `nepaCommentForm` | `usa-form` + sub-components | `@wire(getProcessRecord)`, Apex DML |
| P1 | `nepaStepIndicator` | `usa-step-indicator` | `@api currentStage` |
| P1 | `nepaProjectSummary` | `usa-summary-box` | `@wire(getProjectRecord)` |
| P1 | `nepaDocumentTable` | `usa-table--stacked` | `@wire(getDocuments)` |
| P1 | `nepaCommentAlert` | `usa-site-alert`, `usa-alert` | `@wire(getOpenCommentPeriods)` |
| P1 | `nepaReviewTypeTag` | `usa-tag` | `@api reviewType` |
| P1 | `nepaBreadcrumb` | `usa-breadcrumb` | `@api crumbs` array |
| P2 | `nepaProcessAccordion` | `usa-accordion` | `@api sections` array |
| P2 | `nepaEngagementList` | `usa-collection` | `@wire(getEngagements)` |
| P2 | `nepaCommentModal` | `usa-modal` | `@track` internal |
| P2 | `nepaLearnSidenav` | `usa-sidenav` | Static nav config |
| P2 | `nepaFooter` | `usa-footer--slim` + `usa-identifier` | Static |

### Apex method signatures required

```apex
// ProjectController.cls
@AuraEnabled(cacheable=true)
public static List<ProjectSearchResult> getProjectList(
    String searchTerm,
    String reviewTypeFilter,
    String sortBy,
    Integer pageNumber,
    Integer pageSize
) {}

@AuraEnabled(cacheable=true)
public static ProjectDetail getProjectDetail(String federalUniqueId) {}

@AuraEnabled(cacheable=true)
public static List<DocumentRecord> getPublicDocuments(String processId) {}

@AuraEnabled(cacheable=true)
public static List<EngagementRecord> getPublicEngagements(String processId) {}

@AuraEnabled(cacheable=true)
public static List<OpenCommentPeriod> getOpenCommentPeriods() {}

// CommentController.cls
@AuraEnabled
public static String submitComment(CommentInput input) {}
```

All methods enforce guest-user visibility: documents filtered to `nepa_public_access__c = true`, comments written as the guest user. `submitComment` returns a reference UUID from the created `PublicComplaint` record.

### `@wire` data shape examples

```js
// nepaProjectTable.js
@wire(getProjectList, {
    searchTerm: '$searchTerm',
    reviewTypeFilter: '$selectedFilter',
    sortBy: '$sortBy',
    pageNumber: '$currentPage',
    pageSize: 20
})
wiredProjects({ data, error }) { ... }
```

---

## 11. Open Items

| # | Item | Owner | Status |
|---|---|---|---|
| 1 | Agency logo and official seal assets for `usa-identifier` | Agency | Open |
| 2 | Confirm guest user FLS for `nepa_public_comment_period_end_date__c` on `IndividualApplication` | Dev | Open |
| 3 | Define comment period "open" logic — based on field dates or a separate `nepa_process_status__c` gate? | Product | Open |
| 4 | File upload strategy for comment attachments — ContentVersion linked to `PublicComplaint`, or S3 presigned? ContentVersion requires authenticated session for binary upload | Arch | Open |
| 5 | Map embed for project location — USWDS has no native map component. Options: (a) leaflet.js in LWC with LWS-safe wrapper, (b) ArcGIS LWC SDK, (c) static image with descriptive text fallback | Dev | Open |
| 6 | Notification opt-in storage — contact record creation for guest users has privacy/PII implications; alternatives: email list platform webhook vs. Salesforce EmailSubscription | Product/Legal | Open |
| 7 | Translation / multilingual support — USWDS has `usa-language-selector`; Salesforce Translation Workbench handles label translation; scope of supported languages TBD | Product | Open |
| 8 | Print stylesheet — agency staff print project packets; `@media print` styles needed | Dev | Open |
| 9 | Robots.txt and sitemap — `/learn/*` pages should be crawlable; project detail pages may need `noindex` for draft processes | Product | Open |
| 10 | VPAT / ACR — Voluntary Product Accessibility Template required for federal deployment | Compliance | Open |

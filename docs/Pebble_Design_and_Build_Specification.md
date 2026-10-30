# PEBBLE

## Product Design & Build Specification

**Version:** 1.0  
**Date:** 30 October 2026  
**Status:** Proposed baseline for implementation  
**Product:** Pebble — an offline-first personal expense and receipt tracker  
**Primary platforms:** Android and iOS (Flutter)  
**Default locale and currency:** en-AU / AUD  
**Audience:** Product owner, Flutter engineer, designer, tester

> **Design intent:** Make recording a purchase feel as effortless as dropping a pebble into a jar. Capture it now; understand it later. The app must remain useful without an account, internet connection, subscription, or banking integration.

---

# 1. Executive summary

Pebble records personal expenses in two ways: (1) enter date, amount and description manually, or (2) photograph/import a receipt and review automatically extracted details. Entries are stored in a **local SQLite database**; photographs are stored as **files in the app's private documents directory**, with database records pointing to their relative paths. The user can browse, edit, search, filter, view basic spending insights, and export/restore their records.

**Core product decisions**

| Decision | Baseline |
|---|---|
| Product model | Local-first; usable entirely offline |
| Sign-in | None required in v1 |
| Platforms | Android and iOS, with adaptable layouts for a future desktop release |
| Entry paths | Manual entry and camera/gallery receipt import |
| Receipt recognition | On-device Google ML Kit text recognition, followed by deterministic Dart parsing |
| Human review | Mandatory confirmation before scanned fields become a saved expense |
| Persistence | Drift/SQLite for records; private filesystem for images |
| Currency | AUD for v1; amount stored as integer cents |
| Data exit | CSV for tabular export; ZIP bundle for complete backup/restore |
| Cloud/sync | Not part of MVP; architecture must allow it later |
| Primary privacy rule | No receipt image, OCR text or expense data leaves the device except by explicit user export/share |

**Success definition:** A user can record an ordinary expense in seconds, recover from a failed scan without losing the receipt, and restore their full history from a verified backup. Receipt interpretation is assistive, not authoritative.

# 2. Product vision, users and boundaries

## 2.1 Problem statement

People forget small expenses, lose thermal-paper receipts, and spend too long entering the same information into spreadsheets. Full banking applications may demand account connections or expose information the user does not want to share. Pebble solves the narrower problem of recording what was spent and keeping evidence of that purchase.

## 2.2 User profiles

- **Quick recorder:** Wants to save a purchase using only date, amount and a short description.
- **Receipt keeper:** Photographs a paper docket and wants merchant, total and date prefilled.
- **Spending reviewer:** Wants useful monthly totals, categories and searchable history.
- **Privacy-conscious user:** Wants offline operation, manual backup and clear deletion controls.

## 2.3 Product principles

1. **Capture first:** Never make category, merchant, budget or a photo mandatory for a manually entered expense.
2. **Correctness over automation:** Never silently accept a guessed total, date, tax figure or merchant.
3. **User-owned data:** Provide a complete, documented backup and a practical restore path.
4. **Quiet, approachable UI:** A pebble-inspired visual identity with strong contrast, soft surfaces and selective colour.
5. **Fast by default:** Minimal navigation, sensible defaults and no unnecessary onboarding.
6. **No hidden network dependency:** Manual entries, browsing, search, insights and the initial OCR experience work without internet once required native OCR assets are installed.

## 2.4 In scope for v1

Manual CRUD; categories; date, amount, description and optional merchant/notes; receipt capture and gallery import; manual crop/rotate; offline OCR; editable extracted fields; image attachments; transaction list/search/filter; monthly/category summary; budgets as an optional feature after the core capture flow; CSV export; full backup and restore; settings; accessibility; light/dark presentation; privacy controls.

## 2.5 Explicitly out of scope for v1

Bank-account aggregation, card transaction scraping, recurring transaction creation, shared family ledgers, cloud account login, device-to-device sync, email receipt ingestion, automatic tax filing, automatic exchange rates, AI cloud inference, item-level inventory, and guaranteed line-item parsing. These are potential later features, not dependencies for the first release.

# 3. Release strategy and priorities

| Priority | Meaning | Example |
|---|---|---|
| P0 | Required before first usable release | Manual add/edit, local persistence, receipt capture, OCR review, backup/restore |
| P1 | Strong candidate for v1.0 after P0 is stable | Category trends, budgets, dark mode, app lock, richer filters |
| P2 | Future roadmap | Line-item analytics, automation, sync, multi-currency, desktop OCR alternatives |

**Recommended delivery slices**

- **M0 — Foundation:** App shell, theme, migrations, storage abstraction and tests.
- **M1 — Manual ledger:** Add/edit/delete, categories, transaction list, search and totals; release an internal build.
- **M2 — Receipt capture:** Image import, crop, file lifecycle, OCR, parsing and review; test on physical devices.
- **M3 — Data safety:** Backup, restore, export, integrity verification and failure recovery.
- **M4 — Polish and release:** Insight charts, accessibility, error states, privacy review and store preparation.

# 4. Requirements catalogue

Requirement IDs are stable and should be referenced in tests, issues and pull requests.

| ID | Requirement | Priority | Acceptance signal |
|---|---|---|---|
| FR-01 | Create manual expense with date, amount and description | P0 | Valid entry persists and displays on restart |
| FR-02 | Edit and delete an expense | P0 | Changes update history and totals; delete requires confirmation |
| FR-03 | Create and assign custom categories | P0 | Changes persist; unassigned/archived categories are safe |
| FR-04 | Photograph or import a receipt | P0 | Valid photo opens a review flow |
| FR-05 | Crop/rotate a receipt | P0 | Processed image is saved persistently, not in temporary cache |
| FR-06 | Recognise receipt text on device | P0 | OCR produces text blocks/lines or an actionable failure state |
| FR-07 | Prefill merchant, date and total when possible | P0 | Uncertain or missing values are flagged; no silent saves |
| FR-08 | Correct OCR information before saving | P0 | Every extracted field is editable, with image preview available |
| FR-09 | Store/retrieve receipt attachments | P0 | Photo reopens after restart, and missing-photo state is handled |
| FR-10 | Search and filter transaction history | P0 | Date, merchant, description, category and amount filters work |
| FR-11 | Display monthly and category spending | P0 | Totals agree exactly with saved transactions |
| FR-12 | Export CSV | P0 | Export opens via system share/save sheet, with defined columns |
| FR-13 | Create and restore full backup | P0 | Database-derived records and all available attachments round-trip |
| FR-14 | Work without internet or account | P0 | Entire standard workflow passes in airplane mode |
| FR-15 | Show onboarding, settings and recovery messages | P0 | Permissions can be denied without blocking manual entry |
| FR-16 | Optional app lock | P1 | User can enable device authentication, with tested fallback |
| FR-17 | Monthly/category budgets | P1 | User-set limits do not affect expense creation |
| FR-18 | Multiple attachments per expense | P1 | Attachment order and deletion behave consistently |
| FR-19 | Dark mode and accessible motion settings | P1 | Readability and contrast remain acceptable |
| FR-20 | Optional individual receipt line items | P2 | Line items are manually correctable and not assumed complete |

# 5. Information architecture

## 5.1 Main navigation

Five primary destinations are proposed. Keep a persistent bottom navigation bar on mobile except while the camera is actively capturing, while a blocking confirmation is present, or when the native share sheet is open.

| Destination | Purpose | Main actions |
|---|---|---|
| Home | Snapshot of this month and recent activity | Add expense, Scan, open recent item |
| Expenses | Searchable ledger | Filter, sort, open/edit/delete, Add |
| Scan | Start a receipt capture | Camera, Gallery, crop, recognise, review |
| Insights | Spending by time and category | Change period, inspect category, view budget |
| Settings | Personalisation and data control | Categories, currency, export, backup, privacy |

The **central Scan action** may be visually emphasised, but it must not obscure navigation or important content. "Add Expense" should also be an explicit one-tap action on Home and Expenses.

## 5.2 Route inventory

```text
/
├── /home
├── /expenses
│   ├── /expenses/new
│   └── /expenses/:expenseId
│       └── /edit
├── /scan
│   ├── /capture
│   ├── /crop
│   └── /review
├── /insights
└── /settings
    ├── /categories
    ├── /backups
    ├── /appearance
    └── /privacy
```

Use typed routes / `go_router` and preserve navigation state when switching between primary tabs. Deep-linking to internal detail screens is optional; do not expose private files through public URLs.

# 6. Detailed UX screen specifications

## 6.1 S01 — Home / dashboard

**Primary goal:** Communicate spending at a glance and provide an immediate recording path.

**Hierarchy:** App title or small greeting; selected month; total spent; optional budget remaining; two prominent actions (Add Expense / Scan Receipt); compact category tiles or chart; 3–5 recent transactions. Avoid showing redundant charts if the visible area becomes crowded.

**Behaviour:** Current calendar month is selected by default; tapping a month changes all summaries; tapping recent item opens detail; Add Expense opens the manual form; Scan opens capture source selection. If no budget exists, show "Set a budget" rather than inventing a remaining amount. Totals and category cards reflect the same selected period.

**States:** Fresh install with no expenses; loading; normal; database error; budget not configured. First-run empty state should say "Your first expense starts here" and expose both actions.

**Acceptance:** From Home, the user reaches amount entry with one tap, or receipt capture with one tap. Summaries are recalculated after a record is created, edited or deleted.

## 6.2 S02 — Add expense (manual)

**Required controls:** Date (defaults to today in device locale), Amount (starts empty, never implicitly $0), Description. **Optional controls:** Category (initially "Uncategorised"), Merchant, Payment method, GST, Notes, Photo attachment. Only three required fields must be visible before scrolling.

**Layout:** Large numeric amount input with AUD prefix; native date picker; single-line description with focus; horizontal category chips plus "More"; collapsible "More details" area; bottom-anchored Save button when keyboard allows. Avoid making users scroll past multiple optional fields.

**Validation:** Amount must be a positive value representable in integer cents; reject zero, malformed decimals, unsupported currency formats and excessive amounts with a field-level error. Allow descriptions up to 200 Unicode characters after trimming. Date cannot be blank; historical/future dates are allowed but warn about unusually distant dates instead of forbidding them. A refund uses an explicit transaction type rather than a negative amount typed into an expense field.

**Interaction:** Support paste of amount, numeric keypad and decimal separator; preserve unsaved form on temporary navigation or permission interruptions; Save disabled during database write; display success feedback only after commit. Do not create two records from repeated taps.

**Acceptance:** A normal manual expense takes no more than three required data entries plus Save, and persists across force-close/relaunch.

## 6.3 S03 — Scan source and camera

**Entry point:** Scan tab or Scan Receipt CTA.

**Choices:** "Take photo" and "Choose from photos". Request camera permission only when needed; if denied, explain how to proceed by importing a photo or entering manually. Use native camera or `image_picker` for initial release; a full custom live scanning overlay is not necessary.

**Capture guidance:** Show "Fit the whole receipt inside the frame", "Use good light", and "Avoid shadows and glare". Allow retake or cancel. If a camera app supplies a transient path, immediately copy the selected image into a managed staging area.

**Acceptance:** Camera denial never prevents manual expense recording. Gallery imports and new photos follow the same subsequent processing pipeline.

## 6.4 S04 — Crop and straighten

**Layout:** Dominant receipt image; crop handles; rotate 90°; reset; Continue; Back. Maintain aspect ratio flexibility because receipts are often long and narrow.

**Behaviour:** User must be able to crop away a table/background, keep the original until save decision, and preview the processed result. The native cropper can be used in v1. On Continue, run OCR on the cropped image; show a non-blocking progress state and a Cancel option.

**Failure:** If processing fails, preserve photo and offer Retry / Edit manually / Retake; never quietly discard the captured image.

## 6.5 S05 — Scan review (critical screen)

**Layout:** Small expandable receipt preview (not a giant permanent photo), editable Date / Merchant / Total / Description / Category, optional GST and payment method, extraction status chips, Save Expense at the bottom. Provide "View full receipt" and "Edit crop" actions. Line items should be hidden in MVP or marked an experimental expansion.

**Data rules:** Populate only plausible candidates. Show "Not detected" or a visible warning if merchant/date/total is absent or ambiguous. Users can override every extracted value. A detected tax figure must be labelled "GST shown on receipt" and not automatically calculated as 10% of the full receipt total.

**Confidence:** Use app-defined confidence from text patterns, source geometry and competing candidates. Google ML Kit text recognition does **not** promise calibrated receipt-field confidence values; never represent the heuristic score as a guaranteed probability.

**Save:** Only enabled once required fields are valid and confirmed. Save the structured record and photo consistently. If image commit succeeds but DB commit fails, recover/clean up the orphan during startup maintenance. If a user chooses manual editing after OCR failure, preserve the receipt attachment.

**Acceptance:** A low-confidence scan can be completed by correction and Save; a blank or illegible receipt does not crash the app.

## 6.6 S06 — Expenses / history

**Header:** Title and a search box. Secondary controls: date period, category, amount range, "With receipt", source (manual/scan), sort (newest, oldest, highest amount). Default list is newest-first, grouped by local date.

**Row content:** Merchant or description; date; amount with consistent AUD formatting; category indicator; receipt thumbnail icon if attached. Avoid third-party brand logos unless legally licensed and available offline; use simple generated merchant initials or category icons in v1.

**Interactions:** Tap opens detail; long-press or overflow exposes Edit, Duplicate, Share (optional) and Delete; pull-to-refresh re-queries local DB rather than downloading data; filters remain stable within the tab.

**Acceptance:** Search is case-insensitive; expense deletion updates list, dashboard and insights on the same device session.

## 6.7 S07 — Expense detail and edit

Display all saved fields, receipt image(s), time of creation/update, source type and any entered notes. Open image fullscreen with pinch zoom. Edit reuses manual form with prefilled values. Remove a receipt only with confirmation; remove an expense with a clearly explained effect on its attachments. A refund is visually distinguished from spending.

**Acceptance:** Save edits atomically. If a referenced attachment is missing, the transaction remains readable and displays "Receipt unavailable" with a repair/remove attachment action.

## 6.8 S08 — Insights

**v1:** Selected month total; previous-month comparison only if there is a meaningful baseline; category ranking, donut or bar chart with numeric labels; month-by-month trend. Charts must present the underlying values in accessible text. For refunds, show net expenses and allow viewing gross expenses separately where needed.

**P1:** Category budgets, overspend alerts, daily average and rolling trends. Avoid invented AI recommendations; all observations must derive from actual local data.

**Acceptance:** Chart data exactly equals a grouped SQLite query with the same period, refund and category filters.

## 6.9 S09 — Settings, categories and data

**Sections:** Preferences (theme, currency display, week start); Manage Categories (add/rename/colour/archive); Security (optional app lock); Data Management (CSV export, full backup, restore, storage usage, delete all data); About/Privacy (offline processing description and open-source licences).

**Restore UX:** Show backup date, version, counts, required disk space and whether restore will replace or merge. Require an explicit confirmation. Prefer a **restore-into-temporary-store + validate + atomic switch** strategy rather than importing over live data.

**Acceptance:** User can locate a working full backup without logging in, and can permanently erase data with explicit confirmation.

# 7. Design system and interaction language

## 7.1 Identity and tone

Pebble should be calm and tactile rather than banking-corporate. "Small records, clear picture" is a possible tagline. Use rounded pebbles/circles sparingly in the icon and category badges; the interface itself should privilege clarity. The previously explored pastel mockups are *visual references*, not pixel-perfect source files; product text, dates and currency must be converted to AUD / Australian formatting.

## 7.2 Design tokens (initial proposal)

| Token | Light | Usage |
|---|---|---|
| Canvas | `#F7F9FC` | Screen background |
| Surface | `#FFFFFF` | Cards, input surfaces |
| Ink | `#162039` | Primary text |
| Secondary text | `#65718A` | Metadata |
| Primary blue | `#2563EB` | Save, selected nav, major CTA |
| Mint surface | `#DFF5EA` | Monthly summary and success accents |
| Lilac surface | `#EEE5FF` | Receipt/OCR accent |
| Coral surface | `#FFE8E4` | Food category, gentle alerts |
| Amber surface | `#FFF0CC` | Bills/attention accents |
| Border | `#DFE5EF` | Field/card edge |
| Destructive | `#C62828` | Permanent delete/error |

**Typography:** Use an appropriately licensed, bundled family with Google-Sans-like readability (e.g. Inter), with platform fallback; 28–32sp display, 20–24sp titles, 16sp body, 14sp supporting text, 12sp only for non-essential labels. Use tabular numerals for money and charts. **Spacing:** 4pt base grid, screen margins 16–20pt, card gaps 12–16pt, card padding 16–20pt. **Shape:** cards 18–24pt radius; inputs 12–14pt; primary buttons 14–16pt; category chips 20pt or pill. **Elevation:** subtle 1-level shadow only; avoid redundant nested cards.

## 7.3 Motion and feedback

Subtle page transition of ~180–240ms; one gentle pulse on successful save; OCR progress with text such as "Reading receipt…". Respect the OS reduce-motion preference. Never use animation to hide IO latency. Every error message should pair a diagnosis with an action.

## 7.4 Responsive layouts

Use safe areas and flexible widths. Minimum supported phone width should be tested at 320 logical pixels; avoid mandatory four-column category tiles at this size. For tablets or future desktop, switch to navigation rail and a two-pane list/detail layout. Never lock business logic to a particular screen size.

## 7.5 Accessibility

44–48 logical pixel effective touch targets, screen-reader semantics for charts, meaningful form labels and error summaries, adjustable text scaling to at least 200% without hidden save controls, WCAG AA-inspired contrast goals, distinguish categories by icon/text in addition to colour, keyboard and focus order, and large/zoomable receipt images.

# 8. End-to-end functional flows

## 8.1 Manual expense

```text
Home / Expenses
   -> Add Expense
   -> Enter date (default today), amount, description
   -> [Optional category, merchant, notes, attachment]
   -> Validate
   -> Commit SQLite transaction and attachment reference
   -> Refresh reactive queries -> Show saved record
```

## 8.2 Receipt expense

```text
Scan -> Camera / Photo picker
   -> Copy input to staging -> Crop / rotate -> OCR
   -> Organise recognised text into lines / blocks
   -> Parse candidates: merchant / date / total / GST
   -> Review uncertain or missing values
   -> User edits and confirms
   -> Move/copy final image into private receipt store
   -> Insert expense + attachment metadata in SQLite
   -> Update summaries -> Show saved record
```

## 8.3 Failure and recovery

| Failure | Expected response |
|---|---|
| User denies camera permission | Offer gallery and manual entry |
| OCR returns zero usable text | Keep photo, allow retake or manual entry |
| Date is ambiguous (03/04/26) | Default to en-AU interpretation only with warning/confirmation |
| Multiple totals match | Show best candidate with "Check total" cue, allow override |
| Insufficient disk space | Do not commit incomplete record; offer storage clean-up |
| App closes during scan | Restore staged draft when possible, or clean old staging safely |
| Backup archive corrupted | Reject, preserve existing dataset, explain problem |
| Referenced photo missing | Show attachment placeholder; never remove expense automatically |

# 9. Flutter architecture

## 9.1 Architecture choice

Use a **feature-first modular architecture**, with presentation, application, domain and data boundaries. This app is small enough to avoid unnecessary microservices or heavyweight clean-architecture boilerplate, but OCR/storage interfaces must be mockable.

```text
Flutter UI (screens, widgets, view models)
          |
Riverpod controllers / application use cases
          |
Domain models + validation + repository contracts
          |
Repositories and adapters
    +-----+------------+--------------+
    |                  |              |
Drift/SQLite     ReceiptFileStore   ReceiptOcrService
    |                  |              |
Local database   App-private files  Native ML Kit Android/iOS
```

**Dependency direction:** UI depends on abstractions; domain layer never imports ML Kit, Flutter widgets or a SQLite implementation. Use explicit result types for recoverable errors and structured logging without receipt content.

## 9.2 Proposed source tree

```text
lib/
  app/
    app.dart
    router.dart
    theme/{colors,typography,theme}.dart
  core/
    errors/
    utils/{money,date,ids}.dart
    storage/
    accessibility/
  features/
    expenses/
      domain/{expense,category,expense_repository}.dart
      data/{expense_dao,expense_repository_impl}.dart
      presentation/{expense_list,expense_detail,expense_form}.dart
    scanning/
      domain/{receipt_candidate,ocr_result}.dart
      application/{capture_receipt,parse_receipt,save_scan}.dart
      data/{mlkit_ocr_adapter,receipt_parser,image_store}.dart
      presentation/{scan_source,crop,scan_review}.dart
    insights/
      data/insight_queries.dart
      presentation/insights_screen.dart
    settings/
    backup/
  database/{app_database,tables,migrations}.dart
  main.dart

test/{unit,widget,fixtures}/
integration_test/
assets/{icons,illustrations}/
```

## 9.3 Dependency recommendations (verified 30 October 2026)

| Area | Candidate | Purpose / caution |
|---|---|---|
| State | `flutter_riverpod` 3.4.x | Testable state and reactive async flow |
| Navigation | `go_router` 18.x | Tab shells and typed navigation |
| Database | `drift` 2.35.x and `drift_flutter` | Typed queries, migrations, watch streams |
| OCR | `google_mlkit_text_recognition` 0.17.x | On-device text recognition on Android/iOS only |
| Camera/gallery | `image_picker` 1.2.x | Simplest first-release capture/import; implement lost-data recovery on Android |
| Crop | `image_cropper` 13.x | Native crop/rotate; copy output out of cache |
| File locations | `path_provider` 2.1.x | App documents and temporary storage |
| Share/export | `share_plus` 13.x | Platform share sheets |
| Archive | `archive` 4.5.x | Backup ZIP creation and validation |
| Optional app lock | `local_auth` 3.x | Biometric/device authentication in P1 |
| Optional key storage | `flutter_secure_storage` 11.x | Only if encryption keys or other secrets are added |

**Toolchain baseline:** Use a current Flutter stable channel that satisfies Dart 3.12 and the chosen plugin requirements; iOS deployment target at least **15.5** for the cited ML Kit plugin. Select Android SDK minimum 24+ as a conservative cross-plugin baseline and validate the actual resolved dependencies and Google Play target/compile SDK policy before building a release. Lock specific verified versions in `pubspec.lock`. Do not add the obsolete `sqlite3_flutter_libs` package for a modern `sqlite3` 3.x stack.

**Platform caveat:** Google's ML Kit **text recognition** works on Android/iOS via native platform channels; it is not a Flutter desktop/web OCR engine. The separate Google ML Kit **document scanner** offering is Android-only in the cited package, so Pebble's base cross-platform flow should use capture/picker plus cropper and text recognition, not require that scanner feature.

# 10. Data architecture and schema

## 10.1 Data conventions

- Generate UUID identifiers locally; never rely on sequential IDs for import/merge identity.
- Save money as signed or unsigned **integer minor units** and transaction type, not IEEE floating-point; AUD is 100 cents per dollar.
- Save the transaction's **local calendar date** (`YYYY-MM-DD`) separately from UTC creation/update timestamps to preserve the user-entered expense date across timezones.
- Use `expense` and `refund` transaction types, each with a positive magnitude `amount_minor`; derive signed net total in queries.
- Store only **relative file paths**. Absolute sandbox paths can change between installations.
- Enable `PRAGMA foreign_keys=ON`; use migrations and integrity tests. Use transactions for logically related inserts/updates.

## 10.2 Entity relationships

```text
Category (1) ---------- (many) Expense
                              |
                              | (1 -> many)
                              +---------- ReceiptAttachment
                              |
                              +---------- ReceiptLineItem [P2]

AppSetting (key -> value)
```

## 10.3 SQL reference schema (conceptual migration v1)

```sql
CREATE TABLE categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL COLLATE NOCASE UNIQUE,
  colour_hex TEXT NOT NULL,
  icon_key TEXT NOT NULL,
  is_system INTEGER NOT NULL DEFAULT 0 CHECK (is_system IN (0, 1)),
  is_archived INTEGER NOT NULL DEFAULT 0 CHECK (is_archived IN (0, 1)),
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE expenses (
  id TEXT PRIMARY KEY,
  local_date TEXT NOT NULL,            -- YYYY-MM-DD
  amount_minor INTEGER NOT NULL CHECK (amount_minor > 0),
  currency TEXT NOT NULL DEFAULT 'AUD',
  txn_type TEXT NOT NULL DEFAULT 'expense'
    CHECK (txn_type IN ('expense', 'refund')),
  description TEXT NOT NULL CHECK (length(trim(description)) > 0),
  merchant TEXT,
  category_id TEXT REFERENCES categories(id) ON DELETE SET NULL,
  payment_method TEXT,
  gst_minor INTEGER CHECK (gst_minor IS NULL OR gst_minor >= 0),
  notes TEXT,
  source TEXT NOT NULL CHECK (source IN ('manual', 'camera', 'gallery')),
  created_at_utc TEXT NOT NULL,
  updated_at_utc TEXT NOT NULL,
  CHECK (gst_minor IS NULL OR gst_minor <= amount_minor)
);

CREATE TABLE receipt_attachments (
  id TEXT PRIMARY KEY,
  expense_id TEXT NOT NULL REFERENCES expenses(id) ON DELETE CASCADE,
  relative_path TEXT NOT NULL UNIQUE,
  sha256_hex TEXT NOT NULL,
  mime_type TEXT NOT NULL,
  width_px INTEGER,
  height_px INTEGER,
  byte_size INTEGER NOT NULL CHECK (byte_size >= 0),
  created_at_utc TEXT NOT NULL
);

CREATE TABLE app_settings (
  setting_key TEXT PRIMARY KEY,
  setting_value TEXT NOT NULL
);

CREATE INDEX idx_expenses_local_date ON expenses(local_date DESC);
CREATE INDEX idx_expenses_category_date ON expenses(category_id, local_date DESC);
CREATE INDEX idx_expenses_merchant ON expenses(merchant);
CREATE INDEX idx_attachments_expense ON receipt_attachments(expense_id);
```

**Implementation note:** Express tables and migrations using Drift declarations. The SQL above is a reference contract, not a request to bypass Drift code generation. FTS5 or a searchable normalized column can be added only after profiling. A nullable `category_id` represents "Uncategorised"; archiving a category does not rewrite historical entries.

## 10.4 Query semantics

An expense of 1,250 cents and a refund of 250 cents in the same selected month produce a **net spend of 1,000 cents**. Example concept:

```sql
SELECT SUM(CASE txn_type
             WHEN 'refund' THEN -amount_minor
             ELSE amount_minor
           END) AS net_spend_minor
FROM expenses
WHERE local_date >= ? AND local_date < ?;
```

Use half-open date intervals based on **local calendar dates** for monthly reporting. Do not parse or compare formatted currency strings. All chart percentages must use the same reporting denominator and rounding rules; annotate negative or zero net totals instead of displaying misleading pie slices.

## 10.5 Default categories

Groceries, Dining, Transport, Shopping, Bills, Health, Entertainment, Home, Travel, Other. Users can rename, reorder, recolour, add or archive categories. Keep initial categorisation optional; merchant-to-category suggestions can be a later enhancement, not a hidden requirement.

# 11. Receipt image storage and lifecycle

## 11.1 Filesystem layout

```text
<ApplicationDocumentsDirectory>/pebble/
  data/pebble.sqlite
  receipts/2026/10/<uuid>.jpg
  thumbs/<uuid>.jpg                 [optional regenerated cache]
  staging/<session-uuid>.*         [temporary, reclaimable]
  backups/                         [optional local pre-share staging]
```

Store authoritative images in `receipts`, **not** a cache or the public camera roll. The DB stores `receipts/2026/10/<uuid>.jpg`, not an OS-specific absolute location. Original imports should not be modified in the user's photo library. Prefer resized JPEG for typical receipts (e.g. 2000–3000 px long edge, quality ~80–88) while retaining legibility; do not downscale so aggressively that small text becomes unreadable. Retain enough information to inspect details later.

## 11.2 Atomic-ish save protocol

1. Capture/select -> copy photo into private staging.
2. Crop/process -> write final image to a new private path and flush it.
3. Compute SHA-256 and metadata; validate that the file exists and is readable.
4. In one SQLite transaction, insert expense and attachment references.
5. On failure, remove unreferenced final files or mark them for safe startup garbage collection; never remove original user-gallery images.
6. On delete, remove DB references transactionally, then asynchronously remove owned files using a retryable cleanup queue; integrity scan reclaims orphans.

Use random UUID filenames, extension allow-list, MIME checking, size ceilings and path canonicalisation. Do not blindly load path strings from a backup into filesystem operations.

## 11.3 Privacy defaults

No advertising SDK; no analytics containing merchant names, amounts, descriptions, OCR text or photos; no upload-by-default; redact sensitive fields in logs and crash reports; show permissions on first need. Explain the difference between encrypted OS device storage and **app-level encryption**. If app-level encryption is offered later, design explicit key recovery first, because unrecoverable keys can make backups unusable.

# 12. Receipt OCR and parsing design

## 12.1 Processing stages

1. **Input:** Check format, reasonable file size and image dimensions; strip unneeded EXIF metadata from the derived image where practical.
2. **Preprocess:** Crop/rotate via user's crop selection; optionally grayscale/contrast/sharpen in a carefully tested path (retain original processed sample for troubleshooting).
3. **Recognise:** Run ML Kit TextRecognizer with Latin script; collect recognised blocks, lines and text elements with bounding boxes.
4. **Normalise:** Preserve original line order and geometry; normalise spaces, Unicode currency variants and common OCR substitutions only in candidate matching (never irreversibly overwrite the raw source).
5. **Find candidates:** Merchant header, localised date/time, grand total, explicit GST, optional ABN and optional line items.
6. **Rank candidates:** Apply receipt-specific heuristics and cross-checks; keep alternatives for uncertain fields.
7. **Review:** Show extracted values and flags; user explicitly confirms.
8. **Persist:** Save only reviewed expense fields and attachment; raw OCR text should be ephemeral by default or stored only through a clearly documented opt-in diagnostic mechanism.

## 12.2 Candidate extraction rules

| Field | First-pass approach | Common pitfall |
|---|---|---|
| Merchant | Prefer prominent non-generic lines near top; exclude ABN/address labels | Store number mistaken for store name |
| Date | Match `DD/MM/YYYY`, `DD-MM-YYYY`, `DD MMM YYYY`, ISO and nearby "DATE" | AU vs US date ambiguity |
| Total | Look for "TOTAL", "AMOUNT PAID", "EFTPOS", "BALANCE DUE" and nearby amount | Subtotal, cash tendered, change and card authorisation |
| GST | Prefer explicitly labelled "GST" or "TOTAL GST" line | Inferring tax from overall total on mixed-tax groceries |
| Amount | Recognise `$12.50`, `12.50`, thousands separators | OCR confusion between `0/O`, `8/B`, `.`, `,` |
| Refund | Look for refund/return/credit indicators | Treating refund as ordinary expense |
| Line items | Experimental pairs of left-side description and right-side amount | Discounts, weighed products, wrapped descriptions |

**Australian-specific rules:** `en-AU` parsing and AUD default; ABN matching is informative but optional; receipt GST may be zero or absent; grocery receipts may contain GST-free items; do not assume 10% GST on every transaction or reconstruct totals from line items if confidence is insufficient.

## 12.3 Deterministic confidence bands

- **High:** Single strong labelled total plus plausible currency/date/merchant signals.
- **Medium:** Plausible value with competing candidates or imperfect formatting.
- **Low:** No label, multiple contradictions, or inferred from a weak candidate.

Define score functions and thresholds in unit-tested Dart code, such as total label weight + geometry + amount validity − nearby "subtotal"/"change" penalties. Treat these as **application heuristics**, not statistical guarantees. Do not imply that ML Kit offers field-level receipt-confidence scores.

## 12.4 OCR example

```text
WOOLWORTHS
ABN 88 000 014 675
DATE 30/10/2026
Milk            3.10
Apples          5.00
Subtotal        8.10
GST             0.00
TOTAL AUD       8.10
```

**Expected parser result:** merchant = Woolworths; local_date = `2026-10-30`; total = 810 cents; GST = 0 cents; category suggestion = Groceries only if user-enabled mapping rules exist. The user must be able to change any of these values, and all examples must be validated against real, varied receipt fixtures.

## 12.5 Duplicates and multi-receipt images

V1 should warn on likely duplicate **attachment hashes** and on same merchant/date/amount within a configurable period, but let the user save legitimate repeats. Multi-receipt photographs are unsupported in v1: ask the user to crop to a single receipt or import each individually. Never hard-block because two distinct purchases can legitimately have the same amount.

# 13. Backup, restore, export and portability

## 13.1 CSV export

CSV UTF-8 with a BOM option for Excel compatibility. Header: `id,date,type,amount,currency,description,merchant,category,payment_method,gst,notes,source,receipt_count,created_at_utc,updated_at_utc`. Export a **human-readable decimal amount** (`12.50`) from integer cents. Quote embedded commas, quotes and newlines. CSV intentionally does not embed photos; communicate this plainly. Share via native sheet and support saving to Files/Downloads.

## 13.2 Complete backup format

```text
pebble-backup-2026-10-30.zip
  manifest.json
  expenses.json
  categories.json
  settings.json
  receipts/<uuid>.jpg
  [optional] checksums.json
```

`manifest.json` must include `format_version`, `exported_at_utc`, `app_version`, `currency`, row counts and checksum metadata. Prefer a documented, canonical JSON data export rather than raw SQLite only; it can survive database schema changes. Version the backup schema independently from the DB schema. JSON money fields use integer cents. Support checksum verification for every receipt and the JSON payloads.

**Restore mode in v1:** **Replace all local data**, after full validation and prominent confirmation. A verified snapshot of the current state before replacement is strongly recommended. Merge import is deferred to P2 because deduplication and conflict resolution are complex.

## 13.3 Backup/restore acceptance

- Back up a test dataset containing manual entries, scanned entries, custom categories, notes, refunds and images.
- Restore on a clean install of the same app release; verify row counts, totals and SHA-256 hashes.
- Repeat with a backup made by a prior supported schema version.
- Test truncated/corrupt archive, missing file, path traversal attempts, oversized payload and insufficient storage.
- Never alter the existing database until the incoming archive and its content pass validation.
- Require the user to choose a safe location; explain that exported files may no longer be controlled by Pebble once shared.

# 14. Security, privacy and compliance considerations

## 14.1 Threat model

Main threats: misplaced phone; overly broad photo permission; accidentally exported backups; malicious imported archives; image decompression bombs; leaked receipt text in logs; corrupted/partial writes; and app reinstall without backup. OCR must execute on device for v1. Apply input size bounds before decode and constrain total uncompressed ZIP size and entry count on restore.

## 14.2 Controls

- Use platform app-private directories and device encryption; optional biometric/PIN gate is a second-line UX control, not proof of encrypted-at-rest app data.
- Use least-privilege permissions; photo-picker access where available and camera permission only when needed.
- Use file type and MIME validation, archive canonical path validation, symlink rejection and checksum verification.
- Avoid storing raw OCR data and image EXIF location metadata unnecessarily.
- Make Export, Delete attachment and Delete all data user-initiated, and require destructive-action confirmation.
- Add a privacy policy before release describing local processing, permissions, backup/sharing and crash reporting, even if no user account exists.
- Assess OS-level automatic backup behaviour explicitly (Android and iOS), so the statement "offline-only" is not confused with a claim that the OS never backs up application data.

# 15. Performance, resilience and quality targets

| Metric | Proposed target | Measurement |
|---|---|---|
| Manual entry responsiveness | Tap to editable form ≤ 300 ms on typical target device | Profile build, warm start |
| DB inserts | Single-entry commit typically ≤ 300 ms | Integration benchmark |
| List scrolling | Stable 60 fps target in normal 1,000-entry dataset | Flutter DevTools |
| History scale | 10,000 entries with paged display and indexed filters | Load benchmark |
| OCR experience | Display progress immediately; aim for typical scan in < 5 s, not a hard guarantee | Device matrix + real receipt fixtures |
| Offline capability | 100% of P0 feature flows without network | Airplane-mode suite |
| Financial accuracy | Integer-cent exact totals across CRUD, export and restore | Property/unit tests |
| Crash-free goal | ≥ 99.5% sessions in release monitoring where user opts in | Aggregated, privacy-safe telemetry |

Avoid relying on performance promises from one device. Profile memory and image decode on lower-end Android hardware. Background processing must respect lifecycle, cancellation and resumption. Use thumbnail caching, lazy image loading, query pagination and `watch()` only for screen-relevant result sets.

# 16. Validation, error handling and empty states

**Form rules:** Date required; amount positive with two decimal places for AUD; description nonblank; category optional; GST cannot exceed amount; excessively long inputs are rejected with helpful limits. **Scan rules:** Unreadable receipt -> keep image and allow manual correction; mismatch between OCR and user-selected total -> reviewed user value wins. **Storage rules:** Failed save returns an actionable error; never claim success before commit.

**Sample microcopy**

| State | Proposed text | Action |
|---|---|---|
| Empty ledger | "Every little expense adds up. Add your first one." | Add expense / Scan |
| Camera denied | "Camera access is off. You can still choose a photo." | Choose photo / Settings |
| OCR empty | "We couldn't read this receipt clearly." | Try again / Enter manually |
| Total uncertain | "Please check the total before saving." | Edit total |
| Backup successful | "Backup created and checked." | Save/share |
| Missing receipt | "The receipt image isn't available on this device." | Remove broken link |
| Restore invalid | "This backup could not be verified. Your current data is unchanged." | Choose another file |

# 17. Testing strategy

## 17.1 Unit tests

Money parsing/rounding; currency formatting; date parsing (including ambiguous dates and daylight saving boundaries); receipt total ranking; exclusions for subtotal/change/refund; checksum; duplicate detection; category aggregation; refund net calculations; backup manifest validation; sanitisation of restored paths.

## 17.2 Widget tests

Empty-state CTAs; date/amount input; keyboard resize and text scale; save loading state; OCR review highlighting; image missing-state; category chip layout at 320dp width; high contrast/dark mode; screen-reader descriptions and focus order.

## 17.3 Database and integration tests

CRUD/migration versions; foreign-key behaviour; attachment cleanup; reactive update after edit/delete; process interruption; restart with staging artifacts; export/import round trip; gallery and camera flows with plugin seams mocked; image storage errors; invalid ZIP attacks.

## 17.4 Device acceptance matrix

| Device class | Test priorities |
|---|---|
| Recent Android | Permissions, camera, ML Kit, system photo picker |
| Lower-end Android | OCR latency, memory, image sizes, interrupted capture |
| Recent iPhone | Camera/photo permissions, crop, ML Kit, share sheet |
| Smaller iPhone | Form keyboard overlap, tab bar, 200% text scale |
| Airplane mode | Manual, scan, search, insights, backup, restore |
| Device language en-AU | AUD, DD/MM/YYYY, month boundaries, accessibility |

**Receipt test corpus:** minimum 100 varied, user-consented or synthetic test receipts: groceries with GST-free lines, restaurant receipts, fuel, long/faded thermal paper, crumpled, skewed, high/low light, partial photos, refunds, multiple totals, unfamiliar merchants and handwritten additions. Remove any real personal/payment details from fixtures.

## 17.5 Acceptance scenario examples

- **AT-01:** Given an empty DB, when the user enters 30/10/2026, $12.50 and "Coffee", then one expense appears in History, Home and Insights and survives relaunch.
- **AT-02:** Given a photographed receipt with a clear `TOTAL 48.75`, when the user scans and confirms, then amount=4,875 cents and the image is linked to the saved record.
- **AT-03:** Given OCR incorrectly recognises $48.75 as $43.75, when the user corrects the field, then only $48.75 is stored and reported.
- **AT-04:** Given camera permission denied, the user can still enter manually or pick a photo.
- **AT-05:** Given 1 expense $15.00 and 1 refund $5.00 in a month, Insights shows net spend $10.00 with clearly labelled refund handling.
- **AT-06:** Given an exported backup, restoring on a clean install yields identical UUIDs, amounts, categories and image checksums.
- **AT-07:** Given corrupt backup content, importing does not change any existing record.
- **AT-08:** Given no network, manual entry, OCR, search, summaries and backup remain available.

# 18. Build, tooling, CI and release operations

## 18.1 Developer setup

Flutter stable + Dart meeting package constraints, Android Studio/Xcode as appropriate, platform SDKs, and a physical iOS/Android testing device. Commit `pubspec.lock` for reproducibility. Use `flutter analyze`, formatter and lints on every PR. Store signing keys and provisioning information outside the repo.

## 18.2 CI workflow

```text
Pull request
  -> flutter pub get
  -> dart format --output=none --set-exit-if-changed .
  -> flutter analyze
  -> flutter test --coverage
  -> drift code generation verification
  -> build Android debug/profile artifact
  -> platform-specific iOS build/test in macOS CI
  -> verify coverage and dependency audit
  -> require review before merge
```

Include a migration test that opens previous-schema fixture DBs and validates both schema upgrade and representative data. Require golden screenshot coverage for the main screens only after UX stabilises; don't block early logic work on brittle golden tests.

## 18.3 Definition of done

Each story has: tested functional behaviour; empty/loading/error states; accessibility checks; no sensitive logs; consistent design tokens; updated migrations/docs; rollback awareness; and at least one automated test at the appropriate layer. Receipt changes additionally require device testing and a new/updated receipt fixture.

## 18.4 Release checklist

Privacy policy; permissions copy; app icon/splash; accessibility test; release-mode OCR performance; verified restore drill; data-deletion process; error reporting choice; store screenshots; crash-free smoke test; store review metadata; platform signing; package licences and attribution.

# 19. Suggested milestone backlog

| Sprint / workstream | Deliverables | Exit gate |
|---|---|---|
| A. Foundation | Theme, navigation, Drift tables/migrations, repositories, validation | Database test + app shell |
| B. Ledger | Manual form, list, detail, category management, search | End-to-end manual CRUD |
| C. Image pipeline | Camera/gallery, persistent staging, crop/rotate, thumbnails | Photo survives restart |
| D. OCR | Native ML Kit adapter, parsing, confidence flags, review UI | 100-receipt suite + corrections |
| E. Safety | Full backup/import, CSV, integrity checks, storage cleanup | Clean-device restore drill |
| F. Quality | Insights, error states, a11y, dark mode optional, release checks | Signed beta and acceptance suite |

Estimate effort only after prototype spikes: camera/ML Kit compatibility, realistic receipt recognition accuracy, and backup integrity. These are the highest-uncertainty workstreams.

# 20. Risks and mitigation

| Risk | Impact | Mitigation |
|---|---|---|
| OCR reads wrong grand total | High financial inaccuracy | Mandatory review; ranked candidates and warnings |
| Offline OCR model availability differs by platform/device | Interrupted scanning | Device validation; graceful manual fallback |
| Photos remain in cache and disappear | Broken receipt evidence | Copy to app-private persistent folder before DB reference |
| Restore causes partial data loss | Critical | Validate in staging; atomic switch + tested rollback |
| Large images exhaust memory | Crash on lower-end devices | Bound image resolution, stream and cache thumbnails |
| Dependency/SDK incompatibility | Build failure | Check plugin platform constraints; pin and CI test versions |
| Missing cloud sync loses data on uninstall | User loses history | Prominent periodic backup reminder; verified export path |
| Generic merchant/category inference is unreliable | Misleading analytics | Make categories user-controlled; avoid silent assumptions |
| Raw receipts expose personal data | Privacy breach | On-device OCR, private storage, no sensitive logs |

# 21. Roadmap after v1

- **1.1:** Category budgets, recurring expense templates, duplicate/merchant shortcuts, robust share-to-Pebble receipt import.
- **1.2:** Optional item-level extraction and review, better line-item grouping, deeper trends and custom report periods.
- **2.0:** Encrypted cloud backup and optional multi-device sync using stable UUIDs, versioning and conflict handling. No sync implementation should be started until device identity, deletion/tombstone semantics, key management and conflict resolution are designed.
- **Desktop:** Flutter layout can be reused, but OCR adapter must be replaced/extended because the current ML Kit text recognition plugin is mobile-only.

# 22. Open design decisions and recommended defaults

| Question | Proposed default | Reason |
|---|---|---|
| Is a category required? | No | Fast entry wins |
| Keep receipt original and cropped image? | Keep final processed version in v1 | Smaller storage and simpler lifecycle; original only if required later |
| Allow multiple currencies? | AUD only in v1 | Simpler precise summaries |
| Should OCR save automatically? | No | Receipt errors are too consequential |
| Should GST be inferred? | No | Mixed taxable/GST-free receipts |
| Do we need cloud sync? | No in v1 | Privacy, time-to-release and reliability |
| Do we need authentication? | No; optional local app lock later | Avoid sign-in friction |
| Can expenses be soft-deleted? | Hard-delete locally in v1 after confirmation | Simpler; add tombstones with sync architecture |
| How does restore behave? | Replace after validated preview and confirmation | Safer than ambiguous merge |
| Should receipts be indexed in search? | Merchant/description first; OCR body indexing later | Privacy and complexity trade-off |

# 23. Build acceptance gate — release 1.0

Pebble 1.0 is ready only when all of the following are true:

- [ ] New installation completes onboarding without an account or internet connection.
- [ ] Manual expense can be created, edited, deleted and correctly aggregated.
- [ ] Camera/gallery receipt can be cropped, read and corrected without data loss.
- [ ] OCR failures and denied permissions have a usable manual path.
- [ ] Each saved receipt opens after restart, and missing photos are handled safely.
- [ ] Monthly totals, categories and refunds reconcile to integer-cent SQLite queries.
- [ ] Search/filter behaves on at least 10,000 representative entries.
- [ ] CSV is machine-readable, and backup/restore passes integrity tests.
- [ ] Full restore fails safely without modifying existing data.
- [ ] UI meets small-screen, text scaling, touch target and screen-reader checks.
- [ ] Real-device Android/iOS beta test covers the receipt corpus and airplane mode.
- [ ] Privacy policy, permissions and store-ready release configuration are complete.

# 24. Reference links and verification notes

Package/API references were reviewed on **30 October 2026**. Versions are candidates, not a substitute for a build-time resolution check. Official package pages:

- ML Kit Text Recognition: https://pub.dev/packages/google_mlkit_text_recognition
- ML Kit Document Scanner (Android-only beta in the cited package): https://pub.dev/packages/google_mlkit_document_scanner
- Drift: https://pub.dev/packages/drift
- Riverpod: https://pub.dev/packages/flutter_riverpod
- go_router: https://pub.dev/packages/go_router
- image_picker: https://pub.dev/packages/image_picker
- image_cropper: https://pub.dev/packages/image_cropper
- path_provider: https://pub.dev/packages/path_provider
- share_plus: https://pub.dev/packages/share_plus
- archive: https://pub.dev/packages/archive
- local_auth: https://pub.dev/packages/local_auth
- flutter_secure_storage: https://pub.dev/packages/flutter_secure_storage
- Obsolete legacy sqlite3 Flutter library package: https://pub.dev/packages/sqlite3_flutter_libs

**Document usage:** This is a complete v1 product/build baseline, not a claim that implementation or device tests have already occurred. Mockup images are concepts only, and their sample amounts, people, dates and currency must not be treated as functional product requirements.

# Appendix A. UI design mockups

The five SVGs below illustrate the planned Flutter app and can be viewed directly on GitHub. They are **scalable design references, not implemented app screenshots or pixel-perfect component specifications**. The primary build source of truth remains the functional requirements, data model, interaction guidelines and acceptance tests in this document.

The mockups use Australian-dollar sample data and Australian-style dates. Original exploratory concept images are retained in the separately distributed design package; the repository's editable SVGs provide a consistent, directly viewable reference set.

## A.1 Home dashboard

![Pebble home screen](mockups/home.svg)

## A.2 Manual expense entry

![Pebble add expense screen](mockups/add-expense.svg)

## A.3 Receipt scan and OCR review

![Pebble scan receipt screen](mockups/scan-receipt.svg)

## A.4 Expense history

![Pebble expenses screen](mockups/expenses.svg)

## A.5 Insights and data storage

![Pebble insights screen](mockups/insights.svg)

Browse the [mockup gallery](mockups/README.md) for page-by-page design intent and implementation notes.

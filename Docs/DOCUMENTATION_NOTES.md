# Documentation Notes

This note explains how the documentation set in this repository was
produced, what it deliberately did and did not rely on, and what should be
checked before treating any specific number or claim as final.

## Documents in this set

`README.md`, `PRD.md`, `ARCHITECTURE.md`, `DATABASE.md`, `BACKEND.md`,
`FRONTEND.md`, `API_DOCUMENTATION.md`, `BP_PREDICTION.md`,
`SYMPTOM_CHECKER.md`, `IOT.md`, and the university-template thesis document,
produced in three forms: `Final_Graduation_Documentation.md` (source of
truth), `Final_Graduation_Documentation.tex` (LaTeX), and
`Final_Graduation_Documentation.docx` (Word). All three carry identical
content; the `.tex` and `.docx` are formatted derivatives of the `.md`, not
independently written.

### On the cover page and logos

The official template (`Documentation structure guide.docx`, provided by the
user) embeds two real institutional logo images
(`word/media/image1.jpeg`/`image2.jpeg` inside that `.docx`'s own ZIP
structure): the Zagazig University logo and the Faculty of Computers and
Informatics logo. Both were extracted and copied into
`assets/branding/zagazig_university_logo.jpeg` and
`assets/branding/faculty_computers_informatics_logo.jpeg`, and are used
as-is on the cover page of both the `.tex` and `.docx` outputs — they were
not recreated, redrawn, or substituted with placeholder art.

The `.docx` was assembled by reusing the official template's own style
sheet, theme, fonts, and numbering definitions (`word/styles.xml`,
`word/theme/`, `word/fontTable.xml`, `word/numbering.xml`) verbatim, and
replacing only `word/document.xml` (the body content) and
`docProps/core.xml` (document metadata, which previously carried the prior
template author's name and should not be attributed to this project). This
means headings, fonts, and general formatting in the `.docx` match the
official template's own defaults rather than an independently chosen style.
Team member names, roles, and supervisor names on the cover page were taken
from `Project_Documentation.tex` (an earlier project document already in
the repository) — this is the only information reused from that file.
Nothing technical was reused from it: that file separately contains
outdated technical claims (e.g., describing the BP model as an LSTM, and
describing the smart-box hardware as "in progress") that were independently
found to be incorrect during this documentation effort and are not repeated
anywhere in this set.

No system tool was available in this environment to render the `.docx` in
Word itself or compile the `.tex` with a LaTeX toolchain (neither `pandoc`,
`soffice`, nor `pdflatex` were present). Both files were instead validated
structurally: the `.tex` follows the same package/document-class pattern as
the already-existing `Project_Documentation.tex` (known to be a working
LaTeX file), and the `.docx` was built as a raw OOXML package, unzip-verified
(`file` correctly identifies it as "Microsoft Word 2007+", all 15 zip
entries pass an integrity test, and tag-balance was checked across the
generated `document.xml`). A first attempt at packaging the `.docx` used
PowerShell's `Compress-Archive`, which stores entries with backslash path
separators on Windows — invalid per the ZIP/OPC spec and would have made
the file unreadable by Word; this was caught by inspecting the zip entry
names directly and corrected by writing a minimal, spec-compliant ZIP
packer instead. Despite this validation, a final open-in-Word check by a
human before submission is still recommended, since no tool in this
environment could perform that specific check.

## Method

Every factual claim in this set was produced by reading primary sources
directly, in this priority order:

1. **Source code** — Python backend modules, Dart/Flutter widgets and
   providers, Arduino/ESP firmware `.ino` files, SQLAlchemy models, Pydantic
   schemas, Alembic migrations.
2. **Generated artifacts** — model metadata JSON, evaluation reports, result
   CSVs, and the training notebook's own cell outputs. These are treated as
   primary evidence (the same way a lab result is), not as documentation
   prose, because they are produced by running actual code, not written by a
   person describing intent.
3. **Direct verification** — where a claim could be checked two ways (e.g.,
   "does the QR code encode an encrypted payload?"), the code was read on
   both sides (backend endpoint and Flutter screen) rather than trusting one
   side's comment or docstring alone.

**Deliberately not used as a source of fact**: the repository's own prior
planning and handoff notes (`BP_FLOW_CALIBRATION_HANDOFF.md`,
`BP_Hardware_Analysis.md`, and everything under `Plans/`), and the
pre-existing `README.md` and `Database-Tables.png` before this pass. These
were checked *against* the code to see whether they were still accurate —
several were found to be stale or aspirational — but no fact in the final
documents traces back to one of these files as its source. Where a planning
document's stated intent turned out to already be implemented (e.g., the
BP-triage handoff, the calibration service's actual clamp/upgrade logic),
the documentation cites the implementing code directly, not the plan that
preceded it.

## Corrections made during this pass

These are documented here because they contradict earlier project
materials, and a reader comparing this set against those materials should
know the discrepancy was found and resolved deliberately, not overlooked:

- The blood-pressure model is a **1D-CNN**, not an LSTM as an earlier README
  stated — verified against the training notebook's own model comparison
  table (`BP_PREDICTION.md` §8).
- The production symptom-checker model is **LightGBM over structured
  features**, not a "Standard MLP" — an older TF-IDF/classical-ML pipeline
  still runs in parallel, not in the newer model's place
  (`SYMPTOM_CHECKER.md` §1–§2).
- The "90.3% accuracy" figure attached to the symptom checker in an earlier
  README is explicitly disowned by the current model's own generated
  metadata as measured on a non-representative, narrow synthetic method —
  not a number this documentation repeats as current (`SYMPTOM_CHECKER.md`
  §4).
- The caregiver-linking QR code is **not encrypted** — it encodes a plain
  user UUID, verified by reading both the Flutter QR-generation code and the
  backend linking endpoint (`BACKEND.md` §1).
- The smart medicine box **does not physically dispense medication** — its
  firmware drives only LEDs and a buzzer, with no motor or lock of any kind,
  verified across all three copies of its firmware in the repository
  (`IOT.md` §2). An earlier description of the architecture in this same
  documentation effort was itself corrected mid-pass once this was found —
  see the git history for `ARCHITECTURE.md` if reviewing how this was
  caught.

## Known limitations of this documentation set

- **Screenshots of the running application are not included.** Several
  `[IMAGE REQUIRED]` markers throughout the set ask for actual UI
  screenshots, which require a build/run pass against a device or emulator
  that was not performed as part of this documentation effort. Diagrams and
  flows that could be generated directly from code (architecture, database
  ER, sequence/state flows) were generated inline as Mermaid rather than
  deferred — the remaining `[IMAGE REQUIRED]` markers are specifically for
  material that cannot be produced without running the app.
- **The BP model's clinical accuracy figures come from a held-out MIMIC test
  split, not from real MAX30102/AD8232 hardware recordings.** This is stated
  directly in `BP_PREDICTION.md` §12 and is the single largest open
  validation question for that feature.
- **The symptom-checker v2 dataset is entirely synthetic** — its accuracy
  figures describe how well the model recovers its own generating process,
  not necessarily how it will perform against real patient-reported
  symptoms (`SYMPTOM_CHECKER.md` §9).
- **This documentation reflects the codebase at the time it was written**
  (per-file dates are visible in git history). A reader relying on this
  months later should re-verify specific claims — especially any file paths,
  line numbers, or "currently unimplemented" statements — against the
  current code rather than assuming they still hold, per the same standard
  this documentation held prior materials to.

## Folder layout

All documents produced in this pass live in `Docs/` (this file included).
`assets/branding/` (the two logo images) and the pre-existing
`Documentation structure guide.docx` / `Project_Documentation.tex` /
`BP_FLOW_CALIBRATION_HANDOFF.md` / `BP_Hardware_Analysis.md` / `Plans/`
remain at the repository root, since they are either shared assets or
pre-existing material this set was deliberately *not* sourced from. The root
`README.md` is now a short pointer into `Docs/README.md` rather than the
full orientation document, so the repository still has a landing page.
`Final_Graduation_Documentation.tex`'s `\includegraphics` paths were updated
to `../assets/branding/...` to account for the `.tex` file now living one
directory below the repo root.

## What still needs human input

- Supervisor signature blocks on the cover page (if the university format
  requires a physical/scanned signature rather than a printed name) cannot
  be sourced from the codebase and are not attempted here. The institutional
  logos themselves are already resolved — see the note above.
- Any claim in `PRD.md`'s risk analysis or `BP_PREDICTION.md`/
  `SYMPTOM_CHECKER.md`'s limitations sections that reads as a genuine open
  question (e.g., real-hardware validation, the calibration simulation's
  methodology) is exactly that — an open question this documentation
  surfaced rather than resolved, since resolving it requires new data
  collection or experimentation beyond reading the existing code.

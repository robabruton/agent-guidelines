---
when: maintaining a date-based CHANGELOG.md for an unversioned project
load: recall
summary: >-
  Date-based changelog sections for projects without versioned
  releases. Heading format `## YYYY-MM-DD`, no `[Unreleased]`
  section, multiple changes on the same day append to the existing
  dated section, and entries are written into today's section as
  branch work completes rather than retroactively at branch end.
---
# Date-Based Changelog Rules

Use date-based changelog sections for projects that do not publish
versioned releases.

## Section Headings

- Section heading format: `## YYYY-MM-DD`
- Do NOT use an `[Unreleased]` section
- Write each change directly into the dated section for the day the
  change is made
- If today's dated section does not exist yet, create it at the top of
  the dated entries
- If multiple changes land on the same day, append them to the existing
  dated section rather than creating a duplicate heading
- Treat the calendar date as the only cut point for non-versioned
  projects

## Workflow

- Update today's dated section as branch work is completed
- Do not wait until the branch is finished to write all entries
  retroactively
- For single-scope branches, write the entry directly into today's dated
  section

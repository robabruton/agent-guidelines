---
name: short-kebab-case-slug
description: one line — used to judge relevance during recall
type: decision
load: recall
status: active
updated: 2026-01-01
triggers: [keyword, keyword]
---

## Current Truth

The load-bearing facts: what is true now. Keep this short — it is what a
recalled or partial read should get cheaply. Link related entries with
[[other-slug]].

## Details

Background needed for task work in this area.

## Archive Notes

Completed or superseded history; safe to leave out of routine context.

<!--
For `type: feedback` or `type: user`, replace the Current Truth/Details/
Archive shape with the fact followed by:

**Why:** the reason the correction or preference matters.
**How to apply:** the concrete behavior change to make next time.

Field reminders:
- type:   directive | decision | status | runbook | reference | feedback | user
- load:   always (boot set) | recall (on demand) | archive (out of path)
- status: active | superseded   (superseded entries re-tier to archive)
-->

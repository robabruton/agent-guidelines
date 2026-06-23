# Memory Index

Router for the memory store — the one file loaded every session. Keep it
terse: one line per active memory, grouped by area, each line a
title/link plus a short hook so you can decide what to open without
reading the file. Archived memories live in the collapsed section at the
bottom and are not routed to in normal work.

Format per line: `- [Title](<file>.md) — <hook>`

## Boot — load every session

<!-- Hard rules and the current-state entry (load: always). Keep small. -->

- [Title](file.md) — hook

## User

- [Title](file.md) — hook

## Decisions & architecture

- [Title](file.md) — hook

## Status & active work

- [Title](file.md) — hook

## Runbooks

- [Title](file.md) — hook

## Reference (load on demand)

- [Title](file.md) — hook

## Archive — superseded / completed (do not load in normal work)

- [Title](archive-file.md) — hook

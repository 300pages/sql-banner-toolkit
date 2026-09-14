# sql-banner-toolkit

My cross-project preferences — how I want work done, committed, tested and
explained — live in **`300pages/claude-config`**. Read its `CLAUDE.md` before
starting and follow it alongside everything below.

If that repo is not attached to this session you cannot fetch it, and retrying
will not help; say so rather than guessing at the conventions.

## What this is

Oracle SQL queries against a Banner/Ellucian instance, written to be run by hand
in SQL Developer and published so other Banner schools can adapt them. One
folder per subject area, each carrying its own README. The subject areas vary —
do not assume the repo as a whole shares the purpose of whichever folder you
happened to open.

**This repo is public.** Real student data, rosters and pasted response lists
never land in it — placeholders only, and a pass looking solely for identifying
detail before anything is committed.

## Things that will bite you here

- **Do not write `CASE WHEN`.** Asked for twice, after real failures: "is there
  a way to rely less on case when? i don't trust them." Use `DECODE`, a
  presence-based CTE, or two filtered CTEs split on the condition — the existing
  query does the last of those and says so inline. If a rewrite trades one
  complexity for another or costs performance, name the tradeoff; do not comply
  silently.
- **`DECODE` substitutes only where it is genuinely equivalent** — one column,
  one condition, a flat mapping. Do not stretch it across multiple conditions to
  avoid `CASE`. That makes things worse, and saying so is the right answer.
- **`AR_STATUS` is a trap for readers.** The labels mirror what Banner screens
  display, so `C` prints as "Confirmed" and `Y` prints as "Accepted" — but
  Confirmed is the *temporary* hold and Accepted is the permanent one. The
  inline comment glosses what they actually mean. Both are correct; do not
  "fix" either one to match the other.
- **Email is the only join key back to Banner**, because it is the only field
  the RCC form validates. A known weak point, documented as such — not an
  oversight waiting to be solved.
- **Banner term codes are `YYYYTT`,** and the arithmetic on them is deliberate:
  `CURRENT_TERM - 200` steps back exactly two academic years within the same
  term period. It is not date subtraction.
- **`DEFINE CURRENT_TERM` is silent** — it does not prompt for a value. A
  comment claiming that it prompts has already been wrong here once.
- **Audit notes are dated and environment-specific.** "Duplicate addresses:
  effectively zero" was true of this instance in 2026-08, and is why the
  fallback logic was removed. Do not generalise those findings to another Banner
  instance, and re-date them whenever they are re-checked.

## Before committing

Read the query and its README together — the output column table, the column
names and their order all have to still match. Two mismatches have been caught
that way already.

Then the public-repo pass: `RCC_RESPONDENTS` and anything like it holds
placeholders, with no real addresses, no Banner IDs and no named individuals.

A new subject area gets its own folder, its own README in the shape of the
existing ones, and a row in the root `README.md` table. Anything true only of
that folder goes in its README, never here — this file has to stay correct
whatever folders exist.

# Previously-Certified, No-Form-Response Follow-Up Query (Banner / Oracle SQL)

Finds previously-certified VA benefits students who are registered for the
current term but have not yet submitted a Request for Class Certification
(RCC). Used to send reminder emails without manually cross-referencing
rosters.

**File:** `prevcert-noform-followup.sql`

## What it does

1. Builds the population: every student ever VA-certified (`SGRVETN`).
2. Narrows to students registered with credit hours > 0 in the current term.
3. Excludes anyone already certified for the current term.
4. Picks an outreach email per student: their active official UNCG email
   (`TEMA`), falling back to an active UNCG email listed as EMA only if
   no TEMA exists.
5. Cross-references a pasted list of RCC respondent emails and excludes
   students whose response can be matched to them individually.
6. Flags any match that came from an email address shared with another
   person's Banner record, since that match can't be trusted to belong to
   the student being evaluated.

## Requirements

- Oracle SQL (tested in SQL Developer against a Banner/Ellucian ERP instance)
- Uses `SYS.ODCIVARCHAR2LIST` to inline a pasted list — Oracle-specific,
  no external table or temp table required.
- No special privileges beyond read access to the tables listed below.

## Before you run it

1. **Set the term.** Edit the `DEFINE CURRENT_TERM` line near the top
   (Banner `YYYYTT` format, e.g. `202608`).
2. **Paste the RCC respondent list.** Replace the placeholder values inside
   `RCC_RESPONDENTS` with a lowercase, comma-separated, single-quoted list
   of email addresses. If your respondent data lives in a spreadsheet, this
   Excel formula builds the paste-ready string from a column of addresses:

   ```
   ="('" & LOWER(TEXTJOIN("','", TRUE, Responses!D:D)) & "')"
   ```

## Output columns

| Column | Meaning |
|---|---|
| `STUDENT_ID` | Banner ID |
| `EMAIL_ADDRESS` | Best available active UNCG outreach address (TEMA, or EMA if no TEMA) |
| `LEGAL_LAST_NAME` | Legal name, from `SPRIDEN` |
| `LEGAL_FIRST_NAME` | Legal name, from `SPRIDEN` |
| `PREFERRED_NAME` | Preferred first name, from `SPBPERS` — use this for the greeting line in outreach emails when present |
| `SFBETRM_AR_IND` | Raw Banner AR indicator for the current term |
| `AR_STATUS` | Readable form of `SFBETRM_AR_IND` — None / Accepted / Confirmed |
| `CREDIT_HR_SUM` | Current-term credit hours |
| `LAST_TERM` | Most recent term the student was VA-certified |
| `LAST_BENEFIT` | Description of that certification's benefit chapter |
| `FLAG` | Non-null only when the RCC match relied on a shared email address — verify manually before treating as "no response" |

> **`AR_STATUS` reads backwards if you are new to Banner.** *Accepted* is the
> permanent, good state; *Confirmed* is only a temporary hold. The labels match
> what the Banner screens show, so they are kept as-is rather than renamed to
> something more intuitive.

## Assumptions specific to this environment

- **Term code arithmetic.** UNCG Banner term codes are `YYYYTT`. The query looks
  back up to two academic years (`CURRENT_TERM - 200`) for a student's last
  certification.
- **Email reliability.** Email is the only field the RCC submission form
  validates, so it's the only reliable join key back to Banner. This is a
  known weak point, see Audit Notes below.
- **Active status only.** `GOREMAL_STATUS_IND = 'A'` is applied everywhere
  email addresses are read. Inactive rows are excluded from both outreach
  selection and RCC matching, on the reasoning that a response tied only to
  a deactivated address should still count as a response, but a deactivated
  address is not a valid one to send new outreach to.

## Audit notes (as of 2026-08, this institution's data)

These were checked against real data before finalizing the query and may
not generalize to other Banner instances:

- **Duplicate active TEMA/EMA addresses per student: effectively zero.**
  Early versions of this query included flags and fallback logic for
  students with multiple UNCG addresses of the same type. That logic was
  removed after confirming it wasn't needed here.
- **Missing active TEMA: rare but non-zero.** A small number of enrolled
  students had no active TEMA address, which is why the EMA fallback
  exists.
- **Shared addresses: mostly noise.** Addresses attached to multiple Banner
  IDs were almost entirely old diagnostic/test student records or
  bad data entry person records. The `FLAG` column exists as a narrow,
  low-noise safety net for the rare case where it does matter, rather than
  a broad "this address is suspicious" warning.

## Known limitations

- Requires a manual copy-paste of the RCC respondent list before each run;
  it does not query the RCC/form system directly.
- Email is used as the sole matching key because it's the only field the
  RCC form validates.

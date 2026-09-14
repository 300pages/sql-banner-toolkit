--Pulls credit hour total and confirmation status for students who have previously used benefits but have not submitted an RCC for the current semester.
--Paste RCC respondent emails into RCC_RESPONDENTS below before running and edit current term.
--Match is made on email, the only form-validated field. Only active (STATUS_IND='A') @uncg.edu addresses are used.
--Outreach email is the active TEMA; falls back to an active EMA only if no TEMA exists. Audited 2026-08: Found some active students with no TEMA.
--FLAG fires only when a student's RCC match came solely from an address shared with another pidm.

-- Edit the term code below before running.
DEFINE CURRENT_TERM = '202608'

WITH
--Paste RCC respondent emails on line 15 (lowercase).
--excel formula to retrieve email addresses from RCC entries ="('" & LOWER(TEXTJOIN("','", TRUE, Responses!D:D)) & "')"
RCC_RESPONDENTS AS (
    SELECT LOWER(COLUMN_VALUE) AS EMAIL_ADDR
    FROM TABLE(SYS.ODCIVARCHAR2LIST
    ('email','placeholder@uncg.edu')
    )),

-- Doubles as the VA population (one row per pidm ever certified) and the last cert term.
LAST_CERT AS (
    SELECT SGRVETN_PIDM AS CERT_PIDM,
        MAX(SGRVETN_TERM_CODE_VA) AS LAST_TERM
    FROM SGRVETN
    GROUP BY SGRVETN_PIDM),

-- Filters to enrolled PIDMs.
SFRSTCR_SUM AS (
    SELECT SFRSTCR_PIDM,
    SUM(SFRSTCR_CREDIT_HR) AS CREDIT_HR_SUM
    FROM SFRSTCR
    WHERE SFRSTCR_TERM_CODE=&&CURRENT_TERM AND
    SFRSTCR_RSTS_CODE IN
        (SELECT STVRSTS_CODE FROM STVRSTS
        WHERE STVRSTS_INCL_SECT_ENRL = 'Y')
    GROUP BY SFRSTCR_PIDM
    HAVING SUM(SFRSTCR_CREDIT_HR) > 0),

-- Active @uncg.edu addresses attached to more than one pidm anywhere in Banner.
-- Not restricted to the VA population, since the other owner could be anyone.
SHARED_ADDRESSES AS (
    SELECT LOWER(GOREMAL_EMAIL_ADDRESS) AS EMAIL_ADDR
    FROM GOREMAL
    WHERE GOREMAL_EMAL_CODE IN ('TEMA','EMA')
        AND GOREMAL_STATUS_IND='A'
        AND LOWER(GOREMAL_EMAIL_ADDRESS) LIKE '%@uncg.edu'
    GROUP BY LOWER(GOREMAL_EMAIL_ADDRESS)
    HAVING COUNT(DISTINCT GOREMAL_PIDM) > 1),

-- Outreach address per pidm: active TEMA if present, else active EMA.
-- MIN() is a formality - kept as a safety net for future terms.
STUDENT_EMAIL AS (
    SELECT GOREMAL_PIDM AS PIDM,
        COALESCE(
            MIN(DECODE(GOREMAL_EMAL_CODE,'TEMA',LOWER(GOREMAL_EMAIL_ADDRESS))),
            MIN(DECODE(GOREMAL_EMAL_CODE,'EMA',LOWER(GOREMAL_EMAIL_ADDRESS)))
        ) AS EMAIL_ADDRESS
    FROM GOREMAL
    WHERE GOREMAL_EMAL_CODE IN ('TEMA','EMA')
        AND GOREMAL_STATUS_IND='A'
        AND LOWER(GOREMAL_EMAIL_ADDRESS) LIKE '%@uncg.edu'
    GROUP BY GOREMAL_PIDM),

-- Every VA pidm/address pair that matched the RCC list, active rows only.
-- Split into exclusive vs shared below to avoid CASE.
RCC_ROW_MATCHES AS (
    SELECT G.GOREMAL_PIDM AS PIDM,
        LOWER(G.GOREMAL_EMAIL_ADDRESS) AS EMAIL_ADDR
    FROM LAST_CERT
    JOIN GOREMAL G
        ON G.GOREMAL_PIDM = LAST_CERT.CERT_PIDM
        AND G.GOREMAL_EMAL_CODE IN ('TEMA','EMA')
        AND G.GOREMAL_STATUS_IND='A'
    JOIN RCC_RESPONDENTS R
        ON R.EMAIL_ADDR = LOWER(G.GOREMAL_EMAIL_ADDRESS)),

-- Pidms whose RCC match came from an address that is exclusively theirs, safe to exclude.
EXCLUSIVE_MATCHES AS (
    SELECT DISTINCT RM.PIDM
    FROM RCC_ROW_MATCHES RM
    WHERE NOT EXISTS (
        SELECT 1 FROM SHARED_ADDRESSES SA
        WHERE SA.EMAIL_ADDR = RM.EMAIL_ADDR)),

-- Pidms whose RCC match came from a shared address, keep & flag for review.
SHARED_MATCHES AS (
    SELECT DISTINCT RM.PIDM
    FROM RCC_ROW_MATCHES RM
    JOIN SHARED_ADDRESSES SA
        ON SA.EMAIL_ADDR = RM.EMAIL_ADDR
    WHERE RM.PIDM NOT IN (SELECT PIDM FROM EXCLUSIVE_MATCHES))

SELECT DISTINCT SPRIDEN_ID AS STUDENT_ID,
    STUDENT_EMAIL.EMAIL_ADDRESS,
    SPRIDEN_LAST_NAME AS LEGAL_LAST_NAME,
    SPRIDEN_FIRST_NAME AS LEGAL_FIRST_NAME,
    SPBPERS_PREF_FIRST_NAME AS PREFERRED_NAME,
    SFBETRM_AR_IND,
--N = danger of drop, C = 'Confirmed', a manual temporary hold, Y = 'Accepted', system officially marked good to go
    DECODE(
        SFBETRM_AR_IND,
        'N', 'None',
        'Y', 'Accepted',
        'C', 'Confirmed',
        SFBETRM_AR_IND) AS AR_STATUS,
    CREDIT_HR_SUM,
    LAST_TERM,
    STVVETC_DESC AS LAST_BENEFIT,
    DECODE(SHARED_MATCHES.PIDM, NULL, NULL,
        'RCC MATCH ON SHARED EMAIL - VERIFY') AS FLAG
FROM SGRVETN
JOIN SPRIDEN
    ON SPRIDEN_PIDM=SGRVETN_PIDM
    AND SPRIDEN_CHANGE_IND IS NULL
JOIN SFRSTCR_SUM
    ON SFRSTCR_PIDM=SGRVETN_PIDM
JOIN LAST_CERT
    ON CERT_PIDM=SGRVETN_PIDM
LEFT JOIN STUDENT_EMAIL
    ON STUDENT_EMAIL.PIDM=SGRVETN_PIDM
LEFT JOIN SHARED_MATCHES
    ON SHARED_MATCHES.PIDM=SGRVETN_PIDM
LEFT JOIN SFBETRM
    ON SFBETRM_PIDM=SGRVETN_PIDM
    AND SFBETRM_TERM_CODE=&&CURRENT_TERM
LEFT JOIN STVVETC
    ON SGRVETN_VETC_CODE=STVVETC_CODE
LEFT JOIN SPBPERS
    ON SPBPERS_PIDM = SPRIDEN_PIDM
WHERE SGRVETN_TERM_CODE_VA=LAST_TERM
-- UNCG Banner term codes follow YYYYTT format (e.g. 202608 = academic year 2026, semester starting 08).
-- Subtracting 200 steps back exactly 2 academic years within the same term period (e.g. 202608 - 200 = 202408).
    AND LAST_TERM >= &&CURRENT_TERM - 200
    AND SGRVETN_PIDM NOT IN
        (SELECT SGRVETN_PIDM
            FROM SGRVETN
            WHERE SGRVETN_TERM_CODE_VA=&&CURRENT_TERM)
-- Only exclude students whose RCC match was exclusive to them.
-- A shared match keeps the student in the list, flagged for review instead.
    AND SGRVETN_PIDM NOT IN (SELECT PIDM FROM EXCLUSIVE_MATCHES)
ORDER BY SPRIDEN_LAST_NAME, SPRIDEN_FIRST_NAME;

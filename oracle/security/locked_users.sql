-- ============================================================
-- Oracle DBA Toolkit
-- Script  : locked_users.sql
-- Purpose : Identify locked Oracle database accounts
-- ============================================================

SET LINESIZE 200
SET PAGESIZE 100

COLUMN USERNAME FORMAT A30
COLUMN ACCOUNT_STATUS FORMAT A30
COLUMN LOCK_DATE FORMAT A25
COLUMN PROFILE FORMAT A20

PROMPT
PROMPT ============================================================
PROMPT              LOCKED DATABASE USERS
PROMPT ============================================================
PROMPT

SELECT
    username,
    account_status,
    lock_date,
    profile
FROM
    dba_users
WHERE
    account_status LIKE '%LOCKED%'
ORDER BY
    username;

PROMPT
PROMPT ============================================================
PROMPT              LOCKED USER SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    account_status,
    COUNT(*) AS user_count
FROM
    dba_users
WHERE
    account_status LIKE '%LOCKED%'
GROUP BY
    account_status
ORDER BY
    account_status;

PROMPT
PROMPT ============================================================
PROMPT              END OF REPORT
PROMPT ============================================================


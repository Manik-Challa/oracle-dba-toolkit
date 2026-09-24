-- ============================================================
-- Oracle DBA Toolkit
-- Script  : wait_events.sql
-- Purpose : Identify current non-idle wait events
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100

COLUMN EVENT FORMAT A50
COLUMN WAIT_CLASS FORMAT A20
COLUMN SESSIONS_WAITING FORMAT 999,999
COLUMN TOTAL_WAIT_SECONDS FORMAT 999,999,999.99

PROMPT
PROMPT ============================================================
PROMPT              CURRENT WAIT EVENTS
PROMPT ============================================================
PROMPT

SELECT
    event,
    wait_class,
    COUNT(*) AS sessions_waiting,
    ROUND(SUM(seconds_in_wait), 2) AS total_wait_seconds
FROM
    v$session
WHERE
    wait_class <> 'Idle'
GROUP BY
    event,
    wait_class
ORDER BY
    sessions_waiting DESC;

PROMPT
PROMPT ============================================================
PROMPT              ACTIVE USER SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    sid,
    serial#,
    username,
    event,
    wait_class,
    state,
    seconds_in_wait
FROM
    v$session
WHERE
    username IS NOT NULL
    AND wait_class <> 'Idle'
ORDER BY
    seconds_in_wait DESC;

PROMPT
PROMPT ============================================================
PROMPT              END OF REPORT
PROMPT ============================================================


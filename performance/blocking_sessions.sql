-- ============================================================
-- Oracle DBA Toolkit
-- Script  : blocking_sessions.sql
-- Purpose : Identify blocking and blocked sessions
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100

COLUMN BLOCKER_SID FORMAT 99999
COLUMN BLOCKER_SERIAL FORMAT 99999
COLUMN BLOCKER_USER FORMAT A20
COLUMN BLOCKED_SID FORMAT 99999
COLUMN BLOCKED_SERIAL FORMAT 99999
COLUMN BLOCKED_USER FORMAT A20
COLUMN SQL_ID FORMAT A15
COLUMN EVENT FORMAT A45
COLUMN WAIT_SECONDS FORMAT 999999

PROMPT
PROMPT ============================================================
PROMPT             BLOCKING SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    b.sid              AS blocker_sid,
    b.serial#          AS blocker_serial,
    b.username         AS blocker_user,
    s.sid              AS blocked_sid,
    s.serial#          AS blocked_serial,
    s.username         AS blocked_user,
    s.sql_id           AS sql_id,
    s.event             AS event,
    s.seconds_in_wait   AS wait_seconds
FROM
    v$session s
JOIN
    v$session b
ON
    s.blocking_session = b.sid
WHERE
    s.blocking_session IS NOT NULL
ORDER BY
    s.seconds_in_wait DESC;

PROMPT
PROMPT ============================================================
PROMPT             BLOCKING SESSION SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    blocking_session AS blocker_sid,
    COUNT(*) AS blocked_sessions
FROM
    v$session
WHERE
    blocking_session IS NOT NULL
GROUP BY
    blocking_session
ORDER BY
    blocked_sessions DESC;

PROMPT
PROMPT ============================================================
PROMPT             END OF REPORT
PROMPT ============================================================


-- ============================================================
-- Oracle DBA Toolkit
-- Script  : long_running_sessions.sql
-- Purpose : Identify sessions running for a long duration
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100

COLUMN SID FORMAT 99999
COLUMN SERIAL FORMAT 99999
COLUMN USERNAME FORMAT A20
COLUMN SQL_ID FORMAT A15
COLUMN ELAPSED_MIN FORMAT 999,999.99
COLUMN EVENT FORMAT A40
COLUMN MACHINE FORMAT A30
COLUMN PROGRAM FORMAT A35

PROMPT
PROMPT ============================================================
PROMPT                 LONG RUNNING SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    ROUND(
        (SYSDATE - s.logon_time) * 24 * 60,
        2
    ) AS elapsed_min,
    s.event,
    s.machine,
    s.program
FROM
    v$session s
WHERE
    s.username IS NOT NULL
    AND s.status = 'ACTIVE'
    AND s.last_call_et >= 600
ORDER BY
    s.last_call_et DESC;

PROMPT
PROMPT ============================================================
PROMPT        Sessions active for more than 10 minutes
PROMPT ============================================================
PROMPT


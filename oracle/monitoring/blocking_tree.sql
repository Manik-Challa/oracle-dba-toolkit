-- ============================================================
-- Oracle DBA Toolkit
-- Script  : blocking_tree.sql
-- Purpose : Identify blocking sessions and blocking hierarchy
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET VERIFY OFF

COLUMN BLOCKER_SID FORMAT 99999
COLUMN BLOCKER_SERIAL FORMAT 99999
COLUMN BLOCKER_USER FORMAT A20
COLUMN BLOCKED_SID FORMAT 99999
COLUMN BLOCKED_SERIAL FORMAT 99999
COLUMN BLOCKED_USER FORMAT A20
COLUMN BLOCKER_SQL_ID FORMAT A15
COLUMN BLOCKED_SQL_ID FORMAT A15
COLUMN BLOCKER_EVENT FORMAT A45
COLUMN BLOCKED_EVENT FORMAT A45
COLUMN MACHINE FORMAT A35
COLUMN PROGRAM FORMAT A40
COLUMN BLOCKING_TREE FORMAT A120

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKING SESSION SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    COUNT(DISTINCT blocking_session) AS blocking_sessions,
    COUNT(*) AS blocked_sessions
FROM
    v$session
WHERE
    blocking_session IS NOT NULL
    AND username IS NOT NULL;

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKER -> BLOCKED SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    s.blocking_session AS blocker_sid,
    b.serial# AS blocker_serial,
    b.username AS blocker_user,
    s.sid AS blocked_sid,
    s.serial# AS blocked_serial,
    s.username AS blocked_user,
    b.sql_id AS blocker_sql_id,
    s.sql_id AS blocked_sql_id,
    b.event AS blocker_event,
    s.event AS blocked_event,
    s.machine,
    s.program
FROM
    v$session s
LEFT JOIN
    v$session b
ON
    b.sid = s.blocking_session
WHERE
    s.blocking_session IS NOT NULL
    AND s.username IS NOT NULL
ORDER BY
    s.blocking_session,
    s.sid;

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKING SESSION DETAILS
PROMPT ============================================================
PROMPT

SELECT
    b.sid,
    b.serial# AS serial,
    b.username,
    b.status,
    b.sql_id,
    b.event,
    b.wait_class,
    b.machine,
    b.program,
    b.logon_time
FROM
    v$session b
WHERE
    b.sid IN
    (
        SELECT DISTINCT
            blocking_session
        FROM
            v$session
        WHERE
            blocking_session IS NOT NULL
    )
ORDER BY
    b.sid;

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKED SESSION DETAILS
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.machine,
    s.program
FROM
    v$session s
WHERE
    s.blocking_session IS NOT NULL
ORDER BY
    s.blocking_session,
    s.sid;

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKING HIERARCHY
PROMPT ============================================================
PROMPT

SELECT
    LPAD(' ', (LEVEL - 1) * 4) ||
    CASE
        WHEN CONNECT_BY_ISLEAF = 1
        THEN '└─ '
        ELSE '├─ '
    END ||
    'SID=' || sid ||
    ' USER=' || NVL(username, 'UNKNOWN') ||
    ' SQL_ID=' || NVL(sql_id, 'NONE') AS blocking_tree
FROM
    v$session
WHERE
    username IS NOT NULL
START WITH
    blocking_session IS NULL
    AND sid IN
    (
        SELECT DISTINCT
            blocking_session
        FROM
            v$session
        WHERE
            blocking_session IS NOT NULL
    )
CONNECT BY NOCYCLE
    PRIOR sid = blocking_session
ORDER SIBLINGS BY
    sid;

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKER SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    blocking_session AS blocker_sid,
    COUNT(*) AS blocked_sessions
FROM
    v$session
WHERE
    blocking_session IS NOT NULL
    AND username IS NOT NULL
GROUP BY
    blocking_session
ORDER BY
    blocked_sessions DESC;

PROMPT
PROMPT ============================================================
PROMPT                 LONGEST BLOCKED SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.blocking_session AS blocker_sid,
    s.sql_id,
    s.event,
    s.seconds_in_wait,
    s.machine,
    s.program
FROM
    v$session s
WHERE
    s.blocking_session IS NOT NULL
    AND s.username IS NOT NULL
ORDER BY
    s.seconds_in_wait DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKING TREE CHECK COMPLETE
PROMPT ============================================================


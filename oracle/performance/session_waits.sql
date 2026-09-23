-- ============================================================
-- Oracle DBA Toolkit
-- Script  : session_waits.sql
-- Purpose : Monitor current Oracle session wait activity
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET VERIFY OFF

COLUMN SID FORMAT 99999
COLUMN SERIAL FORMAT 99999
COLUMN USERNAME FORMAT A20
COLUMN STATUS FORMAT A10
COLUMN SQL_ID FORMAT A15
COLUMN EVENT FORMAT A55
COLUMN WAIT_CLASS FORMAT A20
COLUMN STATE FORMAT A15
COLUMN SECONDS_IN_WAIT FORMAT 999,999
COLUMN WAIT_TIME_SEC FORMAT 999,999.99
COLUMN BLOCKING_SID FORMAT 99999
COLUMN MACHINE FORMAT A35
COLUMN PROGRAM FORMAT A40

PROMPT
PROMPT ============================================================
PROMPT                 CURRENT SESSION WAITS
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
    s.state,
    s.seconds_in_wait,
    s.blocking_session AS blocking_sid,
    s.machine,
    s.program
FROM
    v$session s
WHERE
    s.username IS NOT NULL
    AND s.status = 'ACTIVE'
    AND s.wait_class <> 'Idle'
ORDER BY
    s.seconds_in_wait DESC;

PROMPT
PROMPT ============================================================
PROMPT                 WAIT EVENTS SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    event,
    wait_class,
    COUNT(*) AS waiting_sessions,
    ROUND(AVG(seconds_in_wait), 2) AS avg_wait_sec,
    MAX(seconds_in_wait) AS max_wait_sec
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
    AND wait_class <> 'Idle'
GROUP BY
    event,
    wait_class
ORDER BY
    waiting_sessions DESC,
    max_wait_sec DESC;

PROMPT
PROMPT ============================================================
PROMPT                 WAIT CLASS SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    wait_class,
    COUNT(*) AS waiting_sessions,
    ROUND(AVG(seconds_in_wait), 2) AS avg_wait_sec,
    MAX(seconds_in_wait) AS max_wait_sec
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
    AND wait_class <> 'Idle'
GROUP BY
    wait_class
ORDER BY
    waiting_sessions DESC;

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKING SESSION WAITS
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.blocking_session AS blocking_sid,
    b.serial# AS blocking_serial,
    b.username AS blocking_user,
    b.sql_id AS blocking_sql_id
FROM
    v$session s
LEFT JOIN
    v$session b
ON
    b.sid = s.blocking_session
WHERE
    s.username IS NOT NULL
    AND s.blocking_session IS NOT NULL
ORDER BY
    s.seconds_in_wait DESC;

PROMPT
PROMPT ============================================================
PROMPT                 LONGEST CURRENT WAITS
PROMPT ============================================================
PROMPT

SELECT
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    state,
    seconds_in_wait,
    blocking_session AS blocking_sid,
    machine,
    program
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
    AND wait_class <> 'Idle'
ORDER BY
    seconds_in_wait DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 SESSIONS WAITING ON I/O
PROMPT ============================================================
PROMPT

SELECT
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    seconds_in_wait,
    machine,
    program
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
    AND wait_class = 'User I/O'
ORDER BY
    seconds_in_wait DESC;

PROMPT
PROMPT ============================================================
PROMPT                 SESSIONS WAITING ON CPU / RESOURCE MANAGER
PROMPT ============================================================
PROMPT

SELECT
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    seconds_in_wait,
    machine,
    program
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
    AND
    (
        event = 'resmgr:cpu quantum'
        OR LOWER(event) LIKE '%cpu%'
    )
ORDER BY
    seconds_in_wait DESC;

PROMPT
PROMPT ============================================================
PROMPT                 SESSIONS WAITING ON CONCURRENCY
PROMPT ============================================================
PROMPT

SELECT
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    seconds_in_wait,
    blocking_session AS blocking_sid,
    machine,
    program
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
    AND wait_class = 'Concurrency'
ORDER BY
    seconds_in_wait DESC;

PROMPT
PROMPT ============================================================
PROMPT                 WAITING SESSION COUNT
PROMPT ============================================================
PROMPT

SELECT
    COUNT(*) AS active_waiting_sessions
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
    AND wait_class <> 'Idle';

PROMPT
PROMPT ============================================================
PROMPT                 SESSION WAIT MONITORING COMPLETE
PROMPT ============================================================


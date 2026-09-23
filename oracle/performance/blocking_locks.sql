-- ============================================================
-- Oracle DBA Toolkit
-- Script  : blocking_locks.sql
-- Purpose : Identify blocking locks and locked database objects
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET VERIFY OFF

COLUMN BLOCKER_SID FORMAT 99999
COLUMN BLOCKER_SERIAL FORMAT 99999
COLUMN BLOCKER_USER FORMAT A20
COLUMN WAITER_SID FORMAT 99999
COLUMN WAITER_SERIAL FORMAT 99999
COLUMN WAITER_USER FORMAT A20
COLUMN OBJECT_OWNER FORMAT A20
COLUMN OBJECT_NAME FORMAT A35
COLUMN OBJECT_TYPE FORMAT A20
COLUMN LOCKED_MODE FORMAT A20
COLUMN REQUESTED_MODE FORMAT A20
COLUMN LOCK_TYPE FORMAT A15
COLUMN SQL_ID FORMAT A15
COLUMN EVENT FORMAT A45
COLUMN MACHINE FORMAT A35
COLUMN PROGRAM FORMAT A40

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKING LOCK SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    COUNT(*) AS blocked_sessions
FROM
    v$lock waiter
WHERE
    waiter.request > 0
    AND EXISTS
    (
        SELECT 1
        FROM v$lock blocker
        WHERE blocker.id1 = waiter.id1
          AND blocker.id2 = waiter.id2
          AND blocker.request = 0
    );

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKER / WAITER LOCK DETAILS
PROMPT ============================================================
PROMPT

SELECT
    blocker.sid AS blocker_sid,
    blocker.serial# AS blocker_serial,
    blocker.username AS blocker_user,
    waiter.sid AS waiter_sid,
    waiter.serial# AS waiter_serial,
    waiter.username AS waiter_user,
    waiter.type AS lock_type,
    blocker.lmode AS locked_mode,
    waiter.request AS requested_mode,
    waiter.id1,
    waiter.id2
FROM
    v$lock blocker
JOIN
    v$lock waiter
ON
    blocker.id1 = waiter.id1
    AND blocker.id2 = waiter.id2
WHERE
    blocker.request = 0
    AND waiter.request > 0
    AND blocker.sid <> waiter.sid
ORDER BY
    blocker.sid,
    waiter.sid;

PROMPT
PROMPT ============================================================
PROMPT                 LOCKED OBJECT DETAILS
PROMPT ============================================================
PROMPT

SELECT
    blocker.sid AS blocker_sid,
    blocker.serial# AS blocker_serial,
    blocker.username AS blocker_user,
    waiter.sid AS waiter_sid,
    waiter.serial# AS waiter_serial,
    waiter.username AS waiter_user,
    o.owner AS object_owner,
    o.object_name,
    o.object_type,
    blocker.type AS lock_type,
    blocker.lmode AS blocker_mode,
    waiter.request AS waiter_request,
    waiter.id1,
    waiter.id2
FROM
    v$lock blocker
JOIN
    v$lock waiter
ON
    blocker.id1 = waiter.id1
    AND blocker.id2 = waiter.id2
JOIN
    dba_objects o
ON
    o.object_id = blocker.id1
WHERE
    blocker.request = 0
    AND waiter.request > 0
    AND blocker.sid <> waiter.sid
ORDER BY
    blocker.sid,
    waiter.sid;

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKER SESSION DETAILS
PROMPT ============================================================
PROMPT

SELECT DISTINCT
    blocker.sid,
    blocker.serial# AS serial,
    blocker.username,
    blocker.status,
    blocker.sql_id,
    blocker.event,
    blocker.wait_class,
    blocker.machine,
    blocker.program,
    blocker.logon_time
FROM
    v$session blocker
JOIN
    v$lock l
ON
    l.sid = blocker.sid
WHERE
    l.request = 0
    AND EXISTS
    (
        SELECT 1
        FROM v$lock waiter
        WHERE waiter.id1 = l.id1
          AND waiter.id2 = l.id2
          AND waiter.request > 0
    )
ORDER BY
    blocker.sid;

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
    s.blocking_session,
    s.machine,
    s.program
FROM
    v$session s
WHERE
    s.blocking_session IS NOT NULL
ORDER BY
    s.seconds_in_wait DESC;

PROMPT
PROMPT ============================================================
PROMPT                 ROW LOCK WAITS
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
    blocking_session AS blocker_sid,
    machine,
    program
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
    AND
    (
        event = 'enq: TX - row lock contention'
        OR event = 'enq: TX - allocate ITL entry'
    )
ORDER BY
    seconds_in_wait DESC;

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKER SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    blocker.sid AS blocker_sid,
    blocker.username AS blocker_user,
    COUNT(DISTINCT waiter.sid) AS blocked_sessions
FROM
    v$lock blocker
JOIN
    v$lock waiter
ON
    blocker.id1 = waiter.id1
    AND blocker.id2 = waiter.id2
WHERE
    blocker.request = 0
    AND waiter.request > 0
    AND blocker.sid <> waiter.sid
GROUP BY
    blocker.sid,
    blocker.username
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
    s.wait_class,
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
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 BLOCKING LOCK CHECK COMPLETE
PROMPT ============================================================


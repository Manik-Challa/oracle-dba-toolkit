-- ============================================================================
-- Oracle DBA Toolkit
-- Script  : lock_details.sql
-- Purpose : Detailed Oracle lock information and lock holders/waiters
-- Author  : Manik Challa
-- Usage   : SQL*Plus / SQLcl
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN sid              FORMAT 99999
COLUMN serial           FORMAT 999999
COLUMN username         FORMAT A20
COLUMN lock_type        FORMAT A12
COLUMN mode_held        FORMAT A18
COLUMN mode_requested   FORMAT A20
COLUMN lmode            FORMAT 999
COLUMN request          FORMAT 999
COLUMN id1              FORMAT 9999999999
COLUMN id2              FORMAT 9999999999
COLUMN object_name      FORMAT A35
COLUMN object_type      FORMAT A20
COLUMN status           FORMAT A10
COLUMN event            FORMAT A40
COLUMN sql_id           FORMAT A15
COLUMN machine          FORMAT A30

PROMPT
PROMPT ================================================================
PROMPT LOCK DETAILS
PROMPT ================================================================
PROMPT

-- ============================================================================
-- 1. All Current Locks
-- ============================================================================

PROMPT
PROMPT [1] CURRENT LOCKS
PROMPT

SELECT
    l.sid,
    s.serial# AS serial,
    s.username,
    DECODE(
        l.type,
        'TM', 'DML',
        'TX', 'TX',
        'UL', 'USER LOCK',
        l.type
    ) AS lock_type,
    DECODE(
        l.lmode,
        0, 'None',
        1, 'Null',
        2, 'Row-S',
        3, 'Row-X',
        4, 'Share',
        5, 'S/Row-X',
        6, 'Exclusive',
        l.lmode
    ) AS mode_held,
    DECODE(
        l.request,
        0, 'None',
        1, 'Null',
        2, 'Row-S',
        3, 'Row-X',
        4, 'Share',
        5, 'S/Row-X',
        6, 'Exclusive',
        l.request
    ) AS mode_requested,
    l.id1,
    l.id2,
    s.status,
    s.sql_id,
    s.event
FROM v$lock l
LEFT JOIN v$session s
       ON s.sid = l.sid
WHERE l.lmode > 0
   OR l.request > 0
ORDER BY l.sid, l.type, l.id1;

-- ============================================================================
-- 2. Lock Holders and Waiters
-- ============================================================================

PROMPT
PROMPT [2] LOCK HOLDERS AND WAITERS
PROMPT

SELECT
    w.sid              AS waiting_sid,
    ws.serial#         AS waiting_serial,
    ws.username        AS waiting_user,
    h.sid              AS holding_sid,
    hs.serial#         AS holding_serial,
    hs.username        AS holding_user,
    w.type             AS lock_type,
    w.id1,
    w.id2,
    DECODE(
        w.request,
        0, 'None',
        1, 'Null',
        2, 'Row-S',
        3, 'Row-X',
        4, 'Share',
        5, 'S/Row-X',
        6, 'Exclusive',
        w.request
    ) AS requested_mode,
    DECODE(
        h.lmode,
        0, 'None',
        1, 'Null',
        2, 'Row-S',
        3, 'Row-X',
        4, 'Share',
        5, 'S/Row-X',
        6, 'Exclusive',
        h.lmode
    ) AS held_mode
FROM v$lock w
JOIN v$lock h
  ON h.id1 = w.id1
 AND h.id2 = w.id2
 AND h.type = w.type
 AND h.sid <> w.sid
JOIN v$session ws
  ON ws.sid = w.sid
JOIN v$session hs
  ON hs.sid = h.sid
WHERE w.request > 0
  AND h.lmode > 0
ORDER BY w.sid;

-- ============================================================================
-- 3. Locked Objects
-- ============================================================================

PROMPT
PROMPT [3] LOCKED OBJECTS
PROMPT

SELECT
    lo.session_id AS sid,
    s.serial# AS serial,
    s.username,
    lo.locked_mode,
    o.owner,
    o.object_name,
    o.object_type,
    s.status,
    s.sql_id,
    s.event
FROM v$locked_object lo
JOIN dba_objects o
  ON o.object_id = lo.object_id
JOIN v$session s
  ON s.sid = lo.session_id
ORDER BY o.owner, o.object_name, lo.session_id;

-- ============================================================================
-- 4. Sessions Waiting for Locks
-- ============================================================================

PROMPT
PROMPT [4] SESSIONS WAITING FOR LOCKS
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
    s.blocking_instance,
    s.machine,
    s.program
FROM v$session s
WHERE s.blocking_session IS NOT NULL
ORDER BY s.seconds_in_wait DESC;

-- ============================================================================
-- 5. Row Lock Contention
-- ============================================================================

PROMPT
PROMPT [5] ROW LOCK CONTENTION
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.seconds_in_wait,
    s.blocking_session,
    s.blocking_instance,
    s.machine,
    s.program
FROM v$session s
WHERE s.event IN (
        'enq: TX - row lock contention',
        'enq: TX - allocate ITL entry'
      )
ORDER BY s.seconds_in_wait DESC;

-- ============================================================================
-- 6. Lock Summary by Type
-- ============================================================================

PROMPT
PROMPT [6] LOCK SUMMARY BY TYPE
PROMPT

SELECT
    type AS lock_type,
    COUNT(*) AS lock_count,
    SUM(CASE WHEN lmode > 0 THEN 1 ELSE 0 END) AS held_locks,
    SUM(CASE WHEN request > 0 THEN 1 ELSE 0 END) AS waiting_locks
FROM v$lock
WHERE lmode > 0
   OR request > 0
GROUP BY type
ORDER BY lock_count DESC;

-- ============================================================================
-- 7. Blocking Sessions
-- ============================================================================

PROMPT
PROMPT [7] BLOCKING SESSIONS
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.machine,
    s.program,
    COUNT(w.sid) AS blocked_sessions
FROM v$session s
JOIN v$session w
  ON w.blocking_session = s.sid
WHERE s.username IS NOT NULL
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    s.machine,
    s.program
ORDER BY blocked_sessions DESC;

-- ============================================================================
-- 8. Longest Current Lock Waits
-- ============================================================================

PROMPT
PROMPT [8] LONGEST CURRENT LOCK WAITS
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.seconds_in_wait,
    s.blocking_session,
    s.blocking_instance,
    s.machine,
    s.program
FROM v$session s
WHERE s.blocking_session IS NOT NULL
ORDER BY s.seconds_in_wait DESC;

PROMPT
PROMPT ================================================================
PROMPT LOCK INVESTIGATION COMPLETE
PROMPT ================================================================
PROMPT
PROMPT DBA CHECKLIST:
PROMPT 1. Identify the waiting session.
PROMPT 2. Identify the blocking session.
PROMPT 3. Check the locked object.
PROMPT 4. Review blocker SQL_ID and current SQL.
PROMPT 5. Check transaction duration and application activity.
PROMPT 6. Confirm business impact before taking corrective action.
PROMPT 7. Do not kill sessions without validating the transaction impact.
PROMPT


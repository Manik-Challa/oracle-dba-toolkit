-- ============================================================================
-- Oracle DBA Toolkit
-- Script  : enqueue_locks.sql
-- Purpose : Monitor Oracle enqueue locks and enqueue contention
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
COLUMN type             FORMAT A10
COLUMN lock_type        FORMAT A25
COLUMN mode_held        FORMAT A18
COLUMN mode_requested   FORMAT A20
COLUMN id1              FORMAT 9999999999
COLUMN id2              FORMAT 9999999999
COLUMN request          FORMAT 999
COLUMN lmode            FORMAT 999
COLUMN event            FORMAT A45
COLUMN wait_class       FORMAT A20
COLUMN sql_id           FORMAT A15
COLUMN machine          FORMAT A30
COLUMN program          FORMAT A35
COLUMN blocking_sid     FORMAT 99999
COLUMN object_name      FORMAT A35
COLUMN object_type      FORMAT A20

PROMPT
PROMPT ================================================================
PROMPT ORACLE ENQUEUE LOCK MONITORING
PROMPT ================================================================
PROMPT

-- ============================================================================
-- 1. Current Enqueue Locks
-- ============================================================================

PROMPT
PROMPT [1] CURRENT ENQUEUE LOCKS
PROMPT

SELECT
    l.sid,
    s.serial# AS serial,
    s.username,
    l.type,
    CASE
        WHEN l.type = 'TX' THEN 'Transaction'
        WHEN l.type = 'TM' THEN 'DML / Object'
        WHEN l.type = 'UL' THEN 'User Lock'
        ELSE 'Other Enqueue'
    END AS lock_type,
    DECODE(
        l.lmode,
        0, 'None',
        1, 'Null',
        2, 'Row-S',
        3, 'Row-X',
        4, 'Share',
        5, 'S/Row-X',
        6, 'Exclusive',
        TO_CHAR(l.lmode)
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
        TO_CHAR(l.request)
    ) AS mode_requested,
    l.id1,
    l.id2,
    s.sql_id,
    s.event,
    s.machine
FROM v$lock l
LEFT JOIN v$session s
       ON s.sid = l.sid
WHERE l.lmode > 0
   OR l.request > 0
ORDER BY l.type, l.sid;

-- ============================================================================
-- 2. Enqueues Currently Waiting
-- ============================================================================

PROMPT
PROMPT [2] ENQUEUES CURRENTLY WAITING
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
    s.blocking_instance,
    s.machine,
    s.program
FROM v$session s
WHERE s.event LIKE 'enq:%'
ORDER BY s.seconds_in_wait DESC;

-- ============================================================================
-- 3. Enqueue Wait Events
-- ============================================================================

PROMPT
PROMPT [3] ENQUEUE WAIT EVENTS
PROMPT

SELECT
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN (time_waited / total_waits) / 100
            ELSE 0
        END,
        4
    ) AS avg_wait_sec
FROM v$system_event
WHERE event LIKE 'enq:%'
ORDER BY time_waited DESC;

-- ============================================================================
-- 4. Enqueue Waits by Session
-- ============================================================================

PROMPT
PROMPT [4] ENQUEUE WAITS BY SESSION
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
    s.state,
    s.blocking_session AS blocking_sid,
    s.machine,
    s.program
FROM v$session s
WHERE s.event LIKE 'enq:%'
ORDER BY s.seconds_in_wait DESC;

-- ============================================================================
-- 5. TX Enqueue Contention
-- ============================================================================

PROMPT
PROMPT [5] TX ENQUEUE CONTENTION
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.seconds_in_wait,
    s.blocking_session AS blocking_sid,
    s.blocking_instance,
    s.machine,
    s.program
FROM v$session s
WHERE s.event IN (
        'enq: TX - row lock contention',
        'enq: TX - allocate ITL entry',
        'enq: TX - contention'
      )
ORDER BY s.seconds_in_wait DESC;

-- ============================================================================
-- 6. TM Enqueue Contention
-- ============================================================================

PROMPT
PROMPT [6] TM ENQUEUE / OBJECT LOCK CONTENTION
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.seconds_in_wait,
    s.blocking_session AS blocking_sid,
    s.blocking_instance,
    s.machine,
    s.program
FROM v$session s
WHERE s.event LIKE 'enq: TM%'
ORDER BY s.seconds_in_wait DESC;

-- ============================================================================
-- 7. Enqueue Holder / Waiter Relationship
-- ============================================================================

PROMPT
PROMPT [7] ENQUEUE HOLDER / WAITER RELATIONSHIP
PROMPT

SELECT
    w.sid AS waiting_sid,
    ws.serial# AS waiting_serial,
    ws.username AS waiting_user,
    h.sid AS holding_sid,
    hs.serial# AS holding_serial,
    hs.username AS holding_user,
    w.type AS enqueue_type,
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
        TO_CHAR(w.request)
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
        TO_CHAR(h.lmode)
    ) AS held_mode,
    ws.event AS waiting_event,
    ws.sql_id AS waiting_sql_id,
    hs.sql_id AS holding_sql_id
FROM v$lock w
JOIN v$lock h
  ON h.type = w.type
 AND h.id1 = w.id1
 AND h.id2 = w.id2
 AND h.sid <> w.sid
JOIN v$session ws
  ON ws.sid = w.sid
JOIN v$session hs
  ON hs.sid = h.sid
WHERE w.request > 0
  AND h.lmode > 0
ORDER BY w.type, w.sid;

-- ============================================================================
-- 8. Enqueue Summary by Type
-- ============================================================================

PROMPT
PROMPT [8] ENQUEUE SUMMARY BY TYPE
PROMPT

SELECT
    type AS enqueue_type,
    COUNT(*) AS total_locks,
    SUM(CASE WHEN lmode > 0 THEN 1 ELSE 0 END) AS held,
    SUM(CASE WHEN request > 0 THEN 1 ELSE 0 END) AS waiting
FROM v$lock
WHERE lmode > 0
   OR request > 0
GROUP BY type
ORDER BY total_locks DESC;

-- ============================================================================
-- 9. Blocking Sessions Causing Enqueue Waits
-- ============================================================================

PROMPT
PROMPT [9] BLOCKING SESSIONS CAUSING ENQUEUE WAITS
PROMPT

SELECT
    bs.sid AS blocking_sid,
    bs.serial# AS blocking_serial,
    bs.username AS blocking_user,
    COUNT(ws.sid) AS blocked_sessions,
    bs.sql_id AS blocking_sql_id,
    bs.status,
    bs.machine,
    bs.program
FROM v$session ws
JOIN v$session bs
  ON bs.sid = ws.blocking_session
WHERE ws.event LIKE 'enq:%'
GROUP BY
    bs.sid,
    bs.serial#,
    bs.username,
    bs.sql_id,
    bs.status,
    bs.machine,
    bs.program
ORDER BY blocked_sessions DESC;

-- ============================================================================
-- 10. Longest Enqueue Waits
-- ============================================================================

PROMPT
PROMPT [10] LONGEST ENQUEUE WAITS
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.state,
    s.blocking_session AS blocking_sid,
    s.machine,
    s.program
FROM v$session s
WHERE s.event LIKE 'enq:%'
ORDER BY s.seconds_in_wait DESC;

-- ============================================================================
-- 11. Enqueue Wait Summary
-- ============================================================================

PROMPT
PROMPT [11] ENQUEUE WAIT SUMMARY
PROMPT

SELECT
    CASE
        WHEN event LIKE 'enq: TX%' THEN 'TX - Transaction'
        WHEN event LIKE 'enq: TM%' THEN 'TM - Object / DML'
        WHEN event LIKE 'enq: UL%' THEN 'UL - User Lock'
        ELSE 'Other Enqueue'
    END AS enqueue_category,
    COUNT(*) AS waiting_sessions
FROM v$session
WHERE event LIKE 'enq:%'
GROUP BY
    CASE
        WHEN event LIKE 'enq: TX%' THEN 'TX - Transaction'
        WHEN event LIKE 'enq: TM%' THEN 'TM - Object / DML'
        WHEN event LIKE 'enq: UL%' THEN 'UL - User Lock'
        ELSE 'Other Enqueue'
    END
ORDER BY waiting_sessions DESC;

PROMPT
PROMPT ================================================================
PROMPT ENQUEUE INVESTIGATION COMPLETE
PROMPT ================================================================
PROMPT
PROMPT DBA CHECKLIST:
PROMPT 1. Identify the enqueue type: TX, TM, UL, or other.
PROMPT 2. Identify waiting sessions.
PROMPT 3. Identify the blocking session.
PROMPT 4. Check blocker SQL_ID and application details.
PROMPT 5. For TX waits, investigate transaction/row-lock contention.
PROMPT 6. For TM waits, investigate object/DML locking.
PROMPT 7. Check transaction duration and uncommitted work.
PROMPT 8. Validate application impact before taking corrective action.
PROMPT 9. Do not kill sessions without understanding transaction impact.
PROMPT
PROMPT Note: V$LOCK ID1/ID2 have enqueue-specific meanings.
PROMPT Do not interpret TX ID1 as a database OBJECT_ID.
PROMPT


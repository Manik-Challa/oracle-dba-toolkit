-- ============================================================================
-- Oracle DBA Toolkit
-- Script  : row_lock_waits.sql
-- Purpose : Monitor row-level lock contention and TX enqueue waits
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
COLUMN sql_id           FORMAT A15
COLUMN event            FORMAT A45
COLUMN wait_class       FORMAT A20
COLUMN blocking_sid     FORMAT 99999
COLUMN blocking_serial  FORMAT 999999
COLUMN object_owner     FORMAT A20
COLUMN object_name      FORMAT A40
COLUMN object_type      FORMAT A25
COLUMN machine          FORMAT A30
COLUMN program          FORMAT A35
COLUMN start_time       FORMAT A20
COLUMN status           FORMAT A12

PROMPT
PROMPT ================================================================
PROMPT ORACLE ROW LOCK WAIT MONITORING
PROMPT ================================================================
PROMPT

-- ============================================================================
-- 1. Current Row Lock Waits
-- ============================================================================

PROMPT
PROMPT [1] CURRENT ROW LOCK WAITS
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
-- 2. Waiting Session and Blocking Session
-- ============================================================================

PROMPT
PROMPT [2] WAITING / BLOCKING SESSION DETAILS
PROMPT

SELECT
    ws.sid AS waiting_sid,
    ws.serial# AS waiting_serial,
    ws.username AS waiting_user,
    ws.sql_id AS waiting_sql_id,
    ws.event AS waiting_event,
    ws.seconds_in_wait,
    bs.sid AS blocking_sid,
    bs.serial# AS blocking_serial,
    bs.username AS blocking_user,
    bs.sql_id AS blocking_sql_id,
    bs.status AS blocking_status,
    bs.machine AS blocking_machine,
    bs.program AS blocking_program
FROM v$session ws
LEFT JOIN v$session bs
       ON bs.sid = ws.blocking_session
WHERE ws.event IN (
        'enq: TX - row lock contention',
        'enq: TX - allocate ITL entry',
        'enq: TX - contention'
      )
ORDER BY ws.seconds_in_wait DESC;

-- ============================================================================
-- 3. Blocking Session Summary
-- ============================================================================

PROMPT
PROMPT [3] BLOCKING SESSION SUMMARY
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
WHERE ws.event IN (
        'enq: TX - row lock contention',
        'enq: TX - allocate ITL entry',
        'enq: TX - contention'
      )
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
-- 4. Active Transactions of Blocking Sessions
-- ============================================================================

PROMPT
PROMPT [4] ACTIVE TRANSACTIONS OF BLOCKING SESSIONS
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    t.status AS transaction_status,
    t.used_ublk,
    t.used_urec,
    s.sql_id,
    s.status AS session_status,
    s.machine,
    s.program
FROM v$transaction t
JOIN v$session s
  ON s.taddr = t.addr
WHERE EXISTS (
    SELECT 1
    FROM v$session ws
    WHERE ws.blocking_session = s.sid
      AND ws.event IN (
            'enq: TX - row lock contention',
            'enq: TX - allocate ITL entry',
            'enq: TX - contention'
          )
)
ORDER BY t.used_ublk DESC;

-- ============================================================================
-- 5. Row Lock Waiters with SQL Details
-- ============================================================================

PROMPT
PROMPT [5] ROW LOCK WAITERS WITH SQL DETAILS
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.seconds_in_wait,
    s.blocking_session AS blocking_sid,
    SUBSTR(q.sql_text, 1, 120) AS sql_text,
    s.machine,
    s.program
FROM v$session s
LEFT JOIN v$sql q
       ON q.sql_id = s.sql_id
      AND q.child_number = s.sql_child_number
WHERE s.event IN (
        'enq: TX - row lock contention',
        'enq: TX - allocate ITL entry',
        'enq: TX - contention'
      )
ORDER BY s.seconds_in_wait DESC;

-- ============================================================================
-- 6. Blocking Sessions with Current SQL
-- ============================================================================

PROMPT
PROMPT [6] BLOCKERS WITH CURRENT SQL
PROMPT

SELECT
    bs.sid,
    bs.serial# AS serial,
    bs.username,
    bs.status,
    bs.sql_id,
    SUBSTR(q.sql_text, 1, 120) AS sql_text,
    bs.machine,
    bs.program
FROM v$session bs
LEFT JOIN v$sql q
       ON q.sql_id = bs.sql_id
      AND q.child_number = bs.sql_child_number
WHERE bs.sid IN (
    SELECT blocking_session
    FROM v$session
    WHERE event IN (
            'enq: TX - row lock contention',
            'enq: TX - allocate ITL entry',
            'enq: TX - contention'
          )
      AND blocking_session IS NOT NULL
)
ORDER BY bs.sid;

-- ============================================================================
-- 7. Row Lock Wait Event Summary
-- ============================================================================

PROMPT
PROMPT [7] ROW LOCK WAIT EVENT SUMMARY
PROMPT

SELECT
    event,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS max_wait_sec,
    ROUND(AVG(seconds_in_wait), 2) AS avg_wait_sec
FROM v$session
WHERE event IN (
        'enq: TX - row lock contention',
        'enq: TX - allocate ITL entry',
        'enq: TX - contention'
      )
GROUP BY event
ORDER BY waiting_sessions DESC;

-- ============================================================================
-- 8. Current TX Locks
-- ============================================================================

PROMPT
PROMPT [8] CURRENT TX LOCKS
PROMPT

SELECT
    l.sid,
    s.serial# AS serial,
    s.username,
    l.type,
    l.lmode,
    l.request,
    l.id1,
    l.id2,
    s.sql_id,
    s.event,
    s.blocking_session AS blocking_sid
FROM v$lock l
JOIN v$session s
  ON s.sid = l.sid
WHERE l.type = 'TX'
  AND (l.lmode > 0 OR l.request > 0)
ORDER BY l.request DESC, l.sid;

-- ============================================================================
-- 9. Sessions with Row Lock Waits by User
-- ============================================================================

PROMPT
PROMPT [9] ROW LOCK WAITS BY DATABASE USER
PROMPT

SELECT
    username,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS max_wait_sec
FROM v$session
WHERE event IN (
        'enq: TX - row lock contention',
        'enq: TX - allocate ITL entry',
        'enq: TX - contention'
      )
GROUP BY username
ORDER BY waiting_sessions DESC;

-- ============================================================================
-- 10. Longest Row Lock Waits
-- ============================================================================

PROMPT
PROMPT [10] LONGEST ROW LOCK WAITS
PROMPT

SELECT
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    seconds_in_wait,
    state,
    blocking_session AS blocking_sid,
    blocking_instance,
    machine,
    program
FROM v$session
WHERE event IN (
        'enq: TX - row lock contention',
        'enq: TX - allocate ITL entry',
        'enq: TX - contention'
      )
ORDER BY seconds_in_wait DESC;

-- ============================================================================
-- 11. Row Lock Related System Events
-- ============================================================================

PROMPT
PROMPT [11] ROW LOCK RELATED SYSTEM EVENTS
PROMPT

SELECT
    event,
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
WHERE event LIKE 'enq: TX%'
ORDER BY time_waited DESC;

PROMPT
PROMPT ================================================================
PROMPT ROW LOCK INVESTIGATION COMPLETE
PROMPT ================================================================
PROMPT
PROMPT DBA CHECKLIST:
PROMPT 1. Identify the waiting session.
PROMPT 2. Identify the blocking session.
PROMPT 3. Check blocker transaction start time.
PROMPT 4. Review blocker SQL_ID and current SQL.
PROMPT 5. Check for uncommitted DML.
PROMPT 6. Identify affected application/object where possible.
PROMPT 7. Distinguish ROW LOCK contention from ITL contention.
PROMPT 8. Check transaction size using USED_UBLK and USED_UREC.
PROMPT 9. Confirm business impact before corrective action.
PROMPT 10. Do not kill a blocker without understanding transaction impact.


-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_blocking.sql
-- Purpose: Monitor blocking and blocked sessions in Oracle RAC
-- Scope  : Blockers, waiters, cross-instance blocking,
--          lock details, transaction details and wait events
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN inst_id              FORMAT 999
COLUMN sid                  FORMAT 999999
COLUMN serial               FORMAT 999999
COLUMN username             FORMAT A20
COLUMN status               FORMAT A10
COLUMN blocker_inst         FORMAT 999
COLUMN blocker_sid          FORMAT 999999
COLUMN blocker_serial       FORMAT 999999
COLUMN sql_id               FORMAT A15
COLUMN event                FORMAT A40
COLUMN wait_class           FORMAT A20
COLUMN machine              FORMAT A30
COLUMN program              FORMAT A35
COLUMN service_name         FORMAT A25
COLUMN object_name         FORMAT A35
COLUMN object_type         FORMAT A20
COLUMN lock_type            FORMAT A10
COLUMN request              FORMAT 999
COLUMN lmode                FORMAT 999
COLUMN seconds_in_wait      FORMAT 999999
COLUMN last_call_min        FORMAT 999999.99
COLUMN start_time           FORMAT A20

PROMPT
PROMPT ============================================================
PROMPT RAC BLOCKING SESSION MONITOR
PROMPT ============================================================

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE INFORMATION
PROMPT ============================================================

SELECT
    name,
    db_unique_name,
    open_mode,
    database_role
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 2. RAC INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    database_status,
    thread# AS thread,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 3. ALL BLOCKED SESSIONS
PROMPT ============================================================

SELECT
    w.inst_id,
    w.sid,
    w.serial# AS serial,
    w.username,
    w.status,
    w.sql_id,
    w.event,
    w.wait_class,
    w.seconds_in_wait,
    w.blocking_instance AS blocker_inst,
    w.blocking_session AS blocker_sid,
    w.machine,
    w.program,
    w.service_name
FROM gv$session w
WHERE w.username IS NOT NULL
  AND w.blocking_session IS NOT NULL
ORDER BY
    w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 4. BLOCKER -> WAITER DETAILS
PROMPT ============================================================

SELECT
    w.inst_id AS waiter_inst,
    w.sid AS waiter_sid,
    w.serial# AS waiter_serial,
    w.username AS waiter_user,
    w.sql_id AS waiter_sql_id,
    w.event AS waiter_event,
    w.wait_class,
    w.seconds_in_wait,

    b.inst_id AS blocker_inst,
    b.sid AS blocker_sid,
    b.serial# AS blocker_serial,
    b.username AS blocker_user,
    b.status AS blocker_status,
    b.sql_id AS blocker_sql_id,
    b.machine AS blocker_machine,
    b.program AS blocker_program
FROM gv$session w
JOIN gv$session b
    ON b.inst_id = w.blocking_instance
   AND b.sid = w.blocking_session
WHERE w.blocking_session IS NOT NULL
ORDER BY
    w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 5. CROSS-INSTANCE BLOCKING
PROMPT ============================================================

SELECT
    w.inst_id AS waiter_inst,
    w.sid AS waiter_sid,
    w.serial# AS waiter_serial,
    w.username AS waiter_user,
    w.sql_id AS waiter_sql_id,
    w.event AS waiter_event,
    w.seconds_in_wait,

    b.inst_id AS blocker_inst,
    b.sid AS blocker_sid,
    b.serial# AS blocker_serial,
    b.username AS blocker_user,
    b.sql_id AS blocker_sql_id,
    b.status AS blocker_status,
    b.machine AS blocker_machine,
    b.program AS blocker_program
FROM gv$session w
JOIN gv$session b
    ON b.inst_id = w.blocking_instance
   AND b.sid = w.blocking_session
WHERE w.blocking_session IS NOT NULL
  AND w.blocking_instance <> w.inst_id
ORDER BY
    w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 6. BLOCKING SUMMARY BY INSTANCE
PROMPT ============================================================

SELECT
    w.inst_id AS waiter_inst,
    w.blocking_instance AS blocker_inst,
    COUNT(*) AS blocked_sessions,
    MAX(w.seconds_in_wait) AS longest_wait_seconds
FROM gv$session w
WHERE w.username IS NOT NULL
  AND w.blocking_session IS NOT NULL
GROUP BY
    w.inst_id,
    w.blocking_instance
ORDER BY
    blocked_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. TOP BLOCKERS
PROMPT ============================================================

SELECT
    b.inst_id AS blocker_inst,
    b.sid AS blocker_sid,
    b.serial# AS blocker_serial,
    b.username AS blocker_user,
    b.status,
    b.sql_id,
    b.machine,
    b.program,
    COUNT(w.sid) AS blocked_sessions
FROM gv$session b
JOIN gv$session w
    ON w.blocking_instance = b.inst_id
   AND w.blocking_session = b.sid
WHERE b.username IS NOT NULL
GROUP BY
    b.inst_id,
    b.sid,
    b.serial#,
    b.username,
    b.status,
    b.sql_id,
    b.machine,
    b.program
ORDER BY
    blocked_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. BLOCKERS WITH LONGEST BLOCKED WAIT
PROMPT ============================================================

SELECT
    b.inst_id AS blocker_inst,
    b.sid AS blocker_sid,
    b.serial# AS blocker_serial,
    b.username AS blocker_user,
    b.status AS blocker_status,
    b.sql_id AS blocker_sql_id,
    MAX(w.seconds_in_wait) AS longest_blocked_wait_sec,
    COUNT(*) AS blocked_sessions,
    b.machine,
    b.program
FROM gv$session b
JOIN gv$session w
    ON w.blocking_instance = b.inst_id
   AND w.blocking_session = b.sid
WHERE b.username IS NOT NULL
GROUP BY
    b.inst_id,
    b.sid,
    b.serial#,
    b.username,
    b.status,
    b.sql_id,
    b.machine,
    b.program
ORDER BY
    longest_blocked_wait_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. BLOCKED SESSION WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    COUNT(*) AS blocked_sessions,
    MAX(seconds_in_wait) AS max_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND blocking_session IS NOT NULL
GROUP BY
    inst_id,
    event,
    wait_class
ORDER BY
    blocked_sessions DESC,
    max_wait_seconds DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. BLOCKING SESSION TRANSACTIONS
PROMPT ============================================================

SELECT
    b.inst_id,
    b.sid,
    b.serial# AS serial,
    b.username,
    b.status,
    b.sql_id,
    t.start_time,
    t.used_ublk,
    t.used_urec,
    ROUND(
        (SYSDATE -
         TO_DATE(t.start_time, 'MM/DD/RR HH24:MI:SS')) * 24 * 60,
        2
    ) AS txn_age_min,
    b.machine,
    b.program
FROM gv$session b
JOIN gv$transaction t
    ON t.inst_id = b.inst_id
   AND t.addr = b.taddr
WHERE b.username IS NOT NULL
  AND EXISTS (
        SELECT 1
        FROM gv$session w
        WHERE w.blocking_instance = b.inst_id
          AND w.blocking_session = b.sid
    )
ORDER BY
    txn_age_min DESC;


PROMPT
PROMPT ============================================================
PROMPT 11. BLOCKING SESSION SQL DETAILS
PROMPT ============================================================

SELECT
    b.inst_id,
    b.sid,
    b.serial# AS serial,
    b.username,
    b.status,
    b.sql_id,
    q.sql_text,
    b.event,
    b.machine,
    b.program,
    b.service_name
FROM gv$session b
LEFT JOIN gv$sql q
    ON q.inst_id = b.inst_id
   AND q.sql_id = b.sql_id
   AND q.child_number = b.sql_child_number
WHERE b.username IS NOT NULL
  AND EXISTS (
        SELECT 1
        FROM gv$session w
        WHERE w.blocking_instance = b.inst_id
          AND w.blocking_session = b.sid
    )
ORDER BY
    b.inst_id,
    b.sid;


PROMPT
PROMPT ============================================================
PROMPT 12. LOCK DETAILS FOR BLOCKED SESSIONS
PROMPT ============================================================

SELECT
    l.inst_id,
    l.sid,
    s.serial# AS serial,
    s.username,
    l.type AS lock_type,
    l.id1,
    l.id2,
    l.lmode,
    l.request,
    l.ctime AS lock_seconds,
    s.sql_id,
    s.event,
    s.machine,
    s.program
FROM gv$lock l
JOIN gv$session s
    ON s.inst_id = l.inst_id
   AND s.sid = l.sid
WHERE s.username IS NOT NULL
  AND l.request > 0
ORDER BY
    l.ctime DESC;


PROMPT
PROMPT ============================================================
PROMPT 13. LOCK HOLDER DETAILS
PROMPT ============================================================

SELECT
    l.inst_id,
    l.sid,
    s.serial# AS serial,
    s.username,
    l.type AS lock_type,
    l.id1,
    l.id2,
    l.lmode,
    l.request,
    l.ctime AS lock_seconds,
    s.status,
    s.sql_id,
    s.machine,
    s.program
FROM gv$lock l
JOIN gv$session s
    ON s.inst_id = l.inst_id
   AND s.sid = l.sid
WHERE s.username IS NOT NULL
  AND l.lmode > 0
  AND EXISTS (
        SELECT 1
        FROM gv$lock w
        WHERE w.type = l.type
          AND w.id1 = l.id1
          AND w.id2 = l.id2
          AND w.request > 0
    )
ORDER BY
    l.ctime DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. OBJECT DETAILS FOR TM LOCKS
PROMPT ============================================================

SELECT
    l.inst_id,
    l.sid,
    s.serial# AS serial,
    s.username,
    l.type AS lock_type,
    l.id1 AS object_id,
    o.owner,
    o.object_name,
    o.object_type,
    l.lmode,
    l.request,
    l.ctime AS lock_seconds,
    s.sql_id,
    s.machine,
    s.program
FROM gv$lock l
JOIN gv$session s
    ON s.inst_id = l.inst_id
   AND s.sid = l.sid
LEFT JOIN dba_objects o
    ON o.object_id = l.id1
WHERE l.type = 'TM'
  AND s.username IS NOT NULL
ORDER BY
    l.ctime DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. TX LOCK CONTENTION
PROMPT ============================================================

SELECT
    w.inst_id AS waiter_inst,
    w.sid AS waiter_sid,
    w.serial# AS waiter_serial,
    w.username AS waiter_user,
    wl.id1 AS waiter_id1,
    wl.id2 AS waiter_id2,
    b.inst_id AS blocker_inst,
    b.sid AS blocker_sid,
    b.serial# AS blocker_serial,
    b.username AS blocker_user,
    bl.id1 AS blocker_id1,
    bl.id2 AS blocker_id2,
    w.event,
    w.seconds_in_wait
FROM gv$lock wl
JOIN gv$session w
    ON w.inst_id = wl.inst_id
   AND w.sid = wl.sid
JOIN gv$lock bl
    ON bl.type = wl.type
   AND bl.id1 = wl.id1
   AND bl.id2 = wl.id2
   AND bl.lmode > 0
JOIN gv$session b
    ON b.inst_id = bl.inst_id
   AND b.sid = bl.sid
WHERE wl.type = 'TX'
  AND wl.request > 0
ORDER BY
    w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 16. BLOCKING BY SERVICE
PROMPT ============================================================

SELECT
    b.inst_id,
    b.service_name,
    b.username,
    COUNT(w.sid) AS blocked_sessions
FROM gv$session b
JOIN gv$session w
    ON w.blocking_instance = b.inst_id
   AND w.blocking_session = b.sid
WHERE b.username IS NOT NULL
GROUP BY
    b.inst_id,
    b.service_name,
    b.username
ORDER BY
    blocked_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 17. BLOCKING BY MACHINE
PROMPT ============================================================

SELECT
    b.inst_id,
    b.machine,
    COUNT(w.sid) AS blocked_sessions
FROM gv$session b
JOIN gv$session w
    ON w.blocking_instance = b.inst_id
   AND w.blocking_session = b.sid
WHERE b.username IS NOT NULL
GROUP BY
    b.inst_id,
    b.machine
ORDER BY
    blocked_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 18. BLOCKING SESSION SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS blocked_sessions,
    COUNT(DISTINCT blocking_instance || ':' || blocking_session)
        AS distinct_blockers,
    COUNT(DISTINCT inst_id)
        AS affected_instances,
    MAX(seconds_in_wait)
        AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND blocking_session IS NOT NULL;


PROMPT
PROMPT ============================================================
PROMPT 19. INSTANCE-WISE BLOCKING HEALTH
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    COUNT(w.sid) AS blocked_sessions,
    COUNT(DISTINCT
          w.blocking_instance || ':' || w.blocking_session)
          AS blocker_count,
    MAX(w.seconds_in_wait) AS longest_wait_seconds
FROM gv$instance i
LEFT JOIN gv$session w
    ON w.inst_id = i.inst_id
   AND w.username IS NOT NULL
   AND w.blocking_session IS NOT NULL
GROUP BY
    i.inst_id,
    i.instance_name,
    i.host_name
ORDER BY
    i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 20. RAC BLOCKING HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN COUNT(*) = 0
        THEN 'HEALTHY - NO CURRENT BLOCKING'
        WHEN MAX(seconds_in_wait) >= 1800
        THEN 'CRITICAL - BLOCKING WAIT >= 30 MINUTES'
        WHEN MAX(seconds_in_wait) >= 600
        THEN 'WARNING - BLOCKING WAIT >= 10 MINUTES'
        ELSE 'REVIEW - CURRENT BLOCKING EXISTS'
    END AS blocking_health,
    COUNT(*) AS blocked_sessions,
    COUNT(DISTINCT blocking_instance || ':' || blocking_session)
        AS distinct_blockers,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND blocking_session IS NOT NULL;


PROMPT
PROMPT ============================================================
PROMPT 21. QUICK RAC BLOCKING CHECK
PROMPT ============================================================

SELECT
    w.inst_id AS waiter_inst,
    w.sid AS waiter_sid,
    w.username AS waiter_user,
    w.blocking_instance AS blocker_inst,
    w.blocking_session AS blocker_sid,
    b.username AS blocker_user,
    w.sql_id AS waiter_sql_id,
    b.sql_id AS blocker_sql_id,
    w.event,
    w.seconds_in_wait
FROM gv$session w
LEFT JOIN gv$session b
    ON b.inst_id = w.blocking_instance
   AND b.sid = w.blocking_session
WHERE w.username IS NOT NULL
  AND w.blocking_session IS NOT NULL
ORDER BY
    w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT 1. Identify the blocker and all affected sessions.
PROMPT 2. Check whether blocking is local or cross-instance.
PROMPT 3. Review blocker SQL_ID and current SQL text.
PROMPT 4. Check blocker transaction age and UNDO usage.
PROMPT 5. Check TX/TM lock information.
PROMPT 6. For TM locks, identify the affected database object.
PROMPT 7. Review blocker machine, program and service.
PROMPT 8. Check whether multiple services are affected.
PROMPT 9. Review cross-instance blocking carefully in RAC.
PROMPT 10. Check application connection-pool and transaction behavior.
PROMPT
PROMPT IMPORTANT:
PROMPT - Do NOT kill sessions based only on this report.
PROMPT - Confirm application impact and transaction ownership first.
PROMPT - TX ID1/ID2 are transaction/enqueue identifiers and should
PROMPT   not be treated as OBJECT_ID values.
PROMPT - TM ID1 can normally be correlated with DBA_OBJECTS.OBJECT_ID.
PROMPT - Blocking can be legitimate and workload-dependent.
PROMPT - Use srvctl/Clusterware/listener checks separately for
PROMPT   RAC service and infrastructure troubleshooting.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================


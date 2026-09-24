-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_ges.sql
-- Purpose: Monitor Oracle RAC Global Enqueue Service (GES)
-- Scope  : GES statistics, enqueue waits, blockers, waiters,
--          lock activity, latency and RAC instance comparison
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN inst_id              FORMAT 999
COLUMN instance_name        FORMAT A15
COLUMN host_name            FORMAT A30
COLUMN stat_name            FORMAT A55
COLUMN event                FORMAT A65
COLUMN wait_class           FORMAT A20
COLUMN username             FORMAT A20
COLUMN sql_id               FORMAT A15
COLUMN service_name         FORMAT A25
COLUMN machine              FORMAT A30
COLUMN program              FORMAT A35
COLUMN lock_type            FORMAT A10
COLUMN request              FORMAT 999
COLUMN lmode                FORMAT 999
COLUMN blocking_instance    FORMAT 999
COLUMN blocking_session     FORMAT 999999
COLUMN seconds_in_wait      FORMAT 999999
COLUMN avg_wait_ms          FORMAT 9999990.99
COLUMN total_wait_time_sec  FORMAT 9999990.99

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE / RAC INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_number,
    i.instance_name,
    i.host_name,
    i.status,
    i.database_status,
    TO_CHAR(i.startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
FROM gv$instance i
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 2. GES SYSTEM STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value AS value_num
FROM gv$sysstat
WHERE LOWER(name) LIKE '%ges%'
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================
PROMPT 3. GLOBAL ENQUEUE RELATED STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value AS value_num
FROM gv$sysstat
WHERE LOWER(name) LIKE '%enqueue%'
   OR LOWER(name) LIKE '%global enqueue%'
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================
PROMPT 4. GES / ENQUEUE WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS total_wait_time_sec,
    ROUND(
        (time_waited / NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE '%ges%'
   OR LOWER(event) LIKE '%enqueue%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 5. CURRENT GES / ENQUEUE WAITERS
PROMPT ============================================================

SELECT
    inst_id,
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    state,
    seconds_in_wait,
    service_name,
    machine,
    program
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND (
        LOWER(event) LIKE '%ges%'
        OR LOWER(event) LIKE '%enqueue%'
      )
ORDER BY seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 6. CURRENT BLOCKING SESSIONS INVOLVING GES/ENQUEUES
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
    b.status AS blocker_status,
    b.sql_id AS blocker_sql_id,
    b.machine AS blocker_machine,
    b.program AS blocker_program
FROM gv$session w
JOIN gv$session b
    ON b.inst_id = w.blocking_instance
   AND b.sid = w.blocking_session
WHERE w.blocking_session IS NOT NULL
  AND (
        LOWER(w.event) LIKE '%ges%'
        OR LOWER(w.event) LIKE '%enqueue%'
      )
ORDER BY w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. CROSS-INSTANCE BLOCKING
PROMPT ============================================================

SELECT
    w.inst_id AS waiter_inst,
    w.sid AS waiter_sid,
    w.username AS waiter_user,
    w.sql_id AS waiter_sql_id,
    w.event AS waiter_event,
    w.seconds_in_wait,

    b.inst_id AS blocker_inst,
    b.sid AS blocker_sid,
    b.username AS blocker_user,
    b.sql_id AS blocker_sql_id,
    b.machine AS blocker_machine
FROM gv$session w
JOIN gv$session b
    ON b.inst_id = w.blocking_instance
   AND b.sid = w.blocking_session
WHERE w.blocking_session IS NOT NULL
  AND w.blocking_instance <> w.inst_id
ORDER BY w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. CURRENT LOCK / ENQUEUE ACTIVITY
PROMPT ============================================================

SELECT
    inst_id,
    type AS lock_type,
    id1,
    id2,
    lmode,
    request,
    block,
    sid
FROM gv$lock
WHERE request > 0
   OR block > 0
ORDER BY
    request DESC,
    block DESC,
    inst_id;


PROMPT
PROMPT ============================================================
PROMPT 9. LOCK WAITERS
PROMPT ============================================================

SELECT
    w.inst_id AS waiter_inst,
    w.sid AS waiter_sid,
    w.type AS lock_type,
    w.id1,
    w.id2,
    w.request AS waiter_request,

    b.inst_id AS blocker_inst,
    b.sid AS blocker_sid,
    b.lmode AS blocker_mode,
    b.block AS blocker_flag
FROM gv$lock w
JOIN gv$lock b
    ON b.type = w.type
   AND b.id1 = w.id1
   AND b.id2 = w.id2
   AND b.lmode > 0
WHERE w.request > 0
ORDER BY w.inst_id, w.sid;


PROMPT
PROMPT ============================================================
PROMPT 10. ENQUEUE WAITERS WITH SESSION DETAILS
PROMPT ============================================================

SELECT
    l.inst_id,
    l.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    l.type AS lock_type,
    l.id1,
    l.id2,
    l.lmode,
    l.request,
    l.block,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.service_name,
    s.machine
FROM gv$lock l
JOIN gv$session s
    ON s.inst_id = l.inst_id
   AND s.sid = l.sid
WHERE l.request > 0
ORDER BY s.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 11. TOP SQL ASSOCIATED WITH ENQUEUE WAITS
PROMPT ============================================================

SELECT
    sql_id,
    executions,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    buffer_gets,
    disk_reads,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM gv$sql
WHERE sql_id IN
(
    SELECT DISTINCT sql_id
    FROM gv$session
    WHERE username IS NOT NULL
      AND sql_id IS NOT NULL
      AND (
            LOWER(event) LIKE '%ges%'
            OR LOWER(event) LIKE '%enqueue%'
          )
)
ORDER BY elapsed_time DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 12. GES / ENQUEUE WAITS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS waiting_sessions,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS max_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND (
        LOWER(event) LIKE '%ges%'
        OR LOWER(event) LIKE '%enqueue%'
      )
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 13. GES / ENQUEUE WAITS BY SERVICE
PROMPT ============================================================

SELECT
    service_name,
    COUNT(*) AS waiting_sessions,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS max_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND (
        LOWER(event) LIKE '%ges%'
        OR LOWER(event) LIKE '%enqueue%'
      )
GROUP BY service_name
ORDER BY waiting_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. GES / ENQUEUE WAITS BY USER
PROMPT ============================================================

SELECT
    username,
    COUNT(*) AS waiting_sessions,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS max_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND (
        LOWER(event) LIKE '%ges%'
        OR LOWER(event) LIKE '%enqueue%'
      )
GROUP BY username
ORDER BY waiting_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. GES / ENQUEUE WAITS BY MACHINE
PROMPT ============================================================

SELECT
    machine,
    COUNT(*) AS waiting_sessions,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS max_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND (
        LOWER(event) LIKE '%ges%'
        OR LOWER(event) LIKE '%enqueue%'
      )
GROUP BY machine
ORDER BY waiting_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 16. INSTANCE-WISE ENQUEUE WAIT LATENCY
PROMPT ============================================================

SELECT
    inst_id,
    SUM(total_waits) AS total_enqueue_waits,
    ROUND(SUM(time_waited) / 100, 2) AS total_wait_time_sec,
    ROUND(
        (SUM(time_waited) /
         NULLIF(SUM(total_waits), 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE '%enqueue%'
   OR LOWER(event) LIKE '%ges%'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 17. GES / ENQUEUE EVENT DISTRIBUTION
PROMPT ============================================================

SELECT
    event,
    wait_class,
    SUM(total_waits) AS total_waits,
    ROUND(SUM(time_waited) / 100, 2) AS total_wait_time_sec,
    ROUND(
        (SUM(time_waited) /
         NULLIF(SUM(total_waits), 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE '%ges%'
   OR LOWER(event) LIKE '%enqueue%'
GROUP BY event, wait_class
ORDER BY total_wait_time_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 18. RAC INSTANCE COMPARISON
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    NVL(w.waiting_sessions, 0) AS waiting_sessions,
    NVL(w.total_wait_seconds, 0) AS total_wait_seconds,
    NVL(w.max_wait_seconds, 0) AS max_wait_seconds
FROM gv$instance i
LEFT JOIN
(
    SELECT
        inst_id,
        COUNT(*) AS waiting_sessions,
        SUM(seconds_in_wait) AS total_wait_seconds,
        MAX(seconds_in_wait) AS max_wait_seconds
    FROM gv$session
    WHERE username IS NOT NULL
      AND status = 'ACTIVE'
      AND state = 'WAITING'
      AND (
            LOWER(event) LIKE '%ges%'
            OR LOWER(event) LIKE '%enqueue%'
          )
    GROUP BY inst_id
) w
    ON w.inst_id = i.inst_id
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 19. GES HEALTH SUMMARY
PROMPT ============================================================

SELECT
    CASE
        WHEN COUNT(*) = 0
            THEN 'HEALTHY - NO CURRENT GES/ENQUEUE WAITERS'
        WHEN MAX(seconds_in_wait) >= 60
            THEN 'WARNING - GES/ENQUEUE WAIT > 60 SECONDS'
        WHEN MAX(seconds_in_wait) >= 10
            THEN 'REVIEW - ELEVATED GES/ENQUEUE WAIT'
        ELSE
            'REVIEW - GES/ENQUEUE ACTIVITY PRESENT'
    END AS ges_health
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND (
        LOWER(event) LIKE '%ges%'
        OR LOWER(event) LIKE '%enqueue%'
      );


PROMPT
PROMPT ============================================================
PROMPT 20. QUICK GES CHECK
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS current_ges_waiters,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND (
        LOWER(event) LIKE '%ges%'
        OR LOWER(event) LIKE '%enqueue%'
      )
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 21. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT If GES/enqueue waits are elevated:
PROMPT
PROMPT 1. Identify the exact enqueue type and wait event.
PROMPT 2. Identify the blocker and waiter sessions.
PROMPT 3. Check whether blocking is local or cross-instance.
PROMPT 4. Review the SQL executed by blocker/waiter sessions.
PROMPT 5. Check active transactions and transaction age.
PROMPT 6. Correlate GES waits with application workload.
PROMPT 7. Review service-to-instance placement and connection routing.
PROMPT 8. Check related GCS/Cache Fusion activity.
PROMPT 9. Check RAC interconnect health if global waits are elevated.
PROMPT 10. Correlate with OS/network metrics.
PROMPT 11. Review Clusterware and listener status when required.
PROMPT 12. Do NOT kill sessions based only on this report.
PROMPT
PROMPT ============================================================
PROMPT Notes:
PROMPT - GES statistics are generally cumulative since instance startup.
PROMPT - Enqueue waits can be legitimate workload behavior.
PROMPT - A GES wait does not automatically indicate an interconnect failure.
PROMPT - Cross-instance blocking should be correlated with transaction ownership.
PROMPT - Wait thresholds in this toolkit are investigation triggers,
PROMPT   not Oracle failure thresholds.
PROMPT - GV$ views provide database-level visibility only.
PROMPT - Use CRS/OS/network tools for complete RAC infrastructure analysis.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC GES MONITORING COMPLETE
PROMPT ============================================================
 
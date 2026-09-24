-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_cr_blocks.sql
-- Purpose: Monitor RAC Consistent Read (CR) block activity
-- Scope  : CR requests, Cache Fusion waits, GC CR events,
--          SQL, sessions, instances and latency
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name       FORMAT A18
COLUMN host_name           FORMAT A30
COLUMN stat_name           FORMAT A55
COLUMN event               FORMAT A65
COLUMN wait_class          FORMAT A20
COLUMN username            FORMAT A20
COLUMN sql_id              FORMAT A15
COLUMN service_name        FORMAT A25
COLUMN machine              FORMAT A30
COLUMN program             FORMAT A35
COLUMN object_name         FORMAT A35
COLUMN owner               FORMAT A20
COLUMN avg_wait_ms         FORMAT 9999990.99
COLUMN total_wait_sec      FORMAT 9999990.99
COLUMN seconds_in_wait     FORMAT 999999
COLUMN cr_requests         FORMAT 999999999999
COLUMN cr_blocks           FORMAT 999999999999

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE / RAC INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    inst_id,
    instance_number,
    instance_name,
    host_name,
    status,
    database_status,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 2. GLOBAL CACHE / CR RELATED SYSTEM STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value AS value_num
FROM gv$sysstat
WHERE LOWER(name) LIKE '%consistent%'
   OR LOWER(name) LIKE '%global cache%'
   OR LOWER(name) LIKE '%gc %'
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================
PROMPT 3. CONSISTENT READ / CACHE FUSION EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS total_wait_sec,
    ROUND(
        (time_waited / NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc cr%'
   OR LOWER(event) LIKE 'gc current%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 4. CR REQUEST EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS total_wait_sec,
    ROUND(
        (time_waited / NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc cr%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 5. CURRENT CR WAITERS
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
  AND LOWER(event) LIKE 'gc cr%'
ORDER BY seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 6. CURRENT GC CR WAITERS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS cr_waiters,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 7. CURRENT CR WAITERS BY SERVICE
PROMPT ============================================================

SELECT
    service_name,
    COUNT(*) AS cr_waiters,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%'
GROUP BY service_name
ORDER BY cr_waiters DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. CURRENT CR WAITERS BY USER
PROMPT ============================================================

SELECT
    username,
    COUNT(*) AS cr_waiters,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%'
GROUP BY username
ORDER BY cr_waiters DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. CURRENT CR WAITERS BY MACHINE
PROMPT ============================================================

SELECT
    machine,
    COUNT(*) AS cr_waiters,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%'
GROUP BY machine
ORDER BY cr_waiters DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. TOP SQL CURRENTLY WAITING FOR CR BLOCKS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sql_id,
    COUNT(*) AS waiting_sessions,
    MAX(s.seconds_in_wait) AS longest_wait_seconds,
    MAX(s.event) AS wait_event
FROM gv$session s
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND s.state = 'WAITING'
  AND LOWER(s.event) LIKE 'gc cr%'
  AND s.sql_id IS NOT NULL
GROUP BY
    s.inst_id,
    s.sql_id
ORDER BY
    waiting_sessions DESC,
    longest_wait_seconds DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 11. SQL DETAILS FOR CR WAITERS
PROMPT ============================================================

SELECT
    q.inst_id,
    q.sql_id,
    q.executions,
    ROUND(q.elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(q.cpu_time / 1000000, 2) AS cpu_sec,
    q.buffer_gets,
    q.disk_reads,
    SUBSTR(q.sql_text, 1, 120) AS sql_text
FROM gv$sql q
WHERE q.sql_id IN
(
    SELECT DISTINCT sql_id
    FROM gv$session
    WHERE username IS NOT NULL
      AND status = 'ACTIVE'
      AND state = 'WAITING'
      AND LOWER(event) LIKE 'gc cr%'
      AND sql_id IS NOT NULL
)
ORDER BY q.elapsed_time DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 12. CR WAIT LATENCY BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    SUM(total_waits) AS cr_waits,
    ROUND(SUM(time_waited) / 100, 2) AS total_wait_sec,
    ROUND(
        (SUM(time_waited) /
         NULLIF(SUM(total_waits), 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc cr%'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 13. CR EVENT DISTRIBUTION
PROMPT ============================================================

SELECT
    event,
    wait_class,
    SUM(total_waits) AS total_waits,
    ROUND(SUM(time_waited) / 100, 2) AS total_wait_sec,
    ROUND(
        (SUM(time_waited) /
         NULLIF(SUM(total_waits), 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc cr%'
GROUP BY
    event,
    wait_class
ORDER BY total_wait_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. CR VS CURRENT BLOCK REQUESTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS total_wait_sec,
    ROUND(
        (time_waited / NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc cr%'
   OR LOWER(event) LIKE 'gc current%'
ORDER BY
    inst_id,
    total_waits DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. INSTANCE COMPARISON
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    NVL(w.cr_waiters, 0) AS current_cr_waiters,
    NVL(w.total_wait_seconds, 0) AS total_wait_seconds,
    NVL(w.longest_wait_seconds, 0) AS longest_wait_seconds
FROM gv$instance i
LEFT JOIN
(
    SELECT
        inst_id,
        COUNT(*) AS cr_waiters,
        SUM(seconds_in_wait) AS total_wait_seconds,
        MAX(seconds_in_wait) AS longest_wait_seconds
    FROM gv$session
    WHERE username IS NOT NULL
      AND status = 'ACTIVE'
      AND state = 'WAITING'
      AND LOWER(event) LIKE 'gc cr%'
    GROUP BY inst_id
) w
    ON w.inst_id = i.inst_id
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 16. BLOCKING CORRELATION
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
    b.machine AS blocker_machine
FROM gv$session w
JOIN gv$session b
    ON b.inst_id = w.blocking_instance
   AND b.sid = w.blocking_session
WHERE w.blocking_session IS NOT NULL
  AND LOWER(w.event) LIKE 'gc cr%'
ORDER BY w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 17. CROSS-INSTANCE CR BLOCKING
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
  AND LOWER(w.event) LIKE 'gc cr%'
ORDER BY w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 18. CR WAIT CLASS SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    wait_class,
    COUNT(*) AS waiting_sessions,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%'
GROUP BY
    inst_id,
    wait_class
ORDER BY
    inst_id,
    total_wait_seconds DESC;


PROMPT
PROMPT ============================================================
PROMPT 19. CR HEALTH SUMMARY
PROMPT ============================================================

SELECT
    CASE
        WHEN COUNT(*) = 0
            THEN 'NO CURRENT CR WAITERS'
        WHEN MAX(seconds_in_wait) >= 60
            THEN 'WARNING - CR WAIT > 60 SECONDS'
        WHEN MAX(seconds_in_wait) >= 10
            THEN 'REVIEW - ELEVATED CR WAIT'
        ELSE
            'REVIEW - CR ACTIVITY PRESENT'
    END AS cr_health
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%';


PROMPT
PROMPT ============================================================
PROMPT 20. QUICK CR CHECK
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS current_cr_waiters,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 21. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT If CR waits are elevated:
PROMPT
PROMPT 1. Identify the exact gc cr wait event.
PROMPT 2. Identify SQL_IDs associated with CR waits.
PROMPT 3. Check whether waits are concentrated on one RAC instance.
PROMPT 4. Check service and machine distribution.
PROMPT 5. Check for cross-instance blocking.
PROMPT 6. Review application access patterns and data affinity.
PROMPT 7. Check hot objects and frequently accessed blocks.
PROMPT 8. Review GCS / Cache Fusion activity.
PROMPT 9. Check RAC interconnect latency and errors.
PROMPT 10. Compare CR waits with gc current waits.
PROMPT 11. Correlate with CPU, I/O and workload changes.
PROMPT 12. Do NOT assume every CR wait indicates an interconnect problem.
PROMPT 13. Do NOT kill sessions based only on this report.
PROMPT
PROMPT ============================================================
PROMPT Notes:
PROMPT - CR waits are normal RAC Cache Fusion activity.
PROMPT - High CR activity can be workload or data-access related.
PROMPT - High CR latency should be correlated with interconnect health.
PROMPT - GV$ system statistics are cumulative since instance startup.
PROMPT - The 10ms/60s thresholds are toolkit investigation triggers,
PROMPT   not Oracle failure thresholds.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC CR BLOCK MONITORING COMPLETE
PROMPT ============================================================
 
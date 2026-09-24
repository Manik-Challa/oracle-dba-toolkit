-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_cr_requests.sql
-- Purpose: Monitor Oracle RAC Consistent Read (CR) requests
-- Scope  : CR request volume, latency, Cache Fusion waits,
--          SQL, services, instances and workload distribution
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name        FORMAT A18
COLUMN host_name            FORMAT A30
COLUMN stat_name            FORMAT A55
COLUMN event                FORMAT A65
COLUMN wait_class           FORMAT A20
COLUMN username             FORMAT A20
COLUMN sql_id               FORMAT A15
COLUMN service_name         FORMAT A25
COLUMN machine              FORMAT A30
COLUMN program              FORMAT A35
COLUMN avg_wait_ms          FORMAT 9999990.99
COLUMN total_wait_sec       FORMAT 9999990.99
COLUMN seconds_in_wait      FORMAT 999999
COLUMN request_count        FORMAT 999999999999
COLUMN executions           FORMAT 999999999999

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
PROMPT 2. CONSISTENT READ / GLOBAL CACHE STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value AS value_num
FROM gv$sysstat
WHERE LOWER(name) LIKE '%consistent%'
   OR LOWER(name) LIKE '%global cache%'
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================
PROMPT 3. CR WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits AS request_count,
    ROUND(time_waited / 100, 2) AS total_wait_sec,
    ROUND(
        (time_waited /
         NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc cr%'
ORDER BY total_waits DESC;


PROMPT
PROMPT ============================================================
PROMPT 4. CR REQUESTS BY EVENT
PROMPT ============================================================

SELECT
    event,
    SUM(total_waits) AS request_count,
    ROUND(SUM(time_waited) / 100, 2) AS total_wait_sec,
    ROUND(
        (SUM(time_waited) /
         NULLIF(SUM(total_waits), 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc cr%'
GROUP BY event
ORDER BY request_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 5. CR REQUEST LATENCY BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    SUM(total_waits) AS request_count,
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
PROMPT 6. CURRENT CR REQUEST WAITERS
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
PROMPT 7. CURRENT CR REQUESTS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS request_waiters,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%'
GROUP BY inst_id
ORDER BY request_waiters DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. CR REQUESTS BY SERVICE
PROMPT ============================================================

SELECT
    service_name,
    COUNT(*) AS request_waiters,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%'
GROUP BY service_name
ORDER BY request_waiters DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. CR REQUESTS BY USER
PROMPT ============================================================

SELECT
    username,
    COUNT(*) AS request_waiters,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%'
GROUP BY username
ORDER BY request_waiters DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. CR REQUESTS BY MACHINE
PROMPT ============================================================

SELECT
    machine,
    COUNT(*) AS request_waiters,
    SUM(seconds_in_wait) AS total_wait_seconds,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%'
GROUP BY machine
ORDER BY request_waiters DESC;


PROMPT
PROMPT ============================================================
PROMPT 11. TOP SQL CURRENTLY WAITING FOR CR REQUESTS
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS longest_wait_seconds,
    MAX(event) AS wait_event
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%'
  AND sql_id IS NOT NULL
GROUP BY
    inst_id,
    sql_id
ORDER BY
    waiting_sessions DESC,
    longest_wait_seconds DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 12. SQL DETAILS FOR CR REQUEST WAITERS
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
PROMPT 13. CR REQUESTS BY SQL_ID
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(*) AS current_waiters,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%'
  AND sql_id IS NOT NULL
GROUP BY sql_id
ORDER BY current_waiters DESC,
         longest_wait_seconds DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. CR REQUESTS BY WAIT CLASS
PROMPT ============================================================

SELECT
    inst_id,
    wait_class,
    COUNT(*) AS current_waiters,
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
    current_waiters DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. CR REQUESTS VS GC CURRENT REQUESTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits AS request_count,
    ROUND(time_waited / 100, 2) AS total_wait_sec,
    ROUND(
        (time_waited /
         NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc cr%'
   OR LOWER(event) LIKE 'gc current%'
ORDER BY
    inst_id,
    request_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 16. CROSS-INSTANCE CR REQUEST CORRELATION
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
PROMPT 17. CR REQUEST INSTANCE COMPARISON
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    NVL(r.request_waiters, 0) AS current_cr_waiters,
    NVL(r.total_wait_seconds, 0) AS total_wait_seconds,
    NVL(r.longest_wait_seconds, 0) AS longest_wait_seconds
FROM gv$instance i
LEFT JOIN
(
    SELECT
        inst_id,
        COUNT(*) AS request_waiters,
        SUM(seconds_in_wait) AS total_wait_seconds,
        MAX(seconds_in_wait) AS longest_wait_seconds
    FROM gv$session
    WHERE username IS NOT NULL
      AND status = 'ACTIVE'
      AND state = 'WAITING'
      AND LOWER(event) LIKE 'gc cr%'
    GROUP BY inst_id
) r
    ON r.inst_id = i.inst_id
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 18. CR REQUEST EVENT DISTRIBUTION
PROMPT ============================================================

SELECT
    event,
    SUM(total_waits) AS request_count,
    ROUND(SUM(time_waited) / 100, 2) AS total_wait_sec,
    ROUND(
        (SUM(time_waited) /
         NULLIF(SUM(total_waits), 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc cr%'
GROUP BY event
ORDER BY total_wait_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 19. CR REQUEST HEALTH SUMMARY
PROMPT ============================================================

SELECT
    CASE
        WHEN COUNT(*) = 0
            THEN 'NO CURRENT CR REQUEST WAITERS'
        WHEN MAX(seconds_in_wait) >= 60
            THEN 'WARNING - CR REQUEST WAIT > 60 SECONDS'
        WHEN MAX(seconds_in_wait) >= 10
            THEN 'REVIEW - ELEVATED CR REQUEST WAIT'
        ELSE
            'REVIEW - CR REQUEST ACTIVITY PRESENT'
    END AS cr_request_health
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc cr%';


PROMPT
PROMPT ============================================================
PROMPT 20. QUICK CR REQUEST CHECK
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS current_cr_requests,
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
PROMPT If CR request activity is elevated:
PROMPT
PROMPT 1. Identify the exact gc cr wait event.
PROMPT 2. Compare CR request volume across RAC instances.
PROMPT 3. Check average and longest CR wait latency.
PROMPT 4. Identify SQL_IDs generating CR requests.
PROMPT 5. Check service and client-machine distribution.
PROMPT 6. Look for cross-instance concentration.
PROMPT 7. Review application data-access patterns.
PROMPT 8. Check for hot blocks and object contention.
PROMPT 9. Correlate with GCS and Cache Fusion activity.
PROMPT 10. Review RAC private interconnect latency.
PROMPT 11. Compare CR requests with gc current requests.
PROMPT 12. Correlate with CPU and I/O workload.
PROMPT 13. Do NOT assume CR requests indicate a RAC failure.
PROMPT 14. Do NOT kill sessions based only on this report.
PROMPT
PROMPT ============================================================
PROMPT Notes:
PROMPT - CR requests are normal RAC Cache Fusion activity.
PROMPT - GV$ system statistics are cumulative since instance startup.
PROMPT - Current session waits show only the current snapshot.
PROMPT - High request volume alone does not prove a performance issue.
PROMPT - 10ms/60s thresholds are investigation triggers,
PROMPT   not Oracle failure thresholds.
PROMPT - CR waits should be correlated with workload and
PROMPT   interconnect measurements.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC CR REQUEST MONITORING COMPLETE
PROMPT ============================================================
 
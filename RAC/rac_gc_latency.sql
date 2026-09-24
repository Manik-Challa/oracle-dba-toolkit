-- ============================================================
-- RAC Global Cache Latency Monitoring
-- File: rac_gc_latency.sql
--
-- Purpose:
--   Monitor RAC Global Cache (GC) latency, identify
--   high-latency gc current / gc cr waits, compare
--   instances, and identify SQL/session hotspots.
--
-- Notes:
--   * GV$SYSTEM_EVENT statistics are cumulative since startup.
--   * GV$SESSION shows point-in-time current waits.
--   * GC waits are normal RAC activity and do not automatically
--     indicate an interconnect or RAC performance problem.
--   * 10 ms is used only as an investigation trigger.
--   * For true workload latency/rates, use interval sampling,
--     ASH/AWR, and OS/interconnect diagnostics.
--
-- Read-only script.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN inst_id              FORMAT 999
COLUMN instance_name        FORMAT A20
COLUMN event                FORMAT A45
COLUMN wait_class           FORMAT A20
COLUMN total_waits          FORMAT 999,999,999,999
COLUMN time_waited_sec      FORMAT 999,999,999.99
COLUMN avg_wait_ms          FORMAT 999,999.99
COLUMN min_wait_ms          FORMAT 999,999.99
COLUMN max_wait_ms          FORMAT 999,999.99
COLUMN username             FORMAT A20
COLUMN service_name         FORMAT A25
COLUMN machine              FORMAT A30
COLUMN sql_id               FORMAT A15
COLUMN plan_hash_value      FORMAT 9999999999
COLUMN event_count          FORMAT 999,999,999
COLUMN cpu_sec              FORMAT 999,999,999.99
COLUMN elapsed_sec          FORMAT 999,999,999.99
COLUMN executions           FORMAT 999,999,999,999

PROMPT
PROMPT ============================================================
PROMPT RAC GLOBAL CACHE LATENCY MONITORING
PROMPT ============================================================
PROMPT

-- ============================================================
-- 1. RAC INSTANCE OVERVIEW
-- ============================================================

PROMPT ============================================================
PROMPT 1. RAC INSTANCE OVERVIEW
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    active_state,
    startup_time
FROM gv$instance
ORDER BY inst_id;


-- ============================================================
-- 2. GC WAIT EVENTS - CUMULATIVE LATENCY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. GLOBAL CACHE WAIT EVENTS - CUMULATIVE LATENCY
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN (time_waited / total_waits) * 10
        END,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE event LIKE 'gc %'
  AND total_waits > 0
ORDER BY avg_wait_ms DESC;


-- ============================================================
-- 3. GC CURRENT EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. GC CURRENT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN (time_waited / total_waits) * 10
        END,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE event LIKE 'gc current%'
  AND total_waits > 0
ORDER BY avg_wait_ms DESC;


-- ============================================================
-- 4. GC CR EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. GC CR EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN (time_waited / total_waits) * 10
        END,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE event LIKE 'gc cr%'
  AND total_waits > 0
ORDER BY avg_wait_ms DESC;


-- ============================================================
-- 5. HIGH-LATENCY GC EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. HIGH-LATENCY GC EVENTS (> 10 ms)
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        (time_waited / NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE event LIKE 'gc %'
  AND total_waits > 0
  AND (time_waited / NULLIF(total_waits, 0)) * 10 > 10
ORDER BY avg_wait_ms DESC;


-- ============================================================
-- 6. GC 2-WAY / 3-WAY LATENCY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. GC 2-WAY / 3-WAY LATENCY
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        (time_waited / NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE event LIKE 'gc %2-way%'
   OR event LIKE 'gc %3-way%'
ORDER BY avg_wait_ms DESC;


-- ============================================================
-- 7. GC LATENCY BY INSTANCE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. GC LATENCY BY INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    SUM(s.total_waits) AS total_gc_waits,
    ROUND(SUM(s.time_waited) / 100, 2) AS total_wait_sec,
    ROUND(
        SUM(s.time_waited)
        / NULLIF(SUM(s.total_waits), 0) * 10,
        2
    ) AS avg_gc_wait_ms
FROM gv$system_event s
JOIN gv$instance i
  ON i.inst_id = s.inst_id
WHERE s.event LIKE 'gc %'
GROUP BY
    s.inst_id,
    i.instance_name
ORDER BY avg_gc_wait_ms DESC;


-- ============================================================
-- 8. CURRENT GC WAITERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. CURRENT GC WAITERS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial#,
    s.username,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.state,
    s.sql_id,
    s.service_name,
    s.machine
FROM gv$session s
WHERE s.wait_class <> 'Idle'
  AND s.event LIKE 'gc %'
ORDER BY s.seconds_in_wait DESC;


-- ============================================================
-- 9. CURRENT HIGH-LATENCY GC WAITERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. CURRENT GC WAITERS > 10 SECONDS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial#,
    s.username,
    s.event,
    s.seconds_in_wait,
    s.state,
    s.sql_id,
    s.service_name,
    s.machine
FROM gv$session s
WHERE s.wait_class <> 'Idle'
  AND s.event LIKE 'gc %'
  AND s.seconds_in_wait > 10
ORDER BY s.seconds_in_wait DESC;


-- ============================================================
-- 10. GC WAITERS BY INSTANCE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. CURRENT GC WAITERS BY INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    COUNT(*) AS gc_waiters
FROM gv$session s
JOIN gv$instance i
  ON i.inst_id = s.inst_id
WHERE s.wait_class <> 'Idle'
  AND s.event LIKE 'gc %'
GROUP BY
    s.inst_id,
    i.instance_name
ORDER BY gc_waiters DESC;


-- ============================================================
-- 11. GC WAITERS BY SERVICE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. CURRENT GC WAITERS BY SERVICE
PROMPT ============================================================

SELECT
    NVL(service_name, 'UNKNOWN') AS service_name,
    COUNT(*) AS gc_waiters
FROM gv$session
WHERE wait_class <> 'Idle'
  AND event LIKE 'gc %'
GROUP BY service_name
ORDER BY gc_waiters DESC;


-- ============================================================
-- 12. GC WAITERS BY USER
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. CURRENT GC WAITERS BY USER
PROMPT ============================================================

SELECT
    NVL(username, 'UNKNOWN') AS username,
    COUNT(*) AS gc_waiters
FROM gv$session
WHERE wait_class <> 'Idle'
  AND event LIKE 'gc %'
GROUP BY username
ORDER BY gc_waiters DESC;


-- ============================================================
-- 13. GC WAITERS BY MACHINE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. CURRENT GC WAITERS BY MACHINE
PROMPT ============================================================

SELECT
    machine,
    COUNT(*) AS gc_waiters
FROM gv$session
WHERE wait_class <> 'Idle'
  AND event LIKE 'gc %'
GROUP BY machine
ORDER BY gc_waiters DESC;


-- ============================================================
-- 14. TOP SQL ASSOCIATED WITH CURRENT GC WAITS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. TOP SQL ASSOCIATED WITH CURRENT GC WAITS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sql_id,
    COUNT(*) AS waiter_count,
    MIN(s.event) AS sample_event,
    MAX(s.seconds_in_wait) AS max_wait_sec
FROM gv$session s
WHERE s.wait_class <> 'Idle'
  AND s.event LIKE 'gc %'
  AND s.sql_id IS NOT NULL
GROUP BY
    s.inst_id,
    s.sql_id
ORDER BY waiter_count DESC, max_wait_sec DESC;


-- ============================================================
-- 15. SQL WITH HIGH GC WAIT ACTIVITY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. SQL WITH HIGH GC WAIT ACTIVITY
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sql_id,
    COUNT(*) AS gc_waiter_count,
    MIN(s.event) AS sample_event,
    MAX(s.seconds_in_wait) AS max_wait_sec
FROM gv$session s
WHERE s.wait_class <> 'Idle'
  AND s.event LIKE 'gc %'
  AND s.sql_id IS NOT NULL
GROUP BY
    s.inst_id,
    s.sql_id
HAVING COUNT(*) >= 2
ORDER BY gc_waiter_count DESC, max_wait_sec DESC;


-- ============================================================
-- 16. SQL DETAILS FOR GC WAITERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. SQL DETAILS FOR GC WAITERS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sql_id,
    q.plan_hash_value,
    q.executions,
    ROUND(q.elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(q.cpu_time / 1000000, 2) AS cpu_sec,
    q.buffer_gets,
    q.disk_reads,
    SUBSTR(q.sql_text, 1, 120) AS sql_text
FROM gv$session s
JOIN gv$sql q
  ON q.inst_id = s.inst_id
 AND q.sql_id = s.sql_id
WHERE s.wait_class <> 'Idle'
  AND s.event LIKE 'gc %'
  AND s.sql_id IS NOT NULL
ORDER BY q.elapsed_time DESC;


-- ============================================================
-- 17. GC WAITS BY SQL
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. GC WAITERS BY SQL
PROMPT ============================================================

SELECT
    s.sql_id,
    COUNT(*) AS gc_waiters,
    COUNT(DISTINCT s.inst_id) AS instance_count,
    COUNT(DISTINCT s.service_name) AS service_count
FROM gv$session s
WHERE s.wait_class <> 'Idle'
  AND s.event LIKE 'gc %'
  AND s.sql_id IS NOT NULL
GROUP BY s.sql_id
ORDER BY gc_waiters DESC;


-- ============================================================
-- 18. GC STATISTICS - GLOBAL CACHE REQUESTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. GLOBAL CACHE REQUEST STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name,
    value
FROM gv$sysstat
WHERE LOWER(name) LIKE '%global cache%'
   OR LOWER(name) LIKE '%gc%'
ORDER BY inst_id, name;


-- ============================================================
-- 19. GC CURRENT VS CR WAIT COUNTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 19. GC CURRENT VS CR WAIT COUNTS
PROMPT ============================================================

SELECT
    inst_id,
    SUM(
        CASE
            WHEN event LIKE 'gc current%'
            THEN total_waits
            ELSE 0
        END
    ) AS gc_current_waits,
    SUM(
        CASE
            WHEN event LIKE 'gc cr%'
            THEN total_waits
            ELSE 0
        END
    ) AS gc_cr_waits,
    SUM(total_waits) AS total_gc_waits
FROM gv$system_event
WHERE event LIKE 'gc %'
GROUP BY inst_id
ORDER BY inst_id;


-- ============================================================
-- 20. GC WAIT CLASS SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 20. GC WAIT CLASS SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    wait_class,
    SUM(total_waits) AS total_waits,
    ROUND(SUM(time_waited) / 100, 2) AS time_waited_sec,
    ROUND(
        SUM(time_waited)
        / NULLIF(SUM(total_waits), 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE event LIKE 'gc %'
GROUP BY
    inst_id,
    wait_class
ORDER BY avg_wait_ms DESC;


-- ============================================================
-- 21. RAC INTERCONNECT-RELATED CURRENT WAITERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 21. CURRENT GC / INTERCONNECT-RELATED WAITERS
PROMPT ============================================================

SELECT
    inst_id,
    sid,
    serial#,
    username,
    event,
    seconds_in_wait,
    state,
    sql_id,
    service_name,
    machine
FROM gv$session
WHERE wait_class <> 'Idle'
  AND (
        event LIKE 'gc %'
        OR event LIKE '%interconnect%'
      )
ORDER BY seconds_in_wait DESC;


-- ============================================================
-- 22. INSTANCE LATENCY COMPARISON
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 22. INSTANCE LATENCY COMPARISON
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    COUNT(DISTINCT s.event) AS gc_event_types,
    SUM(s.total_waits) AS gc_waits,
    ROUND(SUM(s.time_waited) / 100, 2) AS total_wait_sec,
    ROUND(
        SUM(s.time_waited)
        / NULLIF(SUM(s.total_waits), 0) * 10,
        2
    ) AS avg_gc_latency_ms
FROM gv$system_event s
JOIN gv$instance i
  ON i.inst_id = s.inst_id
WHERE s.event LIKE 'gc %'
GROUP BY
    s.inst_id,
    i.instance_name
ORDER BY avg_gc_latency_ms DESC;


-- ============================================================
-- 23. GC EVENTS WITH VERY HIGH LATENCY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 23. GC EVENTS > 20 ms
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(
        (time_waited / NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE event LIKE 'gc %'
  AND total_waits > 100
  AND (time_waited / NULLIF(total_waits, 0)) * 10 > 20
ORDER BY avg_wait_ms DESC;


-- ============================================================
-- 24. RAC GC HEALTH SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 24. RAC GC HEALTH SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS gc_event_types,
    SUM(total_waits) AS total_gc_waits,
    ROUND(SUM(time_waited) / 100, 2) AS total_wait_sec,
    ROUND(
        SUM(time_waited)
        / NULLIF(SUM(total_waits), 0) * 10,
        2
    ) AS avg_gc_latency_ms,
    CASE
        WHEN SUM(total_waits) = 0
            THEN 'NO GC WAITS'
        WHEN
            SUM(time_waited)
            / NULLIF(SUM(total_waits), 0) * 10 > 20
            THEN 'INVESTIGATE HIGH GC LATENCY'
        WHEN
            SUM(time_waited)
            / NULLIF(SUM(total_waits), 0) * 10 > 10
            THEN 'INVESTIGATE GC LATENCY'
        ELSE 'REVIEW / NORMAL RANGE'
    END AS health_status
FROM gv$system_event
WHERE event LIKE 'gc %';


-- ============================================================
-- 25. QUICK DBA CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 25. QUICK DBA CHECK
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(
        (time_waited / NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE event LIKE 'gc %'
  AND total_waits > 0
ORDER BY avg_wait_ms DESC
FETCH FIRST 10 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT RAC GC LATENCY - INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT 1. Compare GC latency across RAC instances.
PROMPT 2. Check gc current and gc cr separately.
PROMPT 3. Look for 2-way / 3-way latency.
PROMPT 4. Identify sessions currently waiting on GC events.
PROMPT 5. Identify SQL associated with GC waits.
PROMPT 6. Check service and instance workload distribution.
PROMPT 7. Review hot blocks / block contention when applicable.
PROMPT 8. Review SQL plans and access patterns.
PROMPT 9. Check RAC interconnect health at the OS/network layer.
PROMPT 10. Use ASH/AWR for interval-based historical analysis.
PROMPT
PROMPT IMPORTANT:
PROMPT GC waits are normal RAC activity. High GC latency alone
PROMPT does not prove an interconnect problem.
PROMPT
PROMPT ============================================================
PROMPT END OF RAC GC LATENCY MONITORING
PROMPT ============================================================


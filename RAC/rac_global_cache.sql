-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_global_cache.sql
-- Purpose: Monitor Oracle RAC Global Cache / Cache Fusion
-- Scope  : GCS activity, GC waits, block transfers,
--          cache fusion latency, SQL and instance comparison
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN inst_id              FORMAT 999
COLUMN instance_name        FORMAT A20
COLUMN host_name            FORMAT A35
COLUMN stat_name            FORMAT A55
COLUMN event                FORMAT A50
COLUMN wait_class           FORMAT A20
COLUMN sql_id               FORMAT A15
COLUMN username             FORMAT A20
COLUMN service_name         FORMAT A25
COLUMN machine              FORMAT A30
COLUMN program              FORMAT A35
COLUMN state                 FORMAT A15
COLUMN value_num            FORMAT 999999999999999
COLUMN total_waits          FORMAT 999999999999
COLUMN time_waited_sec      FORMAT 999999999.99
COLUMN avg_wait_ms          FORMAT 999999.99
COLUMN waiting_sessions     FORMAT 999999
COLUMN seconds_in_wait      FORMAT 999999
COLUMN gc_requests          FORMAT 999999999999999
COLUMN gc_blocks            FORMAT 999999999999999

PROMPT
PROMPT ============================================================
PROMPT RAC GLOBAL CACHE / CACHE FUSION MONITOR
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
    version,
    thread# AS thread,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 3. GLOBAL CACHE RELATED SYSTEM STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value AS value_num
FROM gv$sysstat
WHERE LOWER(name) LIKE '%global cache%'
   OR LOWER(name) LIKE '%gc %'
   OR LOWER(name) LIKE '%cache fusion%'
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 4. GCS RELATED STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value AS value_num
FROM gv$sysstat
WHERE LOWER(name) LIKE '%gcs%'
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 5. GES RELATED STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value AS value_num
FROM gv$sysstat
WHERE LOWER(name) LIKE '%ges%'
   OR LOWER(name) LIKE '%global enqueue%'
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 6. ALL GLOBAL CACHE WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        (time_waited / NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
ORDER BY
    time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. IMPORTANT CACHE FUSION EVENTS
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
WHERE event IN (
    'gc current request',
    'gc current block request',
    'gc cr request',
    'gc cr block request',
    'gc current block 2-way',
    'gc current block 3-way',
    'gc cr block 2-way',
    'gc cr block 3-way'
)
ORDER BY
    time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. CURRENT GLOBAL CACHE WAITERS
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
  AND LOWER(event) LIKE 'gc %'
ORDER BY
    seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. GLOBAL CACHE WAIT SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    event,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS longest_wait_sec
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id,
    event
ORDER BY
    waiting_sessions DESC,
    longest_wait_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. GLOBAL CACHE WAITERS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS gc_waiters,
    MAX(seconds_in_wait) AS longest_wait_sec
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id
ORDER BY
    inst_id;


PROMPT
PROMPT ============================================================
PROMPT 11. SQL ASSOCIATED WITH CURRENT GC WAITS
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS max_wait_sec,
    MIN(username) AS sample_user,
    MIN(event) AS sample_event
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc %'
  AND sql_id IS NOT NULL
GROUP BY
    inst_id,
    sql_id
ORDER BY
    waiting_sessions DESC,
    max_wait_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 12. TOP SQL BY CURRENT GC WAITERS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        s.inst_id,
        s.sql_id,
        COUNT(*) AS waiting_sessions,
        MAX(s.seconds_in_wait) AS max_wait_sec,
        MIN(s.event) AS sample_event,
        MIN(s.service_name) AS service_name
    FROM gv$session s
    WHERE s.username IS NOT NULL
      AND s.status = 'ACTIVE'
      AND s.state = 'WAITING'
      AND LOWER(s.event) LIKE 'gc %'
      AND s.sql_id IS NOT NULL
    GROUP BY
        s.inst_id,
        s.sql_id
    ORDER BY
        waiting_sessions DESC,
        max_wait_sec DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 13. SQL DETAILS FOR CURRENT GC WAITERS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.seconds_in_wait,
    s.service_name,
    s.machine,
    s.program,
    q.executions,
    q.buffer_gets,
    q.disk_reads,
    ROUND(q.cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(q.elapsed_time / 1000000, 2) AS elapsed_sec
FROM gv$session s
LEFT JOIN gv$sql q
    ON q.inst_id = s.inst_id
   AND q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND s.state = 'WAITING'
  AND LOWER(s.event) LIKE 'gc %'
ORDER BY
    s.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. GLOBAL CACHE WAIT LATENCY
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
WHERE LOWER(event) LIKE 'gc %'
  AND total_waits > 0
ORDER BY
    avg_wait_ms DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. GC EVENTS WITH ELEVATED LATENCY
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
WHERE LOWER(event) LIKE 'gc %'
  AND total_waits > 0
  AND (time_waited / NULLIF(total_waits, 0)) * 10 >= 10
ORDER BY
    avg_wait_ms DESC;


PROMPT
PROMPT ============================================================
PROMPT 16. GLOBAL CACHE EVENTS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    SUM(total_waits) AS gc_waits,
    ROUND(SUM(time_waited) / 100, 2) AS gc_wait_time_sec,
    ROUND(
        (SUM(time_waited) / NULLIF(SUM(total_waits), 0)) * 10,
        2
    ) AS avg_gc_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id
ORDER BY
    inst_id;


PROMPT
PROMPT ============================================================
PROMPT 17. GC WAITS BY WAIT CLASS
PROMPT ============================================================

SELECT
    inst_id,
    wait_class,
    SUM(total_waits) AS total_waits,
    ROUND(SUM(time_waited) / 100, 2) AS time_waited_sec
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id,
    wait_class
ORDER BY
    time_waited_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 18. RAC INSTANCE CACHE FUSION ACTIVITY
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    COUNT(s.sid) AS active_sessions,
    SUM(
        CASE
            WHEN LOWER(s.event) LIKE 'gc %'
            THEN 1
            ELSE 0
        END
    ) AS gc_waiters,
    SUM(
        CASE
            WHEN s.state = 'WAITING'
             AND s.wait_class <> 'Idle'
            THEN 1
            ELSE 0
        END
    ) AS non_idle_waiters
FROM gv$instance i
LEFT JOIN gv$session s
    ON s.inst_id = i.inst_id
   AND s.username IS NOT NULL
   AND s.status = 'ACTIVE'
GROUP BY
    i.inst_id,
    i.instance_name,
    i.host_name
ORDER BY
    i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 19. CACHE FUSION ACTIVITY BY SERVICE
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS gc_waiters
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id,
    service_name
ORDER BY
    gc_waiters DESC;


PROMPT
PROMPT ============================================================
PROMPT 20. CACHE FUSION ACTIVITY BY USER
PROMPT ============================================================

SELECT
    inst_id,
    username,
    COUNT(*) AS gc_waiters
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id,
    username
ORDER BY
    gc_waiters DESC;


PROMPT
PROMPT ============================================================
PROMPT 21. CACHE FUSION ACTIVITY BY MACHINE
PROMPT ============================================================

SELECT
    inst_id,
    machine,
    COUNT(*) AS gc_waiters
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id,
    machine
ORDER BY
    gc_waiters DESC;


PROMPT
PROMPT ============================================================
PROMPT 22. GLOBAL CACHE AND BLOCKING CORRELATION
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.seconds_in_wait,
    s.blocking_instance,
    s.blocking_session,
    s.service_name
FROM gv$session s
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND LOWER(s.event) LIKE 'gc %'
  AND (
        s.blocking_session IS NOT NULL
        OR s.final_blocking_session IS NOT NULL
      )
ORDER BY
    s.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 23. GLOBAL CACHE SYSTEM EVENT SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS gc_event_types,
    SUM(total_waits) AS total_gc_waits,
    ROUND(SUM(time_waited) / 100, 2) AS total_gc_wait_sec,
    ROUND(
        (
            SUM(time_waited)
            /
            NULLIF(SUM(total_waits), 0)
        ) * 10,
        2
    ) AS avg_gc_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id
ORDER BY
    inst_id;


PROMPT
PROMPT ============================================================
PROMPT 24. QUICK GLOBAL CACHE CHECK
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
WHERE LOWER(event) LIKE 'gc %'
ORDER BY
    time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 25. GLOBAL CACHE HEALTH SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    SUM(total_waits) AS gc_waits,
    ROUND(SUM(time_waited) / 100, 2) AS gc_wait_time_sec,
    ROUND(
        (SUM(time_waited) / NULLIF(SUM(total_waits), 0)) * 10,
        2
    ) AS avg_gc_wait_ms,
    CASE
        WHEN SUM(total_waits) = 0
            THEN 'NO GC WAITS'
        WHEN
            (SUM(time_waited) / NULLIF(SUM(total_waits), 0)) * 10 >= 10
            THEN 'REVIEW GC LATENCY'
        ELSE 'REVIEW WORKLOAD / CACHE FUSION'
    END AS health_status
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id
ORDER BY
    inst_id;


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT 1. Review GC waits by RAC instance.
PROMPT 2. Check gc current and gc cr wait activity.
PROMPT 3. Review average GC wait latency.
PROMPT 4. Identify sessions currently waiting on GC events.
PROMPT 5. Identify SQL associated with current GC waits.
PROMPT 6. Check service/user/machine concentration.
PROMPT 7. Compare GC activity across RAC instances.
PROMPT 8. Investigate repeated 3-way GC waits.
PROMPT 9. Correlate GC waits with application data access patterns.
PROMPT 10. Check for hot blocks and excessive block shipping.
PROMPT 11. Correlate with RAC interconnect health.
PROMPT 12. Review OS/network metrics when latency is elevated.
PROMPT
PROMPT IMPORTANT:
PROMPT - GV$ statistics are cumulative since instance startup.
PROMPT - GC waits do not automatically indicate an interconnect failure.
PROMPT - Cache Fusion traffic can be normal for RAC workloads.
PROMPT - High GC activity may indicate block contention or poor
PROMPT   data/service affinity and requires workload analysis.
PROMPT - A 3-way wait is not by itself proof of a network problem.
PROMPT - Use AWR/ASH when available for historical analysis.
PROMPT - Use OS and Clusterware tools for infrastructure validation.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================


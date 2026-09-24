-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_gcs_gc.sql
-- Purpose: Monitor Oracle RAC GCS and Global Cache (GC) activity
-- Scope  : GCS statistics, GC waits, 2-way/3-way waits,
--          current waiters, SQL, services and instance health
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN inst_id             FORMAT 999
COLUMN instance_name       FORMAT A20
COLUMN host_name           FORMAT A35
COLUMN stat_name           FORMAT A55
COLUMN event               FORMAT A50
COLUMN wait_class          FORMAT A20
COLUMN sql_id              FORMAT A15
COLUMN username            FORMAT A20
COLUMN service_name        FORMAT A25
COLUMN machine             FORMAT A30
COLUMN program             FORMAT A35
COLUMN state               FORMAT A15

COLUMN total_waits         FORMAT 999999999999
COLUMN time_waited_sec     FORMAT 999999999.99
COLUMN avg_wait_ms         FORMAT 999999.99
COLUMN waiting_sessions    FORMAT 999999
COLUMN longest_wait_sec    FORMAT 999999
COLUMN value_num           FORMAT 999999999999999

PROMPT
PROMPT ============================================================
PROMPT RAC GCS / GLOBAL CACHE MONITOR
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
PROMPT 3. GCS STATISTICS
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
PROMPT 4. GLOBAL CACHE STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value AS value_num
FROM gv$sysstat
WHERE LOWER(name) LIKE '%global cache%'
   OR LOWER(name) LIKE '%gc %'
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 5. GC WAIT EVENTS
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
PROMPT 6. GC CURRENT BLOCK EVENTS
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
WHERE LOWER(event) LIKE 'gc current%'
ORDER BY
    time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. GC CR BLOCK EVENTS
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
WHERE LOWER(event) LIKE 'gc cr%'
ORDER BY
    time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. GC 2-WAY EVENTS
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
WHERE LOWER(event) LIKE 'gc %2-way%'
ORDER BY
    time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. GC 3-WAY EVENTS
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
WHERE LOWER(event) LIKE 'gc %3-way%'
ORDER BY
    time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. CURRENT GCS / GC WAITERS
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
PROMPT 11. CURRENT GC WAIT SUMMARY
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
PROMPT 12. GC WAITERS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS waiting_sessions,
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
PROMPT 13. GC WAITERS BY SERVICE
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS longest_wait_sec
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id,
    service_name
ORDER BY
    waiting_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. GC WAITERS BY USER
PROMPT ============================================================

SELECT
    inst_id,
    username,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS longest_wait_sec
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id,
    username
ORDER BY
    waiting_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. GC WAITERS BY MACHINE
PROMPT ============================================================

SELECT
    inst_id,
    machine,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS longest_wait_sec
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id,
    machine
ORDER BY
    waiting_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 16. TOP SQL BY CURRENT GC WAITERS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        inst_id,
        sql_id,
        COUNT(*) AS waiting_sessions,
        MAX(seconds_in_wait) AS longest_wait_sec,
        MIN(event) AS sample_event,
        MIN(service_name) AS service_name
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
        longest_wait_sec DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 17. SQL DETAILS FOR GC WAITERS
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
PROMPT 18. GC LATENCY BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    SUM(total_waits) AS total_gc_waits,
    ROUND(SUM(time_waited) / 100, 2) AS total_wait_time_sec,
    ROUND(
        (SUM(time_waited) /
         NULLIF(SUM(total_waits), 0)) * 10,
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
PROMPT 19. GC EVENTS WITH HIGHER LATENCY
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
PROMPT 20. GC EVENT DISTRIBUTION
PROMPT ============================================================

SELECT
    event,
    SUM(total_waits) AS total_waits,
    ROUND(SUM(time_waited) / 100, 2) AS time_waited_sec,
    ROUND(
        (SUM(time_waited) /
         NULLIF(SUM(total_waits), 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
GROUP BY event
ORDER BY
    time_waited_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 21. GCS WAIT CLASS SUMMARY
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
PROMPT 22. RAC INSTANCE GCS COMPARISON
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status,
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
            WHEN LOWER(s.event) LIKE 'gc current%'
            THEN 1
            ELSE 0
        END
    ) AS gc_current_waiters,
    SUM(
        CASE
            WHEN LOWER(s.event) LIKE 'gc cr%'
            THEN 1
            ELSE 0
        END
    ) AS gc_cr_waiters
FROM gv$instance i
LEFT JOIN gv$session s
    ON s.inst_id = i.inst_id
   AND s.username IS NOT NULL
   AND s.status = 'ACTIVE'
GROUP BY
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status
ORDER BY
    i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 23. GC WAITERS WITH BLOCKING INFORMATION
PROMPT ============================================================

SELECT
    inst_id,
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    seconds_in_wait,
    blocking_instance,
    blocking_session,
    final_blocking_instance,
    final_blocking_session,
    service_name
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND LOWER(event) LIKE 'gc %'
  AND (
        blocking_session IS NOT NULL
        OR final_blocking_session IS NOT NULL
      )
ORDER BY
    seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 24. GC WAIT SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS current_gc_waiters,
    COUNT(DISTINCT inst_id) AS affected_instances,
    COUNT(DISTINCT sql_id) AS affected_sql,
    COUNT(DISTINCT service_name) AS affected_services,
    MAX(seconds_in_wait) AS longest_wait_sec
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc %';


PROMPT
PROMPT ============================================================
PROMPT 25. GCS / GC HEALTH SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    SUM(total_waits) AS gc_waits,
    ROUND(SUM(time_waited) / 100, 2) AS gc_wait_time_sec,
    ROUND(
        (SUM(time_waited) /
         NULLIF(SUM(total_waits), 0)) * 10,
        2
    ) AS avg_gc_wait_ms,
    CASE
        WHEN SUM(total_waits) = 0
            THEN 'NO GC WAITS'
        WHEN
            (SUM(time_waited) /
             NULLIF(SUM(total_waits), 0)) * 10 >= 10
            THEN 'REVIEW GC LATENCY'
        ELSE 'REVIEW CACHE FUSION ACTIVITY'
    END AS health_status
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id
ORDER BY
    inst_id;


PROMPT
PROMPT ============================================================
PROMPT 26. QUICK GCS / GC CHECK
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
PROMPT DBA INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT 1. Review GCS statistics across all RAC instances.
PROMPT 2. Check gc current and gc cr activity.
PROMPT 3. Review 2-way versus 3-way GC waits.
PROMPT 4. Check GC wait latency by instance.
PROMPT 5. Identify sessions currently waiting on GC events.
PROMPT 6. Identify SQL generating significant GC waits.
PROMPT 7. Check service and machine concentration.
PROMPT 8. Look for repeated high-latency GC events.
PROMPT 9. Investigate hot blocks and block contention.
PROMPT 10. Review application data-access patterns.
PROMPT 11. Correlate with RAC private interconnect health.
PROMPT 12. Use ASH/AWR for historical GC analysis when available.
PROMPT
PROMPT IMPORTANT:
PROMPT - GV$ statistics are cumulative since instance startup.
PROMPT - GC waits are a normal part of RAC Cache Fusion.
PROMPT - GC waits alone do not prove an interconnect problem.
PROMPT - 3-way waits require workload and network correlation.
PROMPT - High GC activity may be caused by block contention,
PROMPT   service placement or application access patterns.
PROMPT - The 10 ms latency value is a toolkit review threshold,
PROMPT   not an Oracle failure threshold.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================


-- ============================================================================
-- RAC CACHE FUSION MONITORING
-- File    : rac_cache_fusion.sql
-- Purpose : Monitor Oracle RAC Cache Fusion / Global Cache activity
-- Author  : Manik Challa
-- Usage   : Run as SYS or a user with appropriate GV$ privileges
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN inst_id              FORMAT 999
COLUMN instance_name        FORMAT A20
COLUMN thread#              FORMAT 999

COLUMN event                FORMAT A45
COLUMN wait_class           FORMAT A20
COLUMN total_waits          FORMAT 999999999
COLUMN time_waited_sec      FORMAT 999999999.99
COLUMN avg_wait_ms          FORMAT 999999.99

COLUMN sid                  FORMAT 999999
COLUMN serial#              FORMAT 999999
COLUMN username             FORMAT A20
COLUMN machine              FORMAT A30
COLUMN program              FORMAT A35
COLUMN service_name         FORMAT A30
COLUMN state                FORMAT A15
COLUMN seconds_in_wait      FORMAT 999999
COLUMN sql_id               FORMAT A15

COLUMN statistic_name       FORMAT A45
COLUMN value                FORMAT 999999999999999

COLUMN executions           FORMAT 999999999
COLUMN buffer_gets         FORMAT 999999999999
COLUMN disk_reads          FORMAT 999999999999
COLUMN rows_processed      FORMAT 999999999999
COLUMN elapsed_sec         FORMAT 999999999.99
COLUMN cpu_sec             FORMAT 999999999.99

COLUMN gc_current_requests  FORMAT 999999999999
COLUMN gc_cr_requests       FORMAT 999999999999
COLUMN gc_current_blocks    FORMAT 999999999999
COLUMN gc_cr_blocks         FORMAT 999999999999

PROMPT
PROMPT ============================================================================
PROMPT RAC CACHE FUSION MONITORING
PROMPT ============================================================================


PROMPT
PROMPT ============================================================================
PROMPT 1. RAC INSTANCE OVERVIEW
PROMPT ============================================================================

SELECT
    inst_id,
    instance_number,
    instance_name,
    host_name,
    status,
    thread#
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 2. GLOBAL CACHE WAIT EVENTS
PROMPT ============================================================================

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
WHERE LOWER(event) LIKE 'gc %'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================================
PROMPT 3. GC CURRENT EVENTS
PROMPT ============================================================================

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
WHERE LOWER(event) LIKE 'gc current%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================================
PROMPT 4. GC CR EVENTS
PROMPT ============================================================================

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
WHERE LOWER(event) LIKE 'gc cr%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================================
PROMPT 5. GC CURRENT 2-WAY / 3-WAY EVENTS
PROMPT ============================================================================

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
WHERE LOWER(event) LIKE 'gc current%'
  AND (
        LOWER(event) LIKE '%2-way%'
        OR LOWER(event) LIKE '%3-way%'
      )
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================================
PROMPT 6. GC CR 2-WAY / 3-WAY EVENTS
PROMPT ============================================================================

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
WHERE LOWER(event) LIKE 'gc cr%'
  AND (
        LOWER(event) LIKE '%2-way%'
        OR LOWER(event) LIKE '%3-way%'
      )
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================================
PROMPT 7. CACHE FUSION WAIT CLASS SUMMARY
PROMPT ============================================================================

SELECT
    inst_id,
    wait_class,
    COUNT(*) AS event_count,
    SUM(total_waits) AS total_waits,
    ROUND(SUM(time_waited) / 100, 2) AS time_waited_sec
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id,
    wait_class
ORDER BY
    inst_id,
    time_waited_sec DESC;


PROMPT
PROMPT ============================================================================
PROMPT 8. CURRENT RAC CACHE FUSION WAITERS
PROMPT ============================================================================

SELECT
    inst_id,
    sid,
    serial#,
    username,
    event,
    wait_class,
    seconds_in_wait,
    state,
    sql_id,
    service_name,
    machine,
    program
FROM gv$session
WHERE status = 'ACTIVE'
  AND LOWER(event) LIKE 'gc %'
ORDER BY seconds_in_wait DESC;


PROMPT
PROMPT ============================================================================
PROMPT 9. CURRENT GC CURRENT WAITERS
PROMPT ============================================================================

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
WHERE status = 'ACTIVE'
  AND LOWER(event) LIKE 'gc current%'
ORDER BY seconds_in_wait DESC;


PROMPT
PROMPT ============================================================================
PROMPT 10. CURRENT GC CR WAITERS
PROMPT ============================================================================

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
WHERE status = 'ACTIVE'
  AND LOWER(event) LIKE 'gc cr%'
ORDER BY seconds_in_wait DESC;


PROMPT
PROMPT ============================================================================
PROMPT 11. GC WAITERS BY INSTANCE
PROMPT ============================================================================

SELECT
    inst_id,
    COUNT(*) AS gc_waiters,
    MAX(seconds_in_wait) AS max_wait_seconds
FROM gv$session
WHERE status = 'ACTIVE'
  AND LOWER(event) LIKE 'gc %'
GROUP BY inst_id
ORDER BY gc_waiters DESC;


PROMPT
PROMPT ============================================================================
PROMPT 12. GC WAITERS BY SERVICE
PROMPT ============================================================================

SELECT
    service_name,
    COUNT(*) AS gc_waiters,
    MAX(seconds_in_wait) AS max_wait_seconds
FROM gv$session
WHERE status = 'ACTIVE'
  AND LOWER(event) LIKE 'gc %'
GROUP BY service_name
ORDER BY gc_waiters DESC;


PROMPT
PROMPT ============================================================================
PROMPT 13. GC WAITERS BY USER
PROMPT ============================================================================

SELECT
    username,
    COUNT(*) AS gc_waiters,
    MAX(seconds_in_wait) AS max_wait_seconds
FROM gv$session
WHERE status = 'ACTIVE'
  AND LOWER(event) LIKE 'gc %'
GROUP BY username
ORDER BY gc_waiters DESC;


PROMPT
PROMPT ============================================================================
PROMPT 14. CACHE FUSION STATISTICS
PROMPT ============================================================================

SELECT
    inst_id,
    name AS statistic_name,
    value
FROM gv$sysstat
WHERE LOWER(name) LIKE '%global cache%'
   OR LOWER(name) LIKE '%gc %'
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================================
PROMPT 15. GLOBAL CACHE REQUEST STATISTICS
PROMPT ============================================================================

SELECT
    inst_id,
    name AS statistic_name,
    value
FROM gv$sysstat
WHERE name IN (
    'gc current blocks received',
    'gc current blocks served',
    'gc cr blocks received',
    'gc cr blocks served',
    'gc current blocks requested',
    'gc cr blocks requested'
)
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================================
PROMPT 16. GC CURRENT / CR REQUEST COUNTS
PROMPT ============================================================================

SELECT
    inst_id,
    SUM(
        CASE
            WHEN LOWER(name) LIKE 'gc current%'
             AND LOWER(name) LIKE '%requested%'
            THEN value
            ELSE 0
        END
    ) AS gc_current_requests,
    SUM(
        CASE
            WHEN LOWER(name) LIKE 'gc cr%'
             AND LOWER(name) LIKE '%requested%'
            THEN value
            ELSE 0
        END
    ) AS gc_cr_requests,
    SUM(
        CASE
            WHEN LOWER(name) LIKE 'gc current%'
             AND LOWER(name) LIKE '%received%'
            THEN value
            ELSE 0
        END
    ) AS gc_current_blocks,
    SUM(
        CASE
            WHEN LOWER(name) LIKE 'gc cr%'
             AND LOWER(name) LIKE '%received%'
            THEN value
            ELSE 0
        END
    ) AS gc_cr_blocks
FROM gv$sysstat
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 17. TOP SQL ASSOCIATED WITH GC WAITS
PROMPT ============================================================================

SELECT *
FROM (
    SELECT
        s.inst_id,
        s.sql_id,
        s.executions,
        s.buffer_gets,
        s.disk_reads,
        ROUND(s.elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(s.cpu_time / 1000000, 2) AS cpu_sec,
        s.sql_text
    FROM gv$sql s
    WHERE s.sql_id IN (
        SELECT DISTINCT sql_id
        FROM gv$session
        WHERE status = 'ACTIVE'
          AND LOWER(event) LIKE 'gc %'
          AND sql_id IS NOT NULL
    )
    ORDER BY s.elapsed_time DESC
)
WHERE ROWNUM <= 30;


PROMPT
PROMPT ============================================================================
PROMPT 18. SQL WITH HIGH BUFFER GETS AND GC ACTIVITY
PROMPT ============================================================================

SELECT *
FROM (
    SELECT
        inst_id,
        sql_id,
        executions,
        buffer_gets,
        disk_reads,
        ROUND(buffer_gets / NULLIF(executions, 0), 2)
            AS buffer_gets_per_exec,
        ROUND(disk_reads / NULLIF(executions, 0), 2)
            AS disk_reads_per_exec,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        sql_text
    FROM gv$sql
    WHERE executions > 0
    ORDER BY buffer_gets DESC
)
WHERE ROWNUM <= 30;


PROMPT
PROMPT ============================================================================
PROMPT 19. GC WAITS BY SQL ID FROM CURRENT SESSIONS
PROMPT ============================================================================

SELECT
    sql_id,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS max_wait_seconds
FROM gv$session
WHERE status = 'ACTIVE'
  AND LOWER(event) LIKE 'gc %'
  AND sql_id IS NOT NULL
GROUP BY sql_id
ORDER BY waiting_sessions DESC, max_wait_seconds DESC;


PROMPT
PROMPT ============================================================================
PROMPT 20. GC WAITS BY SERVICE AND INSTANCE
PROMPT ============================================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS gc_waiters,
    MAX(seconds_in_wait) AS max_wait_seconds
FROM gv$session
WHERE status = 'ACTIVE'
  AND LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id,
    service_name
ORDER BY
    inst_id,
    gc_waiters DESC;


PROMPT
PROMPT ============================================================================
PROMPT 21. GC WAITS BY MACHINE
PROMPT ============================================================================

SELECT
    machine,
    COUNT(*) AS gc_waiters,
    MAX(seconds_in_wait) AS max_wait_seconds
FROM gv$session
WHERE status = 'ACTIVE'
  AND LOWER(event) LIKE 'gc %'
GROUP BY machine
ORDER BY gc_waiters DESC;


PROMPT
PROMPT ============================================================================
PROMPT 22. GLOBAL CACHE WAIT LATENCY
PROMPT ============================================================================

SELECT
    inst_id,
    event,
    ROUND(
        time_waited / NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms,
    total_waits,
    ROUND(time_waited / 100, 2) AS total_wait_sec
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
  AND total_waits > 0
ORDER BY avg_wait_ms DESC;


PROMPT
PROMPT ============================================================================
PROMPT 23. HIGH-LATENCY GC EVENTS
PROMPT ============================================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(
        time_waited / NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms,
    ROUND(time_waited / 100, 2) AS total_wait_sec
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
  AND total_waits > 0
  AND (time_waited / NULLIF(total_waits, 0) * 10) >= 10
ORDER BY avg_wait_ms DESC;


PROMPT
PROMPT ============================================================================
PROMPT 24. CACHE FUSION WAIT EVENTS BY INSTANCE
PROMPT ============================================================================

SELECT
    inst_id,
    COUNT(*) AS gc_event_types,
    SUM(total_waits) AS total_gc_waits,
    ROUND(SUM(time_waited) / 100, 2) AS total_gc_wait_sec
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
GROUP BY inst_id
ORDER BY total_gc_wait_sec DESC;


PROMPT
PROMPT ============================================================================
PROMPT 25. RAC INSTANCE GC COMPARISON
PROMPT ============================================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    (
        SELECT COUNT(*)
        FROM gv$session s
        WHERE s.inst_id = i.inst_id
          AND s.status = 'ACTIVE'
          AND LOWER(s.event) LIKE 'gc %'
    ) AS current_gc_waiters,
    (
        SELECT ROUND(SUM(e.time_waited) / 100, 2)
        FROM gv$system_event e
        WHERE e.inst_id = i.inst_id
          AND LOWER(e.event) LIKE 'gc %'
    ) AS cumulative_gc_wait_sec
FROM gv$instance i
ORDER BY current_gc_waiters DESC;


PROMPT
PROMPT ============================================================================
PROMPT 26. GC CURRENT VS GC CR WAIT DISTRIBUTION
PROMPT ============================================================================

SELECT
    inst_id,
    CASE
        WHEN LOWER(event) LIKE 'gc current%' THEN 'GC CURRENT'
        WHEN LOWER(event) LIKE 'gc cr%'      THEN 'GC CR'
        ELSE 'OTHER GC'
    END AS gc_type,
    COUNT(*) AS event_count,
    SUM(total_waits) AS total_waits,
    ROUND(SUM(time_waited) / 100, 2) AS wait_seconds
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id,
    CASE
        WHEN LOWER(event) LIKE 'gc current%' THEN 'GC CURRENT'
        WHEN LOWER(event) LIKE 'gc cr%'      THEN 'GC CR'
        ELSE 'OTHER GC'
    END
ORDER BY
    inst_id,
    wait_seconds DESC;


PROMPT
PROMPT ============================================================================
PROMPT 27. CACHE FUSION / INTERCONNECT RELATED EVENTS
PROMPT ============================================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS wait_seconds
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
   OR LOWER(event) LIKE '%interconnect%'
   OR LOWER(event) LIKE '%private network%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================================
PROMPT 28. CURRENT INTERCONNECT-RELATED WAITERS
PROMPT ============================================================================

SELECT
    inst_id,
    sid,
    serial#,
    username,
    event,
    wait_class,
    seconds_in_wait,
    sql_id,
    service_name,
    machine
FROM gv$session
WHERE status = 'ACTIVE'
  AND (
        LOWER(event) LIKE 'gc %'
        OR LOWER(event) LIKE '%interconnect%'
        OR LOWER(event) LIKE '%private network%'
      )
ORDER BY seconds_in_wait DESC;


PROMPT
PROMPT ============================================================================
PROMPT 29. CACHE FUSION HEALTH SUMMARY
PROMPT ============================================================================

SELECT
    'GC SYSTEM WAIT EVENTS' AS check_name,
    COUNT(*) AS value,
    CASE
        WHEN COUNT(*) > 0 THEN 'INFO'
        ELSE 'OK'
    END AS health
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'

UNION ALL

SELECT
    'CURRENT GC WAITERS',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'CHECK'
    END
FROM gv$session
WHERE status = 'ACTIVE'
  AND LOWER(event) LIKE 'gc %'

UNION ALL

SELECT
    'HIGH LATENCY GC EVENTS',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'CHECK'
    END
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
  AND total_waits > 0
  AND (time_waited / NULLIF(total_waits, 0) * 10) >= 10;


PROMPT
PROMPT ============================================================================
PROMPT 30. RAC CACHE FUSION DBA CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] Review GC CURRENT waits
PROMPT [ ] Review GC CR waits
PROMPT [ ] Compare GC activity across RAC instances
PROMPT [ ] Identify instances with persistent GC waiters
PROMPT [ ] Identify SQL associated with current GC waits
PROMPT [ ] Check service-level GC wait distribution
PROMPT [ ] Check machine/client distribution
PROMPT [ ] Review GC wait latency
PROMPT [ ] Correlate high GC waits with interconnect/network health
PROMPT [ ] Check for hot blocks / application contention
PROMPT [ ] Review SQL access patterns across RAC instances
PROMPT [ ] Review object/block contention when required
PROMPT [ ] Use ASH/AWR for historical analysis when licensed
PROMPT
PROMPT ============================================================================
PROMPT IMPORTANT
PROMPT ============================================================================
PROMPT GC waits are normal RAC activity and do NOT automatically indicate
PROMPT an interconnect or RAC performance problem.
PROMPT
PROMPT GV$SYSTEM_EVENT values are cumulative since instance startup.
PROMPT GV$SESSION waits are point-in-time observations.
PROMPT
PROMPT The 10 ms latency condition used in this toolkit is an investigation
PROMPT trigger, not an Oracle failure threshold.
PROMPT
PROMPT High GC activity can be caused by normal workload, hot blocks,
PROMPT SQL access patterns, service placement, or application design.
PROMPT
PROMPT Use ASH/AWR, SQL plans, object/block analysis and OS/interconnect
PROMPT diagnostics to establish the actual cause.
PROMPT
PROMPT This script is READ-ONLY.
PROMPT ============================================================================


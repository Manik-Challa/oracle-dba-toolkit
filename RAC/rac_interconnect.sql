-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_interconnect.sql
-- Purpose: Monitor Oracle RAC private interconnect health
-- Scope  : Interconnect configuration, RAC traffic,
--          global cache waits, GCS/GES activity and latency
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN inst_id             FORMAT 999
COLUMN instance_name       FORMAT A20
COLUMN host_name           FORMAT A35
COLUMN parameter_name      FORMAT A30
COLUMN value               FORMAT A80
COLUMN name                FORMAT A45
COLUMN network             FORMAT A20
COLUMN ip_address          FORMAT A20
COLUMN interface           FORMAT A20
COLUMN event               FORMAT A50
COLUMN wait_class          FORMAT A20
COLUMN total_waits         FORMAT 999999999999
COLUMN time_waited_sec     FORMAT 999999999.99
COLUMN avg_wait_ms         FORMAT 999999.99
COLUMN stat_name           FORMAT A55
COLUMN value_num           FORMAT 999999999999999
COLUMN metric_name         FORMAT A50
COLUMN metric_value        FORMAT 999999999999999

PROMPT
PROMPT ============================================================
PROMPT RAC INTERCONNECT MONITORING
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
PROMPT 3. RAC INTERCONNECT PARAMETERS
PROMPT ============================================================

SELECT
    inst_id,
    name AS parameter_name,
    value
FROM gv$parameter
WHERE name IN (
    'cluster_interconnects',
    'cluster_database',
    'cluster_database_instances',
    'instance_name',
    'local_listener',
    'remote_listener'
)
ORDER BY
    name,
    inst_id;


PROMPT
PROMPT ============================================================
PROMPT 4. CLUSTER INTERCONNECT CONFIGURATION
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    value AS cluster_interconnects
FROM gv$parameter p
JOIN gv$instance i
    ON i.inst_id = p.inst_id
WHERE p.name = 'cluster_interconnects'
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 5. RAC INTERCONNECT-RELATED SYSTEM STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value AS value_num
FROM gv$sysstat
WHERE LOWER(name) LIKE '%interconnect%'
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 6. GLOBAL CACHE / GCS STATISTICS
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
PROMPT 7. GLOBAL ENQUEUE / GES STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value AS value_num
FROM gv$sysstat
WHERE LOWER(name) LIKE '%global enqueue%'
   OR LOWER(name) LIKE '%ges%'
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 8. RAC CACHE FUSION WAIT EVENTS
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
PROMPT 9. IMPORTANT GLOBAL CACHE EVENTS
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
PROMPT 10. GLOBAL CACHE EVENTS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    SUM(total_waits) AS total_gc_waits,
    ROUND(SUM(time_waited) / 100, 2) AS total_wait_time_sec,
    ROUND(
        (SUM(time_waited) / NULLIF(SUM(total_waits), 0)) * 10,
        2
    ) AS avg_gc_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 11. CURRENT RAC INTERCONNECT-RELATED WAITERS
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
    machine,
    program,
    service_name
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND (
        LOWER(event) LIKE 'gc %'
        OR LOWER(event) LIKE '%global cache%'
        OR LOWER(event) LIKE '%global enqueue%'
      )
ORDER BY
    seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 12. CURRENT GC WAIT SUMMARY
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
PROMPT 13. RAC GCS/GES STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value AS value_num
FROM gv$sysstat
WHERE LOWER(name) LIKE '%gcs%'
   OR LOWER(name) LIKE '%ges%'
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 14. RAC CACHE FUSION RELATED SQL
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        s.inst_id,
        s.sid,
        s.serial# AS serial,
        s.username,
        s.sql_id,
        s.event,
        s.seconds_in_wait,
        s.machine,
        s.program,
        s.service_name
    FROM gv$session s
    WHERE s.username IS NOT NULL
      AND s.status = 'ACTIVE'
      AND LOWER(s.event) LIKE 'gc %'
    ORDER BY s.seconds_in_wait DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 15. TOP SQL ASSOCIATED WITH GC WAITING SESSIONS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sql_id,
    COUNT(*) AS waiting_sessions,
    MAX(s.seconds_in_wait) AS max_wait_sec,
    MIN(s.username) AS sample_user,
    MIN(s.event) AS sample_event
FROM gv$session s
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND LOWER(s.event) LIKE 'gc %'
  AND s.sql_id IS NOT NULL
GROUP BY
    s.inst_id,
    s.sql_id
ORDER BY
    waiting_sessions DESC,
    max_wait_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 16. RAC INTERCONNECT BY INSTANCE
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
    ) AS gc_wait_sessions,
    SUM(
        CASE
            WHEN LOWER(s.event) LIKE '%global enqueue%'
            THEN 1
            ELSE 0
        END
    ) AS ges_wait_sessions
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
PROMPT 17. GLOBAL CACHE WAIT CLASS SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    wait_class,
    COUNT(*) AS waiting_sessions
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc %'
GROUP BY
    inst_id,
    wait_class
ORDER BY
    waiting_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 18. RAC INTERCONNECT HEALTH SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    SUM(
        CASE
            WHEN LOWER(event) LIKE 'gc %'
            THEN total_waits
            ELSE 0
        END
    ) AS gc_waits,
    ROUND(
        SUM(
            CASE
                WHEN LOWER(event) LIKE 'gc %'
                THEN time_waited
                ELSE 0
            END
        ) / 100,
        2
    ) AS gc_wait_time_sec,
    ROUND(
        (
            SUM(
                CASE
                    WHEN LOWER(event) LIKE 'gc %'
                    THEN time_waited
                    ELSE 0
                END
            )
            /
            NULLIF(
                SUM(
                    CASE
                        WHEN LOWER(event) LIKE 'gc %'
                        THEN total_waits
                        ELSE 0
                    END
                ),
                0
            )
        ) * 10,
        2
    ) AS avg_gc_wait_ms
FROM gv$system_event
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 19. HIGH GC LATENCY EVENTS
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
PROMPT 20. INTERCONNECT-RELATED WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec
FROM gv$system_event
WHERE LOWER(event) LIKE '%interconnect%'
   OR LOWER(event) LIKE '%global cache%'
   OR LOWER(event) LIKE '%global enqueue%'
   OR LOWER(event) LIKE 'gc %'
ORDER BY
    time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 21. CURRENT GLOBAL CACHE WAITERS BY INSTANCE
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
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 22. RAC INSTANCE COMPARISON
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
            WHEN s.blocking_session IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS blocked_sessions
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
PROMPT 23. QUICK RAC INTERCONNECT CHECK
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
WHERE LOWER(event) LIKE 'gc %'
ORDER BY
    time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT 1. Verify the RAC private interconnect configuration.
PROMPT 2. Check cluster_interconnects for unexpected values.
PROMPT 3. Review GC/GCS/GES wait activity by instance.
PROMPT 4. Check current sessions waiting on GC events.
PROMPT 5. Identify SQL associated with significant GC waits.
PROMPT 6. Compare GC activity and latency across instances.
PROMPT 7. Check for unusual concentration on one RAC instance.
PROMPT 8. Correlate GC waits with application/service distribution.
PROMPT 9. Review network/interface errors at the OS level.
PROMPT 10. Check MTU, packet loss and interface health separately.
PROMPT 11. Validate private network redundancy and bonding/HA.
PROMPT 12. For Exadata, correlate with network and cell metrics.
PROMPT
PROMPT IMPORTANT:
PROMPT - GV$ statistics are generally cumulative since instance startup.
PROMPT - GC waits do not automatically prove an interconnect failure.
PROMPT - Cache Fusion traffic can be caused by application workload,
PROMPT   SQL access patterns and data affinity.
PROMPT - High GC latency should be correlated with OS/network metrics.
PROMPT - Database views cannot fully validate physical network health.
PROMPT - Use OS tools and Clusterware utilities for infrastructure
PROMPT   validation.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================


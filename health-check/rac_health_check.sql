-- ============================================================
-- RAC HEALTH CHECK
-- File: rac_health_check.sql
--
-- Purpose:
--   Complete read-only Oracle RAC health check.
--
-- Covers:
--   1. RAC instance status
--   2. Database role / open mode
--   3. Instance uptime
--   4. Session distribution
--   5. Active / blocked sessions
--   6. Services
--   7. System wait events
--   8. RAC Global Cache waits
--   9. Blocking sessions
--  10. CPU / DB Time
--  11. Memory / SGA / PGA
--  12. Tablespace usage
--  13. TEMP usage
--  14. UNDO usage
--  15. Redo threads
--  16. Archive destination status
--  17. ASM diskgroup health
--  18. ASM disk health
--  19. Resource limits
--  20. Invalid objects
--  21. Alert log errors
--  22. RAC health summary
--
-- Important:
--   * All checks are read-only.
--   * Thresholds are investigation triggers, not Oracle
--     failure thresholds.
--   * GC waits are normal RAC activity.
--   * Cumulative statistics require interval sampling for
--     accurate rates.
--
-- Requirements:
--   SELECT privileges on relevant V$ / GV$ / DBA views.
--
-- ============================================================


SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN inst_id          FORMAT 999
COLUMN instance_name    FORMAT A20
COLUMN host_name        FORMAT A30
COLUMN status            FORMAT A12
COLUMN database_role     FORMAT A20
COLUMN open_mode        FORMAT A20
COLUMN active_state     FORMAT A15

COLUMN username         FORMAT A20
COLUMN service_name     FORMAT A25
COLUMN machine          FORMAT A30
COLUMN program           FORMAT A35
COLUMN event             FORMAT A45
COLUMN wait_class        FORMAT A20

COLUMN tablespace_name   FORMAT A30
COLUMN total_gb          FORMAT 999,999.99
COLUMN used_gb           FORMAT 999,999.99
COLUMN free_gb           FORMAT 999,999.99
COLUMN used_pct          FORMAT 990.99

COLUMN name              FORMAT A35
COLUMN value             FORMAT 999,999,999,999,999

COLUMN sql_id            FORMAT A15
COLUMN plan_hash_value   FORMAT 9999999999

COLUMN diskgroup_name    FORMAT A25
COLUMN state             FORMAT A15
COLUMN type              FORMAT A12
COLUMN redundancy        FORMAT A15

COLUMN thread#           FORMAT 999
COLUMN sequence#         FORMAT 999999999

PROMPT
PROMPT ============================================================
PROMPT                ORACLE RAC HEALTH CHECK
PROMPT ============================================================
PROMPT


-- ============================================================
-- 1. DATABASE OVERVIEW
-- ============================================================

PROMPT ============================================================
PROMPT 1. DATABASE OVERVIEW
PROMPT ============================================================

SELECT
    name,
    dbid,
    database_role,
    open_mode,
    log_mode,
    force_logging,
    flashback_on
FROM v$database;


-- ============================================================
-- 2. RAC INSTANCE STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. RAC INSTANCE STATUS
PROMPT ============================================================

SELECT
    inst_id,
    instance_number,
    instance_name,
    host_name,
    status,
    active_state,
    startup_time
FROM gv$instance
ORDER BY inst_id;


-- ============================================================
-- 3. RAC INSTANCE UPTIME
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. RAC INSTANCE UPTIME
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    ROUND(
        (SYSDATE - startup_time),
        2
    ) AS uptime_days,
    startup_time
FROM gv$instance
ORDER BY inst_id;


-- ============================================================
-- 4. SESSION DISTRIBUTION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. SESSION DISTRIBUTION
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS total_sessions,
    SUM(
        CASE
            WHEN status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_sessions,
    SUM(
        CASE
            WHEN status = 'INACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS inactive_sessions
FROM gv$session
GROUP BY inst_id
ORDER BY inst_id;


-- ============================================================
-- 5. ACTIVE SESSIONS BY INSTANCE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. ACTIVE SESSIONS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS active_sessions
FROM gv$session
WHERE status = 'ACTIVE'
  AND type = 'USER'
GROUP BY inst_id
ORDER BY active_sessions DESC;


-- ============================================================
-- 6. BLOCKED SESSIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. BLOCKED SESSIONS
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS blocked_sessions
FROM gv$session
WHERE blocking_session IS NOT NULL
GROUP BY inst_id
ORDER BY blocked_sessions DESC;


-- ============================================================
-- 7. CURRENT BLOCKING DETAILS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. CURRENT BLOCKING DETAILS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial#,
    s.username,
    s.event,
    s.seconds_in_wait,
    s.blocking_instance,
    s.blocking_session,
    s.sql_id,
    s.service_name,
    s.machine
FROM gv$session s
WHERE s.blocking_session IS NOT NULL
ORDER BY s.seconds_in_wait DESC;


-- ============================================================
-- 8. SERVICES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. RAC SERVICE DISTRIBUTION
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS session_count,
    SUM(
        CASE
            WHEN status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_sessions
FROM gv$session
WHERE type = 'USER'
GROUP BY
    inst_id,
    service_name
ORDER BY service_name, inst_id;


-- ============================================================
-- 9. TOP SYSTEM WAIT EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. TOP SYSTEM WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE wait_class <> 'Idle'
  AND total_waits > 0
ORDER BY time_waited DESC
FETCH FIRST 20 ROWS ONLY;


-- ============================================================
-- 10. RAC GLOBAL CACHE WAITS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. RAC GLOBAL CACHE WAITS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE event LIKE 'gc %'
  AND total_waits > 0
ORDER BY avg_wait_ms DESC;


-- ============================================================
-- 11. CURRENT RAC GC WAITERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. CURRENT RAC GC WAITERS
PROMPT ============================================================

SELECT
    inst_id,
    sid,
    serial#,
    username,
    event,
    seconds_in_wait,
    sql_id,
    service_name,
    machine
FROM gv$session
WHERE wait_class <> 'Idle'
  AND event LIKE 'gc %'
ORDER BY seconds_in_wait DESC;


-- ============================================================
-- 12. CPU / DB TIME BY INSTANCE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. DB CPU / DB TIME BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    ROUND(
        MAX(
            CASE
                WHEN stat_name = 'DB CPU'
                THEN value
            END
        ) / 1000000,
        2
    ) AS db_cpu_sec,
    ROUND(
        MAX(
            CASE
                WHEN stat_name = 'DB time'
                THEN value
            END
        ) / 1000000,
        2
    ) AS db_time_sec
FROM gv$sys_time_model
WHERE stat_name IN ('DB CPU', 'DB time')
GROUP BY inst_id
ORDER BY inst_id;


-- ============================================================
-- 13. MEMORY - SGA
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. SGA SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    name,
    ROUND(value / 1024 / 1024, 2) AS value_mb
FROM gv$sga
WHERE name IN (
    'Total SGA',
    'Maximum SGA Size',
    'Fixed Size',
    'Variable Size',
    'Database Buffers',
    'Redo Buffers'
)
ORDER BY inst_id, name;


-- ============================================================
-- 14. PGA SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. PGA SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    name,
    ROUND(value / 1024 / 1024, 2) AS value_mb
FROM gv$pgastat
WHERE name IN (
    'total PGA allocated',
    'maximum PGA allocated',
    'total PGA inuse',
    'over allocation count',
    'cache hit percentage'
)
ORDER BY inst_id, name;


-- ============================================================
-- 15. TABLESPACE USAGE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. TABLESPACE USAGE
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(
        SUM(df.bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_gb,
    ROUND(
        (
            SUM(df.bytes)
            - NVL(
                (
                    SELECT SUM(fs.bytes)
                    FROM dba_free_space fs
                    WHERE fs.tablespace_name =
                          df.tablespace_name
                ),
                0
            )
        ) / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(
        (
            SUM(df.bytes)
            - NVL(
                (
                    SELECT SUM(fs.bytes)
                    FROM dba_free_space fs
                    WHERE fs.tablespace_name =
                          df.tablespace_name
                ),
                0
            )
        )
        / NULLIF(SUM(df.bytes), 0)
        * 100,
        2
    ) AS used_pct
FROM dba_data_files df
GROUP BY df.tablespace_name
ORDER BY used_pct DESC;


-- ============================================================
-- 16. TEMP USAGE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. TEMP TABLESPACE USAGE
PROMPT ============================================================

SELECT
    tablespace_name,
    ROUND(
        SUM(bytes_used) / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(
        SUM(bytes_free) / 1024 / 1024 / 1024,
        2
    ) AS free_gb,
    ROUND(
        SUM(bytes_used)
        / NULLIF(
            SUM(bytes_used + bytes_free),
            0
        ) * 100,
        2
    ) AS used_pct
FROM gv$temp_space_header
GROUP BY tablespace_name
ORDER BY used_pct DESC;


-- ============================================================
-- 17. UNDO USAGE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. UNDO TABLESPACE USAGE
PROMPT ============================================================

SELECT
    tablespace_name,
    status,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM dba_undo_extents
GROUP BY
    tablespace_name,
    status
ORDER BY
    tablespace_name,
    status;


-- ============================================================
-- 18. LONG-RUNNING TRANSACTIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. LONG-RUNNING TRANSACTIONS
PROMPT ============================================================

SELECT
    t.inst_id,
    t.start_time,
    t.used_ublk,
    t.used_urec,
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    s.event
FROM gv$transaction t
LEFT JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND s.taddr = t.addr
ORDER BY t.used_ublk DESC
FETCH FIRST 20 ROWS ONLY;


-- ============================================================
-- 19. REDO THREAD STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 19. REDO THREAD STATUS
PROMPT ============================================================

SELECT
    thread#,
    status,
    enabled,
    instance
FROM v$thread
ORDER BY thread#;


-- ============================================================
-- 20. CURRENT REDO LOGS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 20. CURRENT REDO LOGS
PROMPT ============================================================

SELECT
    l.thread#,
    l.group#,
    l.sequence#,
    l.status,
    l.archived,
    l.bytes / 1024 / 1024 AS size_mb,
    l.first_time
FROM v$log l
ORDER BY l.thread#, l.group#;


-- ============================================================
-- 21. ARCHIVE DESTINATION STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 21. ARCHIVE DESTINATION STATUS
PROMPT ============================================================

SELECT
    dest_id,
    status,
    type,
    destination,
    error,
    target,
    valid_now
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;


-- ============================================================
-- 22. ASM DISKGROUP HEALTH
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 22. ASM DISKGROUP HEALTH
PROMPT ============================================================

SELECT
    name AS diskgroup_name,
    state,
    type,
    ROUND(
        total_mb / 1024,
        2
    ) AS total_gb,
    ROUND(
        free_mb / 1024,
        2
    ) AS free_gb,
    ROUND(
        (total_mb - free_mb)
        / NULLIF(total_mb, 0)
        * 100,
        2
    ) AS used_pct,
    ROUND(
        usable_file_mb / 1024,
        2
    ) AS usable_file_gb
FROM v$asm_diskgroup
ORDER BY used_pct DESC;


-- ============================================================
-- 23. ASM DISKS NOT NORMAL
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 23. ASM DISKS NOT NORMAL
PROMPT ============================================================

SELECT
    group_number,
    disk_number,
    name,
    path,
    header_status,
    mode_status,
    state,
    mount_status,
    failgroup
FROM v$asm_disk
WHERE mode_status <> 'ONLINE'
   OR state <> 'NORMAL'
   OR header_status NOT IN (
        'MEMBER',
        'FORMER',
        'CANDIDATE'
   )
ORDER BY group_number, disk_number;


-- ============================================================
-- 24. ASM REBALANCE OPERATIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 24. ASM REBALANCE OPERATIONS
PROMPT ============================================================

SELECT
    inst_id,
    group_number,
    operation,
    state,
    power,
    sofar,
    est_work,
    est_rate,
    est_minutes
FROM gv$asm_operation
ORDER BY inst_id, group_number;


-- ============================================================
-- 25. RESOURCE LIMITS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 25. RESOURCE LIMITS
PROMPT ============================================================

SELECT
    inst_id,
    resource_name,
    current_utilization,
    max_utilization,
    limit_value
FROM gv$resource_limit
WHERE resource_name IN (
    'processes',
    'sessions',
    'transactions'
)
ORDER BY inst_id, resource_name;


-- ============================================================
-- 26. INVALID OBJECTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 26. INVALID OBJECTS
PROMPT ============================================================

SELECT
    owner,
    object_type,
    COUNT(*) AS invalid_count
FROM dba_objects
WHERE status <> 'VALID'
GROUP BY
    owner,
    object_type
ORDER BY invalid_count DESC;


-- ============================================================
-- 27. RECENT ALERT / DATABASE ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 27. RECENT DATABASE ALERT ERRORS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_type,
    message_level,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >
      SYSTIMESTAMP - INTERVAL '1' DAY
  AND (
        message_type = 2
        OR message_level <= 8
      )
ORDER BY originating_timestamp DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================
-- 28. CURRENT NON-IDLE WAITERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 28. CURRENT NON-IDLE WAITERS
PROMPT ============================================================

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
    service_name
FROM gv$session
WHERE wait_class <> 'Idle'
ORDER BY seconds_in_wait DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================
-- 29. TOP CPU SESSIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 29. TOP CPU SESSIONS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial#,
    s.username,
    ROUND(
        st.value / 100,
        2
    ) AS cpu_seconds,
    s.sql_id,
    s.service_name,
    s.machine
FROM gv$session s
JOIN gv$sesstat st
    ON st.inst_id = s.inst_id
   AND st.sid = s.sid
JOIN gv$statname sn
    ON sn.inst_id = st.inst_id
   AND sn.statistic# = st.statistic#
WHERE sn.name = 'CPU used by this session'
ORDER BY st.value DESC
FETCH FIRST 20 ROWS ONLY;


-- ============================================================
-- 30. TOP SQL BY CPU
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 30. TOP SQL BY CPU
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    buffer_gets,
    disk_reads,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM gv$sql
WHERE executions > 0
ORDER BY cpu_time DESC
FETCH FIRST 20 ROWS ONLY;


-- ============================================================
-- 31. RAC CACHE FUSION SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 31. RAC CACHE FUSION SUMMARY
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
    SUM(
        CASE
            WHEN event LIKE 'gc %'
            THEN total_waits
            ELSE 0
        END
    ) AS total_gc_waits
FROM gv$system_event
GROUP BY inst_id
ORDER BY inst_id;


-- ============================================================
-- 32. TOP GLOBAL CACHE WAIT EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 32. TOP GLOBAL CACHE WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS wait_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE event LIKE 'gc %'
  AND total_waits > 0
ORDER BY avg_wait_ms DESC
FETCH FIRST 15 ROWS ONLY;


-- ============================================================
-- 33. RESOURCE MANAGER PRESSURE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 33. RESOURCE MANAGER WAITS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS wait_sec
FROM gv$system_event
WHERE event LIKE 'resmgr:%'
ORDER BY time_waited DESC;


-- ============================================================
-- 34. RAC INSTANCE HEALTH SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 34. RAC INSTANCE HEALTH SUMMARY
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status,
    COUNT(s.sid) AS total_sessions,
    SUM(
        CASE
            WHEN s.status = 'ACTIVE'
             AND s.type = 'USER'
            THEN 1
            ELSE 0
        END
    ) AS active_user_sessions,
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
GROUP BY
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status
ORDER BY i.inst_id;


-- ============================================================
-- 35. RAC HEALTH INDICATORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 35. RAC HEALTH INDICATORS
PROMPT ============================================================

SELECT
    'BLOCKED SESSIONS' AS check_name,
    COUNT(*) AS value,
    CASE
        WHEN COUNT(*) = 0
            THEN 'OK'
        WHEN COUNT(*) < 10
            THEN 'INVESTIGATE'
        ELSE 'HIGH'
    END AS status
FROM gv$session
WHERE blocking_session IS NOT NULL

UNION ALL

SELECT
    'INVALID OBJECTS',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0
            THEN 'OK'
        ELSE 'INVESTIGATE'
    END
FROM dba_objects
WHERE status <> 'VALID'

UNION ALL

SELECT
    'CURRENT GC WAITERS',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0
            THEN 'OK'
        WHEN COUNT(*) < 10
            THEN 'INVESTIGATE'
        ELSE 'HIGH'
    END
FROM gv$session
WHERE wait_class <> 'Idle'
  AND event LIKE 'gc %'

UNION ALL

SELECT
    'ASM DISKS NOT NORMAL',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0
            THEN 'OK'
        ELSE 'INVESTIGATE'
    END
FROM v$asm_disk
WHERE mode_status <> 'ONLINE'
   OR state <> 'NORMAL';


-- ============================================================
-- 36. RAC HEALTH SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 36. RAC HEALTH SUMMARY
PROMPT ============================================================

SELECT
    (SELECT COUNT(*)
     FROM gv$instance
     WHERE status = 'OPEN') AS open_instances,

    (SELECT COUNT(*)
     FROM gv$session
     WHERE blocking_session IS NOT NULL)
        AS blocked_sessions,

    (SELECT COUNT(*)
     FROM gv$session
     WHERE wait_class <> 'Idle'
       AND event LIKE 'gc %')
        AS current_gc_waiters,

    (SELECT COUNT(*)
     FROM dba_objects
     WHERE status <> 'VALID')
        AS invalid_objects,

    (SELECT COUNT(*)
     FROM v$asm_disk
     WHERE mode_status <> 'ONLINE'
        OR state <> 'NORMAL')
        AS abnormal_asm_disks
FROM dual;


-- ============================================================
-- 37. DBA QUICK CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT ============================================================
PROMPT                 RAC DBA QUICK CHECK
PROMPT ============================================================
PROMPT
PROMPT Check 1  : All RAC instances OPEN?
PROMPT Check 2  : Any blocked sessions?
PROMPT Check 3  : Any abnormal ASM disks?
PROMPT Check 4  : Any ASM diskgroup low on usable space?
PROMPT Check 5  : Any high GC latency?
PROMPT Check 6  : Any significant current GC waiters?
PROMPT Check 7  : Any excessive TEMP usage?
PROMPT Check 8  : Any long-running UNDO transactions?
PROMPT Check 9  : Any archive destination errors?
PROMPT Check 10 : Any resource limit pressure?
PROMPT Check 11 : Any invalid objects?
PROMPT Check 12 : Any recent critical alert messages?
PROMPT Check 13 : Is workload balanced across instances?
PROMPT Check 14 : Are services distributed as expected?
PROMPT Check 15 : Review OS / Clusterware health separately.
PROMPT


-- ============================================================
-- PRODUCTION SAFETY
-- ============================================================

PROMPT ============================================================
PROMPT PRODUCTION SAFETY
PROMPT ============================================================
PROMPT This script is READ-ONLY.
PROMPT
PROMPT Do NOT kill sessions, offline ASM disks, drop disks,
PROMPT modify services, or change RAC configuration based only
PROMPT on this report.
PROMPT
PROMPT For cluster-level verification use:
PROMPT
PROMPT   crsctl status resource -t
PROMPT   srvctl status database
PROMPT   srvctl status service
PROMPT   srvctl status asm
PROMPT   srvctl status listener
PROMPT   srvctl status scan
PROMPT   srvctl status scan_listener
PROMPT
PROMPT ============================================================
PROMPT END OF RAC HEALTH CHECK
PROMPT ============================================================


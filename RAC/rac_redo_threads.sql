-- ============================================================================
-- RAC REDO THREAD MONITORING
-- File    : rac_redo_threads.sql
-- Purpose : Monitor RAC redo threads, instances, redo logs and log switches
-- Author  : Manik Challa
-- Usage   : Run as SYS or a user with appropriate dictionary privileges
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN thread#              FORMAT 999
COLUMN instance_name        FORMAT A20
COLUMN thread_status        FORMAT A12
COLUMN enabled              FORMAT A10
COLUMN instance_status      FORMAT A12
COLUMN open_mode            FORMAT A20
COLUMN log_status           FORMAT A12
COLUMN member               FORMAT A80
COLUMN group#               FORMAT 9999
COLUMN sequence#            FORMAT 999999999
COLUMN archived             FORMAT A10
COLUMN first_time           FORMAT A20
COLUMN next_time            FORMAT A20
COLUMN bytes_mb             FORMAT 999999999
COLUMN redo_mb              FORMAT 999999999
COLUMN switches             FORMAT 999999
COLUMN minutes              FORMAT 999999
COLUMN switches_per_hour    FORMAT 999999.99

PROMPT
PROMPT ============================================================================
PROMPT RAC REDO THREAD MONITORING
PROMPT ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT 1. DATABASE AND INSTANCE OVERVIEW
PROMPT ============================================================================

SELECT
    i.inst_id,
    i.instance_number,
    i.instance_name,
    i.thread#,
    i.status AS instance_status,
    i.parallel,
    d.open_mode,
    d.database_role
FROM gv$instance i
CROSS JOIN v$database d
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 2. REDO THREAD STATUS
PROMPT ============================================================================

SELECT
    t.thread#,
    t.instance,
    t.status AS thread_status,
    t.enabled,
    t.groups
FROM v$thread t
ORDER BY t.thread#;


PROMPT
PROMPT ============================================================================
PROMPT 3. THREAD TO RAC INSTANCE MAPPING
PROMPT ============================================================================

SELECT
    i.inst_id,
    i.instance_number,
    i.instance_name,
    i.thread#,
    t.status AS thread_status,
    t.enabled
FROM gv$instance i
LEFT JOIN v$thread t
       ON t.thread# = i.thread#
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 4. THREAD REDO LOG GROUPS
PROMPT ============================================================================

SELECT
    l.thread#,
    l.group#,
    l.sequence#,
    ROUND(l.bytes / 1024 / 1024, 2) AS bytes_mb,
    l.members,
    l.status,
    l.archived,
    l.first_time,
    l.next_time
FROM gv$log l
ORDER BY l.thread#, l.group#;


PROMPT
PROMPT ============================================================================
PROMPT 5. REDO LOG MEMBER DETAILS
PROMPT ============================================================================

SELECT
    l.thread#,
    l.group#,
    l.sequence#,
    l.status AS log_status,
    lf.member
FROM gv$log l
JOIN gv$logfile lf
  ON lf.group# = l.group#
 AND lf.inst_id = l.inst_id
ORDER BY l.thread#, l.group#, lf.member;


PROMPT
PROMPT ============================================================================
PROMPT 6. CURRENT REDO LOG PER THREAD
PROMPT ============================================================================

SELECT
    thread#,
    group#,
    sequence#,
    ROUND(bytes / 1024 / 1024, 2) AS bytes_mb,
    status,
    archived,
    first_time
FROM gv$log
WHERE status = 'CURRENT'
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 7. REDO LOG STATUS SUMMARY
PROMPT ============================================================================

SELECT
    thread#,
    status,
    COUNT(*) AS log_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS total_gb
FROM gv$log
GROUP BY thread#, status
ORDER BY thread#, status;


PROMPT
PROMPT ============================================================================
PROMPT 8. LOG GROUP COUNT PER THREAD
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS log_groups,
    COUNT(CASE WHEN status = 'CURRENT' THEN 1 END) AS current_groups,
    COUNT(CASE WHEN status = 'ACTIVE' THEN 1 END) AS active_groups,
    COUNT(CASE WHEN status = 'INACTIVE' THEN 1 END) AS inactive_groups,
    COUNT(CASE WHEN status = 'CLEARING' THEN 1 END) AS clearing_groups,
    COUNT(CASE WHEN status = 'CLEARING_CURRENT' THEN 1 END)
        AS clearing_current_groups
FROM gv$log
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 9. REDO GENERATION BY RAC INSTANCE
PROMPT ============================================================================

SELECT
    s.inst_id,
    i.instance_name,
    ROUND(
        SUM(
            CASE
                WHEN n.name = 'redo size'
                THEN s.value
                ELSE 0
            END
        ) / 1024 / 1024,
        2
    ) AS redo_mb
FROM gv$sysstat s
JOIN gv$statname n
  ON n.inst_id = s.inst_id
 AND n.statistic# = s.statistic#
JOIN gv$instance i
  ON i.inst_id = s.inst_id
WHERE n.name = 'redo size'
GROUP BY s.inst_id, i.instance_name
ORDER BY redo_mb DESC;


PROMPT
PROMPT ============================================================================
PROMPT 10. REDO GENERATION BY THREAD
PROMPT ============================================================================

SELECT
    i.thread#,
    i.instance_name,
    ROUND(
        MAX(CASE
                WHEN n.name = 'redo size'
                THEN s.value
            END) / 1024 / 1024,
        2
    ) AS redo_mb
FROM gv$instance i
JOIN gv$sysstat s
  ON s.inst_id = i.inst_id
JOIN gv$statname n
  ON n.inst_id = s.inst_id
 AND n.statistic# = s.statistic#
WHERE n.name = 'redo size'
GROUP BY i.thread#, i.instance_name
ORDER BY i.thread#;


PROMPT
PROMPT ============================================================================
PROMPT 11. REDO LOG SWITCH INFORMATION
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS log_switch_records,
    MIN(first_time) AS first_log_time,
    MAX(first_time) AS latest_log_time
FROM gv$log_history
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 12. RECENT REDO LOG SWITCHES
PROMPT ============================================================================

SELECT *
FROM (
    SELECT
        thread#,
        sequence#,
        first_time
    FROM gv$log_history
    ORDER BY first_time DESC
)
WHERE ROWNUM <= 30;


PROMPT
PROMPT ============================================================================
PROMPT 13. LOG SWITCHES IN LAST 24 HOURS
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS switches_last_24h
FROM gv$log_history
WHERE first_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 14. LOG SWITCHES BY HOUR - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    thread#,
    TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS log_hour,
    COUNT(*) AS switches
FROM gv$log_history
WHERE first_time >= SYSDATE - 1
GROUP BY
    thread#,
    TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY
    log_hour,
    thread#;


PROMPT
PROMPT ============================================================================
PROMPT 15. AVERAGE LOG SWITCH INTERVAL BY THREAD
PROMPT ============================================================================

SELECT
    thread#,
    ROUND(
        (MAX(first_time) - MIN(first_time)) * 24 * 60
        / NULLIF(COUNT(*) - 1, 0),
        2
    ) AS avg_minutes_between_switches,
    COUNT(*) AS switches
FROM gv$log_history
WHERE first_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 16. REDO LOGS NOT IN INACTIVE STATUS
PROMPT ============================================================================

SELECT
    thread#,
    group#,
    sequence#,
    status,
    archived,
    ROUND(bytes / 1024 / 1024, 2) AS bytes_mb
FROM gv$log
WHERE status <> 'INACTIVE'
ORDER BY thread#, group#;


PROMPT
PROMPT ============================================================================
PROMPT 17. ACTIVE REDO LOGS
PROMPT ============================================================================

SELECT
    thread#,
    group#,
    sequence#,
    status,
    archived,
    ROUND(bytes / 1024 / 1024, 2) AS bytes_mb,
    first_time
FROM gv$log
WHERE status = 'ACTIVE'
ORDER BY thread#, group#;


PROMPT
PROMPT ============================================================================
PROMPT 18. UNARCHIVED REDO LOGS
PROMPT ============================================================================

SELECT
    thread#,
    group#,
    sequence#,
    status,
    archived,
    ROUND(bytes / 1024 / 1024, 2) AS bytes_mb
FROM gv$log
WHERE archived = 'NO'
ORDER BY thread#, group#;


PROMPT
PROMPT ============================================================================
PROMPT 19. REDO LOG MEMBER COUNT
PROMPT ============================================================================

SELECT
    l.thread#,
    l.group#,
    l.status,
    COUNT(lf.member) AS member_count
FROM gv$log l
LEFT JOIN gv$logfile lf
       ON lf.group# = l.group#
      AND lf.inst_id = l.inst_id
GROUP BY
    l.thread#,
    l.group#,
    l.status
ORDER BY
    l.thread#,
    l.group#;


PROMPT
PROMPT ============================================================================
PROMPT 20. REDO LOG GROUPS WITH SINGLE MEMBER
PROMPT ============================================================================

SELECT
    l.thread#,
    l.group#,
    l.status,
    COUNT(lf.member) AS member_count
FROM gv$log l
LEFT JOIN gv$logfile lf
       ON lf.group# = l.group#
      AND lf.inst_id = l.inst_id
GROUP BY
    l.thread#,
    l.group#,
    l.status
HAVING COUNT(lf.member) = 1
ORDER BY l.thread#, l.group#;


PROMPT
PROMPT ============================================================================
PROMPT 21. REDO LOG FILE SYSTEM DETAILS
PROMPT ============================================================================

SELECT
    l.thread#,
    l.group#,
    l.sequence#,
    l.status,
    lf.type,
    lf.member
FROM gv$log l
JOIN gv$logfile lf
  ON lf.group# = l.group#
 AND lf.inst_id = l.inst_id
ORDER BY l.thread#, l.group#;


PROMPT
PROMPT ============================================================================
PROMPT 22. REDO-RELATED WAIT EVENTS
PROMPT ============================================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN time_waited / total_waits * 10
        END,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE '%log file%'
   OR LOWER(event) LIKE '%redo%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================================
PROMPT 23. CURRENT SESSIONS WAITING FOR REDO / LOG EVENTS
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
    machine,
    program
FROM gv$session
WHERE status = 'ACTIVE'
  AND (
        LOWER(event) LIKE '%log file%'
        OR LOWER(event) LIKE '%redo%'
      )
ORDER BY seconds_in_wait DESC;


PROMPT
PROMPT ============================================================================
PROMPT 24. LOG BUFFER / REDO STATISTICS
PROMPT ============================================================================

SELECT
    inst_id,
    name,
    value
FROM gv$sysstat
WHERE name IN (
    'redo size',
    'redo entries',
    'redo buffer allocation retries',
    'redo wastage',
    'redo synch time',
    'redo synch writes'
)
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================================
PROMPT 25. REDO SYNCHRONIZATION STATISTICS
PROMPT ============================================================================

SELECT
    inst_id,
    name,
    value
FROM gv$sysstat
WHERE name IN (
    'redo synch time',
    'redo synch writes',
    'user commits',
    'user rollbacks'
)
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================================
PROMPT 26. INSTANCE REDO HEALTH SUMMARY
PROMPT ============================================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.thread#,
    i.status AS instance_status,
    t.status AS thread_status,
    t.enabled AS thread_enabled,
    (
        SELECT COUNT(*)
        FROM gv$log l
        WHERE l.inst_id = i.inst_id
          AND l.thread# = i.thread#
    ) AS log_groups,
    (
        SELECT COUNT(*)
        FROM gv$log l
        WHERE l.inst_id = i.inst_id
          AND l.thread# = i.thread#
          AND l.status = 'CURRENT'
    ) AS current_groups,
    (
        SELECT COUNT(*)
        FROM gv$log l
        WHERE l.inst_id = i.inst_id
          AND l.thread# = i.thread#
          AND l.status = 'ACTIVE'
    ) AS active_groups
FROM gv$instance i
LEFT JOIN v$thread t
       ON t.thread# = i.thread#
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 27. THREAD BALANCE CHECK
PROMPT ============================================================================

SELECT
    i.thread#,
    i.instance_name,
    COUNT(l.group#) AS log_groups,
    ROUND(SUM(l.bytes) / 1024 / 1024 / 1024, 2) AS redo_log_gb,
    COUNT(CASE WHEN l.status = 'CURRENT' THEN 1 END) AS current_groups,
    COUNT(CASE WHEN l.status = 'ACTIVE' THEN 1 END) AS active_groups,
    COUNT(CASE WHEN l.archived = 'NO' THEN 1 END) AS unarchived_groups
FROM gv$instance i
LEFT JOIN gv$log l
       ON l.thread# = i.thread#
GROUP BY
    i.thread#,
    i.instance_name
ORDER BY i.thread#;


PROMPT
PROMPT ============================================================================
PROMPT 28. REDO HEALTH CHECK
PROMPT ============================================================================

SELECT
    'THREADS' AS check_name,
    COUNT(*) AS value,
    CASE
        WHEN COUNT(*) > 0 THEN 'OK'
        ELSE 'CHECK'
    END AS status
FROM v$thread

UNION ALL

SELECT
    'CURRENT REDO LOGS',
    COUNT(*),
    CASE
        WHEN COUNT(*) > 0 THEN 'OK'
        ELSE 'CHECK'
    END
FROM gv$log
WHERE status = 'CURRENT'

UNION ALL

SELECT
    'ACTIVE REDO LOGS',
    COUNT(*),
    CASE
        WHEN COUNT(*) >= 0 THEN 'INFO'
        ELSE 'CHECK'
    END
FROM gv$log
WHERE status = 'ACTIVE'

UNION ALL

SELECT
    'UNARCHIVED REDO LOGS',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'CHECK'
    END
FROM gv$log
WHERE archived = 'NO';


PROMPT
PROMPT ============================================================================
PROMPT 29. RAC REDO DBA CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] Every RAC instance has the expected redo thread
PROMPT [ ] All expected threads are ENABLED
PROMPT [ ] Each thread has the expected number of redo groups
PROMPT [ ] Current redo log exists for every active thread
PROMPT [ ] No unexpected CLEARING/CLEARING_CURRENT logs
PROMPT [ ] Redo log members are multiplexed as designed
PROMPT [ ] No unexpected unarchived redo logs
PROMPT [ ] Log switches are not excessively frequent
PROMPT [ ] Redo-related waits are reviewed
PROMPT [ ] Redo synch waits are reviewed when commit latency is high
PROMPT [ ] Redo generation is reasonably distributed across RAC instances
PROMPT [ ] Redo logs are sized appropriately for workload
PROMPT [ ] OS/storage health is checked if redo waits are elevated
PROMPT
PROMPT ============================================================================
PROMPT IMPORTANT
PROMPT ============================================================================
PROMPT GV$ redo statistics are cumulative counters unless explicitly filtered.
PROMPT Log-switch counts are historical observations from V$LOG_HISTORY.
PROMPT High redo generation is not automatically a problem.
PROMPT Frequent log switches should be correlated with redo volume and workload.
PROMPT Redo waits should be correlated with storage, commit rate and workload.
PROMPT This script is READ-ONLY.
PROMPT ============================================================================


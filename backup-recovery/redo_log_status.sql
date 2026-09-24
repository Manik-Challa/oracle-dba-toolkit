-- ============================================================================
-- Oracle DBA Toolkit
-- Script   : redo_log_status.sql
-- Purpose  : Redo log health, status, sizing and switch monitoring
-- Author   : Manik Challa
-- Version  : 1.0
-- ============================================================================
--
-- READ-ONLY SCRIPT
--
-- Covers:
--   1. Database / instance information
--   2. Redo log group status
--   3. Redo log member details
--   4. Redo log sizing
--   5. Redo thread status
--   6. Current redo log
--   7. Redo log groups by status
--   8. Redo log switches
--   9. Redo generation
--  10. Log switch frequency
--  11. Recent log switches
--  12. Archive status
--  13. RAC thread coverage
--  14. Redo health summary
--  15. DBA investigation checklist
--
-- Notes:
--   * GV$ views are used where appropriate for RAC visibility.
--   * Redo statistics are cumulative unless a time window is explicitly used.
--   * Frequent log switches should be investigated in relation to redo volume,
--     workload and redo log size rather than using a fixed threshold alone.
--   * This script does NOT resize, add, drop or switch redo logs.
-- ============================================================================


SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

COLUMN database_name FORMAT A15
COLUMN instance_name FORMAT A15
COLUMN host_name FORMAT A30
COLUMN thread# FORMAT 999
COLUMN group# FORMAT 999
COLUMN sequence# FORMAT 999999999
COLUMN status FORMAT A12
COLUMN type FORMAT A10
COLUMN member FORMAT A80
COLUMN archived FORMAT A8
COLUMN enabled FORMAT A10
COLUMN bytes_mb FORMAT 999,999,999
COLUMN members FORMAT 999
COLUMN first_time FORMAT A20
COLUMN next_time FORMAT A20
COLUMN log_mode FORMAT A15
COLUMN force_logging FORMAT A15
COLUMN open_mode FORMAT A20
COLUMN switch_count FORMAT 999,999
COLUMN redo_mb FORMAT 999,999,999
COLUMN switches_per_hour FORMAT 999,999.99
COLUMN avg_redo_mb FORMAT 999,999,999.99
COLUMN min_time FORMAT A20
COLUMN max_time FORMAT A20
COLUMN issue FORMAT A80


PROMPT
PROMPT ============================================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ============================================================================

SELECT
    d.name AS database_name,
    d.open_mode,
    d.log_mode,
    d.force_logging,
    i.instance_name,
    i.host_name,
    i.thread#
FROM v$database d
CROSS JOIN v$instance i;


PROMPT
PROMPT ============================================================================
PROMPT 2. REDO LOG GROUP STATUS
PROMPT ============================================================================

SELECT
    l.thread#,
    l.group#,
    l.sequence#,
    l.status,
    l.archived,
    l.bytes / 1024 / 1024 AS bytes_mb,
    COUNT(lm.member) AS members
FROM v$log l
LEFT JOIN v$logfile lm
    ON l.group# = lm.group#
GROUP BY
    l.thread#,
    l.group#,
    l.sequence#,
    l.status,
    l.archived,
    l.bytes
ORDER BY
    l.thread#,
    l.group#;


PROMPT
PROMPT ============================================================================
PROMPT 3. REDO LOG MEMBER DETAILS
PROMPT ============================================================================

SELECT
    lf.group#,
    lf.thread#,
    lf.type,
    lf.status,
    lf.member
FROM v$logfile lf
ORDER BY
    lf.thread#,
    lf.group#,
    lf.member;


PROMPT
PROMPT ============================================================================
PROMPT 4. REDO LOG SIZING
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS log_groups,
    MIN(bytes) / 1024 / 1024 AS min_size_mb,
    MAX(bytes) / 1024 / 1024 AS max_size_mb,
    ROUND(AVG(bytes) / 1024 / 1024, 2) AS avg_size_mb
FROM v$log
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 5. REDO THREAD STATUS
PROMPT ============================================================================

SELECT
    thread#,
    status,
    enabled,
    groups_count,
    instance
FROM v$thread
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 6. CURRENT REDO LOG
PROMPT ============================================================================

SELECT
    thread#,
    group#,
    sequence#,
    status,
    archived,
    bytes / 1024 / 1024 AS bytes_mb
FROM v$log
WHERE status = 'CURRENT'
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 7. REDO LOG STATUS SUMMARY
PROMPT ============================================================================

SELECT
    thread#,
    status,
    COUNT(*) AS log_groups,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS total_gb
FROM v$log
GROUP BY
    thread#,
    status
ORDER BY
    thread#,
    status;


PROMPT
PROMPT ============================================================================
PROMPT 8. REDO LOG GROUPS WITH MULTIPLE MEMBERS
PROMPT ============================================================================

SELECT
    l.thread#,
    l.group#,
    l.status,
    COUNT(lf.member) AS members,
    ROUND(l.bytes / 1024 / 1024, 2) AS size_mb
FROM v$log l
JOIN v$logfile lf
    ON l.group# = lf.group#
GROUP BY
    l.thread#,
    l.group#,
    l.status,
    l.bytes
HAVING COUNT(lf.member) > 1
ORDER BY
    l.thread#,
    l.group#;


PROMPT
PROMPT ============================================================================
PROMPT 9. REDO LOG GROUPS WITH SINGLE MEMBER
PROMPT ============================================================================

SELECT
    l.thread#,
    l.group#,
    l.status,
    COUNT(lf.member) AS members,
    ROUND(l.bytes / 1024 / 1024, 2) AS size_mb
FROM v$log l
JOIN v$logfile lf
    ON l.group# = lf.group#
GROUP BY
    l.thread#,
    l.group#,
    l.status,
    l.bytes
HAVING COUNT(lf.member) = 1
ORDER BY
    l.thread#,
    l.group#;


PROMPT
PROMPT ============================================================================
PROMPT 10. REDO LOG SWITCH STATISTICS
PROMPT ============================================================================
PROMPT Note: V$LOG_HISTORY contains historical switch information.
PROMPT       Results are based on available control-file history.

SELECT
    thread#,
    COUNT(*) AS switch_count,
    MIN(first_time) AS min_time,
    MAX(first_time) AS max_time
FROM v$log_history
WHERE first_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 11. LOG SWITCHES BY HOUR - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    thread#,
    TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS switch_hour,
    COUNT(*) AS switch_count
FROM v$log_history
WHERE first_time >= SYSDATE - 1
GROUP BY
    thread#,
    TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY
    thread#,
    switch_hour;


PROMPT
PROMPT ============================================================================
PROMPT 12. LOG SWITCHES BY DAY - LAST 7 DAYS
PROMPT ============================================================================

SELECT
    thread#,
    TRUNC(first_time) AS switch_date,
    COUNT(*) AS switch_count
FROM v$log_history
WHERE first_time >= SYSDATE - 7
GROUP BY
    thread#,
    TRUNC(first_time)
ORDER BY
    thread#,
    switch_date;


PROMPT
PROMPT ============================================================================
PROMPT 13. RECENT REDO LOG SWITCHES
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    first_time,
    first_change#,
    next_change#
FROM v$log_history
WHERE first_time >= SYSDATE - 1
ORDER BY
    thread#,
    first_time DESC;


PROMPT
PROMPT ============================================================================
PROMPT 14. ARCHIVED REDO STATUS
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS archive_records,
    SUM(CASE WHEN archived = 'YES' THEN 1 ELSE 0 END) AS archived_yes,
    SUM(CASE WHEN archived = 'NO' THEN 1 ELSE 0 END) AS archived_no
FROM v$log
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 15. REDO GENERATION - INSTANCE STATISTICS
PROMPT ============================================================================
PROMPT Note: V$SYSSTAT values are cumulative since instance startup.

SELECT
    inst_id,
    instance_name,
    ROUND(
        MAX(CASE WHEN name = 'redo size' THEN value END)
        / 1024 / 1024,
        2
    ) AS redo_generated_mb,
    MAX(CASE WHEN name = 'redo entries' THEN value END) AS redo_entries,
    MAX(CASE WHEN name = 'redo writes' THEN value END) AS redo_writes
FROM gv$sysstat s
JOIN gv$instance i
    ON s.inst_id = i.inst_id
WHERE s.name IN
    ('redo size', 'redo entries', 'redo writes')
GROUP BY
    inst_id,
    instance_name
ORDER BY
    inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 16. REDO GENERATION - DATABASE STATISTICS
PROMPT ============================================================================
PROMPT Note: Values are cumulative since instance startup.

SELECT
    name,
    value
FROM v$sysstat
WHERE name IN
    (
        'redo size',
        'redo entries',
        'redo writes',
        'redo wastage',
        'redo synch writes',
        'redo synch time'
    )
ORDER BY name;


PROMPT
PROMPT ============================================================================
PROMPT 17. REDO SYNCHRONIZATION STATISTICS
PROMPT ============================================================================

SELECT
    name,
    value
FROM v$sysstat
WHERE name IN
    (
        'redo synch writes',
        'redo synch time',
        'redo write time',
        'redo writes'
    )
ORDER BY name;


PROMPT
PROMPT ============================================================================
PROMPT 18. REDO LOG CONFIGURATION SUMMARY
PROMPT ============================================================================

SELECT
    COUNT(*) AS total_log_groups,
    SUM(CASE WHEN status = 'CURRENT' THEN 1 ELSE 0 END) AS current_groups,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_groups,
    SUM(CASE WHEN status = 'INACTIVE' THEN 1 ELSE 0 END) AS inactive_groups,
    SUM(CASE WHEN status = 'UNUSED' THEN 1 ELSE 0 END) AS unused_groups,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS total_redo_gb
FROM v$log;


PROMPT
PROMPT ============================================================================
PROMPT 19. REDO THREAD / GROUP COVERAGE
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS groups,
    SUM(CASE WHEN status = 'CURRENT' THEN 1 ELSE 0 END) AS current_groups,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_groups,
    SUM(CASE WHEN status = 'INACTIVE' THEN 1 ELSE 0 END) AS inactive_groups,
    ROUND(MIN(bytes) / 1024 / 1024, 2) AS min_mb,
    ROUND(MAX(bytes) / 1024 / 1024, 2) AS max_mb
FROM v$log
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 20. REDO LOG SIZE CONSISTENCY CHECK
PROMPT ============================================================================

SELECT
    thread#,
    MIN(bytes) / 1024 / 1024 AS min_size_mb,
    MAX(bytes) / 1024 / 1024 AS max_size_mb,
    CASE
        WHEN MIN(bytes) = MAX(bytes)
        THEN 'CONSISTENT'
        ELSE 'CHECK - MIXED REDO LOG SIZES'
    END AS status
FROM v$log
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 21. REDO MEMBER STATUS CHECK
PROMPT ============================================================================

SELECT
    lf.group#,
    lf.thread#,
    lf.type,
    lf.status,
    lf.member
FROM v$logfile lf
WHERE NVL(lf.status, 'ONLINE') <> 'ONLINE'
ORDER BY
    lf.thread#,
    lf.group#;


PROMPT
PROMPT ============================================================================
PROMPT 22. REDO HEALTH SUMMARY
PROMPT ============================================================================

SELECT
    CASE
        WHEN EXISTS
             (
                 SELECT 1
                 FROM v$log
                 WHERE status = 'CURRENT'
             )
        AND NOT EXISTS
             (
                 SELECT 1
                 FROM v$logfile
                 WHERE status IS NOT NULL
                   AND status <> 'ONLINE'
             )
        AND NOT EXISTS
             (
                 SELECT 1
                 FROM v$log
                 GROUP BY thread#
                 HAVING MIN(bytes) <> MAX(bytes)
             )
        THEN 'OK - REDO LOG CONFIGURATION LOOKS HEALTHY'

        WHEN EXISTS
             (
                 SELECT 1
                 FROM v$logfile
                 WHERE status IS NOT NULL
                   AND status <> 'ONLINE'
             )
        THEN 'CHECK - REDO LOG MEMBER STATUS ISSUE'

        WHEN EXISTS
             (
                 SELECT 1
                 FROM v$log
                 GROUP BY thread#
                 HAVING MIN(bytes) <> MAX(bytes)
             )
        THEN 'CHECK - MIXED REDO LOG SIZES'

        ELSE
            'CHECK - REVIEW REDO LOG CONFIGURATION'
    END AS redo_health
FROM dual;


PROMPT
PROMPT ============================================================================
PROMPT 23. QUICK REDO HEALTH CHECK
PROMPT ============================================================================

SELECT
    (SELECT COUNT(*) FROM v$log) AS total_log_groups,
    (SELECT COUNT(*) FROM v$log WHERE status = 'CURRENT') AS current_groups,
    (SELECT COUNT(*) FROM v$log WHERE status = 'ACTIVE') AS active_groups,
    (SELECT COUNT(*) FROM v$log WHERE status = 'INACTIVE') AS inactive_groups,
    (SELECT COUNT(*) FROM v$logfile
     WHERE status IS NOT NULL
       AND status <> 'ONLINE') AS abnormal_members,
    (SELECT COUNT(DISTINCT thread#) FROM v$log) AS redo_threads
FROM dual;


PROMPT
PROMPT ============================================================================
PROMPT 24. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] Check redo log group count per thread.
PROMPT [ ] Check redo log size consistency.
PROMPT [ ] Check CURRENT / ACTIVE / INACTIVE status.
PROMPT [ ] Check all redo log members are ONLINE.
PROMPT [ ] Check redo member multiplexing.
PROMPT [ ] Check redo log switch frequency.
PROMPT [ ] Check redo generation volume.
PROMPT [ ] Check redo synch writes/time if commit latency is suspected.
PROMPT [ ] Check archive destination health.
PROMPT [ ] Check RAC thread coverage where applicable.
PROMPT [ ] Correlate frequent switches with redo volume and workload.
PROMPT [ ] Resize/add redo logs only after workload-based analysis.
PROMPT [ ] Do not drop the current or required active redo log.
PROMPT
PROMPT ============================================================================
PROMPT END OF REDO LOG HEALTH CHECK
PROMPT ============================================================================


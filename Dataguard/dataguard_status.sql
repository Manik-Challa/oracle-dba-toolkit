-- ================================================================
-- Oracle DBA Toolkit
-- Script : dataguard_status.sql
-- Purpose: Monitor Oracle Data Guard configuration and status
-- Usage  : Run as SYS or a user with access to required V$ views
-- Notes  : Read-only monitoring script
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN database_name FORMAT A18
COLUMN db_unique_name FORMAT A25
COLUMN database_role FORMAT A20
COLUMN open_mode FORMAT A22
COLUMN protection_mode FORMAT A30
COLUMN protection_level FORMAT A30
COLUMN instance_name FORMAT A18
COLUMN host_name FORMAT A35

COLUMN dest_id FORMAT 999
COLUMN destination FORMAT A55
COLUMN status FORMAT A15
COLUMN target FORMAT A10
COLUMN archiver FORMAT A12
COLUMN error FORMAT A60
COLUMN destination_status FORMAT A15
COLUMN recovery_mode FORMAT A30

COLUMN process FORMAT A12
COLUMN client_process FORMAT A18
COLUMN thread# FORMAT 999
COLUMN sequence# FORMAT 99999999
COLUMN applied FORMAT A10
COLUMN gap_status FORMAT A20
COLUMN transport_status FORMAT A20

COLUMN metric_name FORMAT A35
COLUMN metric_unit FORMAT A20
COLUMN value FORMAT 999999999999.99

COLUMN start_time FORMAT A20
COLUMN end_time FORMAT A20
COLUMN timestamp FORMAT A30

PROMPT
PROMPT ================================================================
PROMPT ORACLE DATA GUARD STATUS MONITOR
PROMPT ================================================================

PROMPT
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ----------------------------------------------------------------

SELECT
    d.name AS database_name,
    d.db_unique_name,
    d.database_role,
    d.open_mode,
    d.protection_mode,
    d.protection_level,
    i.instance_name,
    i.host_name,
    i.status AS instance_status
FROM v$database d
CROSS JOIN v$instance i;

PROMPT
PROMPT 2. DATA GUARD DATABASE ROLE
PROMPT ----------------------------------------------------------------

SELECT
    name AS database_name,
    db_unique_name,
    database_role,
    open_mode,
    protection_mode,
    protection_level,
    switchover_status,
    database_status
FROM v$database;

PROMPT
PROMPT 3. ARCHIVE DESTINATION CONFIGURATION
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    status,
    target,
    destination,
    archiver,
    transmit_mode,
    affirm,
    async_blocks,
    net_timeout,
    delay_mins,
    reopen_secs,
    binding
FROM v$archive_dest
WHERE target <> 'LOCAL'
ORDER BY dest_id;

PROMPT
PROMPT 4. ARCHIVE DESTINATION STATUS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    status,
    type,
    database_mode,
    recovery_mode,
    protection_mode,
    synchronization_status,
    gap_status,
    synchronized,
    error
FROM v$archive_dest_status
WHERE dest_id IN
(
    SELECT dest_id
    FROM v$archive_dest
    WHERE target <> 'LOCAL'
)
ORDER BY dest_id;

PROMPT
PROMPT 5. DATA GUARD DESTINATIONS WITH ERRORS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    status,
    destination,
    error
FROM v$archive_dest
WHERE error IS NOT NULL
ORDER BY dest_id;

PROMPT
PROMPT 6. DESTINATIONS NOT VALID
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    status,
    target,
    destination,
    error
FROM v$archive_dest
WHERE status NOT IN ('VALID', 'INACTIVE', 'DEFERRED')
ORDER BY dest_id;

PROMPT
PROMPT 7. DATA GUARD DESTINATION SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    status,
    target,
    COUNT(*) AS destinations
FROM v$archive_dest
GROUP BY status, target
ORDER BY target, status;

PROMPT
PROMPT 8. DATA GUARD REDO TRANSPORT STATUS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    status,
    database_mode,
    recovery_mode,
    synchronization_status,
    gap_status,
    synchronized,
    error
FROM v$archive_dest_status
WHERE status <> 'INACTIVE'
ORDER BY dest_id;

PROMPT
PROMPT 9. MANAGED STANDBY PROCESSES
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    client_process,
    thread#,
    sequence#,
    block#,
    blocks,
    delay_mins
FROM v$managed_standby
ORDER BY
    CASE process
        WHEN 'MRP0' THEN 1
        WHEN 'RFS' THEN 2
        WHEN 'LNS' THEN 3
        WHEN 'ARCH' THEN 4
        ELSE 5
    END,
    process;

PROMPT
PROMPT 10. MANAGED RECOVERY PROCESS
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    thread#,
    sequence#,
    block#,
    blocks,
    delay_mins
FROM v$managed_standby
WHERE process LIKE 'MRP%'
ORDER BY process;

PROMPT
PROMPT 11. STANDBY REDO LOG STATUS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    group#,
    sequence#,
    bytes / 1024 / 1024 AS size_mb,
    status,
    archived
FROM v$standby_log
ORDER BY thread#, group#;

PROMPT
PROMPT 12. STANDBY REDO LOG SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    status,
    COUNT(*) AS groups,
    ROUND(SUM(bytes) / 1024 / 1024, 2) AS total_mb
FROM v$standby_log
GROUP BY thread#, status
ORDER BY thread#, status;

PROMPT
PROMPT 13. ONLINE REDO LOG STATUS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    group#,
    sequence#,
    bytes / 1024 / 1024 AS size_mb,
    members,
    archived,
    status
FROM v$log
ORDER BY thread#, group#;

PROMPT
PROMPT 14. REDO THREAD STATUS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    enabled,
    instance,
    groups,
    instances
FROM v$thread
ORDER BY thread#;

PROMPT
PROMPT 15. ARCHIVE LOG GENERATION BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS archived_logs,
    MIN(sequence#) AS min_sequence,
    MAX(sequence#) AS max_sequence,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024 / 1024,
        2
    ) AS archived_gb
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 16. LATEST ARCHIVED LOG PER THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) AS latest_sequence,
    MAX(completion_time) AS latest_archive_time
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 17. LATEST APPLIED ARCHIVE LOG PER THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) AS latest_applied_sequence,
    MAX(completion_time) AS latest_applied_time
FROM v$archived_log
WHERE applied = 'YES'
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 18. ARCHIVE LOG APPLY STATUS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) KEEP
    (
        DENSE_RANK LAST ORDER BY sequence#
    ) AS latest_sequence,
    MAX(
        CASE
            WHEN applied = 'YES' THEN sequence#
        END
    ) AS latest_applied_sequence,
    MAX(
        CASE
            WHEN applied = 'NO' THEN sequence#
        END
    ) AS latest_not_applied_sequence
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 19. DATA GUARD ARCHIVE GAP
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    low_sequence#,
    high_sequence#
FROM v$archive_gap
ORDER BY thread#;

PROMPT
PROMPT 20. CURRENT REDO TRANSPORT / APPLY LAG
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    unit,
    time_computed,
    datum_time
FROM v$dataguard_stats
WHERE name IN
(
    'transport lag',
    'apply lag',
    'apply finish time',
    'estimated startup time'
)
ORDER BY name;

PROMPT
PROMPT 21. DATA GUARD STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    unit,
    time_computed
FROM v$dataguard_stats
ORDER BY name;

PROMPT
PROMPT 22. DATA GUARD PROCESS STATUS
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    thread#,
    sequence#,
    client_process
FROM v$managed_standby
ORDER BY process;

PROMPT
PROMPT 23. RECOVERY DESTINATION / FRA STATUS
PROMPT ----------------------------------------------------------------

SELECT
    name AS fra_location,
    ROUND(space_limit / 1024 / 1024 / 1024, 2) AS space_limit_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS space_used_gb,
    ROUND(space_reclaimable / 1024 / 1024 / 1024, 2) AS reclaimable_gb,
    ROUND(
        space_used / NULLIF(space_limit, 0) * 100,
        2
    ) AS used_pct
FROM v$recovery_file_dest;

PROMPT
PROMPT 24. FRA FILE TYPE USAGE
PROMPT ----------------------------------------------------------------

SELECT
    file_type,
    percent_space_used,
    percent_space_reclaimable,
    number_of_files
FROM v$flash_recovery_area_usage
ORDER BY percent_space_used DESC;

PROMPT
PROMPT 25. DATA GUARD STATUS FROM GV$DATABASE
PROMPT ----------------------------------------------------------------

SELECT
    inst_id,
    name,
    db_unique_name,
    database_role,
    open_mode,
    protection_mode,
    protection_level,
    switchover_status,
    database_status
FROM gv$database
ORDER BY inst_id;

PROMPT
PROMPT 26. DATA GUARD DESTINATIONS FROM GV$ARCHIVE_DEST_STATUS
PROMPT ----------------------------------------------------------------

SELECT
    inst_id,
    dest_id,
    status,
    type,
    database_mode,
    recovery_mode,
    synchronization_status,
    gap_status,
    synchronized,
    error
FROM gv$archive_dest_status
WHERE status <> 'INACTIVE'
ORDER BY inst_id, dest_id;

PROMPT
PROMPT 27. DATA GUARD RELATED ALERT LOG ERRORS
PROMPT ----------------------------------------------------------------

SELECT
    originating_timestamp,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND
  (
       UPPER(message_text) LIKE '%ORA-16%'
    OR UPPER(message_text) LIKE '%ORA-17%'
    OR UPPER(message_text) LIKE '%ORA-18%'
    OR UPPER(message_text) LIKE '%ORA-19%'
    OR UPPER(message_text) LIKE '%DATAGUARD%'
    OR UPPER(message_text) LIKE '%REDO TRANSPORT%'
    OR UPPER(message_text) LIKE '%MANAGED RECOVERY%'
    OR UPPER(message_text) LIKE '%ARCHIVE GAP%'
  )
ORDER BY originating_timestamp DESC;

PROMPT
PROMPT 28. DATA GUARD ERROR SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS destinations_with_errors
FROM v$archive_dest
WHERE error IS NOT NULL;

PROMPT
PROMPT 29. APPLY LAG HEALTH INDICATOR
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    unit,
    CASE
        WHEN name = 'apply lag'
             AND REGEXP_LIKE(value, '^[0-9]+')
        THEN 'REVIEW APPLY LAG'
        WHEN name = 'transport lag'
             AND REGEXP_LIKE(value, '^[0-9]+')
        THEN 'REVIEW TRANSPORT LAG'
        ELSE 'REVIEW'
    END AS health_indicator
FROM v$dataguard_stats
WHERE name IN
(
    'transport lag',
    'apply lag'
);

PROMPT
PROMPT 30. DATA GUARD HEALTH SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    d.database_role,
    d.open_mode,
    d.protection_mode,
    d.protection_level,
    d.switchover_status,
    (
        SELECT COUNT(*)
        FROM v$archive_dest
        WHERE error IS NOT NULL
    ) AS destinations_with_errors,
    (
        SELECT COUNT(*)
        FROM v$archive_dest_status
        WHERE gap_status NOT IN ('NO GAP', 'UNKNOWN')
          AND status <> 'INACTIVE'
    ) AS destinations_with_gap_status
FROM v$database d;

PROMPT
PROMPT 31. QUICK DATA GUARD CHECK
PROMPT ----------------------------------------------------------------

SELECT
    d.database_role,
    d.open_mode,
    d.protection_mode,
    d.switchover_status,
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM v$archive_dest
            WHERE error IS NOT NULL
        )
        THEN 'CHECK - ARCHIVE DESTINATION ERROR'
        WHEN EXISTS
        (
            SELECT 1
            FROM v$archive_gap
        )
        THEN 'CHECK - ARCHIVE GAP'
        WHEN d.database_role = 'PHYSICAL STANDBY'
             AND NOT EXISTS
             (
                 SELECT 1
                 FROM v$managed_standby
                 WHERE process LIKE 'MRP%'
                   AND status LIKE '%APPLYING%'
             )
        THEN 'CHECK - MANAGED RECOVERY'
        ELSE 'REVIEW - DATA GUARD STATUS'
    END AS health_status
FROM v$database d;

PROMPT
PROMPT ================================================================
PROMPT DATA GUARD DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Confirm PRIMARY / STANDBY database roles.
PROMPT 2. Check protection mode and protection level.
PROMPT 3. Review archive destination status.
PROMPT 4. Check destination errors.
PROMPT 5. Review transport status.
PROMPT 6. Review apply status.
PROMPT 7. Check transport lag and apply lag.
PROMPT 8. Check V$ARCHIVE_GAP.
PROMPT 9. Review MRP/RFS/LNS processes.
PROMPT 10. Verify standby redo log configuration.
PROMPT 11. Review archive sequences by thread.
PROMPT 12. Check FRA usage on standby.
PROMPT 13. Review recent Data Guard-related alert messages.
PROMPT 14. Correlate issues with listener/network/storage health.
PROMPT
PROMPT IMPORTANT:
PROMPT - Data Guard lag values are workload and network dependent.
PROMPT - An archive gap result requires investigation; validate the actual
PROMPT   missing redo before taking recovery action.
PROMPT - UNKNOWN GAP STATUS does not automatically indicate failure.
PROMPT - APPLIED values in V$ARCHIVED_LOG depend on database role and
PROMPT   destination/history.
PROMPT - V$MANAGED_STANDBY is version dependent and may be superseded
PROMPT   by newer Data Guard monitoring views in later releases.
PROMPT - RAC environments should be reviewed per thread and instance.
PROMPT - Read-only script. No Data Guard configuration is modified.
PROMPT - Do not perform switchover, failover, recovery, or destination
PROMPT   changes based only on this report.
PROMPT
PROMPT ================================================================
PROMPT END OF DATA GUARD STATUS MONITOR
PROMPT ================================================================


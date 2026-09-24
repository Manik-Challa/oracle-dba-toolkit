-- ================================================================
-- Oracle DBA Toolkit
-- Script : standby_status.sql
-- Purpose: Oracle Data Guard Standby Database Health Check
-- Usage  : Run as SYS or a user with access to required V$ views
-- Scope  : Read-only monitoring
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN name                 FORMAT A20
COLUMN db_unique_name       FORMAT A25
COLUMN database_role        FORMAT A22
COLUMN open_mode            FORMAT A25
COLUMN protection_mode      FORMAT A25
COLUMN protection_level     FORMAT A25
COLUMN instance_name        FORMAT A20
COLUMN host_name            FORMAT A35
COLUMN instance_status      FORMAT A15
COLUMN process               FORMAT A12
COLUMN client_process        FORMAT A18
COLUMN status                FORMAT A20
COLUMN thread#               FORMAT 999
COLUMN sequence#             FORMAT 999999999
COLUMN block#                FORMAT 999999999
COLUMN action                FORMAT A20
COLUMN recovery_mode         FORMAT A30
COLUMN recovery_destination  FORMAT A50
COLUMN destination           FORMAT A60
COLUMN target                FORMAT A12
COLUMN error                 FORMAT A70
COLUMN gap_status            FORMAT A25
COLUMN synchronization_status FORMAT A30
COLUMN value                 FORMAT A30
COLUMN datum_time            FORMAT A25
COLUMN time_computed         FORMAT A25
COLUMN start_time            FORMAT A25
COLUMN end_time              FORMAT A25
COLUMN member                FORMAT A70
COLUMN type                  FORMAT A15
COLUMN bytes_gb              FORMAT 9999990.99
COLUMN used_gb               FORMAT 9999990.99
COLUMN free_gb               FORMAT 9999990.99
COLUMN pct_used              FORMAT 990.99
COLUMN health_status         FORMAT A45

PROMPT
PROMPT ================================================================
PROMPT ORACLE DATA GUARD STANDBY STATUS MONITOR
PROMPT ================================================================

PROMPT
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ----------------------------------------------------------------

SELECT
    d.name,
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
PROMPT 2. STANDBY ROLE CHECK
PROMPT ----------------------------------------------------------------

SELECT
    name,
    db_unique_name,
    database_role,
    open_mode,
    protection_mode,
    protection_level,
    CASE
        WHEN database_role = 'PHYSICAL STANDBY'
            THEN 'OK - PHYSICAL STANDBY'
        WHEN database_role = 'LOGICAL STANDBY'
            THEN 'INFO - LOGICAL STANDBY'
        WHEN database_role = 'SNAPSHOT STANDBY'
            THEN 'CHECK - SNAPSHOT STANDBY'
        ELSE
            'INFO - DATABASE IS NOT A STANDBY'
    END AS health_status
FROM v$database;

PROMPT
PROMPT 3. DATABASE GUARD STATUS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    db_unique_name,
    database_role,
    switchover_status,
    protection_mode,
    protection_level,
    open_mode,
    force_logging,
    flashback_on
FROM v$database;

PROMPT
PROMPT 4. STANDBY DATABASE OPEN MODE
PROMPT ----------------------------------------------------------------

SELECT
    database_role,
    open_mode,
    CASE
        WHEN database_role = 'PHYSICAL STANDBY'
             AND open_mode IN ('MOUNTED', 'READ ONLY', 'READ ONLY WITH APPLY')
            THEN 'OK - STANDBY OPEN MODE'
        WHEN database_role <> 'PHYSICAL STANDBY'
            THEN 'INFO - NOT PHYSICAL STANDBY'
        ELSE
            'CHECK - REVIEW STANDBY OPEN MODE'
    END AS health_status
FROM v$database;

PROMPT
PROMPT 5. MANAGED STANDBY PROCESSES
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    client_process,
    client_pid,
    thread#,
    sequence#,
    block#,
    blocks,
    delay_mins,
    known_agents,
    active_agents
FROM v$managed_standby
ORDER BY
    CASE process
        WHEN 'MRP0' THEN 1
        WHEN 'RFS'  THEN 2
        WHEN 'LNS'  THEN 3
        WHEN 'ARCH' THEN 4
        ELSE 5
    END,
    process;

PROMPT
PROMPT 6. MRP APPLY PROCESS
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    client_process,
    thread#,
    sequence#,
    block#,
    blocks,
    delay_mins,
    active_agents,
    known_agents
FROM v$managed_standby
WHERE process LIKE 'MRP%'
ORDER BY process;

PROMPT
PROMPT 7. MRP STATUS SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    COUNT(*) AS process_count
FROM v$managed_standby
WHERE process LIKE 'MRP%'
GROUP BY process, status
ORDER BY process, status;

PROMPT
PROMPT 8. RFS RECEIVE PROCESSES
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
WHERE process LIKE 'RFS%'
ORDER BY thread#, sequence# DESC;

PROMPT
PROMPT 9. DATA GUARD PROCESS STATUS SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    COUNT(*) AS process_count
FROM v$managed_standby
GROUP BY process, status
ORDER BY process, status;

PROMPT
PROMPT 10. PROCESSES NOT IN NORMAL ACTIVE STATES
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    client_process,
    thread#,
    sequence#,
    block#,
    blocks
FROM v$managed_standby
WHERE status NOT IN (
    'WAIT_FOR_LOG',
    'WAIT_FOR_GAP',
    'APPLYING_LOG',
    'RECEIVING'
)
ORDER BY process;

PROMPT
PROMPT 11. DATA GUARD TRANSPORT / APPLY LAG
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    datum_time,
    time_computed
FROM v$dataguard_stats
WHERE name IN (
    'transport lag',
    'apply lag',
    'apply finish time',
    'estimated startup time'
)
ORDER BY name;

PROMPT
PROMPT 12. ALL DATA GUARD STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    datum_time,
    time_computed
FROM v$dataguard_stats
ORDER BY name;

PROMPT
PROMPT 13. ARCHIVE GAP
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    low_sequence#,
    high_sequence#
FROM v$archive_gap
ORDER BY thread#;

PROMPT
PROMPT 14. ARCHIVE GAP STATUS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    status,
    gap_status,
    synchronization_status,
    archived_thread# AS thread#,
    archived_seq# AS archived_sequence,
    applied_thread# AS applied_thread,
    applied_seq# AS applied_sequence,
    error
FROM v$archive_dest_status
WHERE target = 'STANDBY'
ORDER BY dest_id;

PROMPT
PROMPT 15. LATEST ARCHIVED SEQUENCE BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) AS latest_archived_sequence
FROM v$archived_log
WHERE archived = 'YES'
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 16. LATEST APPLIED SEQUENCE BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) AS latest_applied_sequence
FROM v$archived_log
WHERE applied = 'YES'
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 17. ARCHIVED VS APPLIED SEQUENCE
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) AS latest_archived_sequence,
    MAX(
        CASE
            WHEN applied = 'YES' THEN sequence#
        END
    ) AS latest_applied_sequence,
    MAX(sequence#)
      - MAX(
            CASE
                WHEN applied = 'YES' THEN sequence#
            END
        ) AS sequence_difference
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 18. STANDBY REDO LOG STATUS
PROMPT ----------------------------------------------------------------

SELECT
    group#,
    thread#,
    sequence#,
    bytes / 1024 / 1024 / 1024 AS size_gb,
    status,
    archived,
    first_change#,
    next_change#
FROM v$standby_log
ORDER BY thread#, group#;

PROMPT
PROMPT 19. STANDBY REDO LOG SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    status,
    COUNT(*) AS srl_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS total_gb
FROM v$standby_log
GROUP BY thread#, status
ORDER BY thread#, status;

PROMPT
PROMPT 20. ACTIVE STANDBY REDO LOGS
PROMPT ----------------------------------------------------------------

SELECT
    group#,
    thread#,
    sequence#,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    status,
    archived
FROM v$standby_log
WHERE status IN ('ACTIVE', 'CLEARING_CURRENT')
ORDER BY thread#, group#;

PROMPT
PROMPT 21. STANDBY REDO LOG MEMBERS
PROMPT ----------------------------------------------------------------

SELECT
    l.group#,
    l.thread#,
    l.sequence#,
    l.status,
    lf.member
FROM v$standby_log l
JOIN v$logfile lf
    ON l.group# = lf.group#
ORDER BY l.thread#, l.group#, lf.member;

PROMPT
PROMPT 22. ONLINE REDO LOG CONFIGURATION
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS online_redo_groups,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS online_redo_gb
FROM v$log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 23. STANDBY REDO LOG CONFIGURATION BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS standby_redo_groups,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS standby_redo_gb
FROM v$standby_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 24. ARCHIVE DESTINATION STATUS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    destination,
    target,
    status,
    db_unique_name,
    valid_now,
    binding,
    process,
    transmit_mode,
    error
FROM v$archive_dest
WHERE target = 'STANDBY'
ORDER BY dest_id;

PROMPT
PROMPT 25. DESTINATIONS WITH ERRORS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    destination,
    target,
    status,
    db_unique_name,
    error
FROM v$archive_dest
WHERE target = 'STANDBY'
  AND error IS NOT NULL
ORDER BY dest_id;

PROMPT
PROMPT 26. FRA STATUS
PROMPT ----------------------------------------------------------------

SELECT
    name AS recovery_destination,
    ROUND(space_limit / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(space_reclaimable / 1024 / 1024 / 1024, 2) AS reclaimable_gb,
    ROUND(
        space_used / NULLIF(space_limit, 0) * 100,
        2
    ) AS pct_used
FROM v$recovery_file_dest;

PROMPT
PROMPT 27. FRA FILE TYPE USAGE
PROMPT ----------------------------------------------------------------

SELECT
    file_type,
    ROUND(percent_space_used, 2) AS pct_used,
    ROUND(percent_space_reclaimable, 2) AS pct_reclaimable
FROM v$flash_recovery_area_usage
ORDER BY percent_space_used DESC;

PROMPT
PROMPT 28. RECENT STANDBY ARCHIVE ACTIVITY
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) AS latest_sequence,
    MAX(first_time) AS latest_first_time,
    MAX(completion_time) AS latest_completion_time
FROM v$archived_log
WHERE first_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 29. RECENTLY APPLIED ARCHIVE LOGS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    applied,
    registrar,
    creator,
    standby_dest
FROM v$archived_log
WHERE applied = 'YES'
  AND completion_time >= SYSDATE - 1
ORDER BY completion_time DESC;

PROMPT
PROMPT 30. RECENT DATA GUARD ALERTS
PROMPT ----------------------------------------------------------------

SELECT
    originating_timestamp,
    message_level,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
       UPPER(message_text) LIKE '%DATA GUARD%'
    OR UPPER(message_text) LIKE '%DATAGUARD%'
    OR UPPER(message_text) LIKE '%MRP%'
    OR UPPER(message_text) LIKE '%RFS%'
    OR UPPER(message_text) LIKE '%LNS%'
    OR UPPER(message_text) LIKE '%ARCHIVE GAP%'
    OR UPPER(message_text) LIKE '%APPLY%'
  )
ORDER BY originating_timestamp DESC;

PROMPT
PROMPT 31. STANDBY HEALTH SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    d.database_role,
    d.open_mode,
    d.switchover_status,
    d.protection_mode,
    d.protection_level,
    CASE
        WHEN d.database_role NOT IN (
            'PHYSICAL STANDBY',
            'LOGICAL STANDBY',
            'SNAPSHOT STANDBY'
        )
            THEN 'INFO - DATABASE IS NOT A STANDBY'

        WHEN EXISTS (
            SELECT 1
            FROM v$archive_dest
            WHERE target = 'STANDBY'
              AND error IS NOT NULL
        )
            THEN 'CHECK - STANDBY DESTINATION ERROR'

        WHEN EXISTS (
            SELECT 1
            FROM v$archive_gap
        )
            THEN 'CHECK - ARCHIVE GAP EXISTS'

        WHEN EXISTS (
            SELECT 1
            FROM v$managed_standby
            WHERE process LIKE 'MRP%'
              AND status NOT IN (
                  'APPLYING_LOG',
                  'WAIT_FOR_LOG',
                  'WAIT_FOR_GAP'
              )
        )
            THEN 'CHECK - REVIEW MRP STATUS'

        WHEN EXISTS (
            SELECT 1
            FROM v$dataguard_stats
            WHERE name = 'transport lag'
              AND value IS NOT NULL
        )
            THEN 'OK - REVIEW LAG DETAILS'

        ELSE
            'OK - STANDBY STATUS LOOKS NORMAL'
    END AS health_status
FROM v$database d;

PROMPT
PROMPT 32. QUICK STANDBY CHECK
PROMPT ----------------------------------------------------------------

SELECT
    d.database_role,
    d.open_mode,
    d.switchover_status,
    (
        SELECT COUNT(*)
        FROM v$managed_standby
        WHERE process LIKE 'MRP%'
    ) AS mrp_processes,
    (
        SELECT COUNT(*)
        FROM v$managed_standby
        WHERE process LIKE 'RFS%'
    ) AS rfs_processes,
    (
        SELECT COUNT(*)
        FROM v$standby_log
    ) AS standby_redo_groups,
    (
        SELECT COUNT(*)
        FROM v$archive_gap
    ) AS archive_gap_rows,
    (
        SELECT COUNT(*)
        FROM v$archive_dest
        WHERE target = 'STANDBY'
          AND error IS NOT NULL
    ) AS destination_errors
FROM v$database d;

PROMPT
PROMPT ================================================================
PROMPT STANDBY DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Confirm DATABASE_ROLE is the expected standby role.
PROMPT 2. Check OPEN_MODE and recovery mode.
PROMPT 3. Review MRP status and apply activity.
PROMPT 4. Review RFS receive processes.
PROMPT 5. Check transport lag and apply lag.
PROMPT 6. Check V$ARCHIVE_GAP.
PROMPT 7. Compare archived and applied sequences by RAC thread.
PROMPT 8. Review standby redo log configuration.
PROMPT 9. Check standby redo log activity and sizing.
PROMPT 10. Review standby archive destination status.
PROMPT 11. Check destination errors.
PROMPT 12. Review FRA usage and reclaimable space.
PROMPT 13. Review recent Data Guard alert messages.
PROMPT 14. Correlate MRP/RFS status with transport and apply lag.
PROMPT 15. Investigate RAC threads individually where applicable.
PROMPT
PROMPT IMPORTANT:
PROMPT - This script is read-only.
PROMPT - V$MANAGED_STANDBY is version-dependent and may be deprecated
PROMPT   in newer Oracle releases; verify the target release.
PROMPT - V$DATAGUARD_STATS is preferred for transport/apply lag.
PROMPT - Sequence differences are investigation indicators, not formal lag.
PROMPT - V$ARCHIVED_LOG can contain multiple rows for a sequence.
PROMPT - V$ARCHIVE_GAP is especially relevant to physical standby gaps.
PROMPT - WAIT_FOR_LOG does not automatically indicate a problem.
PROMPT - WAIT_FOR_GAP requires correlation with actual gap information.
PROMPT - Standby redo log requirements depend on the Data Guard design.
PROMPT - FRA reclaimable space is not automatically safe to remove.
PROMPT - Do not restart recovery or modify Data Guard configuration
PROMPT   based only on this report.
PROMPT
PROMPT ================================================================
PROMPT END OF STANDBY STATUS MONITOR
PROMPT ================================================================

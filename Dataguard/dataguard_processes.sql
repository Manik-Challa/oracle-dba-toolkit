-- ================================================================
-- Oracle DBA Toolkit
-- Script : dataguard_processes.sql
-- Purpose: Monitor Oracle Data Guard Processes
-- Usage  : Run as SYS or a user with access to required V$ views
-- Notes  : Read-only monitoring script
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN database_name FORMAT A20
COLUMN db_unique_name FORMAT A25
COLUMN database_role FORMAT A22
COLUMN open_mode FORMAT A22
COLUMN instance_name FORMAT A20
COLUMN host_name FORMAT A35
COLUMN instance_status FORMAT A15

COLUMN process FORMAT A15
COLUMN status FORMAT A25
COLUMN client_process FORMAT A20
COLUMN client_pid FORMAT A15
COLUMN thread# FORMAT 999
COLUMN sequence# FORMAT 99999999
COLUMN block# FORMAT 999999999
COLUMN blocks FORMAT 999999999
COLUMN delay_mins FORMAT 999999

COLUMN process_name FORMAT A15
COLUMN pname FORMAT A15
COLUMN spid FORMAT A20
COLUMN program FORMAT A50
COLUMN background FORMAT A10
COLUMN tracefile FORMAT A80

COLUMN dest_id FORMAT 999
COLUMN target FORMAT A12
COLUMN destination FORMAT A55
COLUMN error FORMAT A70
COLUMN gap_status FORMAT A20
COLUMN synchronization_status FORMAT A25
COLUMN recovery_mode FORMAT A25

PROMPT
PROMPT ================================================================
PROMPT ORACLE DATA GUARD PROCESS MONITOR
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
PROMPT 2. DATA GUARD MANAGED PROCESSES
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
        WHEN 'MRP'  THEN 2
        WHEN 'RFS'  THEN 3
        WHEN 'LNS'  THEN 4
        WHEN 'ARCH' THEN 5
        ELSE 6
    END,
    process;

PROMPT
PROMPT 3. MANAGED RECOVERY PROCESS - MRP
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
WHERE process LIKE 'MRP%'
ORDER BY process;

PROMPT
PROMPT 4. REMOTE FILE SERVER PROCESSES - RFS
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
ORDER BY
    thread#,
    sequence#;

PROMPT
PROMPT 5. LOG NETWORK SERVER PROCESSES - LNS
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
WHERE process LIKE 'LNS%'
ORDER BY
    thread#,
    sequence#;

PROMPT
PROMPT 6. ARCHIVER PROCESSES - ARCH
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
WHERE process LIKE 'ARCH%'
ORDER BY
    thread#,
    sequence#;

PROMPT
PROMPT 7. DATA GUARD PROCESS STATUS SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    COUNT(*) AS process_count
FROM v$managed_standby
GROUP BY
    process,
    status
ORDER BY
    process,
    status;

PROMPT
PROMPT 8. PROCESS STATUS SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    status,
    COUNT(*) AS process_count
FROM v$managed_standby
GROUP BY status
ORDER BY
    CASE
        WHEN status LIKE '%APPLYING%' THEN 1
        WHEN status LIKE '%RECEIVING%' THEN 2
        WHEN status LIKE '%WAIT%' THEN 3
        ELSE 4
    END,
    status;

PROMPT
PROMPT 9. MRP APPLY STATUS
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    thread#,
    sequence#,
    block#,
    blocks,
    delay_mins,
    CASE
        WHEN status LIKE '%APPLYING%' THEN 'APPLYING'
        WHEN status LIKE '%WAIT%' THEN 'WAITING'
        ELSE 'REVIEW'
    END AS health_status
FROM v$managed_standby
WHERE process LIKE 'MRP%'
ORDER BY process;

PROMPT
PROMPT 10. RFS RECEIVE STATUS
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    thread#,
    sequence#,
    block#,
    blocks,
    CASE
        WHEN status LIKE '%RECEIVING%' THEN 'RECEIVING REDO'
        WHEN status LIKE '%WAIT%' THEN 'WAITING'
        ELSE 'REVIEW'
    END AS health_status
FROM v$managed_standby
WHERE process LIKE 'RFS%'
ORDER BY
    thread#,
    sequence#;

PROMPT
PROMPT 11. LNS TRANSPORT STATUS
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    thread#,
    sequence#,
    block#,
    blocks,
    CASE
        WHEN status LIKE '%WRITING%' THEN 'TRANSPORT ACTIVE'
        WHEN status LIKE '%NETWORK%' THEN 'NETWORK ACTIVITY'
        WHEN status LIKE '%WAIT%' THEN 'WAITING'
        ELSE 'REVIEW'
    END AS health_status
FROM v$managed_standby
WHERE process LIKE 'LNS%'
ORDER BY
    thread#,
    sequence#;

PROMPT
PROMPT 12. DATA GUARD PROCESSES BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    process,
    status,
    COUNT(*) AS process_count,
    MAX(sequence#) AS latest_sequence
FROM v$managed_standby
WHERE thread# IS NOT NULL
GROUP BY
    thread#,
    process,
    status
ORDER BY
    thread#,
    process;

PROMPT
PROMPT 13. DATA GUARD PROCESSES NOT ACTIVE
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    client_process,
    thread#,
    sequence#,
    delay_mins
FROM v$managed_standby
WHERE status NOT LIKE '%APPLYING%'
  AND status NOT LIKE '%RECEIVING%'
  AND status NOT LIKE '%WAIT%'
ORDER BY
    process,
    thread#;

PROMPT
PROMPT 14. MRP PROCESSES NOT APPLYING
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
  AND status NOT LIKE '%APPLYING%'
ORDER BY process;

PROMPT
PROMPT 15. DATA GUARD PROCESS SEQUENCE ACTIVITY
PROMPT ----------------------------------------------------------------

SELECT
    process,
    thread#,
    MIN(sequence#) AS min_sequence,
    MAX(sequence#) AS max_sequence,
    COUNT(*) AS process_records
FROM v$managed_standby
WHERE thread# IS NOT NULL
GROUP BY
    process,
    thread#
ORDER BY
    thread#,
    process;

PROMPT
PROMPT 16. DATA GUARD DESTINATION STATUS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    status,
    target,
    destination,
    synchronization_status,
    gap_status,
    recovery_mode,
    error
FROM v$archive_dest_status
WHERE status <> 'INACTIVE'
ORDER BY dest_id;

PROMPT
PROMPT 17. DATA GUARD DESTINATIONS WITH ERRORS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    status,
    target,
    destination,
    error
FROM v$archive_dest
WHERE error IS NOT NULL
ORDER BY dest_id;

PROMPT
PROMPT 18. DATA GUARD TRANSPORT / APPLY LAG
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
    'apply lag'
)
ORDER BY name;

PROMPT
PROMPT 19. ARCHIVE GAP STATUS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    low_sequence#,
    high_sequence#,
    high_sequence# - low_sequence# + 1 AS sequence_count
FROM v$archive_gap
ORDER BY thread#;

PROMPT
PROMPT 20. STANDBY REDO LOG STATUS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    group#,
    sequence#,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    status,
    archived
FROM v$standby_log
ORDER BY
    thread#,
    group#;

PROMPT
PROMPT 21. RAC INSTANCE STATUS
PROMPT ----------------------------------------------------------------

SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    thread#,
    parallel,
    archiver,
    logins
FROM gv$instance
ORDER BY inst_id;

PROMPT
PROMPT 22. RAC DATA GUARD INSTANCE VISIBILITY
PROMPT ----------------------------------------------------------------

SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    thread#
FROM gv$instance
ORDER BY inst_id;

PROMPT
PROMPT 23. DATA GUARD BACKGROUND PROCESSES
PROMPT ----------------------------------------------------------------

SELECT
    p.inst_id,
    p.pid,
    p.spid,
    p.pname,
    p.program,
    p.background
FROM gv$process p
WHERE
       UPPER(p.pname) LIKE '%MRP%'
    OR UPPER(p.pname) LIKE '%RFS%'
    OR UPPER(p.pname) LIKE '%LNS%'
    OR UPPER(p.pname) LIKE '%DMON%'
    OR UPPER(p.pname) LIKE '%DGRD%'
    OR UPPER(p.program) LIKE '%(MRP%'
    OR UPPER(p.program) LIKE '%(RFS%'
    OR UPPER(p.program) LIKE '%(LNS%'
ORDER BY
    p.inst_id,
    p.pname,
    p.pid;

PROMPT
PROMPT 24. DATA GUARD PROCESS COUNT
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS total_managed_processes,
    SUM(
        CASE
            WHEN process LIKE 'MRP%' THEN 1
            ELSE 0
        END
    ) AS mrp_processes,
    SUM(
        CASE
            WHEN process LIKE 'RFS%' THEN 1
            ELSE 0
        END
    ) AS rfs_processes,
    SUM(
        CASE
            WHEN process LIKE 'LNS%' THEN 1
            ELSE 0
        END
    ) AS lns_processes,
    SUM(
        CASE
            WHEN process LIKE 'ARCH%' THEN 1
            ELSE 0
        END
    ) AS arch_processes
FROM v$managed_standby;

PROMPT
PROMPT 25. DATA GUARD PROCESS HEALTH SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    (
        SELECT COUNT(*)
        FROM v$managed_standby
        WHERE process LIKE 'MRP%'
    ) AS mrp_count,

    (
        SELECT COUNT(*)
        FROM v$managed_standby
        WHERE process LIKE 'MRP%'
          AND status LIKE '%APPLYING%'
    ) AS mrp_applying,

    (
        SELECT COUNT(*)
        FROM v$managed_standby
        WHERE process LIKE 'RFS%'
    ) AS rfs_count,

    (
        SELECT COUNT(*)
        FROM v$managed_standby
        WHERE process LIKE 'LNS%'
    ) AS lns_count,

    (
        SELECT COUNT(*)
        FROM v$archive_dest
        WHERE error IS NOT NULL
    ) AS destination_errors,

    (
        SELECT COUNT(*)
        FROM v$archive_gap
    ) AS archive_gap_threads
FROM dual;

PROMPT
PROMPT 26. QUICK DATA GUARD PROCESS CHECK
PROMPT ----------------------------------------------------------------

SELECT
    d.database_role,
    CASE
        WHEN d.database_role = 'PHYSICAL STANDBY'
             AND NOT EXISTS
             (
                 SELECT 1
                 FROM v$managed_standby
                 WHERE process LIKE 'MRP%'
                   AND status LIKE '%APPLYING%'
             )
        THEN 'CHECK - MRP NOT APPLYING'

        WHEN EXISTS
             (
                 SELECT 1
                 FROM v$archive_dest
                 WHERE error IS NOT NULL
             )
        THEN 'CHECK - DESTINATION ERROR'

        WHEN EXISTS
             (
                 SELECT 1
                 FROM v$archive_gap
             )
        THEN 'CHECK - ARCHIVE GAP'

        ELSE 'REVIEW - PROCESS STATUS'
    END AS process_health
FROM v$database d;

PROMPT
PROMPT 27. RECENT DATA GUARD PROCESS ALERTS
PROMPT ----------------------------------------------------------------

SELECT
    originating_timestamp,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND
  (
       UPPER(message_text) LIKE '%MRP%'
    OR UPPER(message_text) LIKE '%RFS%'
    OR UPPER(message_text) LIKE '%LNS%'
    OR UPPER(message_text) LIKE '%DATAGUARD%'
    OR UPPER(message_text) LIKE '%MANAGED RECOVERY%'
    OR UPPER(message_text) LIKE '%REDO TRANSPORT%'
  )
ORDER BY originating_timestamp DESC;

PROMPT
PROMPT ================================================================
PROMPT DATA GUARD PROCESS DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Check MRP status on physical standby databases.
PROMPT 2. Check RFS processes receiving redo.
PROMPT 3. Check LNS transport processes on primary databases.
PROMPT 4. Review ARCH process activity where applicable.
PROMPT 5. Check process status per RAC instance/thread.
PROMPT 6. Correlate process sequence numbers with archived redo.
PROMPT 7. Check transport and apply lag.
PROMPT 8. Check V$ARCHIVE_GAP.
PROMPT 9. Review standby redo log status.
PROMPT 10. Review archive destination errors.
PROMPT 11. Review recent Data Guard process-related alerts.
PROMPT 12. Correlate process issues with network and storage health.
PROMPT
PROMPT IMPORTANT:
PROMPT - V$MANAGED_STANDBY is version dependent.
PROMPT - Process names and statuses can vary by Oracle release and
PROMPT   Data Guard configuration.
PROMPT - MRP should be evaluated according to the standby role and
PROMPT   configured recovery mode.
PROMPT - LNS processes are primarily relevant to redo transport.
PROMPT - RFS processes are primarily relevant to redo reception.
PROMPT - A process in WAIT status is not automatically an error.
PROMPT - RAC environments should be reviewed per instance and thread.
PROMPT - This script is read-only and does not start, stop, or modify
PROMPT   Data Guard processes.
PROMPT - Do not restart or alter Data Guard processes based only on
PROMPT   this report.
PROMPT
PROMPT ================================================================
PROMPT END OF DATA GUARD PROCESS MONITOR
PROMPT ================================================================


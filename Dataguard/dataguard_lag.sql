-- ================================================================
-- Oracle DBA Toolkit
-- Script : dataguard_lag.sql
-- Purpose: Monitor Oracle Data Guard Transport and Apply Lag
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
COLUMN protection_mode FORMAT A30
COLUMN protection_level FORMAT A30

COLUMN name FORMAT A30
COLUMN value FORMAT A40
COLUMN unit FORMAT A25
COLUMN time_computed FORMAT A30
COLUMN datum_time FORMAT A30

COLUMN thread# FORMAT 999
COLUMN sequence# FORMAT 99999999
COLUMN applied FORMAT A10
COLUMN archived FORMAT A10
COLUMN completion_time FORMAT A30
COLUMN first_time FORMAT A30

COLUMN dest_id FORMAT 999
COLUMN status FORMAT A15
COLUMN destination FORMAT A55
COLUMN target FORMAT A12
COLUMN error FORMAT A70
COLUMN gap_status FORMAT A20
COLUMN synchronization_status FORMAT A25
COLUMN synchronized FORMAT A15

COLUMN process FORMAT A12
COLUMN client_process FORMAT A18
COLUMN process_status FORMAT A20

COLUMN lag_minutes FORMAT 999999999.99
COLUMN redo_mb FORMAT 999999999.99
COLUMN archive_count FORMAT 99999999
COLUMN sequence_gap FORMAT 99999999

PROMPT
PROMPT ================================================================
PROMPT ORACLE DATA GUARD LAG MONITOR
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
PROMPT 2. DATA GUARD LAG METRICS
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
ORDER BY
    CASE name
        WHEN 'transport lag' THEN 1
        WHEN 'apply lag' THEN 2
        WHEN 'apply finish time' THEN 3
        WHEN 'estimated startup time' THEN 4
        ELSE 5
    END;

PROMPT
PROMPT 3. ALL DATA GUARD STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    unit,
    time_computed,
    datum_time
FROM v$dataguard_stats
ORDER BY name;

PROMPT
PROMPT 4. DATA GUARD DESTINATION STATUS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    status,
    target,
    destination,
    archiver,
    transmit_mode,
    affirm,
    error
FROM v$archive_dest
WHERE target <> 'LOCAL'
ORDER BY dest_id;

PROMPT
PROMPT 5. DESTINATION SYNCHRONIZATION STATUS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    status,
    type,
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
PROMPT 6. DESTINATIONS WITH TRANSPORT ERRORS
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
PROMPT 7. DATA GUARD ARCHIVE GAP
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    low_sequence#,
    high_sequence#
FROM v$archive_gap
ORDER BY thread#;

PROMPT
PROMPT 8. MANAGED RECOVERY PROCESS STATUS
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
PROMPT 9. MRP APPLY STATUS
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
PROMPT 10. LATEST ARCHIVED SEQUENCE BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) AS latest_archived_sequence,
    MAX(completion_time) AS latest_archive_time
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 11. LATEST APPLIED SEQUENCE BY THREAD
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
PROMPT 12. ARCHIVED VS APPLIED SEQUENCE
PROMPT ----------------------------------------------------------------

WITH archived AS
(
    SELECT
        thread#,
        MAX(sequence#) AS latest_archived_sequence
    FROM v$archived_log
    GROUP BY thread#
),
applied AS
(
    SELECT
        thread#,
        MAX(sequence#) AS latest_applied_sequence
    FROM v$archived_log
    WHERE applied = 'YES'
    GROUP BY thread#
)
SELECT
    a.thread#,
    a.latest_archived_sequence,
    NVL(p.latest_applied_sequence, 0) AS latest_applied_sequence,
    a.latest_archived_sequence -
        NVL(p.latest_applied_sequence, 0) AS sequence_gap
FROM archived a
LEFT JOIN applied p
    ON p.thread# = a.thread#
ORDER BY a.thread#;

PROMPT
PROMPT 13. ARCHIVE GENERATION LAST 24 HOURS BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS redo_mb,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 14. ARCHIVE GENERATION LAST 1 HOUR
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS redo_mb,
    MIN(completion_time) AS first_archive_time,
    MAX(completion_time) AS last_archive_time
FROM v$archived_log
WHERE completion_time >= SYSDATE - (1 / 24)
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 15. ARCHIVE GENERATION BY HOUR - LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24') AS archive_hour,
    thread#,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS redo_mb
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24'),
    thread#
ORDER BY
    archive_hour DESC,
    thread#;

PROMPT
PROMPT 16. RECENT ARCHIVE LOG APPLY ACTIVITY
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    applied,
    archived
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
ORDER BY
    thread#,
    sequence# DESC;

PROMPT
PROMPT 17. ARCHIVE LOGS NOT YET APPLIED
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    applied,
    archived
FROM v$archived_log
WHERE applied = 'NO'
  AND completion_time >= SYSDATE - 1
ORDER BY
    thread#,
    sequence# DESC;

PROMPT
PROMPT 18. LATEST ARCHIVE LOG PER THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    applied,
    archived
FROM
(
    SELECT
        thread#,
        sequence#,
        first_time,
        completion_time,
        applied,
        archived,
        ROW_NUMBER() OVER
        (
            PARTITION BY thread#
            ORDER BY sequence# DESC, completion_time DESC
        ) AS rn
    FROM v$archived_log
)
WHERE rn = 1
ORDER BY thread#;

PROMPT
PROMPT 19. LATEST APPLIED ARCHIVE LOG PER THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time
FROM
(
    SELECT
        thread#,
        sequence#,
        first_time,
        completion_time,
        ROW_NUMBER() OVER
        (
            PARTITION BY thread#
            ORDER BY sequence# DESC, completion_time DESC
        ) AS rn
    FROM v$archived_log
    WHERE applied = 'YES'
)
WHERE rn = 1
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
ORDER BY thread#, group#;

PROMPT
PROMPT 21. STANDBY REDO LOGS CURRENTLY IN USE
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    group#,
    sequence#,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    status,
    archived
FROM v$standby_log
WHERE status = 'ACTIVE'
ORDER BY thread#, group#;

PROMPT
PROMPT 22. REDO THREAD STATUS
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
PROMPT 23. DATA GUARD LAG-RELATED ALERTS
PROMPT ----------------------------------------------------------------

SELECT
    originating_timestamp,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND
  (
       UPPER(message_text) LIKE '%LAG%'
    OR UPPER(message_text) LIKE '%ARCHIVE GAP%'
    OR UPPER(message_text) LIKE '%DATAGUARD%'
    OR UPPER(message_text) LIKE '%REDO TRANSPORT%'
    OR UPPER(message_text) LIKE '%MANAGED RECOVERY%'
  )
ORDER BY originating_timestamp DESC;

PROMPT
PROMPT 24. LAG HEALTH INDICATORS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    unit,
    CASE
        WHEN name = 'transport lag'
        THEN 'REVIEW TRANSPORT LAG'
        WHEN name = 'apply lag'
        THEN 'REVIEW APPLY LAG'
        ELSE 'REVIEW'
    END AS health_indicator
FROM v$dataguard_stats
WHERE name IN
(
    'transport lag',
    'apply lag'
);

PROMPT
PROMPT 25. TRANSPORT ERROR SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS destinations_with_errors
FROM v$archive_dest
WHERE error IS NOT NULL;

PROMPT
PROMPT 26. GAP STATUS SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    gap_status,
    COUNT(*) AS destinations
FROM v$archive_dest_status
WHERE status <> 'INACTIVE'
GROUP BY gap_status
ORDER BY gap_status;

PROMPT
PROMPT 27. APPLY PROCESS HEALTH
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS mrp_processes,
    SUM(
        CASE
            WHEN status LIKE '%APPLYING%' THEN 1
            ELSE 0
        END
    ) AS applying_processes
FROM v$managed_standby
WHERE process LIKE 'MRP%';

PROMPT
PROMPT 28. THREAD-WISE SEQUENCE GAP SUMMARY
PROMPT ----------------------------------------------------------------

WITH archived AS
(
    SELECT
        thread#,
        MAX(sequence#) AS latest_archived
    FROM v$archived_log
    GROUP BY thread#
),
applied AS
(
    SELECT
        thread#,
        MAX(sequence#) AS latest_applied
    FROM v$archived_log
    WHERE applied = 'YES'
    GROUP BY thread#
)
SELECT
    a.thread#,
    a.latest_archived,
    NVL(p.latest_applied, 0) AS latest_applied,
    a.latest_archived -
        NVL(p.latest_applied, 0) AS sequence_gap,
    CASE
        WHEN a.latest_archived -
             NVL(p.latest_applied, 0) > 0
        THEN 'APPLY BEHIND'
        ELSE 'NO SEQUENCE GAP'
    END AS status
FROM archived a
LEFT JOIN applied p
    ON p.thread# = a.thread#
ORDER BY a.thread#;

PROMPT
PROMPT 29. DATA GUARD LAG SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    d.database_role,
    d.open_mode,
    d.protection_mode,
    d.protection_level,
    d.switchover_status,

    (
        SELECT value
        FROM v$dataguard_stats
        WHERE name = 'transport lag'
    ) AS transport_lag,

    (
        SELECT value
        FROM v$dataguard_stats
        WHERE name = 'apply lag'
    ) AS apply_lag,

    (
        SELECT COUNT(*)
        FROM v$archive_gap
    ) AS archive_gap_rows,

    (
        SELECT COUNT(*)
        FROM v$archive_dest
        WHERE error IS NOT NULL
    ) AS destination_errors

FROM v$database d;

PROMPT
PROMPT 30. QUICK DATA GUARD LAG CHECK
PROMPT ----------------------------------------------------------------

SELECT
    d.database_role,
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM v$archive_gap
        )
        THEN 'CHECK - ARCHIVE GAP'

        WHEN EXISTS
        (
            SELECT 1
            FROM v$archive_dest
            WHERE error IS NOT NULL
        )
        THEN 'CHECK - TRANSPORT ERROR'

        WHEN d.database_role = 'PHYSICAL STANDBY'
             AND NOT EXISTS
             (
                 SELECT 1
                 FROM v$managed_standby
                 WHERE process LIKE 'MRP%'
                   AND status LIKE '%APPLYING%'
             )
        THEN 'CHECK - APPLY PROCESS'

        ELSE 'REVIEW - LAG METRICS'
    END AS lag_health
FROM v$database d;

PROMPT
PROMPT ================================================================
PROMPT DATA GUARD LAG DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Review transport lag.
PROMPT 2. Review apply lag.
PROMPT 3. Check V$ARCHIVE_GAP.
PROMPT 4. Review archive destination errors.
PROMPT 5. Check MRP/RFS/LNS process status.
PROMPT 6. Compare latest archived and applied sequences.
PROMPT 7. Review lag separately for each RAC redo thread.
PROMPT 8. Check standby redo log availability and status.
PROMPT 9. Review recent archive generation volume.
PROMPT 10. Check network and storage when transport/apply lag increases.
PROMPT 11. Review recent Data Guard-related alert messages.
PROMPT 12. Correlate lag with workload and redo generation.
PROMPT
PROMPT IMPORTANT:
PROMPT - Transport lag and apply lag are workload/network dependent.
PROMPT - Sequence difference is an investigation indicator and does not
PROMPT   by itself prove missing redo.
PROMPT - V$ARCHIVED_LOG can contain multiple rows for the same sequence.
PROMPT - RAC environments must be evaluated thread by thread.
PROMPT - APPLIED='YES' has role/destination-dependent semantics.
PROMPT - V$MANAGED_STANDBY is version dependent.
PROMPT - Lag thresholds should be defined according to the application's
PROMPT   Data Guard recovery and business requirements.
PROMPT - This script is read-only and does not modify Data Guard.
PROMPT - Do not perform failover, switchover, recovery, or log deletion
PROMPT   based only on this report.
PROMPT
PROMPT ================================================================
PROMPT END OF DATA GUARD LAG MONITOR
PROMPT ================================================================


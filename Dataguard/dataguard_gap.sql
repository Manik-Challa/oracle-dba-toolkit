-- ================================================================
-- Oracle DBA Toolkit
-- Script : dataguard_gap.sql
-- Purpose: Monitor Oracle Data Guard Archive Gaps
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

COLUMN thread# FORMAT 999
COLUMN sequence# FORMAT 99999999
COLUMN low_sequence# FORMAT 99999999
COLUMN high_sequence# FORMAT 99999999
COLUMN sequence_gap FORMAT 99999999

COLUMN first_time FORMAT A25
COLUMN completion_time FORMAT A25
COLUMN applied FORMAT A10
COLUMN archived FORMAT A10
COLUMN status FORMAT A15

COLUMN dest_id FORMAT 999
COLUMN target FORMAT A12
COLUMN destination FORMAT A55
COLUMN error FORMAT A70
COLUMN gap_status FORMAT A20
COLUMN synchronization_status FORMAT A25
COLUMN synchronized FORMAT A15

COLUMN process FORMAT A12
COLUMN client_process FORMAT A18
COLUMN process_status FORMAT A20

PROMPT
PROMPT ================================================================
PROMPT ORACLE DATA GUARD ARCHIVE GAP MONITOR
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
PROMPT 2. V$ARCHIVE_GAP - CURRENT ARCHIVE GAP
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    low_sequence#,
    high_sequence#,
    (high_sequence# - low_sequence# + 1) AS missing_sequence_count
FROM v$archive_gap
ORDER BY thread#;

PROMPT
PROMPT 3. CURRENT ARCHIVE GAP SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS gap_threads,
    NVL(
        SUM(high_sequence# - low_sequence# + 1),
        0
    ) AS total_sequences_in_gap
FROM v$archive_gap;

PROMPT
PROMPT 4. DATA GUARD DESTINATION GAP STATUS
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
PROMPT 5. ARCHIVE DESTINATIONS WITH ERRORS
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
PROMPT 6. DESTINATIONS WITH NON-NORMAL GAP STATUS
PROMPT ----------------------------------------------------------------

SELECT
    dest_id,
    status,
    target,
    destination,
    gap_status,
    error
FROM v$archive_dest_status
WHERE status <> 'INACTIVE'
  AND gap_status NOT IN ('NO GAP', 'UNKNOWN')
ORDER BY dest_id;

PROMPT
PROMPT 7. LATEST ARCHIVED SEQUENCE BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) AS latest_archived_sequence,
    MAX(completion_time) AS latest_archive_time
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 8. LATEST APPLIED SEQUENCE BY THREAD
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
PROMPT 9. ARCHIVED VS APPLIED SEQUENCE BY THREAD
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
        NVL(p.latest_applied_sequence, 0) AS sequence_difference,
    CASE
        WHEN a.latest_archived_sequence -
             NVL(p.latest_applied_sequence, 0) > 0
        THEN 'APPLY BEHIND'
        ELSE 'NO SEQUENCE DIFFERENCE'
    END AS status
FROM archived a
LEFT JOIN applied p
    ON p.thread# = a.thread#
ORDER BY a.thread#;

PROMPT
PROMPT 10. RECENT ARCHIVE LOGS BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    archived,
    applied
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
ORDER BY
    thread#,
    sequence# DESC;

PROMPT
PROMPT 11. RECENT UNAPPLIED ARCHIVE LOGS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    archived,
    applied
FROM v$archived_log
WHERE applied = 'NO'
  AND completion_time >= SYSDATE - 1
ORDER BY
    thread#,
    sequence# DESC;

PROMPT
PROMPT 12. RECENT ARCHIVE LOG ACTIVITY BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS archive_records,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS redo_mb
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 13. SEQUENCE CONTINUITY - LAST 24 HOURS
PROMPT ----------------------------------------------------------------

WITH logs AS
(
    SELECT
        thread#,
        sequence#,
        LAG(sequence#) OVER
        (
            PARTITION BY thread#
            ORDER BY sequence#
        ) AS previous_sequence
    FROM
    (
        SELECT DISTINCT
            thread#,
            sequence#
        FROM v$archived_log
        WHERE completion_time >= SYSDATE - 1
    )
)
SELECT
    thread#,
    previous_sequence,
    sequence#,
    sequence# - previous_sequence - 1 AS missing_sequences
FROM logs
WHERE previous_sequence IS NOT NULL
  AND sequence# > previous_sequence + 1
ORDER BY
    thread#,
    sequence#;

PROMPT
PROMPT 14. SEQUENCE DISCONTINUITIES - LAST 7 DAYS
PROMPT ----------------------------------------------------------------

WITH logs AS
(
    SELECT
        thread#,
        sequence#,
        LAG(sequence#) OVER
        (
            PARTITION BY thread#
            ORDER BY sequence#
        ) AS previous_sequence
    FROM
    (
        SELECT DISTINCT
            thread#,
            sequence#
        FROM v$archived_log
        WHERE completion_time >= SYSDATE - 7
    )
)
SELECT
    thread#,
    previous_sequence,
    sequence#,
    sequence# - previous_sequence - 1 AS missing_sequences
FROM logs
WHERE previous_sequence IS NOT NULL
  AND sequence# > previous_sequence + 1
ORDER BY
    thread#,
    sequence#;

PROMPT
PROMPT 15. ARCHIVE LOGS AROUND DETECTED DISCONTINUITIES
PROMPT ----------------------------------------------------------------

WITH logs AS
(
    SELECT
        thread#,
        sequence#,
        LAG(sequence#) OVER
        (
            PARTITION BY thread#
            ORDER BY sequence#
        ) AS previous_sequence
    FROM
    (
        SELECT DISTINCT
            thread#,
            sequence#
        FROM v$archived_log
        WHERE completion_time >= SYSDATE - 7
    )
)
SELECT
    thread#,
    previous_sequence,
    sequence#,
    sequence# - previous_sequence - 1 AS missing_sequences
FROM logs
WHERE previous_sequence IS NOT NULL
  AND sequence# > previous_sequence + 1
ORDER BY
    thread#,
    sequence#;

PROMPT
PROMPT 16. DATA GUARD APPLY PROCESS
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
PROMPT 17. MRP STATUS
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
PROMPT 18. STANDBY REDO LOG STATUS
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
PROMPT 19. STANDBY REDO LOGS CURRENTLY ACTIVE
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
ORDER BY
    thread#,
    group#;

PROMPT
PROMPT 20. REDO THREAD CONFIGURATION
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
PROMPT 21. DATA GUARD TRANSPORT / APPLY LAG
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
PROMPT 22. ARCHIVE DESTINATION STATUS SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    status,
    gap_status,
    COUNT(*) AS destinations
FROM v$archive_dest_status
WHERE status <> 'INACTIVE'
GROUP BY
    status,
    gap_status
ORDER BY
    status,
    gap_status;

PROMPT
PROMPT 23. RECENT DATA GUARD GAP / TRANSPORT ALERTS
PROMPT ----------------------------------------------------------------

SELECT
    originating_timestamp,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND
  (
       UPPER(message_text) LIKE '%ARCHIVE GAP%'
    OR UPPER(message_text) LIKE '%GAP%'
    OR UPPER(message_text) LIKE '%DATAGUARD%'
    OR UPPER(message_text) LIKE '%REDO TRANSPORT%'
    OR UPPER(message_text) LIKE '%MANAGED RECOVERY%'
  )
ORDER BY originating_timestamp DESC;

PROMPT
PROMPT 24. THREAD-WISE GAP SUMMARY
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
        NVL(p.latest_applied, 0) AS sequence_difference,
    CASE
        WHEN a.latest_archived -
             NVL(p.latest_applied, 0) > 0
        THEN 'CHECK APPLY'
        ELSE 'NO DIFFERENCE'
    END AS health_status
FROM archived a
LEFT JOIN applied p
    ON p.thread# = a.thread#
ORDER BY a.thread#;

PROMPT
PROMPT 25. ARCHIVE GAP HEALTH SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    (
        SELECT COUNT(*)
        FROM v$archive_gap
    ) AS gap_threads,

    (
        SELECT NVL(
            SUM(high_sequence# - low_sequence# + 1),
            0
        )
        FROM v$archive_gap
    ) AS gap_sequence_count,

    (
        SELECT COUNT(*)
        FROM v$archive_dest
        WHERE error IS NOT NULL
    ) AS destination_errors,

    (
        SELECT COUNT(*)
        FROM v$archive_dest_status
        WHERE status <> 'INACTIVE'
          AND gap_status NOT IN ('NO GAP', 'UNKNOWN')
    ) AS destinations_with_gap_status;

PROMPT
PROMPT 26. QUICK DATA GUARD GAP CHECK
PROMPT ----------------------------------------------------------------

SELECT
    d.database_role,
    d.open_mode,
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

        WHEN EXISTS
        (
            SELECT 1
            FROM v$archive_dest_status
            WHERE status <> 'INACTIVE'
              AND gap_status NOT IN ('NO GAP', 'UNKNOWN')
        )
        THEN 'CHECK - DESTINATION GAP STATUS'

        ELSE 'NO CURRENT GAP INDICATOR'
    END AS gap_health
FROM v$database d;

PROMPT
PROMPT ================================================================
PROMPT DATA GUARD GAP DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Check V$ARCHIVE_GAP first.
PROMPT 2. Review low and high missing sequence numbers.
PROMPT 3. Review gap status for each Data Guard destination.
PROMPT 4. Check destination transport errors.
PROMPT 5. Compare archived and applied sequences per RAC thread.
PROMPT 6. Check MRP and RFS process status.
PROMPT 7. Review standby redo log status.
PROMPT 8. Review transport and apply lag.
PROMPT 9. Investigate sequence discontinuities separately.
PROMPT 10. Check recent Data Guard-related alert messages.
PROMPT 11. Validate whether apparent gaps are real before recovery action.
PROMPT
PROMPT IMPORTANT:
PROMPT - V$ARCHIVE_GAP identifies gaps relevant to the standby database.
PROMPT - Sequence discontinuity in V$ARCHIVED_LOG is only an investigation
PROMPT   indicator and does not automatically prove missing redo.
PROMPT - V$ARCHIVED_LOG can contain multiple rows for the same sequence.
PROMPT - RAC environments must be checked thread by thread.
PROMPT - UNKNOWN GAP_STATUS does not automatically mean failure.
PROMPT - APPLIED='YES' has role and destination-dependent semantics.
PROMPT - Archive gap resolution may require fetching missing archive logs,
PROMPT   FAL, RMAN, or other Data Guard recovery procedures.
PROMPT - Do not delete archive logs or perform recovery based only on this
PROMPT   report.
PROMPT - This script is read-only and does not modify Data Guard.
PROMPT
PROMPT ================================================================
PROMPT END OF DATA GUARD GAP MONITOR
PROMPT ================================================================


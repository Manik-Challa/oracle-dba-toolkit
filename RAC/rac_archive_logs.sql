-- ============================================================================
-- RAC ARCHIVE LOG MONITORING
-- File    : rac_archive_logs.sql
-- Purpose : Monitor RAC archive generation, destinations, gaps and health
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
COLUMN sequence#            FORMAT 999999999
COLUMN name                 FORMAT A80
COLUMN destination          FORMAT A50
COLUMN destination_status   FORMAT A12
COLUMN status               FORMAT A15
COLUMN archived              FORMAT A10
COLUMN applied              FORMAT A10
COLUMN gap_status            FORMAT A20
COLUMN completion_time       FORMAT A20
COLUMN first_time            FORMAT A20
COLUMN next_time             FORMAT A20
COLUMN error                 FORMAT A60
COLUMN error_count           FORMAT 999999
COLUMN archive_count         FORMAT 999999
COLUMN archived_gb           FORMAT 999999.99
COLUMN archived_mb           FORMAT 999999999
COLUMN avg_mb                FORMAT 999999.99
COLUMN switches              FORMAT 999999
COLUMN files_per_hour        FORMAT 999999.99

PROMPT
PROMPT ============================================================================
PROMPT RAC ARCHIVE LOG MONITORING
PROMPT ============================================================================


PROMPT
PROMPT ============================================================================
PROMPT 1. DATABASE AND RAC INSTANCE OVERVIEW
PROMPT ============================================================================

SELECT
    i.inst_id,
    i.instance_number,
    i.instance_name,
    i.thread#,
    i.status AS instance_status,
    d.open_mode,
    d.database_role,
    d.log_mode
FROM gv$instance i
CROSS JOIN v$database d
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 2. ARCHIVE DESTINATION STATUS
PROMPT ============================================================================

SELECT
    inst_id,
    dest_id,
    status,
    target,
    destination,
    binding,
    schedule,
    valid_now,
    valid_type,
    error
FROM gv$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY inst_id, dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 3. ARCHIVE DESTINATION CONFIGURATION
PROMPT ============================================================================

SELECT
    inst_id,
    dest_id,
    status,
    target,
    destination,
    binding,
    schedule,
    process,
    transmit_mode,
    affirm,
    valid_now
FROM gv$archive_dest
ORDER BY inst_id, dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 4. ARCHIVE DESTINATIONS WITH ERRORS
PROMPT ============================================================================

SELECT
    inst_id,
    dest_id,
    status,
    target,
    destination,
    error
FROM gv$archive_dest
WHERE error IS NOT NULL
   OR status IN ('ERROR', 'DISABLED')
ORDER BY inst_id, dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 5. ARCHIVE DESTINATION STATISTICS
PROMPT ============================================================================

SELECT
    inst_id,
    dest_id,
    status,
    archived_seq#,
    applied_seq#,
    gap_status,
    error
FROM gv$archive_dest_status
ORDER BY inst_id, dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 6. ARCHIVE LOG SUMMARY BY RAC THREAD
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS archive_count,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence,
    MIN(first_time) AS first_archive_time,
    MAX(next_time) AS latest_archive_time
FROM gv$archived_log
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 7. RECENT ARCHIVED LOGS
PROMPT ============================================================================

SELECT *
FROM (
    SELECT
        thread#,
        sequence#,
        first_time,
        next_time,
        completion_time,
        archived,
        applied,
        name
    FROM gv$archived_log
    WHERE name IS NOT NULL
    ORDER BY completion_time DESC
)
WHERE ROWNUM <= 50;


PROMPT
PROMPT ============================================================================
PROMPT 8. LATEST ARCHIVED SEQUENCE PER THREAD
PROMPT ============================================================================

SELECT
    thread#,
    MAX(sequence#) AS latest_sequence,
    MAX(completion_time) AS latest_archive_time
FROM gv$archived_log
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 9. ARCHIVE GENERATION - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024 / 1024,
        2
    ) AS archived_gb,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS archived_mb
FROM gv$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 10. ARCHIVE GENERATION - LAST 1 HOUR
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS archived_mb
FROM gv$archived_log
WHERE completion_time >= SYSDATE - (1 / 24)
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 11. ARCHIVE GENERATION BY HOUR - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    thread#,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24') AS archive_hour,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS archived_mb
FROM gv$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY
    thread#,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24')
ORDER BY
    archive_hour,
    thread#;


PROMPT
PROMPT ============================================================================
PROMPT 12. ARCHIVE GENERATION BY INSTANCE
PROMPT ============================================================================

SELECT
    al.thread#,
    i.instance_name,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(al.blocks * al.block_size) / 1024 / 1024 / 1024,
        2
    ) AS archived_gb
FROM gv$archived_log al
LEFT JOIN gv$instance i
       ON i.thread# = al.thread#
WHERE al.completion_time >= SYSDATE - 1
GROUP BY
    al.thread#,
    i.instance_name
ORDER BY al.thread#;


PROMPT
PROMPT ============================================================================
PROMPT 13. ARCHIVED LOG STATUS
PROMPT ============================================================================

SELECT
    thread#,
    archived,
    applied,
    COUNT(*) AS log_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024 / 1024,
        2
    ) AS total_gb
FROM gv$archived_log
GROUP BY
    thread#,
    archived,
    applied
ORDER BY
    thread#,
    archived,
    applied;


PROMPT
PROMPT ============================================================================
PROMPT 14. UNAPPLIED ARCHIVED LOGS
PROMPT ============================================================================

SELECT
    thread#,
    MIN(sequence#) AS oldest_unapplied_sequence,
    MAX(sequence#) AS latest_unapplied_sequence,
    COUNT(*) AS unapplied_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024 / 1024,
        2
    ) AS unapplied_gb
FROM gv$archived_log
WHERE applied = 'NO'
  AND name IS NOT NULL
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 15. ARCHIVE LOG GAP INDICATORS
PROMPT ============================================================================

SELECT
    thread#,
    MIN(sequence#) AS minimum_sequence,
    MAX(sequence#) AS maximum_sequence,
    COUNT(DISTINCT sequence#) AS sequence_count,
    MAX(sequence#) - MIN(sequence#) + 1 AS expected_sequence_count,
    (
        MAX(sequence#) - MIN(sequence#) + 1
    ) - COUNT(DISTINCT sequence#) AS possible_missing_sequences
FROM gv$archived_log
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 16. ARCHIVE LOG SEQUENCE GAPS
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    LAG(sequence#) OVER (
        PARTITION BY thread#
        ORDER BY sequence#
    ) AS previous_sequence,
    sequence#
      - LAG(sequence#) OVER (
            PARTITION BY thread#
            ORDER BY sequence#
        ) AS sequence_difference
FROM gv$archived_log
WHERE sequence# IS NOT NULL
ORDER BY thread#, sequence#;


PROMPT
PROMPT ============================================================================
PROMPT 17. ARCHIVE LOGS WITH SEQUENCE DISCONTINUITY
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    previous_sequence,
    sequence_difference
FROM (
    SELECT
        thread#,
        sequence#,
        LAG(sequence#) OVER (
            PARTITION BY thread#
            ORDER BY sequence#
        ) AS previous_sequence,
        sequence#
          - LAG(sequence#) OVER (
                PARTITION BY thread#
                ORDER BY sequence#
            ) AS sequence_difference
    FROM gv$archived_log
)
WHERE sequence_difference > 1
ORDER BY thread#, sequence#;


PROMPT
PROMPT ============================================================================
PROMPT 18. ARCHIVE LOG DESTINATION SUMMARY
PROMPT ============================================================================

SELECT
    inst_id,
    dest_id,
    status,
    target,
    archived_seq#,
    applied_seq#,
    gap_status,
    error
FROM gv$archive_dest_status
ORDER BY inst_id, dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 19. ARCHIVE DESTINATION LAG
PROMPT ============================================================================

SELECT
    inst_id,
    dest_id,
    target,
    status,
    archived_seq#,
    applied_seq#,
    CASE
        WHEN archived_seq# IS NOT NULL
         AND applied_seq# IS NOT NULL
        THEN archived_seq# - applied_seq#
    END AS sequence_lag,
    gap_status,
    error
FROM gv$archive_dest_status
WHERE target IS NOT NULL
ORDER BY inst_id, dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 20. FAILED / ERROR ARCHIVE DESTINATIONS
PROMPT ============================================================================

SELECT
    inst_id,
    dest_id,
    target,
    status,
    destination,
    error
FROM gv$archive_dest
WHERE status IN ('ERROR', 'DISABLED')
   OR error IS NOT NULL
ORDER BY inst_id, dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 21. LOCAL ARCHIVE DESTINATIONS
PROMPT ============================================================================

SELECT
    inst_id,
    dest_id,
    status,
    target,
    destination,
    binding,
    valid_now
FROM gv$archive_dest
WHERE target = 'LOCAL'
ORDER BY inst_id, dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 22. REMOTE ARCHIVE DESTINATIONS
PROMPT ============================================================================

SELECT
    inst_id,
    dest_id,
    status,
    target,
    destination,
    binding,
    transmit_mode,
    affirm,
    valid_now,
    error
FROM gv$archive_dest
WHERE target = 'STANDBY'
ORDER BY inst_id, dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 23. ARCHIVE LOGS NOT YET APPLIED
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    first_time,
    next_time,
    completion_time,
    applied,
    name
FROM gv$archived_log
WHERE applied = 'NO'
  AND name IS NOT NULL
ORDER BY thread#, sequence#;


PROMPT
PROMPT ============================================================================
PROMPT 24. LATEST APPLIED SEQUENCE PER THREAD
PROMPT ============================================================================

SELECT
    thread#,
    MAX(sequence#) AS latest_applied_sequence,
    MAX(completion_time) AS latest_archive_time
FROM gv$archived_log
WHERE applied = 'YES'
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 25. ARCHIVE DESTINATION ERRORS BY INSTANCE
PROMPT ============================================================================

SELECT
    inst_id,
    COUNT(*) AS destination_error_count
FROM gv$archive_dest
WHERE status = 'ERROR'
   OR error IS NOT NULL
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 26. ARCHIVE-RELATED WAIT EVENTS
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
WHERE LOWER(event) LIKE '%archive%'
   OR LOWER(event) LIKE '%log file%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================================
PROMPT 27. CURRENT ARCHIVE / LOG WAITERS
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
        LOWER(event) LIKE '%archive%'
        OR LOWER(event) LIKE '%log file%'
      )
ORDER BY seconds_in_wait DESC;


PROMPT
PROMPT ============================================================================
PROMPT 28. ARCHIVE PROCESS INFORMATION
PROMPT ============================================================================

SELECT
    inst_id,
    process,
    status,
    client_process,
    client_pid,
    sequence#
FROM gv$archive_processes
ORDER BY inst_id, process;


PROMPT
PROMPT ============================================================================
PROMPT 29. ARCHIVE PROCESS STATUS SUMMARY
PROMPT ============================================================================

SELECT
    inst_id,
    status,
    COUNT(*) AS process_count
FROM gv$archive_processes
GROUP BY inst_id, status
ORDER BY inst_id, status;


PROMPT
PROMPT ============================================================================
PROMPT 30. ARCHIVE LOG GENERATION SUMMARY
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS archive_mb,
    ROUND(
        AVG(blocks * block_size) / 1024 / 1024,
        2
    ) AS avg_archive_mb
FROM gv$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 31. ARCHIVE LOGS BY HOUR
PROMPT ============================================================================

SELECT
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24') AS archive_hour,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024 / 1024,
        2
    ) AS archive_gb
FROM gv$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY TO_CHAR(completion_time, 'YYYY-MM-DD HH24')
ORDER BY archive_hour;


PROMPT
PROMPT ============================================================================
PROMPT 32. ARCHIVE RATE BY THREAD
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS archives_last_hour,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS archive_mb_last_hour
FROM gv$archived_log
WHERE completion_time >= SYSDATE - (1 / 24)
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 33. ARCHIVE LOGS WITH ERROR STATUS
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    name,
    archived,
    applied,
    status,
    completion_time
FROM gv$archived_log
WHERE status <> 'A'
ORDER BY completion_time DESC;


PROMPT
PROMPT ============================================================================
PROMPT 34. STANDBY DESTINATION HEALTH
PROMPT ============================================================================

SELECT
    inst_id,
    dest_id,
    status,
    target,
    archived_seq#,
    applied_seq#,
    gap_status,
    error
FROM gv$archive_dest_status
WHERE target = 'STANDBY'
ORDER BY inst_id, dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 35. RAC ARCHIVE HEALTH SUMMARY
PROMPT ============================================================================

SELECT
    'RAC THREADS' AS check_name,
    COUNT(*) AS value,
    CASE
        WHEN COUNT(*) > 0 THEN 'OK'
        ELSE 'CHECK'
    END AS status
FROM v$thread

UNION ALL

SELECT
    'ARCHIVE DESTINATION ERRORS',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'CHECK'
    END
FROM gv$archive_dest
WHERE status = 'ERROR'
   OR error IS NOT NULL

UNION ALL

SELECT
    'UNAPPLIED ARCHIVED LOGS',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'INFO'
    END
FROM gv$archived_log
WHERE applied = 'NO'
  AND name IS NOT NULL

UNION ALL

SELECT
    'ACTIVE ARCHIVE PROCESSES',
    COUNT(*),
    CASE
        WHEN COUNT(*) > 0 THEN 'OK'
        ELSE 'INFO'
    END
FROM gv$archive_processes
WHERE status = 'ACTIVE';


PROMPT
PROMPT ============================================================================
PROMPT 36. RAC ARCHIVE DBA CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] Every RAC thread is present and enabled
PROMPT [ ] Archive destinations are in the expected state
PROMPT [ ] No unexpected archive destination errors
PROMPT [ ] Archive generation is reasonably balanced across threads
PROMPT [ ] Archive generation rate is understood for the workload
PROMPT [ ] No unexpected sequence gaps
PROMPT [ ] Standby/archive destinations are checked when Data Guard is used
PROMPT [ ] Archived logs are being applied as expected
PROMPT [ ] Archive process status is healthy
PROMPT [ ] Archive filesystem/ASM/FRA capacity is sufficient
PROMPT [ ] FRA usage is checked separately
PROMPT [ ] Archive-related waits are reviewed
PROMPT [ ] Sudden archive-rate increases are correlated with workload
PROMPT [ ] Recovery/backup retention requirements are considered before cleanup
PROMPT
PROMPT ============================================================================
PROMPT IMPORTANT
PROMPT ============================================================================
PROMPT GV$ARCHIVED_LOG contains historical/archive records and may contain
PROMPT multiple records for the same sequence depending on destination/history.
PROMPT
PROMPT A sequence discontinuity in this report is an INVESTIGATION INDICATOR,
PROMPT not automatic proof of a missing archive log.
PROMPT
PROMPT Applied='NO' is meaningful primarily in Data Guard/archive destination
PROMPT contexts and should not automatically be treated as an error.
PROMPT
PROMPT Archive generation is workload dependent. High archive volume alone
PROMPT does not indicate a problem.
PROMPT
PROMPT This script is READ-ONLY.
PROMPT ============================================================================


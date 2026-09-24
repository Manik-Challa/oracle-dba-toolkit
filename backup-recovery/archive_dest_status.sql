-- ============================================================================
-- Oracle DBA Toolkit
-- Script   : archive_dest_status.sql
-- Purpose  : Monitor Oracle ARCHIVELOG destination health and status
-- Author   : Manik Challa
-- Version  : 1.0
-- ============================================================================
--
-- READ-ONLY SCRIPT
--
-- Covers:
--   1. Database / instance information
--   2. Archive destination configuration
--   3. Destination status and errors
--   4. Local / remote destination details
--   5. Archive destination usage
--   6. Current archive destination status
--   7. Failed / error destinations
--   8. Archive generation by thread
--   9. Recent archived logs
--  10. Archive destination health summary
--  11. DBA investigation checklist
--
-- Notes:
--   * V$ARCHIVE_DEST describes configured archive destinations.
--   * V$ARCHIVE_DEST_STATUS provides runtime destination status.
--   * DEST_ID values may differ between environments.
--   * Remote destinations may be Data Guard related.
--   * A destination with STATUS=VALID does not by itself prove that
--     end-to-end recovery/transport is healthy.
--   * This script does NOT modify archive destinations.
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
COLUMN log_mode FORMAT A15
COLUMN force_logging FORMAT A15

COLUMN dest_id FORMAT 999
COLUMN destination FORMAT A70
COLUMN status FORMAT A15
COLUMN target FORMAT A10
COLUMN type FORMAT A12
COLUMN database_mode FORMAT A15
COLUMN recovery_mode FORMAT A20
COLUMN protection_mode FORMAT A25
COLUMN synchronization_status FORMAT A20
COLUMN gap_status FORMAT A20
COLUMN error FORMAT A80
COLUMN db_unique_name FORMAT A25
COLUMN binding FORMAT A12
COLUMN schedule FORMAT A12
COLUMN valid_now FORMAT A12
COLUMN valid_type FORMAT A15
COLUMN valid_role FORMAT A15
COLUMN archived_seq FORMAT 999999999
COLUMN applied_seq FORMAT 999999999
COLUMN thread# FORMAT 999
COLUMN sequence# FORMAT 999999999
COLUMN completion_time FORMAT A20
COLUMN first_time FORMAT A20
COLUMN last_time FORMAT A20
COLUMN recovery_dest FORMAT A15
COLUMN quota_size_mb FORMAT 999,999,999
COLUMN space_limit_mb FORMAT 999,999,999
COLUMN space_used_mb FORMAT 999,999,999
COLUMN space_reclaimable_mb FORMAT 999,999,999
COLUMN pct_used FORMAT 999.99
COLUMN health_status FORMAT A70


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
PROMPT 2. ARCHIVE DESTINATION CONFIGURATION
PROMPT ============================================================================

SELECT
    dest_id,
    status,
    target,
    destination,
    binding,
    schedule,
    valid_now,
    valid_type,
    valid_role
FROM v$archive_dest
WHERE destination IS NOT NULL
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 3. ARCHIVE DESTINATION DETAILS
PROMPT ============================================================================

SELECT
    dest_id,
    status,
    target,
    type,
    destination,
    db_unique_name,
    binding,
    schedule,
    valid_now,
    valid_type,
    valid_role
FROM v$archive_dest
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 4. ARCHIVE DESTINATION RUNTIME STATUS
PROMPT ============================================================================

SELECT
    dest_id,
    status,
    type,
    database_mode,
    recovery_mode,
    synchronization_status,
    gap_status,
    archived_thread#,
    archived_seq#
FROM v$archive_dest_status
WHERE status IS NOT NULL
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 5. ARCHIVE DESTINATION ERRORS
PROMPT ============================================================================

SELECT
    dest_id,
    status,
    target,
    destination,
    error
FROM v$archive_dest
WHERE error IS NOT NULL
  AND TRIM(error) IS NOT NULL
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 6. DESTINATIONS NOT IN VALID STATE
PROMPT ============================================================================

SELECT
    dest_id,
    status,
    target,
    destination,
    error
FROM v$archive_dest
WHERE status NOT IN ('VALID', 'INACTIVE')
   OR error IS NOT NULL
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 7. ENABLED ARCHIVE DESTINATIONS
PROMPT ============================================================================

SELECT
    dest_id,
    status,
    target,
    destination,
    binding,
    schedule
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 8. LOCAL ARCHIVE DESTINATIONS
PROMPT ============================================================================

SELECT
    dest_id,
    status,
    target,
    destination,
    binding,
    valid_now
FROM v$archive_dest
WHERE target = 'LOCAL'
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 9. REMOTE ARCHIVE DESTINATIONS
PROMPT ============================================================================

SELECT
    dest_id,
    status,
    target,
    destination,
    db_unique_name,
    binding,
    schedule,
    valid_role
FROM v$archive_dest
WHERE target = 'STANDBY'
   OR target = 'REMOTE'
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 10. ARCHIVE DESTINATION STATUS SUMMARY
PROMPT ============================================================================

SELECT
    status,
    COUNT(*) AS destination_count
FROM v$archive_dest
GROUP BY status
ORDER BY status;


PROMPT
PROMPT ============================================================================
PROMPT 11. DESTINATIONS WITH TRANSPORT / GAP INFORMATION
PROMPT ============================================================================
PROMPT Useful primarily when Data Guard / remote archive destinations exist.

SELECT
    dest_id,
    status,
    database_mode,
    recovery_mode,
    synchronization_status,
    gap_status,
    archived_thread#,
    archived_seq#
FROM v$archive_dest_status
WHERE target = 'STANDBY'
   OR target = 'REMOTE'
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 12. ARCHIVE DESTINATION STATUS WITH ERROR DETAILS
PROMPT ============================================================================

SELECT
    s.dest_id,
    s.status,
    s.database_mode,
    s.recovery_mode,
    s.synchronization_status,
    s.gap_status,
    d.destination,
    d.error
FROM v$archive_dest_status s
LEFT JOIN v$archive_dest d
    ON s.dest_id = d.dest_id
WHERE s.status IS NOT NULL
ORDER BY s.dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 13. ARCHIVE DESTINATION VALIDITY
PROMPT ============================================================================

SELECT
    dest_id,
    status,
    valid_now,
    valid_type,
    valid_role,
    target,
    destination
FROM v$archive_dest
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 14. ARCHIVE DESTINATION SPACE USAGE
PROMPT ============================================================================
PROMPT Applies to destinations exposing quota/space information.

SELECT
    dest_id,
    destination,
    ROUND(quota_size / 1024 / 1024, 2) AS quota_size_mb,
    ROUND(space_limit / 1024 / 1024, 2) AS space_limit_mb,
    ROUND(space_used / 1024 / 1024, 2) AS space_used_mb,
    ROUND(space_reclaimable / 1024 / 1024, 2) AS space_reclaimable_mb
FROM v$archive_dest
WHERE destination IS NOT NULL
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 15. FRA / RECOVERY DESTINATION STATUS
PROMPT ============================================================================

SELECT
    name,
    ROUND(space_limit / 1024 / 1024 / 1024, 2) AS space_limit_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS space_used_gb,
    ROUND(space_reclaimable / 1024 / 1024 / 1024, 2) AS reclaimable_gb,
    ROUND(
        space_used / NULLIF(space_limit, 0) * 100,
        2
    ) AS pct_used
FROM v$recovery_file_dest;


PROMPT
PROMPT ============================================================================
PROMPT 16. FRA FILE TYPE USAGE
PROMPT ============================================================================

SELECT
    file_type,
    ROUND(percent_space_used, 2) AS pct_used,
    ROUND(percent_space_reclaimable, 2) AS pct_reclaimable,
    number_of_files
FROM v$flash_recovery_area_usage
ORDER BY percent_space_used DESC;


PROMPT
PROMPT ============================================================================
PROMPT 17. ARCHIVE GENERATION BY THREAD - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS archive_records,
    MIN(first_time) AS first_archive,
    MAX(completion_time) AS last_archive
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 18. ARCHIVE GENERATION BY THREAD - LAST 7 DAYS
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS archive_records,
    MIN(first_time) AS first_archive,
    MAX(completion_time) AS last_archive
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 19. LATEST ARCHIVED SEQUENCE BY THREAD
PROMPT ============================================================================

SELECT
    thread#,
    MAX(sequence#) AS latest_sequence,
    MAX(completion_time) AS latest_archive_time
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 20. RECENT ARCHIVED LOG ACTIVITY
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    archived,
    applied,
    backup_count
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
ORDER BY
    thread#,
    completion_time DESC;


PROMPT
PROMPT ============================================================================
PROMPT 21. ARCHIVE LOGS WITH NO RMAN BACKUP RECORD
PROMPT ============================================================================
PROMPT Investigation indicator only.
PROMPT V$ARCHIVED_LOG may contain multiple rows for the same sequence.

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    backup_count,
    archived,
    applied
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
  AND NVL(backup_count, 0) = 0
ORDER BY
    thread#,
    sequence# DESC;


PROMPT
PROMPT ============================================================================
PROMPT 22. ARCHIVE DESTINATION HEALTH SUMMARY
PROMPT ============================================================================

SELECT
    CASE
        WHEN EXISTS
             (
                 SELECT 1
                 FROM v$archive_dest
                 WHERE error IS NOT NULL
                   AND TRIM(error) IS NOT NULL
             )
        THEN 'CHECK - ARCHIVE DESTINATION ERROR FOUND'

        WHEN EXISTS
             (
                 SELECT 1
                 FROM v$archive_dest
                 WHERE status NOT IN ('VALID', 'INACTIVE')
             )
        THEN 'CHECK - ARCHIVE DESTINATION NOT VALID'

        WHEN EXISTS
             (
                 SELECT 1
                 FROM v$recovery_file_dest
                 WHERE space_limit > 0
                   AND space_used / space_limit * 100 >= 90
             )
        THEN 'CHECK - FRA USAGE >= 90%'

        ELSE
            'OK - ARCHIVE DESTINATIONS LOOK HEALTHY'
    END AS health_status
FROM dual;


PROMPT
PROMPT ============================================================================
PROMPT 23. QUICK ARCHIVE DESTINATION CHECK
PROMPT ============================================================================

SELECT
    (SELECT COUNT(*)
       FROM v$archive_dest
      WHERE destination IS NOT NULL) AS configured_destinations,

    (SELECT COUNT(*)
       FROM v$archive_dest
      WHERE status = 'VALID') AS valid_destinations,

    (SELECT COUNT(*)
       FROM v$archive_dest
      WHERE error IS NOT NULL
        AND TRIM(error) IS NOT NULL) AS destinations_with_errors,

    (SELECT COUNT(*)
       FROM v$archive_dest
      WHERE status NOT IN ('VALID', 'INACTIVE')) AS abnormal_destinations
FROM dual;


PROMPT
PROMPT ============================================================================
PROMPT 24. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] Check V$ARCHIVE_DEST for configured destinations.
PROMPT [ ] Check destination STATUS.
PROMPT [ ] Check DEST_ID-specific ERROR messages.
PROMPT [ ] Check local archive destination availability.
PROMPT [ ] Check remote destinations if Data Guard is configured.
PROMPT [ ] Check SYNCHRONIZATION_STATUS and GAP_STATUS for standby destinations.
PROMPT [ ] Check archived sequence progress by RAC thread.
PROMPT [ ] Check FRA utilization.
PROMPT [ ] Check for recent archive logs without backup records.
PROMPT [ ] Check alert.log for archiver / destination errors.
PROMPT [ ] Check ORA-00257 if archiving has stopped.
PROMPT [ ] Check ORA-16014 / ORA-16038 / ORA-19504 when applicable.
PROMPT [ ] Correlate archive destination issues with FRA/storage capacity.
PROMPT [ ] Do not modify LOG_ARCHIVE_DEST parameters without impact analysis.
PROMPT
PROMPT ============================================================================
PROMPT END OF ARCHIVE DESTINATION STATUS CHECK
PROMPT ============================================================================


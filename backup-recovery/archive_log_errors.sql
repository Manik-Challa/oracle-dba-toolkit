-- ============================================================================
-- Oracle DBA Toolkit
-- Script   : archive_log_errors.sql
-- Purpose  : Monitor Oracle ARCHIVELOG errors and archive destination failures
-- Author   : Manik Challa
-- Version  : 1.0
-- ============================================================================
--
-- READ-ONLY SCRIPT
--
-- Covers:
--   1. Database / instance information
--   2. Archive mode
--   3. Archive destination errors
--   4. Archive destination status
--   5. Archive destination runtime errors
--   6. FRA usage
--   7. FRA archive log usage
--   8. Recent archived log activity
--   9. Archive logs with backup issues
--  10. Alert log archive-related errors
--  11. ORA- archive errors from diagnostic repository
--  12. RAC thread archive activity
--  13. Archive error health summary
--  14. DBA investigation checklist
--
-- IMPORTANT:
--   * This script is READ-ONLY.
--   * It does not modify archive destinations.
--   * It does not delete archive logs.
--   * It does not perform RMAN CROSSCHECK/DELETE.
--   * Alert-log contents depend on ADR retention and database version.
--   * V$ARCHIVED_LOG may contain multiple rows for the same sequence.
--
-- Common errors to investigate:
--   ORA-00257  archiver error
--   ORA-16014  log cannot be archived
--   ORA-16038  log cannot be archived
--   ORA-19504  failed to create file
--   ORA-27040  file create error
--   ORA-19809  limit exceeded for recovery files
--   ORA-19804  cannot reclaim space
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
COLUMN status FORMAT A15
COLUMN target FORMAT A10
COLUMN destination FORMAT A80
COLUMN error FORMAT A100
COLUMN type FORMAT A15
COLUMN database_mode FORMAT A15
COLUMN recovery_mode FORMAT A20
COLUMN synchronization_status FORMAT A25
COLUMN gap_status FORMAT A20
COLUMN db_unique_name FORMAT A25

COLUMN thread# FORMAT 999
COLUMN sequence# FORMAT 999999999
COLUMN backup_count FORMAT 999
COLUMN archived FORMAT A8
COLUMN applied FORMAT A8

COLUMN name FORMAT A40
COLUMN file_type FORMAT A30
COLUMN pct_used FORMAT 999.99
COLUMN pct_reclaimable FORMAT 999.99
COLUMN number_of_files FORMAT 999,999

COLUMN originating_timestamp FORMAT A25
COLUMN message_text FORMAT A120
COLUMN message_level FORMAT 999
COLUMN problem_key FORMAT A60

COLUMN first_time FORMAT A20
COLUMN completion_time FORMAT A20

COLUMN error_count FORMAT 999,999
COLUMN archive_records FORMAT 999,999
COLUMN health_status FORMAT A80


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
PROMPT 2. ARCHIVE MODE CHECK
PROMPT ============================================================================

SELECT
    name AS database_name,
    log_mode,
    open_mode,
    force_logging
FROM v$database;


PROMPT
PROMPT ============================================================================
PROMPT 3. ARCHIVE DESTINATION ERRORS
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
PROMPT 4. ARCHIVE DESTINATION STATUS
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
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 5. DESTINATIONS NOT IN VALID STATE
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
PROMPT 6. ARCHIVE DESTINATION RUNTIME STATUS
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
PROMPT 7. ARCHIVE DESTINATION RUNTIME ERRORS
PROMPT ============================================================================
PROMPT Error details may be available in V$ARCHIVE_DEST.

SELECT
    s.dest_id,
    s.status,
    s.type,
    s.database_mode,
    s.recovery_mode,
    s.synchronization_status,
    s.gap_status,
    d.destination,
    d.error
FROM v$archive_dest_status s
LEFT JOIN v$archive_dest d
    ON s.dest_id = d.dest_id
WHERE d.error IS NOT NULL
  AND TRIM(d.error) IS NOT NULL
ORDER BY s.dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 8. FRA USAGE
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
PROMPT 9. FRA FILE TYPE USAGE
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
PROMPT 10. ARCHIVELOG FILE USAGE IN FRA
PROMPT ============================================================================

SELECT
    file_type,
    ROUND(percent_space_used, 2) AS pct_used,
    ROUND(percent_space_reclaimable, 2) AS pct_reclaimable,
    number_of_files
FROM v$flash_recovery_area_usage
WHERE file_type = 'ARCHIVED LOG';


PROMPT
PROMPT ============================================================================
PROMPT 11. RECENT ARCHIVED LOG ACTIVITY - LAST 24 HOURS
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
PROMPT 12. ARCHIVE LOGS WITH ZERO BACKUP COUNT
PROMPT ============================================================================
PROMPT Investigation indicator only.
PROMPT V$ARCHIVED_LOG can contain multiple records for the same sequence.

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
PROMPT 13. ARCHIVE ACTIVITY BY THREAD
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(DISTINCT sequence#) AS archive_sequences,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence,
    MIN(completion_time) AS first_archive,
    MAX(completion_time) AS last_archive
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 14. ARCHIVE DESTINATION ERROR COUNT
PROMPT ============================================================================

SELECT
    COUNT(*) AS destination_error_count
FROM v$archive_dest
WHERE error IS NOT NULL
  AND TRIM(error) IS NOT NULL;


PROMPT
PROMPT ============================================================================
PROMPT 15. ALERT LOG - ARCHIVE / ARCHIVER ERRORS
PROMPT ============================================================================
PROMPT Searches the ADR alert repository for archive-related messages.
PROMPT Exact message availability depends on ADR retention/version.

SELECT
    originating_timestamp,
    message_level,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
         UPPER(message_text) LIKE '%ARCHIV%'
      OR UPPER(message_text) LIKE '%ORA-00257%'
      OR UPPER(message_text) LIKE '%ORA-16014%'
      OR UPPER(message_text) LIKE '%ORA-16038%'
      OR UPPER(message_text) LIKE '%ORA-19504%'
      OR UPPER(message_text) LIKE '%ORA-27040%'
      OR UPPER(message_text) LIKE '%ORA-19809%'
      OR UPPER(message_text) LIKE '%ORA-19804%'
      )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================================
PROMPT 16. ORA ERRORS RELATED TO ARCHIVING - LAST 7 DAYS
PROMPT ============================================================================

SELECT
    originating_timestamp,
    message_level,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND (
         UPPER(message_text) LIKE '%ORA-00257%'
      OR UPPER(message_text) LIKE '%ORA-16014%'
      OR UPPER(message_text) LIKE '%ORA-16038%'
      OR UPPER(message_text) LIKE '%ORA-19504%'
      OR UPPER(message_text) LIKE '%ORA-27040%'
      OR UPPER(message_text) LIKE '%ORA-19809%'
      OR UPPER(message_text) LIKE '%ORA-19804%'
      )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================================
PROMPT 17. ALL ORA ERRORS IN ALERT LOG - LAST 24 HOURS
PROMPT ============================================================================
PROMPT Broad search for Oracle errors that may require correlation.

SELECT
    originating_timestamp,
    message_level,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND UPPER(message_text) LIKE '%ORA-%'
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================================
PROMPT 18. ARCHIVE DESTINATION STATUS SUMMARY
PROMPT ============================================================================

SELECT
    status,
    COUNT(*) AS destination_count
FROM v$archive_dest
GROUP BY status
ORDER BY status;


PROMPT
PROMPT ============================================================================
PROMPT 19. ARCHIVE DESTINATION ERROR SUMMARY
PROMPT ============================================================================

SELECT
    CASE
        WHEN COUNT(*) = 0
        THEN 'NO ARCHIVE DESTINATION ERRORS FOUND'
        ELSE 'ARCHIVE DESTINATION ERRORS FOUND'
    END AS destination_error_status,
    COUNT(*) AS error_count
FROM v$archive_dest
WHERE error IS NOT NULL
  AND TRIM(error) IS NOT NULL;


PROMPT
PROMPT ============================================================================
PROMPT 20. FRA HEALTH INDICATOR
PROMPT ============================================================================

SELECT
    CASE
        WHEN space_limit = 0
            THEN 'CHECK - FRA SPACE LIMIT IS ZERO'

        WHEN space_used / space_limit * 100 >= 95
            THEN 'CRITICAL - FRA USAGE >= 95%'

        WHEN space_used / space_limit * 100 >= 90
            THEN 'CHECK - FRA USAGE >= 90%'

        WHEN space_used / space_limit * 100 >= 80
            THEN 'REVIEW - FRA USAGE >= 80%'

        ELSE
            'OK - FRA USAGE BELOW 80%'
    END AS health_status,
    ROUND(
        space_used / NULLIF(space_limit, 0) * 100,
        2
    ) AS pct_used
FROM v$recovery_file_dest;


PROMPT
PROMPT ============================================================================
PROMPT 21. ARCHIVE ERROR HEALTH SUMMARY
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
        THEN 'CRITICAL/CHECK - ARCHIVE DESTINATION ERROR FOUND'

        WHEN EXISTS
        (
            SELECT 1
            FROM v$recovery_file_dest
            WHERE space_limit > 0
              AND space_used / space_limit * 100 >= 95
        )
        THEN 'CRITICAL - FRA USAGE >= 95%'

        WHEN EXISTS
        (
            SELECT 1
            FROM v$recovery_file_dest
            WHERE space_limit > 0
              AND space_used / space_limit * 100 >= 90
        )
        THEN 'CHECK - FRA USAGE >= 90%'

        ELSE
            'OK - NO MAJOR ARCHIVE ERROR INDICATOR FOUND'
    END AS health_status
FROM dual;


PROMPT
PROMPT ============================================================================
PROMPT 22. QUICK ARCHIVE ERROR CHECK
PROMPT ============================================================================

SELECT
    (SELECT COUNT(*)
       FROM v$archive_dest
      WHERE destination IS NOT NULL) AS configured_destinations,

    (SELECT COUNT(*)
       FROM v$archive_dest
      WHERE error IS NOT NULL
        AND TRIM(error) IS NOT NULL) AS destination_errors,

    (SELECT COUNT(*)
       FROM v$archived_log
      WHERE completion_time >= SYSDATE - 1) AS archive_records_24h,

    (SELECT COUNT(*)
       FROM v$archived_log
      WHERE completion_time >= SYSDATE - 1
        AND NVL(backup_count, 0) = 0) AS unbacked_archive_records_24h
FROM dual;


PROMPT
PROMPT ============================================================================
PROMPT 23. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] Check V$ARCHIVE_DEST for destination errors.
PROMPT [ ] Check V$ARCHIVE_DEST_STATUS for runtime status.
PROMPT [ ] Check FRA utilization.
PROMPT [ ] Check ARCHIVED LOG percentage in FRA.
PROMPT [ ] Check alert.log / V$DIAG_ALERT_EXT.
PROMPT [ ] Investigate ORA-00257 immediately if present.
PROMPT [ ] Investigate ORA-16014 / ORA-16038 for archive destination failures.
PROMPT [ ] Investigate ORA-19504 / ORA-27040 for file creation/storage issues.
PROMPT [ ] Investigate ORA-19809 / ORA-19804 for FRA pressure.
PROMPT [ ] Check filesystem / ASM space for archive destinations.
PROMPT [ ] Check archive activity by RAC thread.
PROMPT [ ] Check RMAN archive backup coverage.
PROMPT [ ] Check Data Guard transport status where applicable.
PROMPT [ ] Review database and storage alerts before deleting archive logs.
PROMPT [ ] Do not use DELETE ARCHIVELOG or ALTER SYSTEM ARCHIVE LOG commands
PROMPT     from this read-only diagnostic script.
PROMPT
PROMPT ============================================================================
PROMPT END OF ARCHIVE LOG ERROR CHECK
PROMPT ============================================================================


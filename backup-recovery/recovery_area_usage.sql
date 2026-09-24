-- ============================================================================
-- recovery_area_usage.sql
-- Oracle DBA Toolkit
--
-- Purpose:
--   Recovery Area / Fast Recovery Area (FRA) usage and health monitoring.
--
-- Covers:
--   - FRA configuration
--   - FRA space usage
--   - Space used / reclaimable
--   - Usage by file type
--   - Archive log usage
--   - Backup usage
--   - Flashback log usage
--   - Control file / SPFILE usage
--   - FRA pressure indicators
--   - Recent archive activity
--   - RMAN backup activity
--
-- Scope:
--   Read-only monitoring script.
--
-- Notes:
--   - FRA is commonly configured using DB_RECOVERY_FILE_DEST.
--   - Usage percentages are indicators and should be correlated with
--     backup, archive, flashback, and retention requirements.
--   - Reclaimable space does not necessarily mean space can be removed
--     immediately without considering recovery requirements.
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN db_name              FORMAT A15
COLUMN db_unique_name       FORMAT A25
COLUMN database_role        FORMAT A20
COLUMN open_mode            FORMAT A20
COLUMN recovery_dest        FORMAT A70
COLUMN recovery_file_dest   FORMAT A70

COLUMN space_limit_gb       FORMAT 999999990.00
COLUMN space_used_gb        FORMAT 999999990.00
COLUMN space_reclaimable_gb FORMAT 999999990.00
COLUMN free_space_gb        FORMAT 999999990.00
COLUMN used_pct             FORMAT 990.00
COLUMN reclaimable_pct      FORMAT 990.00

COLUMN file_type            FORMAT A30
COLUMN number_of_files      FORMAT 999999999
COLUMN used_gb              FORMAT 999999990.00
COLUMN percent_space_used   FORMAT 990.00

COLUMN status               FORMAT A15
COLUMN name                 FORMAT A80
COLUMN tablespace_name      FORMAT A25
COLUMN sequence#            FORMAT 999999999
COLUMN thread#              FORMAT 999
COLUMN completion_time      FORMAT A20
COLUMN first_time           FORMAT A20
COLUMN next_time            FORMAT A20
COLUMN input_type           FORMAT A25
COLUMN output_device_type   FORMAT A20
COLUMN backup_size_gb       FORMAT 999999990.00
COLUMN elapsed_minutes      FORMAT 9999990.00

COLUMN warning_level        FORMAT A35
COLUMN health               FORMAT A45


PROMPT
PROMPT ============================================================================
PROMPT 1. DATABASE INFORMATION
PROMPT ============================================================================

SELECT
    name AS db_name,
    db_unique_name,
    database_role,
    open_mode,
    log_mode,
    flashback_on
FROM v$database;


PROMPT
PROMPT ============================================================================
PROMPT 2. RECOVERY AREA CONFIGURATION
PROMPT ============================================================================

SELECT
    name AS db_name,
    db_unique_name,
    recovery_file_dest,
    ROUND(recovery_file_dest_size / 1024 / 1024 / 1024, 2)
        AS configured_size_gb
FROM v$database;


PROMPT
PROMPT ============================================================================
PROMPT 3. FRA SPACE SUMMARY
PROMPT ============================================================================

SELECT
    ROUND(space_limit / 1024 / 1024 / 1024, 2)
        AS space_limit_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2)
        AS space_used_gb,
    ROUND(space_reclaimable / 1024 / 1024 / 1024, 2)
        AS space_reclaimable_gb,
    ROUND(
        (space_limit - space_used) / 1024 / 1024 / 1024,
        2
    ) AS free_space_gb,
    ROUND(
        space_used / NULLIF(space_limit, 0) * 100,
        2
    ) AS used_pct,
    ROUND(
        space_reclaimable / NULLIF(space_limit, 0) * 100,
        2
    ) AS reclaimable_pct
FROM v$recovery_file_dest;


PROMPT
PROMPT ============================================================================
PROMPT 4. FRA HEALTH INDICATOR
PROMPT ============================================================================

SELECT
    ROUND(space_limit / 1024 / 1024 / 1024, 2) AS space_limit_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS space_used_gb,
    ROUND(space_reclaimable / 1024 / 1024 / 1024, 2)
        AS space_reclaimable_gb,
    ROUND(space_used / NULLIF(space_limit, 0) * 100, 2)
        AS used_pct,
    CASE
        WHEN space_limit = 0
            THEN 'CHECK - FRA NOT CONFIGURED'
        WHEN space_used / space_limit * 100 >= 95
            THEN 'CRITICAL - FRA >= 95%'
        WHEN space_used / space_limit * 100 >= 90
            THEN 'WARNING - FRA >= 90%'
        WHEN space_used / space_limit * 100 >= 80
            THEN 'REVIEW - FRA >= 80%'
        ELSE 'OK - FRA BELOW 80%'
    END AS health
FROM v$recovery_file_dest;


PROMPT
PROMPT ============================================================================
PROMPT 5. FRA FILE TYPE USAGE
PROMPT ============================================================================

SELECT
    file_type,
    number_of_files,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(
        percent_space_used,
        2
    ) AS percent_space_used,
    ROUND(
        percent_space_reclaimable,
        2
    ) AS percent_reclaimable
FROM v$flash_recovery_area_usage
ORDER BY
    space_used DESC;


PROMPT
PROMPT ============================================================================
PROMPT 6. FRA FILE TYPE USAGE WITH STATUS
PROMPT ============================================================================

SELECT
    file_type,
    number_of_files,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(percent_space_used, 2) AS percent_used,
    ROUND(percent_space_reclaimable, 2) AS percent_reclaimable,
    CASE
        WHEN percent_space_used >= 50
            THEN 'CHECK - HIGH FRA CONSUMER'
        WHEN percent_space_used >= 25
            THEN 'REVIEW'
        ELSE 'OK'
    END AS health
FROM v$flash_recovery_area_usage
ORDER BY
    percent_space_used DESC;


PROMPT
PROMPT ============================================================================
PROMPT 7. ARCHIVED LOG USAGE IN FRA
PROMPT ============================================================================

SELECT
    file_type,
    number_of_files,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(percent_space_used, 2) AS percent_used,
    ROUND(percent_space_reclaimable, 2) AS percent_reclaimable
FROM v$flash_recovery_area_usage
WHERE file_type = 'ARCHIVED LOG';


PROMPT
PROMPT ============================================================================
PROMPT 8. FLASHBACK LOG USAGE
PROMPT ============================================================================

SELECT
    file_type,
    number_of_files,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(percent_space_used, 2) AS percent_used,
    ROUND(percent_space_reclaimable, 2) AS percent_reclaimable
FROM v$flash_recovery_area_usage
WHERE file_type = 'FLASHBACK LOG';


PROMPT
PROMPT ============================================================================
PROMPT 9. BACKUP USAGE IN FRA
PROMPT ============================================================================

SELECT
    file_type,
    number_of_files,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(percent_space_used, 2) AS percent_used,
    ROUND(percent_space_reclaimable, 2) AS percent_reclaimable
FROM v$flash_recovery_area_usage
WHERE file_type LIKE '%BACKUP%'
ORDER BY
    space_used DESC;


PROMPT
PROMPT ============================================================================
PROMPT 10. CONTROL FILE / SPFILE USAGE
PROMPT ============================================================================

SELECT
    file_type,
    number_of_files,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(percent_space_used, 2) AS percent_used,
    ROUND(percent_space_reclaimable, 2) AS percent_reclaimable
FROM v$flash_recovery_area_usage
WHERE file_type IN
(
    'CONTROL FILE',
    'FOREIGN ARCHIVED LOG',
    'CONTROL FILE AUTOBACKUP'
)
ORDER BY
    space_used DESC;


PROMPT
PROMPT ============================================================================
PROMPT 11. FRA DESTINATION DETAILS
PROMPT ============================================================================

SELECT
    name,
    space_limit,
    space_used,
    space_reclaimable,
    number_of_files
FROM v$recovery_file_dest;


PROMPT
PROMPT ============================================================================
PROMPT 12. RECENT ARCHIVE LOG ACTIVITY - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS archive_count,
    ROUND(SUM(blocks * block_size) / 1024 / 1024 / 1024, 2)
        AS archive_gb
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 13. ARCHIVE LOG ACTIVITY BY HOUR - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    TO_CHAR(
        completion_time,
        'YYYY-MM-DD HH24'
    ) AS archive_hour,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024 / 1024,
        2
    ) AS archive_gb
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24')
ORDER BY
    archive_hour;


PROMPT
PROMPT ============================================================================
PROMPT 14. ARCHIVE LOG ACTIVITY - LAST 7 DAYS
PROMPT ============================================================================

SELECT
    TRUNC(completion_time) AS archive_date,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024 / 1024,
        2
    ) AS archive_gb
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
GROUP BY TRUNC(completion_time)
ORDER BY archive_date DESC;


PROMPT
PROMPT ============================================================================
PROMPT 15. RMAN BACKUP ACTIVITY - LAST 7 DAYS
PROMPT ============================================================================

SELECT
    input_type,
    status,
    COUNT(*) AS backup_jobs,
    ROUND(
        SUM(output_bytes) / 1024 / 1024 / 1024,
        2
    ) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
GROUP BY
    input_type,
    status
ORDER BY
    input_type,
    status;


PROMPT
PROMPT ============================================================================
PROMPT 16. LATEST RMAN BACKUP JOBS
PROMPT ============================================================================

SELECT
    start_time,
    end_time,
    input_type,
    status,
    output_device_type,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2)
        AS backup_size_gb,
    ROUND(elapsed_seconds / 60, 2)
        AS elapsed_minutes
FROM
(
    SELECT
        start_time,
        end_time,
        input_type,
        status,
        output_device_type,
        output_bytes,
        elapsed_seconds
    FROM v$rman_backup_job_details
    ORDER BY start_time DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================================
PROMPT 17. RMAN BACKUP FAILURES - LAST 7 DAYS
PROMPT ============================================================================

SELECT
    start_time,
    end_time,
    input_type,
    status,
    output_device_type,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2)
        AS backup_size_gb,
    ROUND(elapsed_seconds / 60, 2)
        AS elapsed_minutes
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
  AND status <> 'COMPLETED'
ORDER BY start_time DESC;


PROMPT
PROMPT ============================================================================
PROMPT 18. ARCHIVE LOGS WITH ZERO RMAN BACKUP COUNT
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    backup_count
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
  AND NVL(backup_count, 0) = 0
ORDER BY
    thread#,
    sequence# DESC;


PROMPT
PROMPT ============================================================================
PROMPT 19. FRA SPACE RECLAIMABLE
PROMPT ============================================================================

SELECT
    ROUND(space_limit / 1024 / 1024 / 1024, 2)
        AS space_limit_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2)
        AS space_used_gb,
    ROUND(space_reclaimable / 1024 / 1024 / 1024, 2)
        AS reclaimable_gb,
    ROUND(
        space_reclaimable /
        NULLIF(space_limit, 0) * 100,
        2
    ) AS reclaimable_pct
FROM v$recovery_file_dest;


PROMPT
PROMPT ============================================================================
PROMPT 20. FRA PRESSURE CHECK
PROMPT ============================================================================

SELECT
    ROUND(space_limit / 1024 / 1024 / 1024, 2) AS limit_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(
        (space_limit - space_used) /
        1024 / 1024 / 1024,
        2
    ) AS free_gb,
    ROUND(space_used / NULLIF(space_limit, 0) * 100, 2)
        AS used_pct,
    CASE
        WHEN space_used / NULLIF(space_limit, 0) * 100 >= 95
            THEN 'CRITICAL'
        WHEN space_used / NULLIF(space_limit, 0) * 100 >= 90
            THEN 'WARNING'
        WHEN space_used / NULLIF(space_limit, 0) * 100 >= 80
            THEN 'REVIEW'
        ELSE 'NORMAL'
    END AS warning_level
FROM v$recovery_file_dest;


PROMPT
PROMPT ============================================================================
PROMPT 21. TOP FRA SPACE CONSUMERS
PROMPT ============================================================================

SELECT
    file_type,
    number_of_files,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(percent_space_used, 2) AS percent_used,
    ROUND(percent_space_reclaimable, 2) AS percent_reclaimable
FROM v$flash_recovery_area_usage
ORDER BY
    space_used DESC
FETCH FIRST 10 ROWS ONLY;


PROMPT
PROMPT ============================================================================
PROMPT 22. FRA CONFIGURATION PARAMETERS
PROMPT ============================================================================

SELECT
    name,
    value
FROM v$parameter
WHERE name IN
(
    'db_recovery_file_dest',
    'db_recovery_file_dest_size',
    'db_flashback_retention_target'
)
ORDER BY name;


PROMPT
PROMPT ============================================================================
PROMPT 23. FLASHBACK STATUS
PROMPT ============================================================================

SELECT
    flashback_on,
    log_mode
FROM v$database;


PROMPT
PROMPT ============================================================================
PROMPT 24. RECENT FRA-RELATED ALERT LOG ERRORS
PROMPT ============================================================================

SELECT
    originating_timestamp,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND
  (
       UPPER(message_text) LIKE '%ORA-198%'
    OR UPPER(message_text) LIKE '%ORA-387%'
    OR UPPER(message_text) LIKE '%RECOVERY AREA%'
    OR UPPER(message_text) LIKE '%FLASHBACK%'
  )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================================
PROMPT 25. FRA HEALTH SUMMARY
PROMPT ============================================================================

SELECT
    ROUND(space_limit / 1024 / 1024 / 1024, 2) AS limit_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(space_reclaimable / 1024 / 1024 / 1024, 2)
        AS reclaimable_gb,
    ROUND(
        (space_limit - space_used) /
        1024 / 1024 / 1024,
        2
    ) AS free_gb,
    ROUND(
        space_used / NULLIF(space_limit, 0) * 100,
        2
    ) AS used_pct,
    CASE
        WHEN space_limit = 0
            THEN 'CHECK - FRA NOT CONFIGURED'
        WHEN space_used / space_limit * 100 >= 95
            THEN 'CRITICAL - FRA PRESSURE'
        WHEN space_used / space_limit * 100 >= 90
            THEN 'WARNING - HIGH FRA USAGE'
        WHEN space_used / space_limit * 100 >= 80
            THEN 'REVIEW - FRA USAGE'
        ELSE 'OK - FRA USAGE'
    END AS health
FROM v$recovery_file_dest;


PROMPT
PROMPT ============================================================================
PROMPT 26. QUICK RECOVERY AREA CHECK
PROMPT ============================================================================

SELECT
    ROUND(space_limit / 1024 / 1024 / 1024, 2) AS limit_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(
        (space_limit - space_used) /
        1024 / 1024 / 1024,
        2
    ) AS free_gb,
    ROUND(
        space_used / NULLIF(space_limit, 0) * 100,
        2
    ) AS used_pct,
    ROUND(
        space_reclaimable / NULLIF(space_limit, 0) * 100,
        2
    ) AS reclaimable_pct
FROM v$recovery_file_dest;


PROMPT
PROMPT ============================================================================
PROMPT 27. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] Check DB_RECOVERY_FILE_DEST and DB_RECOVERY_FILE_DEST_SIZE.
PROMPT [ ] Check FRA used percentage.
PROMPT [ ] Identify the largest FRA file type.
PROMPT [ ] Check ARCHIVED LOG growth.
PROMPT [ ] Check FLASHBACK LOG growth if Flashback is enabled.
PROMPT [ ] Check RMAN backup activity and failures.
PROMPT [ ] Check archive destination status.
PROMPT [ ] Check for ORA-19809 / ORA-19804 / ORA-19815 errors.
PROMPT [ ] Check whether reclaimable FRA space is available.
PROMPT [ ] Verify RMAN retention policy before deleting backups.
PROMPT [ ] Confirm archive logs required for Data Guard are not removed.
PROMPT [ ] Check Flashback retention requirements.
PROMPT [ ] Review backup and archive generation trends.
PROMPT [ ] Increase FRA size when workload/recovery requirements justify it.
PROMPT [ ] Do not manually delete FRA files from the filesystem.
PROMPT [ ] Use RMAN for backup/archive cleanup where appropriate.
PROMPT
PROMPT ============================================================================
PROMPT END OF RECOVERY AREA USAGE CHECK
PROMPT ============================================================================


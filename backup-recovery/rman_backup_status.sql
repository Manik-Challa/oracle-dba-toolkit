-- ============================================================
-- RMAN BACKUP STATUS
-- File: backup-recovery/rman_backup_status.sql
--
-- Purpose:
--   Monitor RMAN backup status, recent backup activity,
--   backup duration, backup size, failed backups and
--   backup coverage.
--
-- Covers:
--   1. Database information
--   2. Recent RMAN backup jobs
--   3. Backup status by type
--   4. Backup size summary
--   5. Backup duration
--   6. Failed / incomplete backups
--   7. Recent database backups
--   8. Recent archive log backups
--   9. Backup pieces
--  10. Backup coverage by day
--  11. Latest successful backup
--  12. RMAN health summary
--
-- Notes:
--   * Read-only script.
--   * Uses RMAN repository views.
--   * V$ views show the current database's RMAN metadata.
--   * For a recovery catalog, query the corresponding RC_*
--     views from the catalog database.
--   * Backup timestamps are repository metadata timestamps.
--
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN db_name            FORMAT A12
COLUMN db_unique_name     FORMAT A20
COLUMN backup_type        FORMAT A15
COLUMN status              FORMAT A15
COLUMN device_type         FORMAT A15
COLUMN start_time          FORMAT A22
COLUMN end_time            FORMAT A22
COLUMN duration_min        FORMAT 999,999.99
COLUMN input_gb            FORMAT 999,999.99
COLUMN output_gb           FORMAT 999,999.99
COLUMN pieces              FORMAT 999,999
COLUMN files               FORMAT 999,999
COLUMN completion_time     FORMAT A22
COLUMN handle              FORMAT A80
COLUMN tag                 FORMAT A30
COLUMN operation            FORMAT A20
COLUMN object_type         FORMAT A20

PROMPT
PROMPT ============================================================
PROMPT                 RMAN BACKUP STATUS
PROMPT ============================================================
PROMPT


-- ============================================================
-- 1. DATABASE INFORMATION
-- ============================================================

PROMPT ============================================================
PROMPT 1. DATABASE INFORMATION
PROMPT ============================================================

SELECT
    name AS db_name,
    db_unique_name,
    database_role,
    open_mode,
    log_mode
FROM v$database;


-- ============================================================
-- 2. RMAN BACKUP SUMMARY - LAST 7 DAYS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. RMAN BACKUP SUMMARY - LAST 7 DAYS
PROMPT ============================================================

SELECT
    backup_type,
    status,
    COUNT(*) AS backup_sets,
    SUM(pieces) AS pieces,
    SUM(files) AS files,
    ROUND(SUM(input_bytes) / 1024 / 1024 / 1024, 2)
        AS input_gb,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2)
        AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
GROUP BY
    backup_type,
    status
ORDER BY
    backup_type,
    status;


-- ============================================================
-- 3. RECENT RMAN BACKUP JOBS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. RECENT RMAN BACKUP JOBS
PROMPT ============================================================

SELECT
    session_key,
    input_type AS backup_type,
    status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    ROUND(
        elapsed_seconds / 60,
        2
    ) AS duration_min,
    ROUND(
        input_bytes / 1024 / 1024 / 1024,
        2
    ) AS input_gb,
    ROUND(
        output_bytes / 1024 / 1024 / 1024,
        2
    ) AS output_gb,
    output_device_type AS device_type
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
ORDER BY start_time DESC;


-- ============================================================
-- 4. RECENT SUCCESSFUL BACKUPS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. RECENT SUCCESSFUL BACKUPS
PROMPT ============================================================

SELECT
    session_key,
    input_type AS backup_type,
    status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    ROUND(
        elapsed_seconds / 60,
        2
    ) AS duration_min,
    ROUND(
        input_bytes / 1024 / 1024 / 1024,
        2
    ) AS input_gb,
    ROUND(
        output_bytes / 1024 / 1024 / 1024,
        2
    ) AS output_gb,
    output_device_type AS device_type
FROM v$rman_backup_job_details
WHERE status = 'COMPLETED'
  AND start_time >= SYSDATE - 7
ORDER BY start_time DESC;


-- ============================================================
-- 5. FAILED / INCOMPLETE BACKUPS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. FAILED / INCOMPLETE BACKUPS
PROMPT ============================================================

SELECT
    session_key,
    input_type AS backup_type,
    status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    ROUND(
        elapsed_seconds / 60,
        2
    ) AS duration_min,
    ROUND(
        input_bytes / 1024 / 1024 / 1024,
        2
    ) AS input_gb,
    output_device_type AS device_type
FROM v$rman_backup_job_details
WHERE status <> 'COMPLETED'
  AND start_time >= SYSDATE - 7
ORDER BY start_time DESC;


-- ============================================================
-- 6. DATABASE BACKUPS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. RECENT DATABASE BACKUPS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    incremental_level,
    status,
    pieces,
    ROUND(
        input_bytes / 1024 / 1024 / 1024,
        2
    ) AS input_gb,
    ROUND(
        output_bytes / 1024 / 1024 / 1024,
        2
    ) AS output_gb,
    device_type
FROM v$backup_set_details
WHERE backup_type = 'D'
ORDER BY start_time DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================
-- 7. INCREMENTAL BACKUP SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. INCREMENTAL BACKUP SUMMARY
PROMPT ============================================================

SELECT
    incremental_level,
    status,
    COUNT(*) AS backup_sets,
    SUM(pieces) AS pieces,
    ROUND(
        SUM(input_bytes) / 1024 / 1024 / 1024,
        2
    ) AS input_gb,
    ROUND(
        SUM(output_bytes) / 1024 / 1024 / 1024,
        2
    ) AS output_gb
FROM v$backup_set_details
WHERE backup_type = 'D'
  AND start_time >= SYSDATE - 7
GROUP BY
    incremental_level,
    status
ORDER BY
    incremental_level,
    status;


-- ============================================================
-- 8. ARCHIVE LOG BACKUPS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. RECENT ARCHIVE LOG BACKUPS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    status,
    pieces,
    ROUND(
        input_bytes / 1024 / 1024 / 1024,
        2
    ) AS input_gb,
    ROUND(
        output_bytes / 1024 / 1024 / 1024,
        2
    ) AS output_gb,
    device_type
FROM v$backup_set_details
WHERE backup_type = 'L'
ORDER BY start_time DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================
-- 9. ARCHIVE LOG BACKUP SUMMARY - LAST 7 DAYS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. ARCHIVE LOG BACKUP SUMMARY - LAST 7 DAYS
PROMPT ============================================================

SELECT
    status,
    COUNT(*) AS backup_sets,
    SUM(pieces) AS pieces,
    ROUND(
        SUM(input_bytes) / 1024 / 1024 / 1024,
        2
    ) AS input_gb,
    ROUND(
        SUM(output_bytes) / 1024 / 1024 / 1024,
        2
    ) AS output_gb
FROM v$backup_set_details
WHERE backup_type = 'L'
  AND start_time >= SYSDATE - 7
GROUP BY status
ORDER BY status;


-- ============================================================
-- 10. BACKUP PIECES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. RECENT BACKUP PIECES
PROMPT ============================================================

SELECT
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    status,
    device_type,
    ROUND(
        bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    handle,
    tag
FROM v$backup_piece
WHERE completion_time >= SYSDATE - 7
ORDER BY completion_time DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================
-- 11. BACKUP COVERAGE BY DAY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. BACKUP COVERAGE BY DAY
PROMPT ============================================================

SELECT
    TRUNC(start_time) AS backup_date,
    COUNT(*) AS backup_jobs,
    SUM(
        CASE
            WHEN status = 'COMPLETED'
            THEN 1
            ELSE 0
        END
    ) AS completed_jobs,
    SUM(
        CASE
            WHEN status <> 'COMPLETED'
            THEN 1
            ELSE 0
        END
    ) AS failed_jobs,
    ROUND(
        SUM(output_bytes) / 1024 / 1024 / 1024,
        2
    ) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
GROUP BY TRUNC(start_time)
ORDER BY backup_date DESC;


-- ============================================================
-- 12. LATEST SUCCESSFUL DATABASE BACKUP
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. LATEST SUCCESSFUL DATABASE BACKUP
PROMPT ============================================================

SELECT
    MAX(completion_time) AS latest_database_backup
FROM v$backup_set_details
WHERE backup_type = 'D'
  AND status = 'A';


-- ============================================================
-- 13. LATEST SUCCESSFUL ARCHIVE LOG BACKUP
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. LATEST SUCCESSFUL ARCHIVE LOG BACKUP
PROMPT ============================================================

SELECT
    MAX(completion_time) AS latest_archive_log_backup
FROM v$backup_set_details
WHERE backup_type = 'L'
  AND status = 'A';


-- ============================================================
-- 14. BACKUPS WITH INPUT/OUTPUT SIZE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. BACKUP SIZE AND COMPRESSION SUMMARY
PROMPT ============================================================

SELECT
    input_type AS backup_type,
    COUNT(*) AS backup_jobs,
    ROUND(
        SUM(input_bytes) / 1024 / 1024 / 1024,
        2
    ) AS input_gb,
    ROUND(
        SUM(output_bytes) / 1024 / 1024 / 1024,
        2
    ) AS output_gb,
    ROUND(
        SUM(output_bytes)
        / NULLIF(SUM(input_bytes), 0)
        * 100,
        2
    ) AS output_vs_input_pct
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
GROUP BY input_type
ORDER BY input_gb DESC;


-- ============================================================
-- 15. BACKUP DEVICE DISTRIBUTION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. BACKUP DEVICE DISTRIBUTION
PROMPT ============================================================

SELECT
    output_device_type AS device_type,
    COUNT(*) AS backup_jobs,
    ROUND(
        SUM(output_bytes) / 1024 / 1024 / 1024,
        2
    ) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
GROUP BY output_device_type
ORDER BY output_gb DESC;


-- ============================================================
-- 16. BACKUP TAG SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. BACKUP TAG SUMMARY
PROMPT ============================================================

SELECT
    tag,
    COUNT(*) AS backup_pieces,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM v$backup_piece
WHERE completion_time >= SYSDATE - 7
GROUP BY tag
ORDER BY size_gb DESC;


-- ============================================================
-- 17. BACKUP OPTIMIZATION / DELETION STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. BACKUP PIECE STATUS SUMMARY
PROMPT ============================================================

SELECT
    status,
    COUNT(*) AS pieces,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM v$backup_piece
WHERE completion_time >= SYSDATE - 30
GROUP BY status
ORDER BY status;


-- ============================================================
-- 18. RMAN BACKUP JOB DURATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. LONGEST RMAN BACKUP JOBS
PROMPT ============================================================

SELECT
    session_key,
    input_type AS backup_type,
    status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    ROUND(
        elapsed_seconds / 60,
        2
    ) AS duration_min,
    ROUND(
        input_bytes / 1024 / 1024 / 1024,
        2
    ) AS input_gb,
    ROUND(
        output_bytes / 1024 / 1024 / 1024,
        2
    ) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
ORDER BY elapsed_seconds DESC
FETCH FIRST 20 ROWS ONLY;


-- ============================================================
-- 19. RECENT FAILED BACKUP DETAILS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 19. RECENT FAILED BACKUP DETAILS
PROMPT ============================================================

SELECT
    session_key,
    input_type AS backup_type,
    status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    output_device_type AS device_type,
    ROUND(
        elapsed_seconds / 60,
        2
    ) AS duration_min
FROM v$rman_backup_job_details
WHERE status IN (
    'FAILED',
    'COMPLETED WITH ERRORS'
)
AND start_time >= SYSDATE - 30
ORDER BY start_time DESC;


-- ============================================================
-- 20. RMAN HEALTH SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 20. RMAN HEALTH SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS backup_jobs_7d,

    SUM(
        CASE
            WHEN status = 'COMPLETED'
            THEN 1
            ELSE 0
        END
    ) AS completed_jobs,

    SUM(
        CASE
            WHEN status <> 'COMPLETED'
            THEN 1
            ELSE 0
        END
    ) AS incomplete_jobs,

    ROUND(
        SUM(output_bytes) / 1024 / 1024 / 1024,
        2
    ) AS backup_output_gb,

    MAX(end_time) AS latest_backup_end
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7;


-- ============================================================
-- 21. QUICK BACKUP HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 21. QUICK BACKUP HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN MAX(completion_time) IS NULL
            THEN 'NO SUCCESSFUL DATABASE BACKUP FOUND'
        WHEN MAX(completion_time) < SYSDATE - 1
            THEN 'DATABASE BACKUP OLDER THAN 24 HOURS'
        ELSE 'RECENT DATABASE BACKUP AVAILABLE'
    END AS database_backup_status,

    MAX(completion_time) AS latest_database_backup
FROM v$backup_set_details
WHERE backup_type = 'D'
  AND status = 'A';


PROMPT
PROMPT ============================================================
PROMPT RMAN BACKUP DBA CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT 1. Verify the latest successful database backup.
PROMPT 2. Verify recent archive log backups.
PROMPT 3. Investigate FAILED or incomplete backup jobs.
PROMPT 4. Review backup duration for unusual increases.
PROMPT 5. Review input/output size changes.
PROMPT 6. Confirm the expected backup device is being used.
PROMPT 7. Check backup piece status and accessibility.
PROMPT 8. Validate backup retention against the recovery policy.
PROMPT 9. Perform RMAN VALIDATE separately when required.
PROMPT 10. Confirm restore/recovery procedures are tested.
PROMPT
PROMPT IMPORTANT:
PROMPT A successful RMAN backup does not by itself prove that
PROMPT the database can be successfully restored.
PROMPT Restore validation and recovery testing are separate steps.
PROMPT
PROMPT ============================================================
PROMPT END OF RMAN BACKUP STATUS
PROMPT ============================================================


-- ============================================================
-- RMAN FAILED BACKUPS
-- Oracle DBA Toolkit
--
-- Purpose:
--   Identify failed, incomplete, expired and problematic
--   RMAN backup operations from the control-file repository.
--
-- Read-only monitoring script.
--
-- Notes:
--   - Uses RMAN control-file repository views.
--   - A failed/incomplete backup should be investigated before
--     assuming the database is unprotected.
--   - Backup metadata alone does not prove restoreability.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

COLUMN db_name              FORMAT A12
COLUMN dbid                 FORMAT 999999999999999
COLUMN backup_start         FORMAT A20
COLUMN backup_end           FORMAT A20
COLUMN status                FORMAT A12
COLUMN input_type            FORMAT A18
COLUMN output_device_type   FORMAT A18
COLUMN elapsed_min          FORMAT 9999990.99
COLUMN input_gb              FORMAT 9999990.99
COLUMN output_gb             FORMAT 9999990.99
COLUMN piece_count          FORMAT 999999
COLUMN session_key          FORMAT 999999999999
COLUMN session_recid        FORMAT 999999999999
COLUMN session_stamp        FORMAT 999999999999999999

PROMPT
PROMPT ============================================================
PROMPT RMAN FAILED BACKUPS - DATABASE INFORMATION
PROMPT ============================================================

SELECT
    name AS db_name,
    dbid,
    open_mode,
    database_role
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 1. FAILED / PROBLEMATIC RMAN JOBS - LAST 7 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    TO_CHAR(end_time,   'YYYY-MM-DD HH24:MI:SS') AS backup_end,
    status,
    input_type,
    output_device_type,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_min,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
  AND status <> 'COMPLETED'
ORDER BY start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 2. RMAN JOB STATUS SUMMARY - LAST 7 DAYS
PROMPT ============================================================

SELECT
    status,
    input_type,
    COUNT(*) AS job_count,
    ROUND(SUM(input_bytes) / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(SUM(elapsed_seconds) / 3600, 2) AS elapsed_hours
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
GROUP BY
    status,
    input_type
ORDER BY
    status,
    input_type;


PROMPT
PROMPT ============================================================
PROMPT 3. FAILED RMAN JOBS - LAST 30 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    TO_CHAR(end_time,   'YYYY-MM-DD HH24:MI:SS') AS backup_end,
    status,
    input_type,
    output_device_type,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_min,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status IN ('FAILED', 'COMPLETED WITH ERRORS')
ORDER BY start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 4. RMAN BACKUP SETS NOT AVAILABLE
PROMPT ============================================================

SELECT
    bs.recid,
    bs.set_stamp,
    bs.set_count,
    bs.backup_type,
    bs.incremental_level,
    bs.status,
    TO_CHAR(bs.start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    TO_CHAR(bs.completion_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_end,
    bs.pieces
FROM v$backup_set bs
WHERE bs.status <> 'A'
ORDER BY bs.start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 5. UNAVAILABLE / EXPIRED BACKUP PIECES
PROMPT ============================================================

SELECT
    bp.recid,
    bp.set_stamp,
    bp.set_count,
    bp.status,
    bp.device_type,
    bp.handle,
    ROUND(bp.bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_piece bp
WHERE bp.status <> 'A'
ORDER BY bp.recid DESC;


PROMPT
PROMPT ============================================================
PROMPT 6. BACKUP PIECES WITH ERROR INFORMATION
PROMPT ============================================================

SELECT
    bp.recid,
    bp.set_stamp,
    bp.set_count,
    bp.status,
    bp.device_type,
    bp.handle,
    bp.completion_time,
    bp.elapsed_seconds,
    ROUND(bp.bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_piece bp
WHERE bp.status <> 'A'
ORDER BY bp.completion_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. RECENT INCOMPLETE DATABASE BACKUPS
PROMPT ============================================================

SELECT
    TO_CHAR(bs.start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    TO_CHAR(bs.completion_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_end,
    bs.status,
    bs.backup_type,
    bs.incremental_level,
    bs.pieces,
    ROUND(bs.elapsed_seconds / 60, 2) AS elapsed_min
FROM v$backup_set_details bs
WHERE bs.start_time >= SYSDATE - 30
  AND bs.status <> 'AVAILABLE'
ORDER BY bs.start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. FAILED / INCOMPLETE ARCHIVE LOG BACKUPS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_end,
    status,
    input_type,
    output_device_type,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_min,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND input_type = 'ARCHIVELOG'
  AND status <> 'COMPLETED'
ORDER BY start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. RMAN BACKUP JOBS BY STATUS - LAST 30 DAYS
PROMPT ============================================================

SELECT
    status,
    COUNT(*) AS jobs,
    MIN(start_time) AS first_job,
    MAX(start_time) AS last_job
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
GROUP BY status
ORDER BY jobs DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. RECENT RMAN BACKUP JOBS FOR INVESTIGATION
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    TO_CHAR(end_time,   'YYYY-MM-DD HH24:MI:SS') AS backup_end,
    status,
    input_type,
    output_device_type,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_min,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 3
ORDER BY start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 11. BACKUP PIECES MARKED EXPIRED
PROMPT ============================================================

SELECT
    COUNT(*) AS expired_pieces,
    ROUND(NVL(SUM(bytes), 0) / 1024 / 1024 / 1024, 2) AS expired_gb
FROM v$backup_piece
WHERE status = 'X';


PROMPT
PROMPT ============================================================
PROMPT 12. BACKUP PIECES UNAVAILABLE
PROMPT ============================================================

SELECT
    COUNT(*) AS unavailable_pieces,
    ROUND(NVL(SUM(bytes), 0) / 1024 / 1024 / 1024, 2) AS unavailable_gb
FROM v$backup_piece
WHERE status = 'U';


PROMPT
PROMPT ============================================================
PROMPT 13. FAILED JOBS BY INPUT TYPE
PROMPT ============================================================

SELECT
    input_type,
    COUNT(*) AS failed_jobs
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status <> 'COMPLETED'
GROUP BY input_type
ORDER BY failed_jobs DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. FAILED JOBS BY DEVICE TYPE
PROMPT ============================================================

SELECT
    output_device_type,
    COUNT(*) AS failed_jobs
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status <> 'COMPLETED'
GROUP BY output_device_type
ORDER BY failed_jobs DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. RMAN BACKUP HEALTH SUMMARY
PROMPT ============================================================

SELECT
    (SELECT COUNT(*)
       FROM v$rman_backup_job_details
      WHERE start_time >= SYSDATE - 7
        AND status <> 'COMPLETED') AS problematic_jobs_7d,

    (SELECT COUNT(*)
       FROM v$backup_piece
      WHERE status = 'X') AS expired_pieces,

    (SELECT COUNT(*)
       FROM v$backup_piece
      WHERE status = 'U') AS unavailable_pieces,

    (SELECT COUNT(*)
       FROM v$backup_set
      WHERE status <> 'A') AS unavailable_backup_sets
FROM dual;


PROMPT
PROMPT ============================================================
PROMPT 16. QUICK RMAN FAILURE CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN problematic_jobs = 0
         AND expired_pieces = 0
         AND unavailable_pieces = 0
        THEN 'HEALTHY - NO RMAN PROBLEMS DETECTED'
        ELSE 'INVESTIGATE - RMAN BACKUP ISSUES FOUND'
    END AS rman_health
FROM (
    SELECT
        (SELECT COUNT(*)
           FROM v$rman_backup_job_details
          WHERE start_time >= SYSDATE - 7
            AND status <> 'COMPLETED') AS problematic_jobs,

        (SELECT COUNT(*)
           FROM v$backup_piece
          WHERE status = 'X') AS expired_pieces,

        (SELECT COUNT(*)
           FROM v$backup_piece
          WHERE status = 'U') AS unavailable_pieces
    FROM dual
);


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT 1. Check failed RMAN job status and start/end time.
PROMPT 2. Review RMAN output/log for the actual RMAN- / ORA- error.
PROMPT 3. Check backup destination filesystem / ASM / FRA capacity.
PROMPT 4. Check archive log generation and backup coverage.
PROMPT 5. Check media manager / SBT errors if using tape.
PROMPT 6. Check RMAN channels and device configuration.
PROMPT 7. Check expired or unavailable backup pieces.
PROMPT 8. Verify backup retention policy and recovery window.
PROMPT 9. Run RMAN CROSSCHECK when appropriate.
PROMPT 10. Validate restoreability separately from backup metadata.
PROMPT
PROMPT IMPORTANT:
PROMPT A failed RMAN job does not automatically mean the database
PROMPT has no usable backup. Review backup sets, pieces, retention,
PROMPT archive logs and restore requirements before taking action.
PROMPT
PROMPT ============================================================
PROMPT END OF RMAN FAILED BACKUPS CHECK
PROMPT ============================================================


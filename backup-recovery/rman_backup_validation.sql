-- ============================================================
-- RMAN BACKUP VALIDATION / RESTORE READINESS
-- Oracle DBA Toolkit
--
-- Purpose:
--   Identify backups that should be reviewed for restore
--   readiness and highlight expired, unavailable or incomplete
--   backup metadata.
--
-- Important:
--   This SQL script is READ-ONLY.
--
--   It does NOT execute:
--       RMAN VALIDATE
--       RESTORE VALIDATE
--       CROSSCHECK
--       DELETE EXPIRED
--       DELETE OBSOLETE
--
--   SQL metadata checks do NOT prove that a backup can be
--   successfully restored.
--
--   For actual validation, use RMAN commands shown at the
--   end of this script.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

COLUMN db_name              FORMAT A15
COLUMN database_role        FORMAT A20
COLUMN open_mode            FORMAT A20
COLUMN status               FORMAT A12
COLUMN backup_type          FORMAT A12
COLUMN incremental_level    FORMAT 999
COLUMN device_type          FORMAT A15
COLUMN handle               FORMAT A100
COLUMN backup_start         FORMAT A20
COLUMN backup_end           FORMAT A20
COLUMN completion_time      FORMAT A20
COLUMN size_gb              FORMAT 9999990.99
COLUMN elapsed_min          FORMAT 9999990.99
COLUMN pieces               FORMAT 999999
COLUMN datafiles            FORMAT 999999
COLUMN backup_sets          FORMAT 999999
COLUMN backup_pieces        FORMAT 999999

PROMPT
PROMPT ============================================================
PROMPT RMAN BACKUP VALIDATION / RESTORE READINESS
PROMPT ============================================================


PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE INFORMATION
PROMPT ============================================================

SELECT
    name AS db_name,
    dbid,
    open_mode,
    database_role,
    log_mode
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 2. RMAN BACKUP JOB STATUS - LAST 7 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    TO_CHAR(end_time,   'YYYY-MM-DD HH24:MI:SS') AS backup_end,
    status,
    input_type,
    output_device_type AS device_type,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_min,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
ORDER BY start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 3. BACKUP SET STATUS
PROMPT ============================================================

SELECT
    status,
    backup_type,
    incremental_level,
    COUNT(*) AS backup_sets,
    SUM(pieces) AS backup_pieces,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_set
GROUP BY
    status,
    backup_type,
    incremental_level
ORDER BY
    status,
    backup_type,
    incremental_level;


PROMPT
PROMPT ============================================================
PROMPT 4. BACKUP SETS NOT AVAILABLE
PROMPT ============================================================

SELECT
    recid,
    set_stamp,
    set_count,
    status,
    backup_type,
    incremental_level,
    pieces,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_end
FROM v$backup_set
WHERE status <> 'A'
ORDER BY start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 5. BACKUP PIECE STATUS
PROMPT ============================================================

SELECT
    status,
    device_type,
    COUNT(*) AS backup_pieces,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_piece
GROUP BY
    status,
    device_type
ORDER BY
    status,
    device_type;


PROMPT
PROMPT ============================================================
PROMPT 6. EXPIRED BACKUP PIECES
PROMPT ============================================================

SELECT
    recid,
    set_stamp,
    set_count,
    status,
    device_type,
    handle,
    completion_time,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_piece
WHERE status = 'X'
ORDER BY completion_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. UNAVAILABLE BACKUP PIECES
PROMPT ============================================================

SELECT
    recid,
    set_stamp,
    set_count,
    status,
    device_type,
    handle,
    completion_time,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_piece
WHERE status = 'U'
ORDER BY completion_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. RECENT AVAILABLE BACKUPS
PROMPT ============================================================

SELECT
    TO_CHAR(bs.completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    bs.backup_type,
    bs.incremental_level,
    bs.status,
    bs.pieces,
    ROUND(bs.bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_set bs
WHERE bs.status = 'A'
  AND bs.completion_time >= SYSDATE - 30
ORDER BY bs.completion_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. DATABASE BACKUP COVERAGE - LAST 30 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(TRUNC(completion_time), 'YYYY-MM-DD') AS backup_date,
    COUNT(*) AS backup_sets,
    SUM(pieces) AS backup_pieces,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_set
WHERE completion_time >= SYSDATE - 30
  AND status = 'A'
GROUP BY TRUNC(completion_time)
ORDER BY backup_date DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. DATABASE DATAFILE BACKUP COVERAGE
PROMPT ============================================================

SELECT
    file#,
    COUNT(*) AS backup_records,
    MAX(completion_time) AS last_backup_time
FROM v$backup_datafile
WHERE completion_time >= SYSDATE - 30
GROUP BY file#
ORDER BY file#;


PROMPT
PROMPT ============================================================
PROMPT 11. DATAFILES WITHOUT RECENT BACKUP RECORD
PROMPT ============================================================

SELECT
    df.file_id,
    df.tablespace_name,
    df.file_name,
    TO_CHAR(
        MAX(bd.completion_time),
        'YYYY-MM-DD HH24:MI:SS'
    ) AS last_backup_time
FROM dba_data_files df
LEFT JOIN v$backup_datafile bd
    ON bd.file# = df.file_id
GROUP BY
    df.file_id,
    df.tablespace_name,
    df.file_name
HAVING MAX(bd.completion_time) IS NULL
    OR MAX(bd.completion_time) < SYSDATE - 7
ORDER BY
    last_backup_time NULLS FIRST,
    df.file_id;


PROMPT
PROMPT ============================================================
PROMPT 12. ARCHIVE LOG BACKUP COVERAGE
PROMPT ============================================================

SELECT
    TO_CHAR(TRUNC(completion_time), 'YYYY-MM-DD') AS backup_date,
    COUNT(*) AS archive_backup_records,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_redolog
WHERE completion_time >= SYSDATE - 30
GROUP BY TRUNC(completion_time)
ORDER BY backup_date DESC;


PROMPT
PROMPT ============================================================
PROMPT 13. RECENT ARCHIVE LOG BACKUP DETAILS
PROMPT ============================================================

SELECT
    thread#,
    sequence#,
    TO_CHAR(first_time, 'YYYY-MM-DD HH24:MI:SS') AS first_time,
    TO_CHAR(next_time,  'YYYY-MM-DD HH24:MI:SS') AS next_time,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM v$backup_redolog
WHERE completion_time >= SYSDATE - 7
ORDER BY
    thread#,
    sequence# DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. LATEST DATABASE BACKUP
PROMPT ============================================================

SELECT
    backup_type,
    incremental_level,
    status,
    pieces,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_set
WHERE status = 'A'
ORDER BY completion_time DESC
FETCH FIRST 1 ROW ONLY;


PROMPT
PROMPT ============================================================
PROMPT 15. LATEST ARCHIVE LOG BACKUP
PROMPT ============================================================

SELECT
    TO_CHAR(MAX(completion_time), 'YYYY-MM-DD HH24:MI:SS')
        AS latest_archivelog_backup
FROM v$backup_redolog;


PROMPT
PROMPT ============================================================
PROMPT 16. BACKUP PIECES WITH MISSING HANDLES
PROMPT ============================================================

SELECT
    recid,
    set_stamp,
    set_count,
    status,
    device_type,
    handle,
    completion_time
FROM v$backup_piece
WHERE handle IS NULL
   OR TRIM(handle) IS NULL
ORDER BY completion_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 17. LARGE BACKUP PIECES FOR VALIDATION REVIEW
PROMPT ============================================================

SELECT
    recid,
    set_stamp,
    set_count,
    status,
    device_type,
    handle,
    completion_time,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_piece
WHERE status = 'A'
ORDER BY bytes DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 18. RMAN BACKUP HEALTH COUNTS
PROMPT ============================================================

SELECT
    (SELECT COUNT(*)
       FROM v$backup_set
      WHERE status = 'A') AS available_backup_sets,

    (SELECT COUNT(*)
       FROM v$backup_set
      WHERE status <> 'A') AS unavailable_backup_sets,

    (SELECT COUNT(*)
       FROM v$backup_piece
      WHERE status = 'A') AS available_backup_pieces,

    (SELECT COUNT(*)
       FROM v$backup_piece
      WHERE status = 'X') AS expired_pieces,

    (SELECT COUNT(*)
       FROM v$backup_piece
      WHERE status = 'U') AS unavailable_pieces
FROM dual;


PROMPT
PROMPT ============================================================
PROMPT 19. RECENT FAILED / INCOMPLETE JOBS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    TO_CHAR(end_time,   'YYYY-MM-DD HH24:MI:SS') AS backup_end,
    status,
    input_type,
    output_device_type AS device_type,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_min
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status <> 'COMPLETED'
ORDER BY start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 20. BACKUP VALIDATION READINESS SUMMARY
PROMPT ============================================================

SELECT
    CASE
        WHEN unavailable_sets = 0
         AND expired_pieces = 0
         AND unavailable_pieces = 0
         AND failed_jobs = 0
        THEN 'REVIEW COMPLETE - NO METADATA ISSUES FOUND'
        ELSE 'INVESTIGATE - BACKUP METADATA ISSUES FOUND'
    END AS validation_readiness
FROM (
    SELECT
        (SELECT COUNT(*)
           FROM v$backup_set
          WHERE status <> 'A') AS unavailable_sets,

        (SELECT COUNT(*)
           FROM v$backup_piece
          WHERE status = 'X') AS expired_pieces,

        (SELECT COUNT(*)
           FROM v$backup_piece
          WHERE status = 'U') AS unavailable_pieces,

        (SELECT COUNT(*)
           FROM v$rman_backup_job_details
          WHERE start_time >= SYSDATE - 7
            AND status <> 'COMPLETED') AS failed_jobs
    FROM dual
);


PROMPT
PROMPT ============================================================
PROMPT RMAN ACTUAL VALIDATION COMMANDS
PROMPT ============================================================

PROMPT
PROMPT -- Validate the physical integrity of backup files:
PROMPT
PROMPT RMAN> VALIDATE BACKUPSET <backup_set_id>;
PROMPT
PROMPT -- Validate all database backups:
PROMPT
PROMPT RMAN> VALIDATE DATABASE;
PROMPT
PROMPT -- Validate database files and archived logs:
PROMPT
PROMPT RMAN> VALIDATE DATABASE ARCHIVELOG ALL;
PROMPT
PROMPT -- Check whether the database can be restored:
PROMPT
PROMPT RMAN> RESTORE DATABASE VALIDATE;
PROMPT
PROMPT -- Validate a specific backup:
PROMPT
PROMPT RMAN> VALIDATE BACKUPSET <backup_set_id>;
PROMPT
PROMPT -- Validate individual backup pieces:
PROMPT
PROMPT RMAN> VALIDATE BACKUPPIECE '<backup_piece>';
PROMPT


PROMPT
PROMPT ============================================================
PROMPT DBA VALIDATION CHECKLIST
PROMPT ============================================================
PROMPT 1. Confirm recent database backups exist.
PROMPT 2. Confirm required ARCHIVELOG backups exist.
PROMPT 3. Check backup sets are AVAILABLE.
PROMPT 4. Check backup pieces are AVAILABLE.
PROMPT 5. Investigate EXPIRED backup pieces.
PROMPT 6. Investigate UNAVAILABLE backup pieces.
PROMPT 7. Review recent FAILED RMAN jobs.
PROMPT 8. Run RMAN VALIDATE for physical backup validation.
PROMPT 9. Run RESTORE DATABASE VALIDATE for restore-readiness.
PROMPT 10. Perform periodic test restores according to the
PROMPT     organization's recovery/testing policy.
PROMPT
PROMPT IMPORTANT:
PROMPT Metadata checks do not prove restoreability.
PROMPT A successful backup job does not guarantee a successful
PROMPT restore. RMAN VALIDATE and restore testing provide stronger
PROMPT evidence of recoverability.
PROMPT
PROMPT ============================================================
PROMPT END OF RMAN BACKUP VALIDATION
PROMPT ============================================================


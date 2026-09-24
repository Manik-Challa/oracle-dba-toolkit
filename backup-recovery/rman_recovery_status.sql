-- ============================================================
-- File        : rman_recovery_status.sql
-- Purpose     : RMAN Recovery / Recoverability Status Report
-- Author      : Manik Challa
-- Description :
--   Read-only RMAN recovery monitoring report.
--
--   Covers:
--     1. Database recovery configuration
--     2. Archive log destination status
--     3. Recovery area / FRA status
--     4. Recent RMAN backup jobs
--     5. Latest database backup
--     6. Latest archive log backup
--     7. Datafile backup coverage
--     8. Archive log backup coverage
--     9. Backup piece availability
--    10. Expired / unavailable backup pieces
--    11. Backup failures
--    12. Recovery-related database status
--    13. Restore readiness indicators
--    14. RMAN recovery health summary
--
--   IMPORTANT:
--   This script reports RMAN repository metadata only.
--   Metadata availability does NOT prove that a restore will
--   succeed. Use RMAN VALIDATE / RESTORE ... VALIDATE for
--   actual restore validation.
--
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

COLUMN db_name              FORMAT A15
COLUMN db_unique_name       FORMAT A20
COLUMN database_role        FORMAT A20
COLUMN open_mode            FORMAT A20
COLUMN log_mode             FORMAT A15
COLUMN force_logging        FORMAT A15
COLUMN flashback_on         FORMAT A15

COLUMN destination          FORMAT A35
COLUMN status               FORMAT A15
COLUMN error                FORMAT A45
COLUMN recovery_area        FORMAT A35

COLUMN start_time           FORMAT A20
COLUMN end_time             FORMAT A20
COLUMN input_type           FORMAT A25
COLUMN output_device_type   FORMAT A20
COLUMN job_status           FORMAT A15
COLUMN elapsed_time         FORMAT A15

COLUMN completion_time      FORMAT A20
COLUMN backup_type          FORMAT A15
COLUMN incremental_level    FORMAT A10
COLUMN tag                  FORMAT A30

COLUMN file_name            FORMAT A70
COLUMN handle               FORMAT A100
COLUMN availability         FORMAT A15
COLUMN piece_status         FORMAT A15

COLUMN tablespace_name      FORMAT A25
COLUMN datafile_name        FORMAT A70

COLUMN thread#              FORMAT 999
COLUMN sequence#            FORMAT 999999999
COLUMN backup_count         FORMAT 999999
COLUMN backup_gb            FORMAT 99999990.99
COLUMN input_gb             FORMAT 99999990.99
COLUMN output_gb            FORMAT 99999990.99

PROMPT
PROMPT ============================================================
PROMPT RMAN RECOVERY STATUS
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
    log_mode,
    force_logging,
    flashback_on
FROM v$database;

PROMPT

SELECT
    instance_name,
    host_name,
    version,
    status,
    startup_time
FROM v$instance;

-- ============================================================
-- 2. RECOVERY CONFIGURATION
-- ============================================================

PROMPT ============================================================
PROMPT 2. RECOVERY CONFIGURATION
PROMPT ============================================================

SELECT
    name,
    value
FROM v$parameter
WHERE name IN
(
    'db_recovery_file_dest',
    'db_recovery_file_dest_size',
    'log_archive_dest_1',
    'log_archive_dest_2',
    'log_archive_config',
    'log_archive_format'
)
ORDER BY name;

-- ============================================================
-- 3. ARCHIVE LOG DESTINATION STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 3. ARCHIVE LOG DESTINATION STATUS
PROMPT ============================================================

SELECT
    dest_id,
    status,
    target,
    destination,
    error
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;

-- ============================================================
-- 4. FRA / RECOVERY AREA STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 4. FRA / RECOVERY AREA STATUS
PROMPT ============================================================

SELECT
    name AS recovery_area,
    ROUND(space_limit / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(space_reclaimable / 1024 / 1024 / 1024, 2) AS reclaimable_gb,
    ROUND(
        CASE
            WHEN space_limit > 0
            THEN space_used / space_limit * 100
        END,
        2
    ) AS used_pct,
    number_of_files
FROM v$recovery_file_dest;

-- ============================================================
-- 5. RECOVERY FILE DESTINATION USAGE
-- ============================================================

PROMPT ============================================================
PROMPT 5. RECOVERY AREA FILE USAGE
PROMPT ============================================================

SELECT
    file_type,
    ROUND(percent_space_used, 2) AS used_pct,
    ROUND(percent_space_reclaimable, 2) AS reclaimable_pct,
    number_of_files
FROM v$recovery_area_usage
ORDER BY percent_space_used DESC;

-- ============================================================
-- 6. RMAN JOB STATUS - LAST 7 DAYS
-- ============================================================

PROMPT ============================================================
PROMPT 6. RMAN JOB STATUS - LAST 7 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    input_type,
    status AS job_status,
    output_device_type,
    elapsed_seconds / 3600 AS elapsed_hours
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
ORDER BY start_time DESC;

-- ============================================================
-- 7. RMAN JOB SUMMARY - LAST 30 DAYS
-- ============================================================

PROMPT ============================================================
PROMPT 7. RMAN JOB SUMMARY - LAST 30 DAYS
PROMPT ============================================================

SELECT
    input_type,
    status,
    COUNT(*) AS backup_count,
    ROUND(SUM(input_bytes) / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
GROUP BY input_type, status
ORDER BY input_type, status;

-- ============================================================
-- 8. LATEST DATABASE BACKUP
-- ============================================================

PROMPT ============================================================
PROMPT 8. LATEST DATABASE BACKUP
PROMPT ============================================================

SELECT
    input_type,
    status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb,
    output_device_type
FROM v$rman_backup_job_details
WHERE input_type LIKE '%DB%'
ORDER BY end_time DESC
FETCH FIRST 1 ROW ONLY;

-- ============================================================
-- 9. LATEST ARCHIVE LOG BACKUP
-- ============================================================

PROMPT ============================================================
PROMPT 9. LATEST ARCHIVE LOG BACKUP
PROMPT ============================================================

SELECT
    input_type,
    status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb,
    output_device_type
FROM v$rman_backup_job_details
WHERE input_type LIKE '%ARCHIVELOG%'
ORDER BY end_time DESC
FETCH FIRST 1 ROW ONLY;

-- ============================================================
-- 10. DATAFILE BACKUP COVERAGE
-- ============================================================

PROMPT ============================================================
PROMPT 10. DATAFILE BACKUP COVERAGE
PROMPT ============================================================

SELECT
    df.file#,
    df.name AS datafile_name,
    df.status,
    TO_CHAR(MAX(bs.completion_time), 'YYYY-MM-DD HH24:MI:SS')
        AS latest_backup
FROM v$datafile df
LEFT JOIN v$backup_datafile bd
       ON bd.file# = df.file#
LEFT JOIN v$backup_set bs
       ON bs.set_stamp = bd.set_stamp
      AND bs.set_count = bd.set_count
GROUP BY
    df.file#,
    df.name,
    df.status
ORDER BY df.file#;

-- ============================================================
-- 11. DATAFILES WITHOUT RECENT BACKUP RECORD
-- ============================================================

PROMPT ============================================================
PROMPT 11. DATAFILES WITHOUT RECENT BACKUP RECORD
PROMPT ============================================================

SELECT
    df.file#,
    df.name AS datafile_name,
    df.status
FROM v$datafile df
WHERE NOT EXISTS
(
    SELECT 1
    FROM v$backup_datafile bd
    JOIN v$backup_set bs
      ON bs.set_stamp = bd.set_stamp
     AND bs.set_count = bd.set_count
    WHERE bd.file# = df.file#
      AND bs.completion_time >= SYSDATE - 7
)
ORDER BY df.file#;

-- ============================================================
-- 12. ARCHIVE LOG BACKUP COVERAGE
-- ============================================================

PROMPT ============================================================
PROMPT 12. ARCHIVE LOG BACKUP COVERAGE
PROMPT ============================================================

SELECT
    thread#,
    COUNT(*) AS archived_logs,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence,
    ROUND(SUM(blocks * block_size) / 1024 / 1024 / 1024, 2)
        AS archive_gb
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 13. ARCHIVE LOGS WITH BACKUP RECORDS
-- ============================================================

PROMPT ============================================================
PROMPT 13. ARCHIVE LOGS WITH BACKUP RECORDS
PROMPT ============================================================

SELECT
    al.thread#,
    al.sequence#,
    TO_CHAR(al.completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    al.archived,
    al.deleted,
    al.backup_count
FROM v$archived_log al
WHERE al.completion_time >= SYSDATE - 3
ORDER BY al.thread#, al.sequence# DESC
FETCH FIRST 200 ROWS ONLY;

-- ============================================================
-- 14. ARCHIVE LOGS WITH NO RMAN BACKUP RECORD
-- ============================================================

PROMPT ============================================================
PROMPT 14. ARCHIVE LOGS WITH NO RMAN BACKUP RECORD
PROMPT ============================================================

SELECT
    thread#,
    sequence#,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    backup_count,
    deleted,
    archived
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
  AND NVL(backup_count, 0) = 0
ORDER BY thread#, sequence#;

-- ============================================================
-- 15. BACKUP PIECE AVAILABILITY
-- ============================================================

PROMPT ============================================================
PROMPT 15. BACKUP PIECE AVAILABILITY
PROMPT ============================================================

SELECT
    status AS availability,
    COUNT(*) AS piece_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS backup_gb
FROM v$backup_piece
GROUP BY status
ORDER BY status;

-- ============================================================
-- 16. EXPIRED / UNAVAILABLE BACKUP PIECES
-- ============================================================

PROMPT ============================================================
PROMPT 16. EXPIRED / UNAVAILABLE BACKUP PIECES
PROMPT ============================================================

SELECT
    piece#,
    status AS availability,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS backup_gb,
    handle
FROM v$backup_piece
WHERE status IN ('X', 'U')
ORDER BY completion_time DESC;

-- ============================================================
-- 17. BACKUP SET STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 17. BACKUP SET STATUS
PROMPT ============================================================

SELECT
    status,
    COUNT(*) AS backup_set_count
FROM v$backup_set
GROUP BY status
ORDER BY status;

-- ============================================================
-- 18. UNAVAILABLE BACKUP SETS
-- ============================================================

PROMPT ============================================================
PROMPT 18. UNAVAILABLE BACKUP SETS
PROMPT ============================================================

SELECT
    set_stamp,
    set_count,
    status,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time
FROM v$backup_set
WHERE status <> 'A'
ORDER BY completion_time DESC;

-- ============================================================
-- 19. RECENT FAILED / INCOMPLETE RMAN JOBS
-- ============================================================

PROMPT ============================================================
PROMPT 19. RECENT FAILED / INCOMPLETE RMAN JOBS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    input_type,
    status,
    output_device_type
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status NOT IN ('COMPLETED', 'COMPLETED WITH WARNINGS')
ORDER BY start_time DESC;

-- ============================================================
-- 20. BACKUP PIECES WITH MISSING HANDLES
-- ============================================================

PROMPT ============================================================
PROMPT 20. BACKUP PIECES WITH MISSING HANDLES
PROMPT ============================================================

SELECT
    piece#,
    status,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS backup_gb,
    handle
FROM v$backup_piece
WHERE handle IS NULL
ORDER BY completion_time DESC;

-- ============================================================
-- 21. LATEST BACKUP BY INPUT TYPE
-- ============================================================

PROMPT ============================================================
PROMPT 21. LATEST BACKUP BY INPUT TYPE
PROMPT ============================================================

SELECT
    input_type,
    status,
    TO_CHAR(MAX(end_time), 'YYYY-MM-DD HH24:MI:SS')
        AS latest_end_time
FROM v$rman_backup_job_details
GROUP BY input_type, status
ORDER BY input_type, latest_end_time DESC;

-- ============================================================
-- 22. RECENT BACKUP THROUGHPUT
-- ============================================================

PROMPT ============================================================
PROMPT 22. RECENT BACKUP THROUGHPUT
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    input_type,
    status,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(
        input_bytes / NULLIF(elapsed_seconds, 0)
        / 1024 / 1024,
        2
    ) AS input_mb_per_sec,
    ROUND(
        output_bytes / NULLIF(elapsed_seconds, 0)
        / 1024 / 1024,
        2
    ) AS output_mb_per_sec
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
ORDER BY start_time DESC;

-- ============================================================
-- 23. RECOVERY READINESS COUNTS
-- ============================================================

PROMPT ============================================================
PROMPT 23. RECOVERY READINESS COUNTS
PROMPT ============================================================

SELECT
    'TOTAL DATAFILES' AS check_name,
    COUNT(*) AS count_value
FROM v$datafile

UNION ALL

SELECT
    'DATAFILES WITH BACKUP RECORD',
    COUNT(DISTINCT bd.file#)
FROM v$backup_datafile bd
JOIN v$backup_set bs
  ON bs.set_stamp = bd.set_stamp
 AND bs.set_count = bd.set_count

UNION ALL

SELECT
    'AVAILABLE BACKUP PIECES',
    COUNT(*)
FROM v$backup_piece
WHERE status = 'A'

UNION ALL

SELECT
    'EXPIRED BACKUP PIECES',
    COUNT(*)
FROM v$backup_piece
WHERE status = 'X'

UNION ALL

SELECT
    'UNAVAILABLE BACKUP PIECES',
    COUNT(*)
FROM v$backup_piece
WHERE status = 'U'

UNION ALL

SELECT
    'FAILED RMAN JOBS - 30D',
    COUNT(*)
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status NOT IN ('COMPLETED', 'COMPLETED WITH WARNINGS');

-- ============================================================
-- 24. RMAN RECOVERY HEALTH SUMMARY
-- ============================================================

PROMPT ============================================================
PROMPT 24. RMAN RECOVERY HEALTH SUMMARY
PROMPT ============================================================

SELECT
    'FAILED RMAN JOBS - LAST 7 DAYS' AS check_name,
    COUNT(*) AS count_value
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
  AND status NOT IN ('COMPLETED', 'COMPLETED WITH WARNINGS')

UNION ALL

SELECT
    'EXPIRED BACKUP PIECES',
    COUNT(*)
FROM v$backup_piece
WHERE status = 'X'

UNION ALL

SELECT
    'UNAVAILABLE BACKUP PIECES',
    COUNT(*)
FROM v$backup_piece
WHERE status = 'U'

UNION ALL

SELECT
    'ARCHIVE LOGS WITHOUT BACKUP - 24H',
    COUNT(*)
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
  AND NVL(backup_count, 0) = 0

UNION ALL

SELECT
    'DATAFILES WITHOUT BACKUP RECORD - 7D',
    COUNT(*)
FROM v$datafile df
WHERE NOT EXISTS
(
    SELECT 1
    FROM v$backup_datafile bd
    JOIN v$backup_set bs
      ON bs.set_stamp = bd.set_stamp
     AND bs.set_count = bd.set_count
    WHERE bd.file# = df.file#
      AND bs.completion_time >= SYSDATE - 7
);

-- ============================================================
-- 25. QUICK RECOVERY STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 25. QUICK RECOVERY STATUS
PROMPT ============================================================

SELECT
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM v$rman_backup_job_details
            WHERE start_time >= SYSDATE - 7
              AND status NOT IN
                  ('COMPLETED', 'COMPLETED WITH WARNINGS')
        )
        THEN 'CHECK - RMAN JOB FAILURE/WARNING FOUND'
        ELSE 'OK - NO RMAN FAILURE/WARNING IN LAST 7 DAYS'
    END AS rman_job_status,
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM v$backup_piece
            WHERE status IN ('X', 'U')
        )
        THEN 'CHECK - EXPIRED/UNAVAILABLE PIECES FOUND'
        ELSE 'OK - NO EXPIRED/UNAVAILABLE PIECES'
    END AS backup_piece_status,
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM v$archived_log
            WHERE completion_time >= SYSDATE - 1
              AND NVL(backup_count, 0) = 0
        )
        THEN 'CHECK - ARCHIVE LOGS WITHOUT BACKUP RECORD'
        ELSE 'OK - ARCHIVE LOG BACKUP RECORDS PRESENT'
    END AS archive_backup_status
FROM dual;

-- ============================================================
-- 26. DBA RECOVERY INVESTIGATION CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 26. DBA RECOVERY INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT [ ] Check latest successful database backup
PROMPT [ ] Check latest successful ARCHIVELOG backup
PROMPT [ ] Review failed/incomplete RMAN jobs
PROMPT [ ] Review expired/unavailable backup pieces
PROMPT [ ] Check datafile backup coverage
PROMPT [ ] Check ARCHIVELOG backup coverage
PROMPT [ ] Check FRA usage and reclaimable space
PROMPT [ ] Review archive destination errors
PROMPT [ ] Check backup throughput/duration changes
PROMPT [ ] Run RMAN VALIDATE DATABASE
PROMPT [ ] Run RMAN RESTORE DATABASE VALIDATE
PROMPT [ ] Run RMAN VALIDATE ARCHIVELOG ALL
PROMPT [ ] Perform periodic test restore
PROMPT [ ] Confirm recovery objectives (RPO/RTO)
PROMPT
PROMPT ============================================================
PROMPT END OF RMAN RECOVERY STATUS REPORT
PROMPT ============================================================


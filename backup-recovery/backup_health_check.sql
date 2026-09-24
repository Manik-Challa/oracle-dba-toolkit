-- ============================================================
-- File        : backup_health_check.sql
-- Purpose     : Oracle Backup Health Check
-- Author      : Manik Challa
--
-- Description :
--   Read-only consolidated backup health report.
--
--   Designed as a quick DBA operational dashboard covering:
--
--     1. Database / recovery configuration
--     2. FRA status
--     3. Archive destination status
--     4. Latest database backup
--     5. Latest ARCHIVELOG backup
--     6. RMAN job status
--     7. Failed / incomplete RMAN jobs
--     8. Datafile backup coverage
--     9. ARCHIVELOG backup coverage
--    10. Backup piece availability
--    11. Expired / unavailable pieces
--    12. Control file / SPFILE backup records
--    13. Backup size / duration
--    14. Backup age
--    15. Consolidated health summary
--    16. Quick DBA checklist
--
-- IMPORTANT:
--   This is a metadata-based health check.
--
--   A successful RMAN job or AVAILABLE backup piece does not
--   guarantee that the backup can be restored.
--
--   For actual validation use:
--
--       RMAN> VALIDATE DATABASE;
--       RMAN> VALIDATE BACKUPSET ALL;
--       RMAN> RESTORE DATABASE VALIDATE;
--       RMAN> VALIDATE ARCHIVELOG ALL;
--
--   Periodic test restores provide stronger evidence of
--   recoverability.
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

COLUMN instance_name        FORMAT A20
COLUMN host_name            FORMAT A40
COLUMN status               FORMAT A20
COLUMN startup_time         FORMAT A20

COLUMN destination          FORMAT A45
COLUMN target               FORMAT A15
COLUMN error                FORMAT A60

COLUMN recovery_area        FORMAT A45
COLUMN file_type            FORMAT A30

COLUMN start_time           FORMAT A20
COLUMN end_time             FORMAT A20
COLUMN completion_time      FORMAT A20

COLUMN input_type           FORMAT A25
COLUMN job_status           FORMAT A30
COLUMN output_device_type   FORMAT A20
COLUMN piece_status         FORMAT A15
COLUMN handle               FORMAT A100

COLUMN file_name            FORMAT A80

COLUMN thread#              FORMAT 999
COLUMN sequence#            FORMAT 999999999
COLUMN backup_count         FORMAT 999999

COLUMN job_count            FORMAT 999999
COLUMN piece_count          FORMAT 999999
COLUMN warning_count        FORMAT 999999

COLUMN total_gb             FORMAT 99999990.99
COLUMN used_gb              FORMAT 99999990.99
COLUMN reclaimable_gb       FORMAT 99999990.99
COLUMN used_pct             FORMAT 999.99

COLUMN input_gb             FORMAT 99999990.99
COLUMN output_gb            FORMAT 99999990.99
COLUMN backup_gb            FORMAT 99999990.99

PROMPT
PROMPT ============================================================
PROMPT ORACLE BACKUP HEALTH CHECK
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
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS')
        AS startup_time
FROM v$instance;

-- ============================================================
-- 2. RECOVERY AREA / FRA STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 2. FAST RECOVERY AREA STATUS
PROMPT ============================================================

SELECT
    name AS recovery_area,
    ROUND(space_limit / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(
        space_reclaimable / 1024 / 1024 / 1024,
        2
    ) AS reclaimable_gb,
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
-- 3. FRA FILE TYPE USAGE
-- ============================================================

PROMPT ============================================================
PROMPT 3. FRA FILE TYPE USAGE
PROMPT ============================================================

SELECT
    file_type,
    ROUND(percent_space_used, 2) AS used_pct,
    ROUND(percent_space_reclaimable, 2) AS reclaimable_pct,
    number_of_files
FROM v$recovery_area_usage
ORDER BY percent_space_used DESC;

-- ============================================================
-- 4. ARCHIVE DESTINATION STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 4. ARCHIVE DESTINATION STATUS
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
-- 5. LATEST DATABASE BACKUP
-- ============================================================

PROMPT ============================================================
PROMPT 5. LATEST DATABASE BACKUP
PROMPT ============================================================

SELECT
    input_type,
    status AS job_status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS')
        AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS')
        AS end_time,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2)
        AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2)
        AS output_gb,
    output_device_type
FROM v$rman_backup_job_details
WHERE input_type LIKE '%DB%'
ORDER BY end_time DESC
FETCH FIRST 1 ROW ONLY;

-- ============================================================
-- 6. LATEST SUCCESSFUL DATABASE BACKUP
-- ============================================================

PROMPT ============================================================
PROMPT 6. LATEST SUCCESSFUL DATABASE BACKUP
PROMPT ============================================================

SELECT
    input_type,
    status AS job_status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS')
        AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS')
        AS end_time,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2)
        AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2)
        AS output_gb,
    output_device_type
FROM v$rman_backup_job_details
WHERE input_type LIKE '%DB%'
  AND status IN
      ('COMPLETED', 'COMPLETED WITH WARNINGS')
ORDER BY end_time DESC
FETCH FIRST 1 ROW ONLY;

-- ============================================================
-- 7. LATEST ARCHIVELOG BACKUP
-- ============================================================

PROMPT ============================================================
PROMPT 7. LATEST ARCHIVELOG BACKUP
PROMPT ============================================================

SELECT
    input_type,
    status AS job_status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS')
        AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS')
        AS end_time,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2)
        AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2)
        AS output_gb,
    output_device_type
FROM v$rman_backup_job_details
WHERE input_type LIKE '%ARCHIVELOG%'
ORDER BY end_time DESC
FETCH FIRST 1 ROW ONLY;

-- ============================================================
-- 8. LATEST SUCCESSFUL ARCHIVELOG BACKUP
-- ============================================================

PROMPT ============================================================
PROMPT 8. LATEST SUCCESSFUL ARCHIVELOG BACKUP
PROMPT ============================================================

SELECT
    input_type,
    status AS job_status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS')
        AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS')
        AS end_time,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2)
        AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2)
        AS output_gb
FROM v$rman_backup_job_details
WHERE input_type LIKE '%ARCHIVELOG%'
  AND status IN
      ('COMPLETED', 'COMPLETED WITH WARNINGS')
ORDER BY end_time DESC
FETCH FIRST 1 ROW ONLY;

-- ============================================================
-- 9. RMAN JOB SUMMARY - LAST 7 DAYS
-- ============================================================

PROMPT ============================================================
PROMPT 9. RMAN JOB SUMMARY - LAST 7 DAYS
PROMPT ============================================================

SELECT
    input_type,
    status AS job_status,
    COUNT(*) AS job_count,
    ROUND(
        SUM(input_bytes) / 1024 / 1024 / 1024,
        2
    ) AS input_gb,
    ROUND(
        SUM(output_bytes) / 1024 / 1024 / 1024,
        2
    ) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
GROUP BY input_type, status
ORDER BY input_type, status;

-- ============================================================
-- 10. FAILED / INCOMPLETE RMAN JOBS
-- ============================================================

PROMPT ============================================================
PROMPT 10. FAILED / INCOMPLETE RMAN JOBS - LAST 30 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    input_type,
    status AS job_status,
    output_device_type
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status NOT IN
      ('COMPLETED', 'COMPLETED WITH WARNINGS')
ORDER BY start_time DESC;

-- ============================================================
-- 11. DATABASE BACKUP AGE
-- ============================================================

PROMPT ============================================================
PROMPT 11. DATABASE BACKUP AGE
PROMPT ============================================================

SELECT
    TO_CHAR(MAX(end_time), 'YYYY-MM-DD HH24:MI:SS')
        AS latest_successful_backup,
    ROUND(
        (SYSDATE - MAX(end_time)) * 24,
        2
    ) AS backup_age_hours
FROM v$rman_backup_job_details
WHERE input_type LIKE '%DB%'
  AND status IN
      ('COMPLETED', 'COMPLETED WITH WARNINGS');

-- ============================================================
-- 12. ARCHIVELOG BACKUP AGE
-- ============================================================

PROMPT ============================================================
PROMPT 12. ARCHIVELOG BACKUP AGE
PROMPT ============================================================

SELECT
    TO_CHAR(MAX(end_time), 'YYYY-MM-DD HH24:MI:SS')
        AS latest_successful_archive_backup,
    ROUND(
        (SYSDATE - MAX(end_time)) * 24,
        2
    ) AS backup_age_hours
FROM v$rman_backup_job_details
WHERE input_type LIKE '%ARCHIVELOG%'
  AND status IN
      ('COMPLETED', 'COMPLETED WITH WARNINGS');

-- ============================================================
-- 13. DATAFILE BACKUP COVERAGE
-- ============================================================

PROMPT ============================================================
PROMPT 13. DATAFILE BACKUP COVERAGE
PROMPT ============================================================

SELECT
    df.file#,
    df.name AS file_name,
    df.status,
    TO_CHAR(
        MAX(bs.completion_time),
        'YYYY-MM-DD HH24:MI:SS'
    ) AS latest_backup
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
-- 14. DATAFILES WITHOUT RECENT BACKUP
-- ============================================================

PROMPT ============================================================
PROMPT 14. DATAFILES WITHOUT BACKUP RECORD - LAST 7 DAYS
PROMPT ============================================================

SELECT
    df.file#,
    df.name AS file_name,
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
-- 15. ARCHIVELOG BACKUP COVERAGE - LAST 24 HOURS
-- ============================================================

PROMPT ============================================================
PROMPT 15. ARCHIVELOG BACKUP COVERAGE - LAST 24 HOURS
PROMPT ============================================================

SELECT
    thread#,
    COUNT(*) AS generated_count,
    SUM(
        CASE
            WHEN NVL(backup_count, 0) > 0 THEN 1
            ELSE 0
        END
    ) AS backed_up_count,
    SUM(
        CASE
            WHEN NVL(backup_count, 0) = 0 THEN 1
            ELSE 0
        END
    ) AS no_backup_count,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 16. UNBACKED ARCHIVELOGS
-- ============================================================

PROMPT ============================================================
PROMPT 16. ARCHIVELOGS WITHOUT BACKUP RECORD - LAST 24 HOURS
PROMPT ============================================================

SELECT
    thread#,
    sequence#,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    backup_count,
    archived,
    deleted
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
  AND NVL(backup_count, 0) = 0
ORDER BY thread#, sequence#;

-- ============================================================
-- 17. BACKUP PIECE STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 17. BACKUP PIECE STATUS
PROMPT ============================================================

SELECT
    status AS piece_status,
    COUNT(*) AS piece_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS backup_gb
FROM v$backup_piece
GROUP BY status
ORDER BY status;

-- ============================================================
-- 18. EXPIRED / UNAVAILABLE BACKUP PIECES
-- ============================================================

PROMPT ============================================================
PROMPT 18. EXPIRED / UNAVAILABLE BACKUP PIECES
PROMPT ============================================================

SELECT
    piece#,
    status,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS backup_gb,
    handle
FROM v$backup_piece
WHERE status IN ('X', 'U')
ORDER BY completion_time DESC;

-- ============================================================
-- 19. CONTROL FILE / SPFILE BACKUP STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 19. CONTROL FILE / SPFILE BACKUP STATUS
PROMPT ============================================================

SELECT
    controlfile_included,
    spfile_included,
    COUNT(*) AS backup_sets
FROM v$backup_set
GROUP BY
    controlfile_included,
    spfile_included
ORDER BY
    controlfile_included,
    spfile_included;

-- ============================================================
-- 20. RECENT CONTROL FILE / SPFILE BACKUPS
-- ============================================================

PROMPT ============================================================
PROMPT 20. RECENT CONTROL FILE / SPFILE BACKUPS
PROMPT ============================================================

SELECT
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    status,
    controlfile_included,
    spfile_included,
    pieces
FROM v$backup_set
WHERE controlfile_included = 'YES'
   OR spfile_included = 'YES'
ORDER BY completion_time DESC
FETCH FIRST 20 ROWS ONLY;

-- ============================================================
-- 21. BACKUP SIZE AND DURATION
-- ============================================================

PROMPT ============================================================
PROMPT 21. RECENT BACKUP SIZE / DURATION
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    input_type,
    status AS job_status,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2)
        AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2)
        AS output_gb,
    ROUND(elapsed_seconds / 60, 2)
        AS elapsed_minutes,
    output_device_type
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
ORDER BY start_time DESC;

-- ============================================================
-- 22. BACKUP THROUGHPUT
-- ============================================================

PROMPT ============================================================
PROMPT 22. RECENT BACKUP THROUGHPUT
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    input_type,
    status AS job_status,
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
-- 23. RECOVERY WINDOW INDICATOR
-- ============================================================

PROMPT ============================================================
PROMPT 23. OLDEST AVAILABLE DATABASE BACKUP
PROMPT ============================================================

SELECT
    TO_CHAR(MIN(completion_time), 'YYYY-MM-DD HH24:MI:SS')
        AS oldest_backup_record,
    TO_CHAR(MAX(completion_time), 'YYYY-MM-DD HH24:MI:SS')
        AS newest_backup_record,
    ROUND(
        MAX(completion_time) - MIN(completion_time),
        2
    ) AS metadata_span_days
FROM v$backup_set;

PROMPT
PROMPT Review the actual RMAN retention policy with:
PROMPT   RMAN> SHOW RETENTION POLICY;
PROMPT   RMAN> SHOW ALL;
PROMPT

-- ============================================================
-- 24. RMAN BACKUP HEALTH COUNTS
-- ============================================================

PROMPT ============================================================
PROMPT 24. RMAN BACKUP HEALTH COUNTS
PROMPT ============================================================

SELECT
    'RMAN JOBS - LAST 7 DAYS' AS check_name,
    COUNT(*) AS count_value
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7

UNION ALL

SELECT
    'FAILED/INCOMPLETE JOBS - 30 DAYS',
    COUNT(*)
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status NOT IN
      ('COMPLETED', 'COMPLETED WITH WARNINGS')

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
    'DATAFILES',
    COUNT(*)
FROM v$datafile

UNION ALL

SELECT
    'DATAFILES WITHOUT 7D BACKUP',
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
)

UNION ALL

SELECT
    'ARCHIVELOGS WITHOUT BACKUP - 24H',
    COUNT(*)
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
  AND NVL(backup_count, 0) = 0

UNION ALL

SELECT
    'ARCHIVE DESTINATION ERRORS',
    COUNT(*)
FROM v$archive_dest
WHERE error IS NOT NULL;

-- ============================================================
-- 25. CONSOLIDATED BACKUP HEALTH
-- ============================================================

PROMPT ============================================================
PROMPT 25. CONSOLIDATED BACKUP HEALTH
PROMPT ============================================================

WITH
latest_db AS
(
    SELECT
        MAX(end_time) AS latest_backup
    FROM v$rman_backup_job_details
    WHERE input_type LIKE '%DB%'
      AND status IN
          ('COMPLETED', 'COMPLETED WITH WARNINGS')
),
latest_arch AS
(
    SELECT
        MAX(end_time) AS latest_backup
    FROM v$rman_backup_job_details
    WHERE input_type LIKE '%ARCHIVELOG%'
      AND status IN
          ('COMPLETED', 'COMPLETED WITH WARNINGS')
),
failed_jobs AS
(
    SELECT
        COUNT(*) AS cnt
    FROM v$rman_backup_job_details
    WHERE start_time >= SYSDATE - 7
      AND status NOT IN
          ('COMPLETED', 'COMPLETED WITH WARNINGS')
),
unavailable_pieces AS
(
    SELECT
        COUNT(*) AS cnt
    FROM v$backup_piece
    WHERE status IN ('X', 'U')
),
missing_datafiles AS
(
    SELECT
        COUNT(*) AS cnt
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
),
unbacked_archive AS
(
    SELECT
        COUNT(*) AS cnt
    FROM v$archived_log
    WHERE completion_time >= SYSDATE - 1
      AND NVL(backup_count, 0) = 0
),
destination_errors AS
(
    SELECT
        COUNT(*) AS cnt
    FROM v$archive_dest
    WHERE error IS NOT NULL
)
SELECT
    CASE
        WHEN latest_db.latest_backup IS NULL
            THEN 'CHECK - NO SUCCESSFUL DATABASE BACKUP FOUND'
        WHEN latest_arch.latest_backup IS NULL
            THEN 'CHECK - NO SUCCESSFUL ARCHIVELOG BACKUP FOUND'
        WHEN failed_jobs.cnt > 0
            THEN 'CHECK - RMAN BACKUP FAILURE/WARNING FOUND'
        WHEN unavailable_pieces.cnt > 0
            THEN 'CHECK - EXPIRED/UNAVAILABLE BACKUP PIECES'
        WHEN missing_datafiles.cnt > 0
            THEN 'CHECK - DATAFILES WITHOUT RECENT BACKUP'
        WHEN unbacked_archive.cnt > 0
            THEN 'CHECK - ARCHIVELOGS WITHOUT BACKUP RECORD'
        WHEN destination_errors.cnt > 0
            THEN 'CHECK - ARCHIVE DESTINATION ERROR'
        ELSE 'REVIEW - NO MAJOR BACKUP WARNING DETECTED'
    END AS backup_health_status,

    TO_CHAR(latest_db.latest_backup,
            'YYYY-MM-DD HH24:MI:SS') AS latest_db_backup,

    TO_CHAR(latest_arch.latest_backup,
            'YYYY-MM-DD HH24:MI:SS') AS latest_arch_backup,

    failed_jobs.cnt AS failed_jobs_7d,
    unavailable_pieces.cnt AS unavailable_pieces,
    missing_datafiles.cnt AS datafiles_without_backup,
    unbacked_archive.cnt AS unbacked_archivelogs,
    destination_errors.cnt AS destination_errors
FROM latest_db
CROSS JOIN latest_arch
CROSS JOIN failed_jobs
CROSS JOIN unavailable_pieces
CROSS JOIN missing_datafiles
CROSS JOIN unbacked_archive
CROSS JOIN destination_errors;

-- ============================================================
-- 26. DATABASE RECOVERY MODE
-- ============================================================

PROMPT ============================================================
PROMPT 26. DATABASE RECOVERY MODE
PROMPT ============================================================

SELECT
    log_mode,
    force_logging,
    flashback_on,
    database_role,
    open_mode
FROM v$database;

-- ============================================================
-- 27. QUICK BACKUP HEALTH CHECK
-- ============================================================

PROMPT ============================================================
PROMPT 27. QUICK BACKUP HEALTH CHECK
PROMPT ============================================================

WITH
db_backup AS
(
    SELECT
        MAX(end_time) AS latest_db_backup
    FROM v$rman_backup_job_details
    WHERE input_type LIKE '%DB%'
      AND status IN
          ('COMPLETED', 'COMPLETED WITH WARNINGS')
),
arch_backup AS
(
    SELECT
        MAX(end_time) AS latest_arch_backup
    FROM v$rman_backup_job_details
    WHERE input_type LIKE '%ARCHIVELOG%'
      AND status IN
          ('COMPLETED', 'COMPLETED WITH WARNINGS')
),
failed AS
(
    SELECT
        COUNT(*) AS failed_count
    FROM v$rman_backup_job_details
    WHERE start_time >= SYSDATE - 7
      AND status NOT IN
          ('COMPLETED', 'COMPLETED WITH WARNINGS')
),
unavailable AS
(
    SELECT
        COUNT(*) AS unavailable_count
    FROM v$backup_piece
    WHERE status IN ('X', 'U')
),
unbacked AS
(
    SELECT
        COUNT(*) AS unbacked_count
    FROM v$archived_log
    WHERE completion_time >= SYSDATE - 1
      AND NVL(backup_count, 0) = 0
)
SELECT
    CASE
        WHEN db_backup.latest_db_backup IS NULL
            THEN 'CRITICAL - NO DATABASE BACKUP FOUND'
        WHEN arch_backup.latest_arch_backup IS NULL
            THEN 'CHECK - NO ARCHIVELOG BACKUP FOUND'
        WHEN failed.failed_count > 0
            THEN 'CHECK - RMAN JOB FAILURE/WARNING'
        WHEN unavailable.unavailable_count > 0
            THEN 'CHECK - UNAVAILABLE BACKUP PIECES'
        WHEN unbacked.unbacked_count > 0
            THEN 'CHECK - UNBACKED ARCHIVELOGS'
        ELSE 'OK - BACKUP REPOSITORY LOOKS HEALTHY'
    END AS quick_backup_status,
    failed.failed_count,
    unavailable.unavailable_count,
    unbacked.unbacked_count
FROM db_backup
CROSS JOIN arch_backup
CROSS JOIN failed
CROSS JOIN unavailable
CROSS JOIN unbacked;

-- ============================================================
-- 28. DBA ACTION CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 28. DBA BACKUP HEALTH CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT [ ] Confirm latest successful database backup
PROMPT [ ] Confirm latest successful ARCHIVELOG backup
PROMPT [ ] Check RMAN failures/warnings
PROMPT [ ] Check datafile backup coverage
PROMPT [ ] Check ARCHIVELOG backup coverage
PROMPT [ ] Check RAC thread coverage where applicable
PROMPT [ ] Check expired/unavailable backup pieces
PROMPT [ ] Check FRA usage
PROMPT [ ] Check archive destination errors
PROMPT [ ] Review backup age against RPO
PROMPT [ ] Review RMAN retention policy
PROMPT [ ] Verify control file backup
PROMPT [ ] Verify SPFILE backup
PROMPT [ ] Run RMAN VALIDATE DATABASE periodically
PROMPT [ ] Run RESTORE DATABASE VALIDATE periodically
PROMPT [ ] Run ARCHIVELOG validation
PROMPT [ ] Perform periodic test restore
PROMPT [ ] Confirm RPO / RTO requirements
PROMPT
PROMPT ============================================================
PROMPT END OF ORACLE BACKUP HEALTH CHECK
PROMPT ============================================================


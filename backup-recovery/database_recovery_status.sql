-- ============================================================
-- File        : database_recovery_status.sql
-- Purpose     : Oracle Database Recovery Status / Readiness
-- Author      : Manik Challa
--
-- Description :
--   Read-only database recovery readiness report.
--
--   Covers:
--     1. Database recovery configuration
--     2. Instance status
--     3. ARCHIVELOG / FORCE LOGGING / Flashback
--     4. FRA configuration and usage
--     5. Archive destination status
--     6. Recovery-related initialization parameters
--     7. Datafile status
--     8. Datafile backup coverage
--     9. Recent database backups
--    10. Archive log backup coverage
--    11. RMAN backup failures
--    12. Backup piece availability
--    13. Unavailable / expired backup pieces
--    14. Recovery window configuration
--    15. Restore readiness indicators
--    16. Overall recovery health summary
--
-- IMPORTANT:
--   This report is a recovery-readiness assessment based on
--   database and RMAN repository metadata.
--
--   It does NOT prove that a restore or recovery will succeed.
--
--   For actual validation use RMAN:
--
--     VALIDATE DATABASE;
--     RESTORE DATABASE VALIDATE;
--     VALIDATE ARCHIVELOG ALL;
--     RESTORE ARCHIVELOG ALL VALIDATE;
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
COLUMN status               FORMAT A15
COLUMN startup_time         FORMAT A20

COLUMN parameter_name       FORMAT A35
COLUMN parameter_value      FORMAT A100

COLUMN destination          FORMAT A45
COLUMN target               FORMAT A15
COLUMN error                FORMAT A60

COLUMN recovery_area        FORMAT A45
COLUMN file_type            FORMAT A30

COLUMN tablespace_name      FORMAT A25
COLUMN file_name            FORMAT A80
COLUMN file_status          FORMAT A15

COLUMN start_time           FORMAT A20
COLUMN end_time             FORMAT A20
COLUMN completion_time      FORMAT A20
COLUMN input_type           FORMAT A25
COLUMN job_status           FORMAT A30
COLUMN output_device_type   FORMAT A20

COLUMN thread#              FORMAT 999
COLUMN sequence#            FORMAT 999999999
COLUMN backup_count         FORMAT 999999

COLUMN total_gb             FORMAT 99999990.99
COLUMN used_gb              FORMAT 99999990.99
COLUMN free_gb              FORMAT 99999990.99
COLUMN reclaimable_gb       FORMAT 99999990.99
COLUMN used_pct             FORMAT 999.99

COLUMN input_gb             FORMAT 99999990.99
COLUMN output_gb            FORMAT 99999990.99
COLUMN backup_gb            FORMAT 99999990.99

PROMPT
PROMPT ============================================================
PROMPT ORACLE DATABASE RECOVERY STATUS
PROMPT ============================================================
PROMPT

-- ============================================================
-- 1. DATABASE RECOVERY CONFIGURATION
-- ============================================================

PROMPT ============================================================
PROMPT 1. DATABASE RECOVERY CONFIGURATION
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
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
FROM v$instance;

-- ============================================================
-- 2. DATABASE RESETLOGS / INCARNATION INFORMATION
-- ============================================================

PROMPT ============================================================
PROMPT 2. DATABASE INCARNATION / RESETLOGS INFORMATION
PROMPT ============================================================

SELECT
    resetlogs_id,
    resetlogs_change#,
    TO_CHAR(resetlogs_time, 'YYYY-MM-DD HH24:MI:SS')
        AS resetlogs_time,
    prior_resetlogs_change#,
    prior_incarnation#
FROM v$database_incarnation
WHERE status = 'CURRENT';

-- ============================================================
-- 3. RECOVERY-RELATED PARAMETERS
-- ============================================================

PROMPT ============================================================
PROMPT 3. RECOVERY-RELATED PARAMETERS
PROMPT ============================================================

SELECT
    name AS parameter_name,
    value AS parameter_value
FROM v$parameter
WHERE name IN
(
    'db_recovery_file_dest',
    'db_recovery_file_dest_size',
    'log_archive_dest_1',
    'log_archive_dest_2',
    'log_archive_config',
    'log_archive_format',
    'log_archive_max_processes',
    'control_file_record_keep_time',
    'db_flashback_retention_target'
)
ORDER BY name;

-- ============================================================
-- 4. FLASHBACK DATABASE STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 4. FLASHBACK DATABASE STATUS
PROMPT ============================================================

SELECT
    flashback_on,
    log_mode,
    force_logging
FROM v$database;

PROMPT
PROMPT Flashback database is an additional recovery capability.
PROMPT It is not a replacement for RMAN backups.
PROMPT

-- ============================================================
-- 5. FRA / RECOVERY AREA STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 5. FAST RECOVERY AREA STATUS
PROMPT ============================================================

SELECT
    name AS recovery_area,
    ROUND(space_limit / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(space_reclaimable / 1024 / 1024 / 1024, 2)
        AS reclaimable_gb,
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
-- 6. FRA FILE TYPE USAGE
-- ============================================================

PROMPT ============================================================
PROMPT 6. FRA FILE TYPE USAGE
PROMPT ============================================================

SELECT
    file_type,
    ROUND(percent_space_used, 2) AS used_pct,
    ROUND(percent_space_reclaimable, 2) AS reclaimable_pct,
    number_of_files
FROM v$recovery_area_usage
ORDER BY percent_space_used DESC;

-- ============================================================
-- 7. ARCHIVE DESTINATION STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 7. ARCHIVE DESTINATION STATUS
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
-- 8. DATAFILE STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 8. DATAFILE STATUS
PROMPT ============================================================

SELECT
    file#,
    name AS file_name,
    status
FROM v$datafile
ORDER BY file#;

-- ============================================================
-- 9. DATAFILES NOT ONLINE
-- ============================================================

PROMPT ============================================================
PROMPT 9. DATAFILES NOT ONLINE
PROMPT ============================================================

SELECT
    file#,
    name AS file_name,
    status
FROM v$datafile
WHERE status <> 'ONLINE'
ORDER BY file#;

-- ============================================================
-- 10. DATAFILE BACKUP COVERAGE
-- ============================================================

PROMPT ============================================================
PROMPT 10. DATAFILE BACKUP COVERAGE
PROMPT ============================================================

SELECT
    df.file#,
    df.name AS file_name,
    df.status AS file_status,
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
-- 11. DATAFILES WITHOUT RECENT BACKUP
-- ============================================================

PROMPT ============================================================
PROMPT 11. DATAFILES WITHOUT BACKUP RECORD - LAST 7 DAYS
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
-- 12. LATEST DATABASE BACKUP
-- ============================================================

PROMPT ============================================================
PROMPT 12. LATEST DATABASE BACKUP
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
-- 13. RECENT DATABASE BACKUP JOBS
-- ============================================================

PROMPT ============================================================
PROMPT 13. DATABASE BACKUP JOBS - LAST 30 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    input_type,
    status AS job_status,
    output_device_type,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND input_type LIKE '%DB%'
ORDER BY start_time DESC;

-- ============================================================
-- 14. LATEST ARCHIVE LOG BACKUP
-- ============================================================

PROMPT ============================================================
PROMPT 14. LATEST ARCHIVE LOG BACKUP
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
-- 15. ARCHIVE LOG BACKUP COVERAGE - LAST 24 HOURS
-- ============================================================

PROMPT ============================================================
PROMPT 15. ARCHIVE LOG BACKUP COVERAGE - LAST 24 HOURS
PROMPT ============================================================

SELECT
    thread#,
    COUNT(*) AS archive_count,
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
-- 16. ARCHIVE LOGS WITHOUT BACKUP RECORD
-- ============================================================

PROMPT ============================================================
PROMPT 16. ARCHIVE LOGS WITHOUT BACKUP RECORD - LAST 24 HOURS
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
-- 17. FAILED / INCOMPLETE RMAN JOBS
-- ============================================================

PROMPT ============================================================
PROMPT 17. FAILED / INCOMPLETE RMAN JOBS - LAST 30 DAYS
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
-- 18. BACKUP PIECE AVAILABILITY
-- ============================================================

PROMPT ============================================================
PROMPT 18. BACKUP PIECE AVAILABILITY
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
-- 19. EXPIRED / UNAVAILABLE BACKUP PIECES
-- ============================================================

PROMPT ============================================================
PROMPT 19. EXPIRED / UNAVAILABLE BACKUP PIECES
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
-- 20. RMAN BACKUP SUMMARY - LAST 7 DAYS
-- ============================================================

PROMPT ============================================================
PROMPT 20. RMAN BACKUP SUMMARY - LAST 7 DAYS
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
-- 21. DATABASE BACKUP AGE
-- ============================================================

PROMPT ============================================================
PROMPT 21. DATABASE BACKUP AGE
PROMPT ============================================================

SELECT
    MAX(end_time) AS latest_database_backup,
    ROUND(
        (SYSDATE - MAX(end_time)) * 24,
        2
    ) AS backup_age_hours
FROM v$rman_backup_job_details
WHERE input_type LIKE '%DB%'
  AND status IN
      ('COMPLETED', 'COMPLETED WITH WARNINGS');

-- ============================================================
-- 22. ARCHIVE BACKUP AGE
-- ============================================================

PROMPT ============================================================
PROMPT 22. ARCHIVE LOG BACKUP AGE
PROMPT ============================================================

SELECT
    MAX(end_time) AS latest_archive_backup,
    ROUND(
        (SYSDATE - MAX(end_time)) * 24,
        2
    ) AS backup_age_hours
FROM v$rman_backup_job_details
WHERE input_type LIKE '%ARCHIVELOG%'
  AND status IN
      ('COMPLETED', 'COMPLETED WITH WARNINGS');

-- ============================================================
-- 23. CONTROL FILE / SPFILE BACKUP STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 23. CONTROL FILE / SPFILE BACKUP STATUS
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
-- 24. CONTROL FILE BACKUP RECORDS
-- ============================================================

PROMPT ============================================================
PROMPT 24. RECENT CONTROL FILE BACKUP RECORDS
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
ORDER BY completion_time DESC
FETCH FIRST 20 ROWS ONLY;

-- ============================================================
-- 25. RECOVERY WINDOW / RETENTION CONFIGURATION
-- ============================================================

PROMPT ============================================================
PROMPT 25. RMAN RETENTION / RECOVERY CONFIGURATION
PROMPT ============================================================
PROMPT
PROMPT RMAN retention policy is stored in the RMAN repository.
PROMPT Review it using RMAN SHOW ALL.
PROMPT
PROMPT Example:
PROMPT   RMAN> SHOW RETENTION POLICY;
PROMPT   RMAN> SHOW ALL;
PROMPT

-- ============================================================
-- 26. RECOVERY READINESS COUNTS
-- ============================================================

PROMPT ============================================================
PROMPT 26. RECOVERY READINESS COUNTS
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
  AND status NOT IN
      ('COMPLETED', 'COMPLETED WITH WARNINGS');

-- ============================================================
-- 27. DATABASE RECOVERY HEALTH SUMMARY
-- ============================================================

PROMPT ============================================================
PROMPT 27. DATABASE RECOVERY HEALTH SUMMARY
PROMPT ============================================================

SELECT
    'ARCHIVELOG MODE' AS check_name,
    log_mode AS status
FROM v$database

UNION ALL

SELECT
    'FORCE LOGGING',
    force_logging
FROM v$database

UNION ALL

SELECT
    'FLASHBACK DATABASE',
    flashback_on
FROM v$database

UNION ALL

SELECT
    'OPEN MODE',
    open_mode
FROM v$database;

-- ============================================================
-- 28. RECOVERY WARNING SUMMARY
-- ============================================================

PROMPT ============================================================
PROMPT 28. RECOVERY WARNING SUMMARY
PROMPT ============================================================

SELECT
    'DATAFILES WITHOUT BACKUP - 7D' AS check_name,
    COUNT(*) AS warning_count
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
    'FAILED RMAN JOBS - 30D',
    COUNT(*)
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status NOT IN
      ('COMPLETED', 'COMPLETED WITH WARNINGS')

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
    'ARCHIVE DESTINATION ERRORS',
    COUNT(*)
FROM v$archive_dest
WHERE error IS NOT NULL;

-- ============================================================
-- 29. QUICK RECOVERY STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 29. QUICK DATABASE RECOVERY STATUS
PROMPT ============================================================

WITH
db_config AS
(
    SELECT
        log_mode,
        force_logging,
        flashback_on
    FROM v$database
),
datafile_check AS
(
    SELECT
        COUNT(*) AS missing_backup_count
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
archive_check AS
(
    SELECT
        COUNT(*) AS unbacked_archive_count
    FROM v$archived_log
    WHERE completion_time >= SYSDATE - 1
      AND NVL(backup_count, 0) = 0
),
rman_check AS
(
    SELECT
        COUNT(*) AS failed_rman_count
    FROM v$rman_backup_job_details
    WHERE start_time >= SYSDATE - 7
      AND status NOT IN
          ('COMPLETED', 'COMPLETED WITH WARNINGS')
),
piece_check AS
(
    SELECT
        SUM(
            CASE
                WHEN status IN ('X', 'U') THEN 1
                ELSE 0
            END
        ) AS unavailable_piece_count
    FROM v$backup_piece
)
SELECT
    CASE
        WHEN db_config.log_mode <> 'ARCHIVELOG'
            THEN 'CHECK - DATABASE NOT IN ARCHIVELOG MODE'
        WHEN datafile_check.missing_backup_count > 0
            THEN 'CHECK - DATAFILES WITHOUT RECENT BACKUP'
        WHEN archive_check.unbacked_archive_count > 0
            THEN 'CHECK - ARCHIVELOGS WITHOUT BACKUP RECORD'
        WHEN rman_check.failed_rman_count > 0
            THEN 'CHECK - FAILED/INCOMPLETE RMAN JOBS'
        WHEN NVL(piece_check.unavailable_piece_count, 0) > 0
            THEN 'CHECK - EXPIRED/UNAVAILABLE BACKUP PIECES'
        ELSE 'REVIEW - NO MAJOR REPOSITORY WARNING DETECTED'
    END AS recovery_status,
    db_config.log_mode,
    db_config.force_logging,
    db_config.flashback_on,
    datafile_check.missing_backup_count,
    archive_check.unbacked_archive_count,
    rman_check.failed_rman_count,
    NVL(piece_check.unavailable_piece_count, 0)
        AS unavailable_piece_count
FROM db_config
CROSS JOIN datafile_check
CROSS JOIN archive_check
CROSS JOIN rman_check
CROSS JOIN piece_check;

-- ============================================================
-- 30. ACTUAL RMAN VALIDATION COMMANDS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 30. RMAN VALIDATION COMMANDS
PROMPT ============================================================
PROMPT
PROMPT RMAN> VALIDATE DATABASE;
PROMPT RMAN> VALIDATE BACKUPSET ALL;
PROMPT RMAN> VALIDATE ARCHIVELOG ALL;
PROMPT RMAN> RESTORE DATABASE VALIDATE;
PROMPT RMAN> RESTORE ARCHIVELOG ALL VALIDATE;
PROMPT
PROMPT For a specific backup piece:
PROMPT RMAN> VALIDATE BACKUPPIECE '<backup_piece>';
PROMPT
PROMPT ============================================================

-- ============================================================
-- 31. DBA RECOVERY READINESS CHECKLIST
-- ============================================================

PROMPT ============================================================
PROMPT 31. DBA RECOVERY READINESS CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT [ ] Database is running in ARCHIVELOG mode
PROMPT [ ] FORCE LOGGING reviewed
PROMPT [ ] Flashback status reviewed
PROMPT [ ] FRA capacity reviewed
PROMPT [ ] Archive destinations have no errors
PROMPT [ ] All datafiles have recent backup coverage
PROMPT [ ] Recent database backup completed successfully
PROMPT [ ] Recent ARCHIVELOG backup completed successfully
PROMPT [ ] No unexpected RMAN failures
PROMPT [ ] No expired/unavailable required backup pieces
PROMPT [ ] Control file backup available
PROMPT [ ] SPFILE backup available
PROMPT [ ] Recovery window / retention policy reviewed
PROMPT [ ] Archive log sequence gaps investigated
PROMPT [ ] RMAN VALIDATE DATABASE executed periodically
PROMPT [ ] RESTORE DATABASE VALIDATE executed periodically
PROMPT [ ] Test restore performed according to DR policy
PROMPT [ ] RPO / RTO requirements documented
PROMPT
PROMPT ============================================================
PROMPT END OF DATABASE RECOVERY STATUS
PROMPT ============================================================


-- ============================================================
-- File        : archive_log_backup_check.sql
-- Purpose     : Archive Log Backup Verification
-- Author      : Manik Challa
--
-- Description :
--   Read-only report to verify ARCHIVELOG backup coverage.
--
--   Covers:
--     1. Database information
--     2. Archive destination status
--     3. Archive generation - last 24 hours
--     4. Archive logs with RMAN backup records
--     5. Archive logs without RMAN backup records
--     6. Backup coverage by thread
--     7. Latest generated sequence by thread
--     8. Latest backed-up sequence by thread
--     9. Backup activity - last 24 hours
--    10. Backup activity - last 7 days
--    11. Archive backup size
--    12. Multiple backup records
--    13. Deleted archive logs
--    14. Archive destination errors
--    15. Failed/incomplete RMAN archive jobs
--    16. Archive backup coverage summary
--    17. Quick health check
--
-- IMPORTANT:
--   V$ARCHIVED_LOG can contain multiple rows for the same
--   THREAD#/SEQUENCE# because of multiple destinations or
--   historical records.
--
--   backup_count > 0 indicates an RMAN backup record exists.
--   It does NOT by itself prove that the backup piece is
--   physically available or restorable.
--
--   Use RMAN VALIDATE / RESTORE ... VALIDATE for stronger
--   restore verification.
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

COLUMN destination          FORMAT A45
COLUMN status               FORMAT A15
COLUMN target               FORMAT A15
COLUMN error                FORMAT A60

COLUMN completion_time      FORMAT A20
COLUMN first_time           FORMAT A20
COLUMN next_time            FORMAT A20
COLUMN start_time           FORMAT A20
COLUMN end_time             FORMAT A20

COLUMN input_type           FORMAT A25
COLUMN output_device_type   FORMAT A20
COLUMN job_status           FORMAT A25

COLUMN thread#              FORMAT 999
COLUMN sequence#            FORMAT 999999999
COLUMN first_sequence       FORMAT 999999999
COLUMN last_sequence        FORMAT 999999999
COLUMN generated_count      FORMAT 999999999
COLUMN backed_up_count      FORMAT 999999999
COLUMN no_backup_count      FORMAT 999999999
COLUMN backup_count         FORMAT 999999

COLUMN archive_gb           FORMAT 99999990.99
COLUMN input_gb             FORMAT 99999990.99
COLUMN output_gb            FORMAT 99999990.99
COLUMN backup_gb            FORMAT 99999990.99

PROMPT
PROMPT ============================================================
PROMPT ARCHIVE LOG BACKUP CHECK
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

PROMPT

SELECT
    instance_name,
    host_name,
    status,
    startup_time
FROM v$instance;

-- ============================================================
-- 2. ARCHIVE DESTINATION STATUS
-- ============================================================

PROMPT ============================================================
PROMPT 2. ARCHIVE DESTINATION STATUS
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
-- 3. ARCHIVE LOG GENERATION - LAST 24 HOURS
-- ============================================================

PROMPT ============================================================
PROMPT 3. ARCHIVE LOG GENERATION - LAST 24 HOURS
PROMPT ============================================================

SELECT
    thread#,
    COUNT(*) AS generated_count,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024 / 1024,
        2
    ) AS archive_gb
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 4. ARCHIVE LOGS WITH RMAN BACKUP RECORD
-- ============================================================

PROMPT ============================================================
PROMPT 4. ARCHIVE LOGS WITH RMAN BACKUP RECORD - LAST 24 HOURS
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
  AND NVL(backup_count, 0) > 0
ORDER BY thread#, sequence# DESC
FETCH FIRST 200 ROWS ONLY;

-- ============================================================
-- 5. ARCHIVE LOGS WITHOUT RMAN BACKUP RECORD
-- ============================================================

PROMPT ============================================================
PROMPT 5. ARCHIVE LOGS WITHOUT RMAN BACKUP RECORD - LAST 24 HOURS
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
-- 6. BACKUP COVERAGE BY THREAD
-- ============================================================

PROMPT ============================================================
PROMPT 6. ARCHIVE BACKUP COVERAGE BY THREAD - LAST 7 DAYS
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
    MAX(sequence#) AS last_sequence,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024 / 1024,
        2
    ) AS archive_gb
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 7. BACKUP COVERAGE PERCENTAGE BY THREAD
-- ============================================================

PROMPT ============================================================
PROMPT 7. ARCHIVE BACKUP COVERAGE PERCENTAGE BY THREAD
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
    ROUND(
        100 *
        SUM(
            CASE
                WHEN NVL(backup_count, 0) > 0 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS backup_coverage_pct
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 8. LATEST GENERATED SEQUENCE BY THREAD
-- ============================================================

PROMPT ============================================================
PROMPT 8. LATEST GENERATED ARCHIVE SEQUENCE BY THREAD
PROMPT ============================================================

SELECT
    thread#,
    MAX(sequence#) AS last_sequence,
    TO_CHAR(
        MAX(completion_time),
        'YYYY-MM-DD HH24:MI:SS'
    ) AS latest_archive_time
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 9. LATEST BACKED-UP SEQUENCE BY THREAD
-- ============================================================

PROMPT ============================================================
PROMPT 9. LATEST ARCHIVE SEQUENCE WITH RMAN BACKUP RECORD
PROMPT ============================================================

SELECT
    thread#,
    MAX(sequence#) AS last_backed_up_sequence,
    TO_CHAR(
        MAX(completion_time),
        'YYYY-MM-DD HH24:MI:SS'
    ) AS latest_backed_up_time
FROM v$archived_log
WHERE NVL(backup_count, 0) > 0
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 10. GENERATED VS BACKED-UP SEQUENCE
-- ============================================================

PROMPT ============================================================
PROMPT 10. GENERATED VS BACKED-UP SEQUENCE BY THREAD
PROMPT ============================================================

WITH archive_status AS
(
    SELECT
        thread#,
        MAX(sequence#) AS latest_generated_sequence,
        MAX(
            CASE
                WHEN NVL(backup_count, 0) > 0
                THEN sequence#
            END
        ) AS latest_backed_up_sequence
    FROM v$archived_log
    WHERE completion_time >= SYSDATE - 7
    GROUP BY thread#
)
SELECT
    thread#,
    latest_generated_sequence,
    latest_backed_up_sequence,
    latest_generated_sequence -
        latest_backed_up_sequence AS sequence_difference
FROM archive_status
ORDER BY thread#;

-- ============================================================
-- 11. RECENT UNBACKED ARCHIVE LOG DETAILS
-- ============================================================

PROMPT ============================================================
PROMPT 11. RECENT UNBACKED ARCHIVE LOG DETAILS
PROMPT ============================================================

SELECT
    thread#,
    sequence#,
    TO_CHAR(first_time, 'YYYY-MM-DD HH24:MI:SS')
        AS first_time,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    backup_count,
    archived,
    deleted
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
  AND NVL(backup_count, 0) = 0
ORDER BY thread#, sequence#;

-- ============================================================
-- 12. ARCHIVE LOGS WITH MULTIPLE BACKUP RECORDS
-- ============================================================

PROMPT ============================================================
PROMPT 12. ARCHIVE LOGS WITH MULTIPLE BACKUP RECORDS
PROMPT ============================================================

SELECT
    thread#,
    sequence#,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    backup_count
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
  AND backup_count > 1
ORDER BY thread#, sequence# DESC;

-- ============================================================
-- 13. DELETED ARCHIVE LOGS
-- ============================================================

PROMPT ============================================================
PROMPT 13. DELETED ARCHIVE LOGS - LAST 7 DAYS
PROMPT ============================================================

SELECT
    thread#,
    sequence#,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    deleted,
    backup_count
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
  AND deleted = 'YES'
ORDER BY thread#, sequence# DESC;

-- ============================================================
-- 14. ARCHIVE BACKUP SIZE - LAST 7 DAYS
-- ============================================================

PROMPT ============================================================
PROMPT 14. ARCHIVE BACKUP SIZE - LAST 7 DAYS
PROMPT ============================================================

SELECT
    thread#,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024 / 1024,
        2
    ) AS archive_gb
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
  AND NVL(backup_count, 0) > 0
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 15. RMAN ARCHIVELOG BACKUP JOBS - LAST 24 HOURS
-- ============================================================

PROMPT ============================================================
PROMPT 15. RMAN ARCHIVELOG BACKUP JOBS - LAST 24 HOURS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    input_type,
    status AS job_status,
    output_device_type,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_minutes
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 1
  AND input_type LIKE '%ARCHIVELOG%'
ORDER BY start_time DESC;

-- ============================================================
-- 16. RMAN ARCHIVELOG BACKUP JOBS - LAST 7 DAYS
-- ============================================================

PROMPT ============================================================
PROMPT 16. RMAN ARCHIVELOG BACKUP JOBS - LAST 7 DAYS
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
  AND input_type LIKE '%ARCHIVELOG%'
GROUP BY input_type, status
ORDER BY input_type, status;

-- ============================================================
-- 17. FAILED / INCOMPLETE ARCHIVELOG BACKUP JOBS
-- ============================================================

PROMPT ============================================================
PROMPT 17. FAILED / INCOMPLETE ARCHIVELOG BACKUP JOBS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS start_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI:SS') AS end_time,
    input_type,
    status AS job_status,
    output_device_type
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND input_type LIKE '%ARCHIVELOG%'
  AND status NOT IN
      ('COMPLETED', 'COMPLETED WITH WARNINGS')
ORDER BY start_time DESC;

-- ============================================================
-- 18. ARCHIVE LOGS WITH RMAN BACKUP RECORD BUT PROBLEMATIC PIECES
-- ============================================================
--
--   This section checks backup-piece repository status.
--   It does not map every archived log directly to a specific
--   piece; it is an additional repository-level warning.
--

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
-- 19. RECENT EXPIRED / UNAVAILABLE PIECES
-- ============================================================

PROMPT ============================================================
PROMPT 19. RECENT EXPIRED / UNAVAILABLE BACKUP PIECES
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
  AND completion_time >= SYSDATE - 30
ORDER BY completion_time DESC;

-- ============================================================
-- 20. ARCHIVE DESTINATION ERRORS
-- ============================================================

PROMPT ============================================================
PROMPT 20. ARCHIVE DESTINATION ERRORS
PROMPT ============================================================

SELECT
    dest_id,
    status,
    target,
    destination,
    error
FROM v$archive_dest
WHERE error IS NOT NULL
ORDER BY dest_id;

-- ============================================================
-- 21. ARCHIVE BACKUP COVERAGE BY DAY
-- ============================================================

PROMPT ============================================================
PROMPT 21. ARCHIVE BACKUP COVERAGE BY DAY
PROMPT ============================================================

SELECT
    TO_CHAR(TRUNC(completion_time), 'YYYY-MM-DD') AS archive_day,
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
    ROUND(
        100 *
        SUM(
            CASE
                WHEN NVL(backup_count, 0) > 0 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS coverage_pct
FROM v$archived_log
WHERE completion_time >= SYSDATE - 30
GROUP BY TRUNC(completion_time)
ORDER BY TRUNC(completion_time);

-- ============================================================
-- 22. THREAD-LEVEL BACKUP COVERAGE SUMMARY
-- ============================================================

PROMPT ============================================================
PROMPT 22. THREAD-LEVEL BACKUP COVERAGE SUMMARY
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
    ROUND(
        100 *
        SUM(
            CASE
                WHEN NVL(backup_count, 0) > 0 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS coverage_pct
FROM v$archived_log
WHERE completion_time >= SYSDATE - 24
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 23. QUICK ARCHIVE BACKUP HEALTH CHECK
-- ============================================================

PROMPT ============================================================
PROMPT 23. QUICK ARCHIVE BACKUP HEALTH CHECK
PROMPT ============================================================

WITH archive_check AS
(
    SELECT
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
        ) AS unbacked_count
    FROM v$archived_log
    WHERE completion_time >= SYSDATE - 1
),
rman_check AS
(
    SELECT
        COUNT(*) AS failed_jobs
    FROM v$rman_backup_job_details
    WHERE start_time >= SYSDATE - 1
      AND input_type LIKE '%ARCHIVELOG%'
      AND status NOT IN
          ('COMPLETED', 'COMPLETED WITH WARNINGS')
),
dest_check AS
(
    SELECT
        COUNT(*) AS destination_errors
    FROM v$archive_dest
    WHERE error IS NOT NULL
)
SELECT
    CASE
        WHEN unbacked_count > 0
            THEN 'CHECK - ARCHIVE LOGS WITHOUT RMAN BACKUP RECORD'
        WHEN failed_jobs > 0
            THEN 'CHECK - FAILED ARCHIVELOG RMAN JOB'
        WHEN destination_errors > 0
            THEN 'CHECK - ARCHIVE DESTINATION ERROR'
        ELSE 'OK - ARCHIVE BACKUP CHECK PASSED'
    END AS archive_backup_status,
    generated_count,
    backed_up_count,
    unbacked_count,
    failed_jobs,
    destination_errors
FROM archive_check
CROSS JOIN rman_check
CROSS JOIN dest_check;

-- ============================================================
-- 24. DBA INVESTIGATION CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 24. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT [ ] Check archive logs generated in the last 24 hours
PROMPT [ ] Check backup_count for recent archive logs
PROMPT [ ] Check coverage separately for each RAC thread
PROMPT [ ] Check latest generated sequence
PROMPT [ ] Check latest backed-up sequence
PROMPT [ ] Review RMAN ARCHIVELOG backup jobs
PROMPT [ ] Review failed/incomplete ARCHIVELOG jobs
PROMPT [ ] Check expired/unavailable backup pieces
PROMPT [ ] Check archive destination errors
PROMPT [ ] Check FRA usage
PROMPT [ ] Check archive sequence gaps
PROMPT [ ] Verify backup pieces with RMAN VALIDATE
PROMPT [ ] Run RESTORE ARCHIVELOG ... VALIDATE when required
PROMPT [ ] Confirm retention policy / recovery window
PROMPT [ ] For Data Guard, check standby transport/apply status
PROMPT
PROMPT ============================================================
PROMPT END OF ARCHIVE LOG BACKUP CHECK
PROMPT ============================================================


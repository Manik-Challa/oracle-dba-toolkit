-- ============================================================
-- RMAN RESTORE VALIDATION
-- Oracle DBA Toolkit
--
-- Purpose:
--   Assess RMAN backup metadata and restore readiness before
--   performing an actual restore.
--
-- This SQL script is READ-ONLY.
--
-- IMPORTANT:
--   SQL metadata checks do NOT prove restoreability.
--
--   Stronger validation should be performed with RMAN:
--
--       RESTORE DATABASE VALIDATE;
--       RESTORE ARCHIVELOG ALL VALIDATE;
--       VALIDATE DATABASE;
--
--   Actual test restores are the strongest practical proof
--   of recoverability.
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
COLUMN backup_type          FORMAT A15
COLUMN device_type          FORMAT A18
COLUMN status               FORMAT A15
COLUMN backup_start         FORMAT A20
COLUMN backup_end           FORMAT A20
COLUMN completion_time      FORMAT A20
COLUMN last_backup_time     FORMAT A20
COLUMN handle               FORMAT A100
COLUMN tablespace_name      FORMAT A30
COLUMN file_name            FORMAT A100
COLUMN size_gb              FORMAT 99999990.99
COLUMN elapsed_min          FORMAT 9999990.99
COLUMN backup_count         FORMAT 999999
COLUMN piece_count          FORMAT 999999
COLUMN sequence#            FORMAT 999999999
COLUMN thread#              FORMAT 999
COLUMN incremental_level    FORMAT 999

PROMPT
PROMPT ============================================================
PROMPT RMAN RESTORE VALIDATION / RESTORE READINESS
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
PROMPT 2. DATABASE RECOVERY CONFIGURATION
PROMPT ============================================================

SELECT
    log_mode,
    force_logging,
    flashback_on
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 3. DATAFILE INVENTORY
PROMPT ============================================================

SELECT
    file_id,
    tablespace_name,
    file_name,
    status,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    autoextensible
FROM dba_data_files
ORDER BY file_id;


PROMPT
PROMPT ============================================================
PROMPT 4. TEMPFILE INVENTORY
PROMPT ============================================================

SELECT
    file_id,
    tablespace_name,
    file_name,
    status,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    autoextensible
FROM dba_temp_files
ORDER BY file_id;


PROMPT
PROMPT ============================================================
PROMPT 5. RMAN BACKUP SET STATUS
PROMPT ============================================================

SELECT
    status,
    backup_type,
    incremental_level,
    COUNT(*) AS backup_count,
    SUM(pieces) AS piece_count,
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
PROMPT 6. AVAILABLE BACKUP PIECES
PROMPT ============================================================

SELECT
    device_type,
    status,
    COUNT(*) AS piece_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    MAX(completion_time) AS last_backup_time
FROM v$backup_piece
WHERE status = 'A'
GROUP BY
    device_type,
    status
ORDER BY size_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. EXPIRED / UNAVAILABLE BACKUP PIECES
PROMPT ============================================================

SELECT
    status,
    device_type,
    COUNT(*) AS piece_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    MAX(completion_time) AS last_backup_time
FROM v$backup_piece
WHERE status <> 'A'
GROUP BY
    status,
    device_type
ORDER BY status;


PROMPT
PROMPT ============================================================
PROMPT 8. RECENT DATABASE BACKUP JOBS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    TO_CHAR(end_time,   'YYYY-MM-DD HH24:MI:SS') AS backup_end,
    status,
    input_type,
    output_device_type AS device_type,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_min
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND input_type <> 'ARCHIVELOG'
ORDER BY start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. FAILED / INCOMPLETE RMAN JOBS
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
PROMPT 10. DATAFILE BACKUP COVERAGE
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
ORDER BY
    last_backup_time NULLS FIRST,
    df.file_id;


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
    last_backup_time NULLS FIRST;


PROMPT
PROMPT ============================================================
PROMPT 12. ARCHIVELOG BACKUP COVERAGE
PROMPT ============================================================

SELECT
    thread#,
    COUNT(*) AS backup_count,
    MIN(sequence#) AS min_sequence,
    MAX(sequence#) AS max_sequence,
    TO_CHAR(MAX(completion_time), 'YYYY-MM-DD HH24:MI:SS')
        AS last_backup_time,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_redolog
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================
PROMPT 13. LATEST ARCHIVELOG GENERATED VS BACKED UP
PROMPT ============================================================

WITH generated AS (
    SELECT
        thread#,
        MAX(sequence#) AS generated_sequence
    FROM v$archived_log
    WHERE standby_dest = 'NO'
    GROUP BY thread#
),
backed_up AS (
    SELECT
        thread#,
        MAX(sequence#) AS backed_up_sequence
    FROM v$backup_redolog
    GROUP BY thread#
)
SELECT
    g.thread#,
    g.generated_sequence,
    NVL(b.backed_up_sequence, 0) AS backed_up_sequence,
    g.generated_sequence
        - NVL(b.backed_up_sequence, 0) AS sequence_difference
FROM generated g
LEFT JOIN backed_up b
    ON b.thread# = g.thread#
ORDER BY g.thread#;


PROMPT
PROMPT ============================================================
PROMPT 14. ARCHIVELOGS NOT RECORDED AS BACKED UP - LAST 24 HOURS
PROMPT ============================================================

SELECT
    a.thread#,
    a.sequence#,
    TO_CHAR(a.first_time, 'YYYY-MM-DD HH24:MI:SS') AS first_time,
    TO_CHAR(a.next_time,  'YYYY-MM-DD HH24:MI:SS') AS next_time,
    ROUND(
        a.blocks * a.block_size / 1024 / 1024,
        2
    ) AS size_mb
FROM v$archived_log a
WHERE a.first_time >= SYSDATE - 1
  AND a.standby_dest = 'NO'
  AND NOT EXISTS (
        SELECT 1
        FROM v$backup_redolog b
        WHERE b.thread# = a.thread#
          AND b.sequence# = a.sequence#
  )
ORDER BY
    a.thread#,
    a.sequence#;


PROMPT
PROMPT ============================================================
PROMPT 15. LATEST DATABASE BACKUP
PROMPT ============================================================

SELECT
    backup_type,
    incremental_level,
    status,
    pieces,
    TO_CHAR(
        completion_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS completion_time,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_set
WHERE status = 'A'
ORDER BY completion_time DESC
FETCH FIRST 1 ROW ONLY;


PROMPT
PROMPT ============================================================
PROMPT 16. LATEST AVAILABLE BACKUP PIECE
PROMPT ============================================================

SELECT
    device_type,
    status,
    handle,
    TO_CHAR(
        completion_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS completion_time,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_piece
WHERE status = 'A'
ORDER BY completion_time DESC
FETCH FIRST 1 ROW ONLY;


PROMPT
PROMPT ============================================================
PROMPT 17. BACKUP PIECES WITH MISSING HANDLES
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
PROMPT 18. BACKUP SETS WITH UNAVAILABLE STATUS
PROMPT ============================================================

SELECT
    recid,
    set_stamp,
    set_count,
    status,
    backup_type,
    incremental_level,
    pieces,
    TO_CHAR(
        completion_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS completion_time
FROM v$backup_set
WHERE status <> 'A'
ORDER BY completion_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 19. RECENT BACKUP THROUGHPUT
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    input_type,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_min,
    ROUND(
        output_bytes
        / NULLIF(elapsed_seconds, 0)
        / 1024 / 1024,
        2
    ) AS output_mb_per_sec
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
  AND status = 'COMPLETED'
ORDER BY start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 20. BACKUP VALIDATION READINESS COUNTS
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
      WHERE status = 'X') AS expired_backup_pieces,

    (SELECT COUNT(*)
       FROM v$backup_piece
      WHERE status = 'U') AS unavailable_backup_pieces,

    (SELECT COUNT(*)
       FROM v$rman_backup_job_details
      WHERE start_time >= SYSDATE - 7
        AND status <> 'COMPLETED') AS failed_jobs_7d
FROM dual;


PROMPT
PROMPT ============================================================
PROMPT 21. RESTORE READINESS SUMMARY
PROMPT ============================================================

WITH metrics AS (
    SELECT
        (SELECT COUNT(*)
           FROM v$backup_set
          WHERE status <> 'A') AS unavailable_sets,

        (SELECT COUNT(*)
           FROM v$backup_piece
          WHERE status IN ('X', 'U')) AS bad_pieces,

        (SELECT COUNT(*)
           FROM v$rman_backup_job_details
          WHERE start_time >= SYSDATE - 7
            AND status <> 'COMPLETED') AS failed_jobs
    FROM dual
)
SELECT
    unavailable_sets,
    bad_pieces,
    failed_jobs,
    CASE
        WHEN unavailable_sets = 0
         AND bad_pieces = 0
         AND failed_jobs = 0
        THEN 'NO METADATA ISSUES DETECTED'
        ELSE 'INVESTIGATE BEFORE RESTORE'
    END AS restore_readiness
FROM metrics;


PROMPT
PROMPT ============================================================
PROMPT 22. RMAN VALIDATE COMMANDS
PROMPT ============================================================

PROMPT
PROMPT -- Validate database files:
PROMPT
PROMPT RMAN> VALIDATE DATABASE;
PROMPT
PROMPT -- Validate database backups:
PROMPT
PROMPT RMAN> VALIDATE BACKUPSET ALL;
PROMPT
PROMPT -- Validate database restore-readiness:
PROMPT
PROMPT RMAN> RESTORE DATABASE VALIDATE;
PROMPT
PROMPT -- Validate archived logs:
PROMPT
PROMPT RMAN> VALIDATE ARCHIVELOG ALL;
PROMPT
PROMPT -- Validate archived logs required for recovery:
PROMPT
PROMPT RMAN> RESTORE ARCHIVELOG ALL VALIDATE;
PROMPT
PROMPT -- Validate a specific backup piece:
PROMPT
PROMPT RMAN> VALIDATE BACKUPPIECE '<backup_piece>';
PROMPT


PROMPT
PROMPT ============================================================
PROMPT 23. RMAN COMPLETE RECOVERY VALIDATION EXAMPLE
PROMPT ============================================================

PROMPT
PROMPT RMAN> LIST BACKUP SUMMARY;
PROMPT RMAN> LIST BACKUP OF DATABASE;
PROMPT RMAN> LIST BACKUP OF ARCHIVELOG ALL;
PROMPT RMAN> RESTORE DATABASE VALIDATE;
PROMPT RMAN> RESTORE ARCHIVELOG ALL VALIDATE;
PROMPT


PROMPT
PROMPT ============================================================
PROMPT 24. DBA RESTORE VALIDATION CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT [1] Confirm the latest database backup.
PROMPT [2] Confirm required incremental/full backup chain.
PROMPT [3] Confirm all required backup pieces are AVAILABLE.
PROMPT [4] Check for EXPIRED backup pieces.
PROMPT [5] Check for UNAVAILABLE backup pieces.
PROMPT [6] Confirm ARCHIVELOG backup coverage.
PROMPT [7] In RAC, verify every redo thread has archive coverage.
PROMPT [8] Review recent failed RMAN jobs.
PROMPT [9] Run RMAN VALIDATE DATABASE.
PROMPT [10] Run RESTORE DATABASE VALIDATE.
PROMPT [11] Validate required ARCHIVELOG backups.
PROMPT [12] Perform periodic test restores according to
PROMPT      organizational recovery policy.
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT
PROMPT ============================================================
PROMPT
PROMPT A backup marked AVAILABLE in the RMAN repository does not
PROMPT guarantee that the backup can be restored successfully.
PROMPT
PROMPT RESTORE DATABASE VALIDATE provides stronger evidence that
PROMPT RMAN can locate and use the required backup files.
PROMPT
PROMPT A successful test restore/recovery provides stronger
PROMPT operational evidence than metadata-only checks.
PROMPT
PROMPT ============================================================
PROMPT END OF RMAN RESTORE VALIDATION
PROMPT ============================================================

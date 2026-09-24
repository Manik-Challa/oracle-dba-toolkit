-- ============================================================
-- RMAN BACKUP DETAILS
-- File: backup-recovery/rman_backup_details.sql
--
-- Purpose:
--   Detailed RMAN backup inventory and backup-piece analysis.
--
-- Covers:
--   1. Database information
--   2. Backup set summary
--   3. Backup set details
--   4. Backup pieces
--   5. Database backup details
--   6. Incremental backup levels
--   7. Archive log backup details
--   8. Backup coverage by datafile
--   9. Backup size by day
--  10. Backup size by tag
--  11. Backup device distribution
--  12. Backup compression details
--  13. Backup piece status
--  14. Backup age
--  15. Latest backup per backup type
--  16. Backup coverage summary
--
-- Notes:
--   * Read-only script.
--   * Uses RMAN control-file repository views.
--   * Repository retention depends on control-file settings
--     or recovery catalog configuration.
--   * A backup listed here does not automatically prove that
--     the backup is physically restorable.
--
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN db_name             FORMAT A15
COLUMN db_unique_name      FORMAT A20
COLUMN backup_type         FORMAT A18
COLUMN status              FORMAT A20
COLUMN device_type         FORMAT A15
COLUMN incremental_level   FORMAT 999
COLUMN start_time          FORMAT A22
COLUMN completion_time     FORMAT A22
COLUMN duration_min        FORMAT 999,999.99
COLUMN input_gb            FORMAT 999,999.99
COLUMN output_gb           FORMAT 999,999.99
COLUMN size_gb             FORMAT 999,999.99
COLUMN pieces              FORMAT 999,999
COLUMN files               FORMAT 999,999
COLUMN set_count           FORMAT 999,999
COLUMN piece_count         FORMAT 999,999
COLUMN tag                 FORMAT A35
COLUMN handle              FORMAT A90
COLUMN file_name           FORMAT A90
COLUMN tablespace_name     FORMAT A30
COLUMN checkpoint_time     FORMAT A22
COLUMN completion_age_days FORMAT 999,999.99

PROMPT
PROMPT ============================================================
PROMPT                 RMAN BACKUP DETAILS
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
-- 2. BACKUP SET SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. BACKUP SET SUMMARY
PROMPT ============================================================

SELECT
    bs.recid,
    bs.set_stamp,
    bs.set_count,
    bs.backup_type,
    bs.incremental_level,
    bs.status,
    TO_CHAR(bs.start_time, 'YYYY-MM-DD HH24:MI:SS')
        AS start_time,
    TO_CHAR(bs.completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    bs.pieces,
    bs.files,
    ROUND(
        bs.bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM v$backup_set bs
ORDER BY bs.completion_time DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================
-- 3. BACKUP SET DETAILS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. BACKUP SET DETAILS
PROMPT ============================================================

SELECT
    set_stamp,
    set_count,
    backup_type,
    incremental_level,
    status,
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS')
        AS start_time,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    pieces,
    files,
    ROUND(
        bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    compressed
FROM v$backup_set
ORDER BY completion_time DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================
-- 4. BACKUP PIECES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. RECENT BACKUP PIECES
PROMPT ============================================================

SELECT
    recid,
    stamp,
    set_stamp,
    set_count,
    piece#,
    copy#,
    status,
    device_type,
    TO_CHAR(
        completion_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS completion_time,
    ROUND(
        bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    tag,
    handle
FROM v$backup_piece
ORDER BY completion_time DESC
FETCH FIRST 100 ROWS ONLY;


-- ============================================================
-- 5. DATABASE BACKUP DETAILS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. DATABASE BACKUP DETAILS
PROMPT ============================================================

SELECT
    bs.set_stamp,
    bs.set_count,
    bs.incremental_level,
    bs.status,
    TO_CHAR(
        bs.start_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS start_time,
    TO_CHAR(
        bs.completion_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS completion_time,
    bs.pieces,
    bs.files,
    ROUND(
        bs.bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    bs.compressed
FROM v$backup_set bs
WHERE bs.backup_type = 'D'
ORDER BY bs.completion_time DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================
-- 6. INCREMENTAL BACKUP LEVEL SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. INCREMENTAL BACKUP LEVEL SUMMARY
PROMPT ============================================================

SELECT
    NVL(
        TO_CHAR(incremental_level),
        'FULL'
    ) AS backup_level,
    status,
    COUNT(*) AS backup_sets,
    SUM(pieces) AS pieces,
    SUM(files) AS files,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM v$backup_set
WHERE backup_type = 'D'
  AND completion_time >= SYSDATE - 30
GROUP BY
    NVL(
        TO_CHAR(incremental_level),
        'FULL'
    ),
    status
ORDER BY
    backup_level,
    status;


-- ============================================================
-- 7. ARCHIVE LOG BACKUP DETAILS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. ARCHIVE LOG BACKUP DETAILS
PROMPT ============================================================

SELECT
    bs.set_stamp,
    bs.set_count,
    bs.status,
    TO_CHAR(
        bs.start_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS start_time,
    TO_CHAR(
        bs.completion_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS completion_time,
    bs.pieces,
    bs.files,
    ROUND(
        bs.bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    bs.compressed
FROM v$backup_set bs
WHERE bs.backup_type = 'L'
ORDER BY bs.completion_time DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================
-- 8. ARCHIVE LOG BACKUP CONTENT
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. ARCHIVE LOG BACKUP CONTENT
PROMPT ============================================================

SELECT
    TO_CHAR(
        al.first_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS first_time,
    TO_CHAR(
        al.next_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS next_time,
    al.thread#,
    al.sequence#,
    al.first_change#,
    al.next_change#,
    al.completion_time,
    al.backed_by_rman
FROM v$archived_log al
WHERE al.backed_by_rman = 'YES'
ORDER BY
    al.completion_time DESC
FETCH FIRST 100 ROWS ONLY;


-- ============================================================
-- 9. DATAFILE BACKUP COVERAGE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. DATAFILE BACKUP COVERAGE
PROMPT ============================================================

SELECT
    df.file#,
    df.name AS file_name,
    df.tablespace_name,
    df.status,
    TO_CHAR(
        MAX(bdf.completion_time),
        'YYYY-MM-DD HH24:MI:SS'
    ) AS latest_backup,
    ROUND(
        SYSDATE - MAX(bdf.completion_time),
        2
    ) AS backup_age_days
FROM v$datafile df
LEFT JOIN v$backup_datafile bdf
    ON bdf.file# = df.file#
GROUP BY
    df.file#,
    df.name,
    df.tablespace_name,
    df.status
ORDER BY backup_age_days DESC NULLS FIRST;


-- ============================================================
-- 10. DATAFILE BACKUP DETAILS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. RECENT DATAFILE BACKUP DETAILS
PROMPT ============================================================

SELECT
    bdf.file#,
    df.tablespace_name,
    df.name AS file_name,
    bdf.set_stamp,
    bdf.set_count,
    bdf.incremental_level,
    bdf.status,
    TO_CHAR(
        bdf.completion_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS completion_time,
    ROUND(
        bdf.datafile_blocks * ts.block_size
        / 1024 / 1024 / 1024,
        2
    ) AS backed_up_gb
FROM v$backup_datafile bdf
JOIN v$datafile df
    ON df.file# = bdf.file#
JOIN dba_tablespaces ts
    ON ts.tablespace_name = df.tablespace_name
ORDER BY bdf.completion_time DESC
FETCH FIRST 100 ROWS ONLY;


-- ============================================================
-- 11. BACKUP SIZE BY DAY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. BACKUP SIZE BY DAY - LAST 30 DAYS
PROMPT ============================================================

SELECT
    TRUNC(completion_time) AS backup_date,
    COUNT(*) AS backup_sets,
    SUM(pieces) AS pieces,
    SUM(files) AS files,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM v$backup_set
WHERE completion_time >= SYSDATE - 30
GROUP BY TRUNC(completion_time)
ORDER BY backup_date DESC;


-- ============================================================
-- 12. BACKUP SIZE BY TAG
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. BACKUP SIZE BY TAG
PROMPT ============================================================

SELECT
    NVL(tag, 'NO TAG') AS tag,
    COUNT(*) AS piece_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM v$backup_piece
WHERE completion_time >= SYSDATE - 30
GROUP BY tag
ORDER BY size_gb DESC;


-- ============================================================
-- 13. BACKUP DEVICE DISTRIBUTION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. BACKUP DEVICE DISTRIBUTION
PROMPT ============================================================

SELECT
    device_type,
    COUNT(*) AS piece_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM v$backup_piece
WHERE completion_time >= SYSDATE - 30
GROUP BY device_type
ORDER BY size_gb DESC;


-- ============================================================
-- 14. BACKUP COMPRESSION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. BACKUP COMPRESSION SUMMARY
PROMPT ============================================================

SELECT
    compressed,
    COUNT(*) AS backup_sets,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM v$backup_set
WHERE completion_time >= SYSDATE - 30
GROUP BY compressed
ORDER BY compressed;


-- ============================================================
-- 15. BACKUP PIECE STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. BACKUP PIECE STATUS
PROMPT ============================================================

SELECT
    status,
    COUNT(*) AS piece_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM v$backup_piece
WHERE completion_time >= SYSDATE - 30
GROUP BY status
ORDER BY status;


-- ============================================================
-- 16. BACKUP AGE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. BACKUP AGE
PROMPT ============================================================

SELECT
    backup_type,
    MAX(completion_time) AS latest_backup,
    ROUND(
        SYSDATE - MAX(completion_time),
        2
    ) AS age_days,
    CASE
        WHEN MAX(completion_time) IS NULL
            THEN 'NO BACKUP FOUND'
        WHEN SYSDATE - MAX(completion_time) <= 1
            THEN 'RECENT'
        WHEN SYSDATE - MAX(completion_time) <= 7
            THEN 'REVIEW'
        ELSE 'OLD'
    END AS health_status
FROM (
    SELECT
        'DATABASE' AS backup_type,
        completion_time
    FROM v$backup_set
    WHERE backup_type = 'D'
      AND status = 'A'

    UNION ALL

    SELECT
        'ARCHIVE LOG' AS backup_type,
        completion_time
    FROM v$backup_set
    WHERE backup_type = 'L'
      AND status = 'A'
)
GROUP BY backup_type
ORDER BY backup_type;


-- ============================================================
-- 17. LATEST BACKUP BY TYPE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. LATEST BACKUP BY TYPE
PROMPT ============================================================

SELECT
    CASE
        WHEN backup_type = 'D'
            THEN 'DATABASE'
        WHEN backup_type = 'L'
            THEN 'ARCHIVE LOG'
        WHEN backup_type = 'I'
            THEN 'INCREMENTAL'
        ELSE backup_type
    END AS backup_type,
    MAX(completion_time) AS latest_backup
FROM v$backup_set
WHERE status = 'A'
GROUP BY backup_type
ORDER BY backup_type;


-- ============================================================
-- 18. BACKUPS WITH LONG GAP
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. BACKUP COVERAGE GAPS
PROMPT ============================================================

SELECT
    backup_date,
    next_backup_date,
    ROUND(
        next_backup_date - backup_date,
        2
    ) AS gap_days
FROM (
    SELECT
        TRUNC(completion_time) AS backup_date,
        LEAD(
            TRUNC(completion_time)
        ) OVER (
            ORDER BY TRUNC(completion_time)
        ) AS next_backup_date
    FROM v$backup_set
    WHERE backup_type = 'D'
      AND status = 'A'
)
WHERE next_backup_date IS NOT NULL
  AND next_backup_date - backup_date > 1
ORDER BY gap_days DESC;


-- ============================================================
-- 19. LARGEST BACKUP PIECES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 19. LARGEST BACKUP PIECES
PROMPT ============================================================

SELECT
    piece#,
    status,
    device_type,
    ROUND(
        bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    TO_CHAR(
        completion_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS completion_time,
    tag,
    handle
FROM v$backup_piece
ORDER BY bytes DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================
-- 20. BACKUP SET / PIECE CORRELATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 20. BACKUP SET / PIECE CORRELATION
PROMPT ============================================================

SELECT
    bs.set_stamp,
    bs.set_count,
    bs.backup_type,
    bs.incremental_level,
    bs.status AS set_status,
    bp.piece#,
    bp.status AS piece_status,
    bp.device_type,
    ROUND(
        bp.bytes / 1024 / 1024 / 1024,
        2
    ) AS piece_size_gb,
    bp.tag,
    bp.handle
FROM v$backup_set bs
JOIN v$backup_piece bp
    ON bp.set_stamp = bs.set_stamp
   AND bp.set_count = bs.set_count
ORDER BY bs.completion_time DESC
FETCH FIRST 100 ROWS ONLY;


-- ============================================================
-- 21. RECENT INCOMPLETE BACKUPS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 21. RECENT INCOMPLETE BACKUPS
PROMPT ============================================================

SELECT
    set_stamp,
    set_count,
    backup_type,
    incremental_level,
    status,
    TO_CHAR(
        start_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS start_time,
    TO_CHAR(
        completion_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS completion_time,
    pieces,
    files,
    ROUND(
        bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM v$backup_set
WHERE status <> 'A'
ORDER BY completion_time DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================
-- 22. BACKUP COVERAGE SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 22. BACKUP COVERAGE SUMMARY
PROMPT ============================================================

SELECT
    COUNT(DISTINCT df.file#) AS total_datafiles,

    COUNT(
        DISTINCT
        CASE
            WHEN bdf.file# IS NOT NULL
            THEN df.file#
        END
    ) AS datafiles_with_backup,

    COUNT(
        DISTINCT
        CASE
            WHEN bdf.file# IS NULL
            THEN df.file#
        END
    ) AS datafiles_without_backup

FROM v$datafile df
LEFT JOIN v$backup_datafile bdf
    ON bdf.file# = df.file#;


-- ============================================================
-- 23. DATABASE BACKUP HEALTH
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 23. DATABASE BACKUP HEALTH
PROMPT ============================================================

SELECT
    MAX(completion_time) AS latest_database_backup,

    ROUND(
        SYSDATE - MAX(completion_time),
        2
    ) AS backup_age_days,

    CASE
        WHEN MAX(completion_time) IS NULL
            THEN 'NO BACKUP FOUND'
        WHEN SYSDATE - MAX(completion_time) <= 1
            THEN 'OK'
        WHEN SYSDATE - MAX(completion_time) <= 2
            THEN 'INVESTIGATE'
        ELSE 'BACKUP IS OLD'
    END AS health_status

FROM v$backup_set
WHERE backup_type = 'D'
  AND status = 'A';


-- ============================================================
-- 24. RMAN BACKUP DETAILS QUICK CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 24. RMAN BACKUP DETAILS QUICK CHECK
PROMPT ============================================================

SELECT
    'DATABASE BACKUPS - LAST 7 DAYS' AS check_name,
    COUNT(*) AS value
FROM v$backup_set
WHERE backup_type = 'D'
  AND completion_time >= SYSDATE - 7

UNION ALL

SELECT
    'ARCHIVE LOG BACKUPS - LAST 7 DAYS',
    COUNT(*)
FROM v$backup_set
WHERE backup_type = 'L'
  AND completion_time >= SYSDATE - 7

UNION ALL

SELECT
    'INCOMPLETE BACKUP SETS',
    COUNT(*)
FROM v$backup_set
WHERE status <> 'A'

UNION ALL

SELECT
    'BACKUP PIECES - LAST 7 DAYS',
    COUNT(*)
FROM v$backup_piece
WHERE completion_time >= SYSDATE - 7;


PROMPT
PROMPT ============================================================
PROMPT RMAN BACKUP DETAILS - DBA CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT 1. Verify backup sets are AVAILABLE.
PROMPT 2. Verify backup pieces are AVAILABLE.
PROMPT 3. Check the latest database backup.
PROMPT 4. Check the latest archive log backup.
PROMPT 5. Review datafile backup coverage.
PROMPT 6. Review backup gaps.
PROMPT 7. Review backup size changes.
PROMPT 8. Review compression and device usage.
PROMPT 9. Investigate incomplete backup sets.
PROMPT 10. Validate important backups with RMAN VALIDATE.
PROMPT 11. Perform periodic restore/recovery testing.
PROMPT
PROMPT IMPORTANT:
PROMPT Backup metadata alone does not prove restore success.
PROMPT Always validate critical backups and test recovery procedures.
PROMPT
PROMPT ============================================================
PROMPT END OF RMAN BACKUP DETAILS
PROMPT ============================================================
 
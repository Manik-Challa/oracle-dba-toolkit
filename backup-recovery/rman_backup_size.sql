-- ============================================================
-- RMAN BACKUP SIZE & GROWTH
-- Oracle DBA Toolkit
--
-- Purpose:
--   Monitor RMAN backup volume, daily backup growth,
--   largest backup pieces, compression, device usage
--   and backup size trends.
--
-- Read-only monitoring script.
--
-- Notes:
--   - Uses RMAN control-file repository views.
--   - Size values are based on RMAN metadata.
--   - Backup size trends are workload dependent.
--   - Actual storage consumption can differ depending on
--     deduplication, compression and media-manager behavior.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

COLUMN db_name             FORMAT A15
COLUMN database_role       FORMAT A20
COLUMN backup_date         FORMAT A12
COLUMN backup_type         FORMAT A15
COLUMN device_type         FORMAT A18
COLUMN status               FORMAT A12
COLUMN tag                  FORMAT A25
COLUMN compression         FORMAT A18
COLUMN size_gb              FORMAT 99999990.99
COLUMN input_gb             FORMAT 99999990.99
COLUMN output_gb            FORMAT 99999990.99
COLUMN avg_gb               FORMAT 99999990.99
COLUMN min_gb               FORMAT 99999990.99
COLUMN max_gb               FORMAT 99999990.99
COLUMN pieces               FORMAT 999999
COLUMN backup_sets          FORMAT 999999
COLUMN backup_count         FORMAT 999999
COLUMN elapsed_min          FORMAT 9999990.99
COLUMN growth_gb            FORMAT 99999990.99
COLUMN growth_pct           FORMAT 999990.99
COLUMN handle               FORMAT A100

PROMPT
PROMPT ============================================================
PROMPT RMAN BACKUP SIZE & GROWTH
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
PROMPT 2. RMAN BACKUP SIZE SUMMARY - LAST 7 DAYS
PROMPT ============================================================

SELECT
    input_type AS backup_type,
    output_device_type AS device_type,
    COUNT(*) AS backup_count,
    ROUND(SUM(input_bytes) / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(AVG(output_bytes) / 1024 / 1024 / 1024, 2) AS avg_gb,
    ROUND(MIN(output_bytes) / 1024 / 1024 / 1024, 2) AS min_gb,
    ROUND(MAX(output_bytes) / 1024 / 1024 / 1024, 2) AS max_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 7
  AND status = 'COMPLETED'
GROUP BY
    input_type,
    output_device_type
ORDER BY
    output_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 3. DAILY BACKUP SIZE - LAST 30 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(TRUNC(start_time), 'YYYY-MM-DD') AS backup_date,
    COUNT(*) AS backup_count,
    ROUND(SUM(input_bytes) / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(AVG(output_bytes) / 1024 / 1024 / 1024, 2) AS avg_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status = 'COMPLETED'
GROUP BY TRUNC(start_time)
ORDER BY backup_date DESC;


PROMPT
PROMPT ============================================================
PROMPT 4. DATABASE BACKUP SIZE BY TYPE - LAST 30 DAYS
PROMPT ============================================================

SELECT
    input_type AS backup_type,
    COUNT(*) AS backup_count,
    ROUND(SUM(input_bytes) / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(AVG(output_bytes) / 1024 / 1024 / 1024, 2) AS avg_output_gb,
    ROUND(MAX(output_bytes) / 1024 / 1024 / 1024, 2) AS max_output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status = 'COMPLETED'
GROUP BY input_type
ORDER BY output_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 5. RMAN BACKUP SIZE BY DEVICE
PROMPT ============================================================

SELECT
    output_device_type AS device_type,
    COUNT(*) AS backup_count,
    ROUND(SUM(input_bytes) / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(AVG(output_bytes) / 1024 / 1024 / 1024, 2) AS avg_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status = 'COMPLETED'
GROUP BY output_device_type
ORDER BY output_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 6. DAILY BACKUP SIZE BY TYPE
PROMPT ============================================================

SELECT
    TO_CHAR(TRUNC(start_time), 'YYYY-MM-DD') AS backup_date,
    input_type AS backup_type,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status = 'COMPLETED'
GROUP BY
    TRUNC(start_time),
    input_type
ORDER BY
    backup_date DESC,
    output_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. LARGEST RMAN BACKUP JOBS - LAST 30 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_date,
    input_type AS backup_type,
    output_device_type AS device_type,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_min,
    status
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
ORDER BY output_bytes DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 8. LARGEST BACKUP PIECES
PROMPT ============================================================

SELECT
    recid,
    set_stamp,
    set_count,
    status,
    device_type,
    completion_time,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    handle
FROM v$backup_piece
WHERE status = 'A'
ORDER BY bytes DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 9. BACKUP PIECE SIZE SUMMARY
PROMPT ============================================================

SELECT
    device_type,
    status,
    COUNT(*) AS pieces,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(AVG(bytes) / 1024 / 1024 / 1024, 2) AS avg_gb,
    ROUND(MAX(bytes) / 1024 / 1024 / 1024, 2) AS max_gb
FROM v$backup_piece
GROUP BY
    device_type,
    status
ORDER BY
    size_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. BACKUP SIZE BY TAG
PROMPT ============================================================

SELECT
    NVL(tag, 'NO TAG') AS tag,
    COUNT(*) AS backup_pieces,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(AVG(bytes) / 1024 / 1024 / 1024, 2) AS avg_gb,
    ROUND(MAX(bytes) / 1024 / 1024 / 1024, 2) AS max_gb
FROM v$backup_piece
WHERE status = 'A'
GROUP BY tag
ORDER BY size_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 11. BACKUP SET SIZE BY BACKUP TYPE
PROMPT ============================================================

SELECT
    backup_type,
    incremental_level,
    status,
    COUNT(*) AS backup_sets,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(AVG(bytes) / 1024 / 1024 / 1024, 2) AS avg_gb,
    ROUND(MAX(bytes) / 1024 / 1024 / 1024, 2) AS max_gb
FROM v$backup_set
GROUP BY
    backup_type,
    incremental_level,
    status
ORDER BY
    size_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 12. ARCHIVE LOG BACKUP SIZE - LAST 30 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(TRUNC(completion_time), 'YYYY-MM-DD') AS backup_date,
    COUNT(*) AS archive_backup_records,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(AVG(bytes) / 1024 / 1024 / 1024, 2) AS avg_gb,
    ROUND(MAX(bytes) / 1024 / 1024 / 1024, 2) AS max_gb
FROM v$backup_redolog
WHERE completion_time >= SYSDATE - 30
GROUP BY TRUNC(completion_time)
ORDER BY backup_date DESC;


PROMPT
PROMPT ============================================================
PROMPT 13. ARCHIVE LOG BACKUP SIZE BY THREAD
PROMPT ============================================================

SELECT
    thread#,
    COUNT(*) AS archive_records,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(AVG(bytes) / 1024 / 1024 / 1024, 2) AS avg_gb,
    ROUND(MAX(bytes) / 1024 / 1024 / 1024, 2) AS max_gb
FROM v$backup_redolog
WHERE completion_time >= SYSDATE - 30
GROUP BY thread#
ORDER BY size_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. BACKUP COMPRESSION / INPUT-OUTPUT RATIO
PROMPT ============================================================

SELECT
    input_type AS backup_type,
    COUNT(*) AS backup_count,
    ROUND(SUM(input_bytes) / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(
        SUM(input_bytes) / NULLIF(SUM(output_bytes), 0),
        2
    ) AS input_output_ratio
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status = 'COMPLETED'
GROUP BY input_type
ORDER BY output_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. DAILY INPUT / OUTPUT RATIO
PROMPT ============================================================

SELECT
    TO_CHAR(TRUNC(start_time), 'YYYY-MM-DD') AS backup_date,
    ROUND(SUM(input_bytes) / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(
        SUM(input_bytes) / NULLIF(SUM(output_bytes), 0),
        2
    ) AS input_output_ratio
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status = 'COMPLETED'
GROUP BY TRUNC(start_time)
ORDER BY backup_date DESC;


PROMPT
PROMPT ============================================================
PROMPT 16. WEEKLY BACKUP SIZE TREND
PROMPT ============================================================

SELECT
    TO_CHAR(TRUNC(start_time, 'IW'), 'YYYY-MM-DD') AS week_start,
    COUNT(*) AS backup_count,
    ROUND(SUM(input_bytes) / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(AVG(output_bytes) / 1024 / 1024 / 1024, 2) AS avg_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 90
  AND status = 'COMPLETED'
GROUP BY TRUNC(start_time, 'IW')
ORDER BY week_start DESC;


PROMPT
PROMPT ============================================================
PROMPT 17. RECENT BACKUP SIZE COMPARED WITH PREVIOUS PERIOD
PROMPT ============================================================

WITH backup_periods AS (
    SELECT
        CASE
            WHEN start_time >= SYSDATE - 7
                THEN 'LAST_7_DAYS'
            WHEN start_time >= SYSDATE - 14
                THEN 'PREVIOUS_7_DAYS'
        END AS period_name,
        output_bytes
    FROM v$rman_backup_job_details
    WHERE start_time >= SYSDATE - 14
      AND status = 'COMPLETED'
)
SELECT
    period_name,
    COUNT(*) AS backup_count,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(AVG(output_bytes) / 1024 / 1024 / 1024, 2) AS avg_gb
FROM backup_periods
GROUP BY period_name
ORDER BY period_name;


PROMPT
PROMPT ============================================================
PROMPT 18. BACKUP SIZE GROWTH INDICATOR
PROMPT ============================================================

WITH period_sizes AS (
    SELECT
        SUM(
            CASE
                WHEN start_time >= SYSDATE - 7
                THEN output_bytes
                ELSE 0
            END
        ) AS current_7d,

        SUM(
            CASE
                WHEN start_time >= SYSDATE - 14
                 AND start_time < SYSDATE - 7
                THEN output_bytes
                ELSE 0
            END
        ) AS previous_7d
    FROM v$rman_backup_job_details
    WHERE start_time >= SYSDATE - 14
      AND status = 'COMPLETED'
)
SELECT
    ROUND(current_7d / 1024 / 1024 / 1024, 2) AS current_7d_gb,
    ROUND(previous_7d / 1024 / 1024 / 1024, 2) AS previous_7d_gb,
    ROUND(
        (current_7d - previous_7d)
        / NULLIF(previous_7d, 0) * 100,
        2
    ) AS growth_pct
FROM period_sizes;


PROMPT
PROMPT ============================================================
PROMPT 19. BACKUP SIZE BY STATUS
PROMPT ============================================================

SELECT
    status,
    COUNT(*) AS backup_jobs,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(AVG(output_bytes) / 1024 / 1024 / 1024, 2) AS avg_gb,
    ROUND(MAX(output_bytes) / 1024 / 1024 / 1024, 2) AS max_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
GROUP BY status
ORDER BY output_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 20. BACKUP DURATION VS BACKUP SIZE
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_date,
    input_type AS backup_type,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_min,
    ROUND(
        output_bytes / NULLIF(elapsed_seconds, 0)
        / 1024 / 1024,
        2
    ) AS output_mb_per_sec,
    status
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status = 'COMPLETED'
ORDER BY output_bytes DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 21. LATEST BACKUP SIZE SUMMARY
PROMPT ============================================================

SELECT
    input_type AS backup_type,
    TO_CHAR(MAX(start_time), 'YYYY-MM-DD HH24:MI:SS') AS latest_backup,
    COUNT(*) AS backup_count,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS total_output_gb,
    ROUND(MAX(output_bytes) / 1024 / 1024 / 1024, 2) AS largest_gb
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status = 'COMPLETED'
GROUP BY input_type
ORDER BY latest_backup DESC;


PROMPT
PROMPT ============================================================
PROMPT 22. RMAN BACKUP STORAGE SUMMARY
PROMPT ============================================================

SELECT
    output_device_type AS device_type,
    COUNT(*) AS jobs,
    ROUND(SUM(output_bytes) / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(
        100 * SUM(output_bytes)
        / NULLIF(
            SUM(SUM(output_bytes)) OVER (),
            0
          ),
        2
    ) AS pct_of_total
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND status = 'COMPLETED'
GROUP BY output_device_type
ORDER BY output_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 23. BACKUP SIZE HEALTH SUMMARY
PROMPT ============================================================

WITH current_period AS (
    SELECT NVL(SUM(output_bytes), 0) AS bytes
    FROM v$rman_backup_job_details
    WHERE start_time >= SYSDATE - 7
      AND status = 'COMPLETED'
),
previous_period AS (
    SELECT NVL(SUM(output_bytes), 0) AS bytes
    FROM v$rman_backup_job_details
    WHERE start_time >= SYSDATE - 14
      AND start_time < SYSDATE - 7
      AND status = 'COMPLETED'
)
SELECT
    ROUND(c.bytes / 1024 / 1024 / 1024, 2) AS current_7d_gb,
    ROUND(p.bytes / 1024 / 1024 / 1024, 2) AS previous_7d_gb,
    ROUND(
        (c.bytes - p.bytes)
        / NULLIF(p.bytes, 0) * 100,
        2
    ) AS growth_pct,
    CASE
        WHEN p.bytes = 0 AND c.bytes > 0
            THEN 'BASELINE - NO PREVIOUS PERIOD'
        WHEN ABS((c.bytes - p.bytes) / NULLIF(p.bytes, 0) * 100) >= 50
            THEN 'INVESTIGATE LARGE SIZE CHANGE'
        ELSE 'NORMAL TREND'
    END AS size_trend
FROM current_period c
CROSS JOIN previous_period p;


PROMPT
PROMPT ============================================================
PROMPT DBA REVIEW CHECKLIST
PROMPT ============================================================
PROMPT 1. Review daily backup volume for unexpected growth.
PROMPT 2. Compare current 7-day output with the previous 7 days.
PROMPT 3. Check unusually large backup jobs or pieces.
PROMPT 4. Review ARCHIVELOG backup growth, especially on RAC.
PROMPT 5. Check backup device distribution.
PROMPT 6. Review input/output ratio when compression is used.
PROMPT 7. Investigate sudden changes in backup duration or throughput.
PROMPT 8. Correlate backup growth with database/data growth.
PROMPT 9. Check FRA/storage capacity separately.
PROMPT 10. Review retention requirements before removing backups.
PROMPT
PROMPT IMPORTANT:
PROMPT Backup size growth does not automatically indicate a problem.
PROMPT Full backups, incremental strategy, workload, ARCHIVELOG rate,
PROMPT compression and retention policy all affect backup volume.
PROMPT
PROMPT ============================================================
PROMPT END OF RMAN BACKUP SIZE CHECK
PROMPT ============================================================


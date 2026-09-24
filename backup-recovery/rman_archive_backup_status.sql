-- ============================================================
-- RMAN ARCHIVELOG BACKUP STATUS
-- Oracle DBA Toolkit
--
-- Purpose:
--   Monitor ARCHIVELOG backup coverage, latest backed-up
--   sequences, RAC thread coverage, archive backup volume,
--   recent archive backup activity and potential gaps.
--
-- Read-only monitoring script.
--
-- Important:
--   - Archive log sequence continuity alone does not prove
--     recoverability.
--   - V$ARCHIVED_LOG can contain multiple rows for the same
--     sequence because of destinations/history.
--   - APPLIED status is primarily meaningful in Data Guard
--     environments.
--   - RMAN metadata should be correlated with actual backup
--     validation and recovery requirements.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

COLUMN db_name             FORMAT A15
COLUMN database_role       FORMAT A20
COLUMN thread#             FORMAT 999
COLUMN sequence#           FORMAT 999999999
COLUMN backup_count        FORMAT 999999
COLUMN archive_count       FORMAT 999999
COLUMN backup_date         FORMAT A12
COLUMN first_time          FORMAT A20
COLUMN next_time           FORMAT A20
COLUMN completion_time     FORMAT A20
COLUMN latest_archive      FORMAT A20
COLUMN latest_backup       FORMAT A20
COLUMN status              FORMAT A12
COLUMN applied             FORMAT A10
COLUMN device_type         FORMAT A18
COLUMN size_gb             FORMAT 9999990.99
COLUMN size_mb             FORMAT 9999990.99
COLUMN gap_count           FORMAT 999999
COLUMN min_sequence        FORMAT 999999999
COLUMN max_sequence        FORMAT 999999999
COLUMN backed_up_sequences FORMAT 999999999
COLUMN destination         FORMAT A20

PROMPT
PROMPT ============================================================
PROMPT RMAN ARCHIVELOG BACKUP STATUS
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
PROMPT 2. ARCHIVE DESTINATION STATUS
PROMPT ============================================================

SELECT
    dest_id,
    status,
    target,
    destination,
    error,
    valid_type,
    valid_role
FROM v$archive_dest
WHERE status <> 'INACTIVE'
ORDER BY dest_id;


PROMPT
PROMPT ============================================================
PROMPT 3. RECENT ARCHIVED LOG GENERATION - LAST 24 HOURS
PROMPT ============================================================

SELECT
    thread#,
    COUNT(*) AS archive_count,
    MIN(sequence#) AS min_sequence,
    MAX(sequence#) AS max_sequence,
    ROUND(SUM(blocks * block_size) / 1024 / 1024 / 1024, 2)
        AS size_gb,
    TO_CHAR(MIN(first_time), 'YYYY-MM-DD HH24:MI:SS')
        AS first_time,
    TO_CHAR(MAX(next_time), 'YYYY-MM-DD HH24:MI:SS')
        AS next_time
FROM v$archived_log
WHERE first_time >= SYSDATE - 1
  AND standby_dest = 'NO'
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================
PROMPT 4. ARCHIVELOG BACKUPS - LAST 24 HOURS
PROMPT ============================================================

SELECT
    COUNT(*) AS archive_backup_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    TO_CHAR(MIN(completion_time), 'YYYY-MM-DD HH24:MI:SS')
        AS first_backup,
    TO_CHAR(MAX(completion_time), 'YYYY-MM-DD HH24:MI:SS')
        AS latest_backup
FROM v$backup_redolog
WHERE completion_time >= SYSDATE - 1;


PROMPT
PROMPT ============================================================
PROMPT 5. ARCHIVELOG BACKUPS BY THREAD
PROMPT ============================================================

SELECT
    thread#,
    COUNT(*) AS backup_count,
    MIN(sequence#) AS min_sequence,
    MAX(sequence#) AS max_sequence,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    TO_CHAR(MAX(completion_time), 'YYYY-MM-DD HH24:MI:SS')
        AS latest_backup
FROM v$backup_redolog
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================
PROMPT 6. ARCHIVELOG BACKUP ACTIVITY - LAST 7 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(TRUNC(completion_time), 'YYYY-MM-DD') AS backup_date,
    thread#,
    COUNT(*) AS backup_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_redolog
WHERE completion_time >= SYSDATE - 7
GROUP BY
    TRUNC(completion_time),
    thread#
ORDER BY
    backup_date DESC,
    thread#;


PROMPT
PROMPT ============================================================
PROMPT 7. ARCHIVELOG BACKUP ACTIVITY - LAST 30 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(TRUNC(completion_time), 'YYYY-MM-DD') AS backup_date,
    COUNT(*) AS backup_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$backup_redolog
WHERE completion_time >= SYSDATE - 30
GROUP BY TRUNC(completion_time)
ORDER BY backup_date DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. LATEST ARCHIVELOG GENERATED BY THREAD
PROMPT ============================================================

SELECT
    thread#,
    MAX(sequence#) AS latest_sequence,
    TO_CHAR(MAX(next_time), 'YYYY-MM-DD HH24:MI:SS')
        AS latest_archive_time
FROM v$archived_log
WHERE standby_dest = 'NO'
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================
PROMPT 9. LATEST ARCHIVELOG BACKED UP BY THREAD
PROMPT ============================================================

SELECT
    thread#,
    MAX(sequence#) AS latest_backed_up_sequence,
    TO_CHAR(MAX(completion_time), 'YYYY-MM-DD HH24:MI:SS')
        AS latest_backup_time
FROM v$backup_redolog
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================
PROMPT 10. GENERATED VS BACKED-UP SEQUENCE
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
    b.backed_up_sequence,
    g.generated_sequence - NVL(b.backed_up_sequence, 0)
        AS sequence_difference
FROM generated g
LEFT JOIN backed_up b
    ON b.thread# = g.thread#
ORDER BY g.thread#;


PROMPT
PROMPT ============================================================
PROMPT 11. RECENT ARCHIVELOGS NOT YET RECORDED AS BACKED UP
PROMPT ============================================================

SELECT
    a.thread#,
    a.sequence#,
    TO_CHAR(a.first_time, 'YYYY-MM-DD HH24:MI:SS') AS first_time,
    TO_CHAR(a.next_time,  'YYYY-MM-DD HH24:MI:SS') AS next_time,
    ROUND(a.blocks * a.block_size / 1024 / 1024, 2) AS size_mb
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
PROMPT 12. ARCHIVELOGS WITH MULTIPLE BACKUP RECORDS
PROMPT ============================================================

SELECT
    thread#,
    sequence#,
    COUNT(*) AS backup_records,
    ROUND(SUM(bytes) / 1024 / 1024, 2) AS total_recorded_mb,
    TO_CHAR(MAX(completion_time), 'YYYY-MM-DD HH24:MI:SS')
        AS latest_backup
FROM v$backup_redolog
GROUP BY
    thread#,
    sequence#
HAVING COUNT(*) > 1
ORDER BY
    backup_records DESC,
    thread#,
    sequence#;


PROMPT
PROMPT ============================================================
PROMPT 13. RECENT ARCHIVELOG BACKUP DETAILS
PROMPT ============================================================

SELECT
    thread#,
    sequence#,
    TO_CHAR(first_time, 'YYYY-MM-DD HH24:MI:SS') AS first_time,
    TO_CHAR(next_time, 'YYYY-MM-DD HH24:MI:SS') AS next_time,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM v$backup_redolog
WHERE completion_time >= SYSDATE - 7
ORDER BY
    completion_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. ARCHIVELOG BACKUP SIZE BY THREAD
PROMPT ============================================================

SELECT
    thread#,
    COUNT(*) AS archive_backup_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(AVG(bytes) / 1024 / 1024, 2) AS avg_size_mb,
    ROUND(MAX(bytes) / 1024 / 1024, 2) AS max_size_mb
FROM v$backup_redolog
WHERE completion_time >= SYSDATE - 30
GROUP BY thread#
ORDER BY size_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. ARCHIVELOG GENERATION VS BACKUP - LAST 7 DAYS
PROMPT ============================================================

WITH generated AS (
    SELECT
        TRUNC(first_time) AS backup_date,
        thread#,
        COUNT(*) AS generated_count,
        SUM(blocks * block_size) AS generated_bytes
    FROM v$archived_log
    WHERE first_time >= SYSDATE - 7
      AND standby_dest = 'NO'
    GROUP BY
        TRUNC(first_time),
        thread#
),
backed_up AS (
    SELECT
        TRUNC(completion_time) AS backup_date,
        thread#,
        COUNT(*) AS backed_up_count,
        SUM(bytes) AS backed_up_bytes
    FROM v$backup_redolog
    WHERE completion_time >= SYSDATE - 7
    GROUP BY
        TRUNC(completion_time),
        thread#
)
SELECT
    TO_CHAR(g.backup_date, 'YYYY-MM-DD') AS backup_date,
    g.thread#,
    g.generated_count,
    NVL(b.backed_up_count, 0) AS backed_up_count,
    ROUND(g.generated_bytes / 1024 / 1024 / 1024, 2)
        AS generated_gb,
    ROUND(NVL(b.backed_up_bytes, 0) / 1024 / 1024 / 1024, 2)
        AS backed_up_gb
FROM generated g
LEFT JOIN backed_up b
    ON b.backup_date = g.backup_date
   AND b.thread# = g.thread#
ORDER BY
    g.backup_date DESC,
    g.thread#;


PROMPT
PROMPT ============================================================
PROMPT 16. ARCHIVELOG SEQUENCE DISCONTINUITIES
PROMPT ============================================================

SELECT
    thread#,
    sequence#,
    LAG(sequence#) OVER (
        PARTITION BY thread#
        ORDER BY sequence#
    ) AS previous_sequence,
    sequence#
      - LAG(sequence#) OVER (
            PARTITION BY thread#
            ORDER BY sequence#
        ) AS sequence_difference
FROM v$archived_log
WHERE standby_dest = 'NO'
  AND first_time >= SYSDATE - 7
ORDER BY
    thread#,
    sequence#;


PROMPT
PROMPT ============================================================
PROMPT 17. POTENTIAL SEQUENCE GAPS
PROMPT ============================================================

SELECT
    thread#,
    previous_sequence,
    sequence# AS current_sequence,
    sequence# - previous_sequence AS gap_difference
FROM (
    SELECT
        thread#,
        sequence#,
        LAG(sequence#) OVER (
            PARTITION BY thread#
            ORDER BY sequence#
        ) AS previous_sequence
    FROM v$archived_log
    WHERE standby_dest = 'NO'
      AND first_time >= SYSDATE - 7
)
WHERE previous_sequence IS NOT NULL
  AND sequence# > previous_sequence + 1
ORDER BY
    thread#,
    sequence#;


PROMPT
PROMPT ============================================================
PROMPT 18. ARCHIVELOGS WITH APPLIED STATUS
PROMPT ============================================================

SELECT
    thread#,
    applied,
    COUNT(*) AS archive_count,
    MIN(sequence#) AS min_sequence,
    MAX(sequence#) AS max_sequence
FROM v$archived_log
WHERE first_time >= SYSDATE - 7
GROUP BY
    thread#,
    applied
ORDER BY
    thread#,
    applied;


PROMPT
PROMPT ============================================================
PROMPT 19. RMAN ARCHIVELOG BACKUP JOBS - LAST 30 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    TO_CHAR(end_time,   'YYYY-MM-DD HH24:MI:SS') AS backup_end,
    status,
    output_device_type AS device_type,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_min
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND input_type = 'ARCHIVELOG'
ORDER BY start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 20. FAILED / INCOMPLETE ARCHIVELOG BACKUP JOBS
PROMPT ============================================================

SELECT
    TO_CHAR(start_time, 'YYYY-MM-DD HH24:MI:SS') AS backup_start,
    TO_CHAR(end_time,   'YYYY-MM-DD HH24:MI:SS') AS backup_end,
    status,
    output_device_type AS device_type,
    ROUND(input_bytes / 1024 / 1024 / 1024, 2) AS input_gb,
    ROUND(output_bytes / 1024 / 1024 / 1024, 2) AS output_gb,
    ROUND(elapsed_seconds / 60, 2) AS elapsed_min
FROM v$rman_backup_job_details
WHERE start_time >= SYSDATE - 30
  AND input_type = 'ARCHIVELOG'
  AND status <> 'COMPLETED'
ORDER BY start_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 21. LATEST BACKUP TIME BY THREAD
PROMPT ============================================================

SELECT
    thread#,
    MAX(completion_time) AS latest_backup_time,
    MAX(sequence#) AS latest_backed_up_sequence
FROM v$backup_redolog
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================
PROMPT 22. ARCHIVELOG BACKUP HEALTH SUMMARY
PROMPT ============================================================

WITH generated AS (
    SELECT
        thread#,
        MAX(sequence#) AS latest_generated
    FROM v$archived_log
    WHERE standby_dest = 'NO'
    GROUP BY thread#
),
backed_up AS (
    SELECT
        thread#,
        MAX(sequence#) AS latest_backed_up
    FROM v$backup_redolog
    GROUP BY thread#
),
failed_jobs AS (
    SELECT COUNT(*) AS failed_count
    FROM v$rman_backup_job_details
    WHERE start_time >= SYSDATE - 7
      AND input_type = 'ARCHIVELOG'
      AND status <> 'COMPLETED'
)
SELECT
    g.thread#,
    g.latest_generated,
    NVL(b.latest_backed_up, 0) AS latest_backed_up,
    g.latest_generated - NVL(b.latest_backed_up, 0)
        AS sequence_difference,
    f.failed_count
FROM generated g
LEFT JOIN backed_up b
    ON b.thread# = g.thread#
CROSS JOIN failed_jobs f
ORDER BY g.thread#;


PROMPT
PROMPT ============================================================
PROMPT 23. QUICK ARCHIVELOG BACKUP CHECK
PROMPT ============================================================

WITH failed_jobs AS (
    SELECT COUNT(*) AS cnt
    FROM v$rman_backup_job_details
    WHERE start_time >= SYSDATE - 7
      AND input_type = 'ARCHIVELOG'
      AND status <> 'COMPLETED'
),
recent_unbacked AS (
    SELECT COUNT(*) AS cnt
    FROM v$archived_log a
    WHERE a.first_time >= SYSDATE - 1
      AND a.standby_dest = 'NO'
      AND NOT EXISTS (
          SELECT 1
          FROM v$backup_redolog b
          WHERE b.thread# = a.thread#
            AND b.sequence# = a.sequence#
      )
)
SELECT
    failed_jobs.cnt AS failed_jobs_7d,
    recent_unbacked.cnt AS recent_unbacked_archivelogs,
    CASE
        WHEN failed_jobs.cnt = 0
         AND recent_unbacked.cnt = 0
        THEN 'NO IMMEDIATE ARCHIVELOG BACKUP ISSUE DETECTED'
        ELSE 'INVESTIGATE ARCHIVELOG BACKUP COVERAGE'
    END AS health_status
FROM failed_jobs
CROSS JOIN recent_unbacked;


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT 1. Check the latest generated archive sequence per thread.
PROMPT 2. Check the latest RMAN-backed-up sequence per thread.
PROMPT 3. Investigate recent archive logs without backup records.
PROMPT 4. Review failed/incomplete ARCHIVELOG RMAN jobs.
PROMPT 5. Check archive destination errors.
PROMPT 6. Check FRA/storage capacity separately.
PROMPT 7. In RAC, verify every redo thread has backup coverage.
PROMPT 8. Investigate sequence discontinuities before assuming
PROMPT    that archive logs are missing.
PROMPT 9. Consider multiple V$ARCHIVED_LOG records caused by
PROMPT    different destinations/history.
PROMPT 10. Use RMAN VALIDATE / RESTORE VALIDATE for stronger
PROMPT     recoverability verification.
PROMPT
PROMPT IMPORTANT:
PROMPT A sequence difference does not automatically mean an archive
PROMPT log is missing. V$ARCHIVED_LOG and V$BACKUP_REDOLOG contain
PROMPT historical metadata and may have multiple records.
PROMPT Correlate with RMAN repository information and recovery
PROMPT requirements before taking action.
PROMPT
PROMPT ============================================================
PROMPT END OF RMAN ARCHIVELOG BACKUP STATUS
PROMPT ============================================================


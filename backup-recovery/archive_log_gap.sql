-- ============================================================
-- File        : archive_log_gap.sql
-- Purpose     : Oracle Archive Log Gap Detection
-- Author      : Manik Challa
--
-- Description :
--   Read-only archive log gap monitoring script.
--
--   Covers:
--     1. Database / Data Guard role
--     2. Archive destination status
--     3. Archive log sequence range by thread
--     4. Sequence discontinuities
--     5. Missing sequence numbers
--     6. Recent archive log activity
--     7. Archive logs with backup_count = 0
--     8. Archive logs marked deleted
--     9. Archive logs with errors
--    10. Per-thread archive coverage
--    11. Quick archive gap health summary
--
-- IMPORTANT:
--   A sequence discontinuity in V$ARCHIVED_LOG does NOT by itself
--   prove that archive logs are missing.
--
--   V$ARCHIVED_LOG can contain multiple records for the same
--   sequence because of multiple destinations, incarnations,
--   registrations, or historical records.
--
--   Always correlate suspected gaps with:
--     - V$ARCHIVE_DEST
--     - RMAN
--     - Data Guard views where applicable
--     - ARCHIVELOG files / backup repository
--     - Primary and standby sequence information
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

COLUMN thread#              FORMAT 999
COLUMN sequence#            FORMAT 999999999
COLUMN previous_sequence    FORMAT 999999999
COLUMN expected_sequence    FORMAT 999999999
COLUMN gap_size             FORMAT 999999999

COLUMN archive_count        FORMAT 999999999
COLUMN backed_up_count      FORMAT 999999999
COLUMN no_backup_count      FORMAT 999999999
COLUMN deleted_count        FORMAT 999999999

COLUMN archive_gb           FORMAT 99999990.99
COLUMN backup_count         FORMAT 999999

PROMPT
PROMPT ============================================================
PROMPT ORACLE ARCHIVE LOG GAP CHECK
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
-- 3. ARCHIVE LOG COVERAGE BY THREAD
-- ============================================================

PROMPT ============================================================
PROMPT 3. ARCHIVE LOG COVERAGE BY THREAD
PROMPT ============================================================

SELECT
    thread#,
    COUNT(*) AS archive_count,
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
-- 4. RECENT ARCHIVE LOG ACTIVITY
-- ============================================================

PROMPT ============================================================
PROMPT 4. RECENT ARCHIVE LOG ACTIVITY - LAST 24 HOURS
PROMPT ============================================================

SELECT
    thread#,
    sequence#,
    TO_CHAR(first_time, 'YYYY-MM-DD HH24:MI:SS') AS first_time,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time,
    archived,
    deleted,
    backup_count
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
ORDER BY thread#, sequence# DESC
FETCH FIRST 200 ROWS ONLY;

-- ============================================================
-- 5. SEQUENCE DISCONTINUITIES
--
--   LAG(sequence#) is evaluated separately for every thread.
-- ============================================================

PROMPT ============================================================
PROMPT 5. SEQUENCE DISCONTINUITIES BY THREAD
PROMPT ============================================================

WITH archive_sequences AS
(
    SELECT
        thread#,
        sequence#,
        completion_time,
        LAG(sequence#)
            OVER
            (
                PARTITION BY thread#
                ORDER BY sequence#
            ) AS previous_sequence
    FROM
    (
        SELECT DISTINCT
            thread#,
            sequence#,
            completion_time
        FROM v$archived_log
        WHERE completion_time >= SYSDATE - 30
    )
)
SELECT
    thread#,
    previous_sequence,
    sequence#,
    sequence# - previous_sequence - 1 AS gap_size,
    TO_CHAR(completion_time, 'YYYY-MM-DD HH24:MI:SS')
        AS completion_time
FROM archive_sequences
WHERE previous_sequence IS NOT NULL
  AND sequence# > previous_sequence + 1
ORDER BY thread#, sequence#;

-- ============================================================
-- 6. EXPECTED SEQUENCES VS ACTUAL SEQUENCES
--
--   Shows the sequence immediately following the previous
--   archived sequence and the observed sequence.
-- ============================================================

PROMPT ============================================================
PROMPT 6. EXPECTED VS ACTUAL ARCHIVE SEQUENCE
PROMPT ============================================================

WITH archive_sequences AS
(
    SELECT
        thread#,
        sequence#,
        LAG(sequence#)
            OVER
            (
                PARTITION BY thread#
                ORDER BY sequence#
            ) AS previous_sequence
    FROM
    (
        SELECT DISTINCT
            thread#,
            sequence#
        FROM v$archived_log
        WHERE completion_time >= SYSDATE - 30
    )
)
SELECT
    thread#,
    previous_sequence,
    previous_sequence + 1 AS expected_sequence,
    sequence# AS actual_sequence,
    sequence# - previous_sequence - 1 AS gap_size
FROM archive_sequences
WHERE previous_sequence IS NOT NULL
  AND sequence# > previous_sequence + 1
ORDER BY thread#, sequence#;

-- ============================================================
-- 7. LARGEST ARCHIVE LOG GAPS
-- ============================================================

PROMPT ============================================================
PROMPT 7. LARGEST ARCHIVE LOG GAPS - LAST 30 DAYS
PROMPT ============================================================

WITH archive_sequences AS
(
    SELECT
        thread#,
        sequence#,
        LAG(sequence#)
            OVER
            (
                PARTITION BY thread#
                ORDER BY sequence#
            ) AS previous_sequence
    FROM
    (
        SELECT DISTINCT
            thread#,
            sequence#
        FROM v$archived_log
        WHERE completion_time >= SYSDATE - 30
    )
)
SELECT
    thread#,
    previous_sequence,
    sequence#,
    sequence# - previous_sequence - 1 AS gap_size
FROM archive_sequences
WHERE previous_sequence IS NOT NULL
  AND sequence# > previous_sequence + 1
ORDER BY gap_size DESC
FETCH FIRST 50 ROWS ONLY;

-- ============================================================
-- 8. CURRENT / LATEST ARCHIVE SEQUENCE BY THREAD
-- ============================================================

PROMPT ============================================================
PROMPT 8. LATEST ARCHIVE SEQUENCE BY THREAD
PROMPT ============================================================

SELECT
    thread#,
    MAX(sequence#) AS last_sequence,
    TO_CHAR(MAX(completion_time), 'YYYY-MM-DD HH24:MI:SS')
        AS latest_archive_time
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 9. ARCHIVE LOGS WITHOUT BACKUP RECORD
-- ============================================================

PROMPT ============================================================
PROMPT 9. ARCHIVE LOGS WITHOUT RMAN BACKUP RECORD - LAST 24 HOURS
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
-- 10. ARCHIVE LOGS MARKED DELETED
-- ============================================================

PROMPT ============================================================
PROMPT 10. ARCHIVE LOGS MARKED DELETED - LAST 7 DAYS
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
-- 11. ARCHIVE LOGS WITH ERRORS
-- ============================================================

PROMPT ============================================================
PROMPT 11. ARCHIVE DESTINATION ERRORS
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
-- 12. ARCHIVE LOG STATUS SUMMARY
-- ============================================================

PROMPT ============================================================
PROMPT 12. ARCHIVE LOG STATUS SUMMARY - LAST 7 DAYS
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
    SUM(
        CASE
            WHEN deleted = 'YES' THEN 1
            ELSE 0
        END
    ) AS deleted_count
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 13. ARCHIVE LOGS AROUND DETECTED GAPS
--
--   Displays the archive records surrounding a gap so the DBA
--   can correlate the missing sequence range.
-- ============================================================

PROMPT ============================================================
PROMPT 13. ARCHIVE RECORDS AROUND DETECTED GAPS
PROMPT ============================================================

WITH archive_sequences AS
(
    SELECT
        thread#,
        sequence#,
        completion_time,
        LAG(sequence#)
            OVER
            (
                PARTITION BY thread#
                ORDER BY sequence#
            ) AS previous_sequence
    FROM
    (
        SELECT DISTINCT
            thread#,
            sequence#,
            completion_time
        FROM v$archived_log
        WHERE completion_time >= SYSDATE - 30
    )
),
gaps AS
(
    SELECT
        thread#,
        previous_sequence,
        sequence# AS current_sequence
    FROM archive_sequences
    WHERE previous_sequence IS NOT NULL
      AND sequence# > previous_sequence + 1
)
SELECT
    g.thread#,
    g.previous_sequence,
    g.current_sequence,
    g.current_sequence - g.previous_sequence - 1
        AS gap_size
FROM gaps g
ORDER BY g.thread#, g.current_sequence;

-- ============================================================
-- 14. RAC THREAD CHECK
--
--   Useful for RAC databases where each instance has its own
--   redo thread.
-- ============================================================

PROMPT ============================================================
PROMPT 14. RAC THREAD ARCHIVE COVERAGE
PROMPT ============================================================

SELECT
    thread#,
    COUNT(*) AS archive_count,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence,
    MAX(completion_time) AS latest_archive_time
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 15. ARCHIVE GENERATION TREND
-- ============================================================

PROMPT ============================================================
PROMPT 15. ARCHIVE LOG GENERATION - LAST 7 DAYS
PROMPT ============================================================

SELECT
    TO_CHAR(TRUNC(completion_time), 'YYYY-MM-DD') AS archive_day,
    thread#,
    COUNT(*) AS archive_count,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024 / 1024,
        2
    ) AS archive_gb
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
GROUP BY
    TRUNC(completion_time),
    thread#
ORDER BY
    TRUNC(completion_time),
    thread#;

-- ============================================================
-- 16. ARCHIVE LOG GAP SUMMARY
-- ============================================================

PROMPT ============================================================
PROMPT 16. ARCHIVE LOG GAP SUMMARY
PROMPT ============================================================

WITH archive_sequences AS
(
    SELECT
        thread#,
        sequence#,
        LAG(sequence#)
            OVER
            (
                PARTITION BY thread#
                ORDER BY sequence#
            ) AS previous_sequence
    FROM
    (
        SELECT DISTINCT
            thread#,
            sequence#
        FROM v$archived_log
        WHERE completion_time >= SYSDATE - 30
    )
)
SELECT
    thread#,
    COUNT(*) AS detected_gaps,
    NVL(SUM(sequence# - previous_sequence - 1), 0)
        AS missing_sequence_count,
    NVL(MAX(sequence# - previous_sequence - 1), 0)
        AS largest_gap
FROM archive_sequences
WHERE previous_sequence IS NOT NULL
  AND sequence# > previous_sequence + 1
GROUP BY thread#
ORDER BY thread#;

-- ============================================================
-- 17. QUICK GAP CHECK
-- ============================================================

PROMPT ============================================================
PROMPT 17. QUICK ARCHIVE GAP CHECK
PROMPT ============================================================

WITH archive_sequences AS
(
    SELECT
        thread#,
        sequence#,
        LAG(sequence#)
            OVER
            (
                PARTITION BY thread#
                ORDER BY sequence#
            ) AS previous_sequence
    FROM
    (
        SELECT DISTINCT
            thread#,
            sequence#
        FROM v$archived_log
        WHERE completion_time >= SYSDATE - 7
    )
),
gap_summary AS
(
    SELECT
        COUNT(*) AS gap_count,
        NVL(SUM(sequence# - previous_sequence - 1), 0)
            AS missing_count
    FROM archive_sequences
    WHERE previous_sequence IS NOT NULL
      AND sequence# > previous_sequence + 1
)
SELECT
    CASE
        WHEN gap_count = 0
        THEN 'OK - NO SEQUENCE DISCONTINUITY DETECTED'
        ELSE
            'CHECK - ' ||
            gap_count ||
            ' GAP(S), ' ||
            missing_count ||
            ' SEQUENCE(S) BETWEEN OBSERVED RECORDS'
    END AS archive_gap_status
FROM gap_summary;

-- ============================================================
-- 18. DBA INVESTIGATION CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT [ ] Confirm database role and environment
PROMPT [ ] Check archive destination status
PROMPT [ ] Check destination errors
PROMPT [ ] Check archive sequence per redo thread
PROMPT [ ] Review detected sequence discontinuities
PROMPT [ ] Check primary/standby sequence alignment if Data Guard
PROMPT [ ] Check V$ARCHIVE_GAP on standby if applicable
PROMPT [ ] Check RMAN LIST ARCHIVELOG
PROMPT [ ] Check archive log backup status
PROMPT [ ] Check archive files on disk / ASM
PROMPT [ ] Check alert.log for archiving errors
PROMPT [ ] Check FRA usage
PROMPT [ ] Check network / standby transport if applicable
PROMPT [ ] Verify suspected missing sequences before recovery action
PROMPT
PROMPT ============================================================
PROMPT END OF ARCHIVE LOG GAP CHECK
PROMPT ============================================================


-- ============================================================================
-- Oracle DBA Toolkit
-- Script   : archive_gap.sql
-- Purpose  : Detect ARCHIVELOG sequence gaps and continuity issues
-- Author   : Manik Challa
-- Version  : 1.0
-- ============================================================================
--
-- READ-ONLY SCRIPT
--
-- Covers:
--   1. Database / instance information
--   2. Archive log configuration
--   3. Archive sequence range by thread
--   4. Sequence discontinuities
--   5. Missing sequence numbers
--   6. Recent archive activity
--   7. RAC thread-wise archive coverage
--   8. Archive destination status
--   9. Archive gap health summary
--  10. DBA investigation checklist
--
-- IMPORTANT:
--   V$ARCHIVED_LOG can contain multiple rows for the same THREAD#/SEQUENCE#
--   because of multiple destinations, incarnations, or archive history.
--
--   Therefore:
--     A sequence discontinuity is an INVESTIGATION INDICATOR.
--     It is NOT by itself proof that an archive log is missing.
--
--   For Data Guard environments, use Data Guard gap/transport views and
--   RMAN validation to confirm actual recoverability.
--
--   This script does NOT generate, delete, register, or restore archive logs.
-- ============================================================================


SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

COLUMN database_name FORMAT A15
COLUMN instance_name FORMAT A15
COLUMN host_name FORMAT A30

COLUMN thread# FORMAT 999
COLUMN sequence# FORMAT 999999999
COLUMN prev_sequence FORMAT 999999999
COLUMN next_sequence FORMAT 999999999
COLUMN sequence_gap FORMAT 999999999
COLUMN archive_records FORMAT 999,999
COLUMN distinct_sequences FORMAT 999,999

COLUMN first_time FORMAT A20
COLUMN completion_time FORMAT A20
COLUMN next_time FORMAT A20

COLUMN archived FORMAT A8
COLUMN applied FORMAT A8
COLUMN backup_count FORMAT 999

COLUMN status FORMAT A15
COLUMN target FORMAT A10
COLUMN destination FORMAT A70
COLUMN error FORMAT A80
COLUMN gap_status FORMAT A20

COLUMN health_status FORMAT A80


PROMPT
PROMPT ============================================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ============================================================================

SELECT
    d.name AS database_name,
    d.open_mode,
    d.log_mode,
    i.instance_name,
    i.host_name,
    i.thread#
FROM v$database d
CROSS JOIN v$instance i;


PROMPT
PROMPT ============================================================================
PROMPT 2. ARCHIVE LOG MODE
PROMPT ============================================================================

SELECT
    name AS database_name,
    log_mode,
    open_mode,
    force_logging
FROM v$database;


PROMPT
PROMPT ============================================================================
PROMPT 3. ARCHIVE SEQUENCE RANGE BY THREAD
PROMPT ============================================================================

SELECT
    thread#,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence,
    COUNT(*) AS archive_records,
    COUNT(DISTINCT sequence#) AS distinct_sequences
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 4. ARCHIVE SEQUENCE RANGE - LAST 7 DAYS
PROMPT ============================================================================

SELECT
    thread#,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence,
    COUNT(DISTINCT sequence#) AS distinct_sequences,
    MIN(completion_time) AS first_archive,
    MAX(completion_time) AS last_archive
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 5. SEQUENCE DISCONTINUITIES - LAST 7 DAYS
PROMPT ============================================================================
PROMPT A gap greater than 1 indicates a sequence discontinuity for that thread.
PROMPT Duplicate V$ARCHIVED_LOG rows are removed before checking continuity.

SELECT
    thread#,
    sequence#,
    prev_sequence,
    sequence# - prev_sequence AS sequence_gap,
    first_time,
    completion_time
FROM
(
    SELECT
        thread#,
        sequence#,
        first_time,
        completion_time,
        LAG(sequence#) OVER
        (
            PARTITION BY thread#
            ORDER BY sequence#
        ) AS prev_sequence
    FROM
    (
        SELECT
            thread#,
            sequence#,
            MIN(first_time) AS first_time,
            MAX(completion_time) AS completion_time
        FROM v$archived_log
        WHERE completion_time >= SYSDATE - 7
        GROUP BY
            thread#,
            sequence#
    )
)
WHERE sequence# - prev_sequence > 1
ORDER BY
    thread#,
    sequence#;


PROMPT
PROMPT ============================================================================
PROMPT 6. ALL DETECTED SEQUENCE GAPS - AVAILABLE HISTORY
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    prev_sequence,
    sequence# - prev_sequence AS sequence_gap,
    first_time,
    completion_time
FROM
(
    SELECT
        thread#,
        sequence#,
        first_time,
        completion_time,
        LAG(sequence#) OVER
        (
            PARTITION BY thread#
            ORDER BY sequence#
        ) AS prev_sequence
    FROM
    (
        SELECT
            thread#,
            sequence#,
            MIN(first_time) AS first_time,
            MAX(completion_time) AS completion_time
        FROM v$archived_log
        GROUP BY
            thread#,
            sequence#
    )
)
WHERE sequence# - prev_sequence > 1
ORDER BY
    thread#,
    sequence#;


PROMPT
PROMPT ============================================================================
PROMPT 7. MISSING SEQUENCE NUMBERS - RECENT GAPS
PROMPT ============================================================================
PROMPT Shows the sequence range between the previous and current sequence.
PROMPT This is an investigation list, not proof of missing physical archive logs.

WITH sequence_list AS
(
    SELECT DISTINCT
        thread#,
        sequence#
    FROM v$archived_log
    WHERE completion_time >= SYSDATE - 7
),
gap_ranges AS
(
    SELECT
        thread#,
        sequence#,
        LAG(sequence#) OVER
        (
            PARTITION BY thread#
            ORDER BY sequence#
        ) AS prev_sequence
    FROM sequence_list
)
SELECT
    thread#,
    prev_sequence + 1 AS missing_from_sequence,
    sequence# - 1 AS missing_to_sequence,
    sequence# - prev_sequence - 1 AS missing_count
FROM gap_ranges
WHERE sequence# - prev_sequence > 1
ORDER BY
    thread#,
    missing_from_sequence;


PROMPT
PROMPT ============================================================================
PROMPT 8. RECENT ARCHIVE LOG ACTIVITY - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    archived,
    applied,
    backup_count
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
ORDER BY
    thread#,
    sequence# DESC;


PROMPT
PROMPT ============================================================================
PROMPT 9. LATEST ARCHIVE SEQUENCE BY THREAD
PROMPT ============================================================================

SELECT
    thread#,
    MAX(sequence#) AS latest_sequence,
    MAX(completion_time) AS latest_archive_time
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 10. ARCHIVE ACTIVITY BY THREAD - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(DISTINCT sequence#) AS distinct_sequences,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence,
    MIN(completion_time) AS first_archive_time,
    MAX(completion_time) AS last_archive_time
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 11. ARCHIVE LOGS WITH ZERO BACKUP COUNT
PROMPT ============================================================================
PROMPT Investigation indicator for RMAN archive backup coverage.

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    backup_count,
    archived,
    applied
FROM v$archived_log
WHERE completion_time >= SYSDATE - 1
  AND NVL(backup_count, 0) = 0
ORDER BY
    thread#,
    sequence# DESC;


PROMPT
PROMPT ============================================================================
PROMPT 12. DUPLICATE ARCHIVE RECORDS
PROMPT ============================================================================
PROMPT Multiple records for the same thread/sequence are possible and are
PROMPT not automatically an error.

SELECT
    thread#,
    sequence#,
    COUNT(*) AS archive_records,
    COUNT(DISTINCT dest_id) AS destinations,
    MIN(first_time) AS first_time,
    MAX(completion_time) AS last_completion
FROM v$archived_log
GROUP BY
    thread#,
    sequence#
HAVING COUNT(*) > 1
ORDER BY
    thread#,
    sequence# DESC;


PROMPT
PROMPT ============================================================================
PROMPT 13. ARCHIVE DESTINATION STATUS
PROMPT ============================================================================

SELECT
    dest_id,
    status,
    target,
    destination,
    error
FROM v$archive_dest
WHERE destination IS NOT NULL
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 14. ARCHIVE DESTINATIONS WITH ERRORS
PROMPT ============================================================================

SELECT
    dest_id,
    status,
    target,
    destination,
    error
FROM v$archive_dest
WHERE error IS NOT NULL
  AND TRIM(error) IS NOT NULL
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 15. RAC THREAD COVERAGE
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(DISTINCT sequence#) AS sequences_last_7d,
    MIN(sequence#) AS first_sequence,
    MAX(sequence#) AS last_sequence,
    MIN(completion_time) AS first_archive,
    MAX(completion_time) AS last_archive
FROM v$archived_log
WHERE completion_time >= SYSDATE - 7
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 16. THREADS WITH NO RECENT ARCHIVE ACTIVITY
PROMPT ============================================================================

SELECT
    t.thread#,
    t.status,
    t.enabled
FROM v$thread t
WHERE t.enabled = 'PUBLIC'
  AND NOT EXISTS
      (
          SELECT 1
          FROM v$archived_log a
          WHERE a.thread# = t.thread#
            AND a.completion_time >= SYSDATE - 1
      )
ORDER BY t.thread#;


PROMPT
PROMPT ============================================================================
PROMPT 17. DATA GUARD GAP STATUS
PROMPT ============================================================================
PROMPT Relevant when the database has standby / Data Guard configuration.

SELECT
    dest_id,
    status,
    database_mode,
    recovery_mode,
    synchronization_status,
    gap_status,
    archived_thread#,
    archived_seq#
FROM v$archive_dest_status
WHERE status IS NOT NULL
ORDER BY dest_id;


PROMPT
PROMPT ============================================================================
PROMPT 18. ARCHIVE GAP SUMMARY
PROMPT ============================================================================

SELECT
    COUNT(*) AS detected_gap_ranges,
    NVL(SUM(sequence_gap - 1), 0) AS total_sequence_numbers_missing
FROM
(
    SELECT
        thread#,
        sequence#,
        sequence# - prev_sequence AS sequence_gap
    FROM
    (
        SELECT
            thread#,
            sequence#,
            LAG(sequence#) OVER
            (
                PARTITION BY thread#
                ORDER BY sequence#
            ) AS prev_sequence
        FROM
        (
            SELECT DISTINCT
                thread#,
                sequence#
            FROM v$archived_log
        )
    )
    WHERE sequence# - prev_sequence > 1
);


PROMPT
PROMPT ============================================================================
PROMPT 19. ARCHIVE GAP HEALTH INDICATOR - LAST 7 DAYS
PROMPT ============================================================================

SELECT
    CASE
        WHEN EXISTS
        (
            SELECT 1
            FROM
            (
                SELECT
                    thread#,
                    sequence#,
                    LAG(sequence#) OVER
                    (
                        PARTITION BY thread#
                        ORDER BY sequence#
                    ) AS prev_sequence
                FROM
                (
                    SELECT DISTINCT
                        thread#,
                        sequence#
                    FROM v$archived_log
                    WHERE completion_time >= SYSDATE - 7
                )
            )
            WHERE sequence# - prev_sequence > 1
        )
        THEN 'CHECK - SEQUENCE DISCONTINUITY DETECTED'

        ELSE 'OK - NO SEQUENCE DISCONTINUITY DETECTED'
    END AS health_status
FROM dual;


PROMPT
PROMPT ============================================================================
PROMPT 20. QUICK ARCHIVE GAP CHECK
PROMPT ============================================================================

SELECT
    (SELECT COUNT(*)
       FROM v$archived_log
      WHERE completion_time >= SYSDATE - 1) AS archive_records_24h,

    (SELECT COUNT(DISTINCT thread#)
       FROM v$archived_log
      WHERE completion_time >= SYSDATE - 1) AS active_threads_24h,

    (SELECT COUNT(*)
       FROM v$archive_dest
      WHERE error IS NOT NULL
        AND TRIM(error) IS NOT NULL) AS destination_errors
FROM dual;


PROMPT
PROMPT ============================================================================
PROMPT 21. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] Check sequence discontinuities by THREAD#.
PROMPT [ ] Review the missing sequence range.
PROMPT [ ] Check V$ARCHIVED_LOG duplicate records.
PROMPT [ ] Check archive destination errors.
PROMPT [ ] Check alert.log for archiver errors.
PROMPT [ ] Check FRA utilization.
PROMPT [ ] Check RMAN archive backup coverage.
PROMPT [ ] Check backup_count for relevant archive logs.
PROMPT [ ] Check RAC thread activity.
PROMPT [ ] For Data Guard, check V$ARCHIVE_DEST_STATUS.
PROMPT [ ] Use Data Guard gap/transport views where applicable.
PROMPT [ ] Use RMAN validation to confirm recoverability.
PROMPT [ ] Do not assume a sequence gap automatically means a missing
PROMPT     or unrecoverable archive log.
PROMPT
PROMPT ============================================================================
PROMPT END OF ARCHIVE GAP CHECK
PROMPT ============================================================================


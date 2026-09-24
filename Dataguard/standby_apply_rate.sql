-- ================================================================
-- Oracle DBA Toolkit
-- Script : standby_apply_rate.sql
-- Purpose: Monitor Oracle Data Guard Standby Redo Apply Rate
-- Usage  : Run as SYS or a user with access to required V$ views
-- Scope  : Read-only monitoring
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN name                 FORMAT A25
COLUMN value                FORMAT A35
COLUMN datum_time           FORMAT A25
COLUMN time_computed        FORMAT A25
COLUMN process              FORMAT A15
COLUMN status               FORMAT A20
COLUMN client_process       FORMAT A20
COLUMN thread#              FORMAT 999
COLUMN sequence#            FORMAT 999999999
COLUMN block#               FORMAT 999999999
COLUMN blocks               FORMAT 999999999
COLUMN first_time           FORMAT A20
COLUMN completion_time      FORMAT A20
COLUMN apply_start_time     FORMAT A20
COLUMN apply_end_time       FORMAT A20
COLUMN apply_minutes        FORMAT 999990.99
COLUMN redo_mb              FORMAT 9999999990.99
COLUMN apply_rate_mb_sec    FORMAT 999999990.99
COLUMN avg_apply_rate       FORMAT 999999990.99
COLUMN latest_sequence      FORMAT 999999999
COLUMN applied_sequence     FORMAT 999999999
COLUMN sequence_lag         FORMAT 999999999
COLUMN health_status        FORMAT A45

PROMPT
PROMPT ================================================================
PROMPT ORACLE DATA GUARD STANDBY APPLY RATE MONITOR
PROMPT ================================================================

PROMPT
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ----------------------------------------------------------------

SELECT
    d.name,
    d.db_unique_name,
    d.database_role,
    d.open_mode,
    d.protection_mode,
    d.protection_level,
    i.instance_name,
    i.host_name,
    i.status AS instance_status
FROM v$database d
CROSS JOIN v$instance i;

PROMPT
PROMPT 2. DATA GUARD APPLY LAG
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    datum_time,
    time_computed
FROM v$dataguard_stats
WHERE name IN (
    'apply lag',
    'apply finish time',
    'transport lag'
)
ORDER BY name;

PROMPT
PROMPT 3. MANAGED RECOVERY PROCESS
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    client_process,
    thread#,
    sequence#,
    block#,
    blocks,
    delay_mins,
    active_agents,
    known_agents
FROM v$managed_standby
WHERE process LIKE 'MRP%'
ORDER BY process;

PROMPT
PROMPT 4. MRP APPLY STATUS
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    thread#,
    sequence#,
    block#,
    blocks,
    CASE
        WHEN status = 'APPLYING_LOG'
            THEN 'APPLY ACTIVE'
        WHEN status = 'WAIT_FOR_LOG'
            THEN 'WAITING FOR REDO'
        WHEN status = 'WAIT_FOR_GAP'
            THEN 'WAITING FOR GAP'
        ELSE
            'REVIEW STATUS'
    END AS health_status
FROM v$managed_standby
WHERE process LIKE 'MRP%'
ORDER BY process;

PROMPT
PROMPT 5. CURRENT MRP SEQUENCE BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    process,
    thread#,
    sequence#,
    block#,
    blocks,
    status
FROM v$managed_standby
WHERE process LIKE 'MRP%'
ORDER BY thread#, sequence# DESC;

PROMPT
PROMPT 6. ARCHIVED REDO GENERATED LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS archive_logs,
    ROUND(SUM(blocks * block_size) / 1024 / 1024, 2) AS redo_mb
FROM v$archived_log
WHERE first_time >= SYSDATE - 1
  AND blocks IS NOT NULL
  AND block_size IS NOT NULL
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 7. REDO RECEIVED LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS received_logs,
    ROUND(SUM(blocks * block_size) / 1024 / 1024, 2) AS received_redo_mb
FROM v$archived_log
WHERE first_time >= SYSDATE - 1
  AND standby_dest = 'YES'
  AND blocks IS NOT NULL
  AND block_size IS NOT NULL
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 8. REDO APPLIED LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS applied_logs,
    ROUND(SUM(blocks * block_size) / 1024 / 1024, 2) AS applied_redo_mb
FROM v$archived_log
WHERE first_time >= SYSDATE - 1
  AND applied = 'YES'
  AND blocks IS NOT NULL
  AND block_size IS NOT NULL
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 9. REDO APPLIED BY DAY - LAST 7 DAYS
PROMPT ----------------------------------------------------------------

SELECT
    TRUNC(completion_time) AS apply_day,
    COUNT(*) AS applied_logs,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS applied_redo_mb
FROM v$archived_log
WHERE applied = 'YES'
  AND completion_time >= SYSDATE - 7
  AND blocks IS NOT NULL
  AND block_size IS NOT NULL
GROUP BY TRUNC(completion_time)
ORDER BY apply_day DESC;

PROMPT
PROMPT 10. REDO APPLIED BY HOUR - LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    TRUNC(completion_time, 'HH24') AS apply_hour,
    COUNT(*) AS applied_logs,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS applied_redo_mb,
    ROUND(
        SUM(blocks * block_size) /
        NULLIF(
            (
                EXTRACT(
                    DAY FROM
                    (
                        MAX(completion_time) -
                        MIN(completion_time)
                    )
                ) * 86400
                +
                EXTRACT(
                    HOUR FROM
                    (
                        MAX(completion_time) -
                        MIN(completion_time)
                    )
                ) * 3600
                +
                EXTRACT(
                    MINUTE FROM
                    (
                        MAX(completion_time) -
                        MIN(completion_time)
                    )
                ) * 60
                +
                EXTRACT(
                    SECOND FROM
                    (
                        MAX(completion_time) -
                        MIN(completion_time)
                    )
                )
            ),
            0
        ) / 1024 / 1024,
        2
    ) AS avg_rate_mb_sec
FROM v$archived_log
WHERE applied = 'YES'
  AND completion_time >= SYSDATE - 1
  AND blocks IS NOT NULL
  AND block_size IS NOT NULL
GROUP BY TRUNC(completion_time, 'HH24')
ORDER BY apply_hour DESC;

PROMPT
PROMPT 11. APPLY RATE BY THREAD - LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS applied_logs,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS applied_redo_mb,
    ROUND(
        (
            SUM(blocks * block_size) / 1024 / 1024
        ) /
        NULLIF(
            (
                MAX(completion_time) - MIN(completion_time)
            ) * 86400,
            0
        ),
        2
    ) AS apply_rate_mb_sec
FROM v$archived_log
WHERE applied = 'YES'
  AND completion_time >= SYSDATE - 1
  AND blocks IS NOT NULL
  AND block_size IS NOT NULL
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 12. RECENTLY APPLIED ARCHIVE LOGS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    ROUND(
        (completion_time - first_time) * 24 * 60,
        2
    ) AS apply_minutes,
    ROUND(
        blocks * block_size / 1024 / 1024,
        2
    ) AS redo_mb,
    applied,
    registrar
FROM v$archived_log
WHERE applied = 'YES'
  AND completion_time >= SYSDATE - 1
ORDER BY completion_time DESC
FETCH FIRST 100 ROWS ONLY;

PROMPT
PROMPT 13. LARGEST RECENT APPLIED REDO LOGS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    ROUND(
        blocks * block_size / 1024 / 1024,
        2
    ) AS redo_mb,
    ROUND(
        (completion_time - first_time) * 24 * 60,
        2
    ) AS apply_minutes
FROM v$archived_log
WHERE applied = 'YES'
  AND completion_time >= SYSDATE - 1
  AND blocks IS NOT NULL
  AND block_size IS NOT NULL
ORDER BY blocks * block_size DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT 14. SLOWEST RECENT APPLY OPERATIONS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    sequence#,
    first_time,
    completion_time,
    ROUND(
        (completion_time - first_time) * 24 * 60,
        2
    ) AS apply_minutes,
    ROUND(
        blocks * block_size / 1024 / 1024,
        2
    ) AS redo_mb
FROM v$archived_log
WHERE applied = 'YES'
  AND completion_time >= SYSDATE - 1
  AND blocks IS NOT NULL
  AND block_size IS NOT NULL
ORDER BY
    (completion_time - first_time) DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT 15. LATEST APPLIED SEQUENCE BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) AS latest_applied_sequence,
    MAX(completion_time) AS latest_apply_time
FROM v$archived_log
WHERE applied = 'YES'
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 16. LATEST RECEIVED SEQUENCE BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(sequence#) AS latest_received_sequence,
    MAX(completion_time) AS latest_receive_time
FROM v$archived_log
WHERE standby_dest = 'YES'
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 17. RECEIVED VS APPLIED SEQUENCE
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MAX(
        CASE
            WHEN standby_dest = 'YES'
            THEN sequence#
        END
    ) AS latest_received_sequence,
    MAX(
        CASE
            WHEN applied = 'YES'
            THEN sequence#
        END
    ) AS latest_applied_sequence,
    MAX(
        CASE
            WHEN standby_dest = 'YES'
            THEN sequence#
        END
    )
    -
    MAX(
        CASE
            WHEN applied = 'YES'
            THEN sequence#
        END
    ) AS sequence_difference
FROM v$archived_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 18. APPLY ACTIVITY LAST 24 HOURS BY THREAD
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    MIN(completion_time) AS first_apply_time,
    MAX(completion_time) AS last_apply_time,
    COUNT(*) AS applied_logs,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS applied_redo_mb
FROM v$archived_log
WHERE applied = 'YES'
  AND completion_time >= SYSDATE - 1
  AND blocks IS NOT NULL
  AND block_size IS NOT NULL
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 19. APPLY RATE SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS applied_logs,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS applied_redo_mb,
    ROUND(
        (
            SUM(blocks * block_size) / 1024 / 1024
        ) /
        NULLIF(
            (MAX(completion_time) - MIN(completion_time)) * 86400,
            0
        ),
        2
    ) AS apply_rate_mb_sec,
    MIN(completion_time) AS first_apply_time,
    MAX(completion_time) AS last_apply_time
FROM v$archived_log
WHERE applied = 'YES'
  AND completion_time >= SYSDATE - 1
  AND blocks IS NOT NULL
  AND block_size IS NOT NULL;

PROMPT
PROMPT 20. APPLY RATE - LAST 7 DAYS
PROMPT ----------------------------------------------------------------

SELECT
    TRUNC(completion_time) AS apply_day,
    COUNT(*) AS applied_logs,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS applied_redo_mb,
    ROUND(
        (
            SUM(blocks * block_size) / 1024 / 1024
        ) /
        NULLIF(
            (MAX(completion_time) - MIN(completion_time)) * 86400,
            0
        ),
        2
    ) AS apply_rate_mb_sec
FROM v$archived_log
WHERE applied = 'YES'
  AND completion_time >= SYSDATE - 7
  AND blocks IS NOT NULL
  AND block_size IS NOT NULL
GROUP BY TRUNC(completion_time)
ORDER BY apply_day DESC;

PROMPT
PROMPT 21. APPLY LAG / FINISH TIME
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    datum_time,
    time_computed
FROM v$dataguard_stats
WHERE name IN (
    'apply lag',
    'apply finish time'
)
ORDER BY name;

PROMPT
PROMPT 22. ARCHIVE GAP STATUS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    low_sequence#,
    high_sequence#
FROM v$archive_gap
ORDER BY thread#;

PROMPT
PROMPT 23. STANDBY REDO LOG ACTIVITY
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS standby_redo_groups,
    SUM(
        CASE
            WHEN status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_srls,
    SUM(
        CASE
            WHEN status = 'UNASSIGNED' THEN 1
            ELSE 0
        END
    ) AS unassigned_srls,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS standby_redo_gb
FROM v$standby_log
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 24. CURRENT MRP APPLY POSITION
PROMPT ----------------------------------------------------------------

SELECT
    process,
    status,
    thread#,
    sequence#,
    block#,
    blocks,
    delay_mins
FROM v$managed_standby
WHERE process LIKE 'MRP%'
ORDER BY thread#, sequence# DESC;

PROMPT
PROMPT 25. DATA GUARD APPLY HEALTH
PROMPT ----------------------------------------------------------------

SELECT
    d.database_role,
    d.open_mode,
    CASE
        WHEN d.database_role NOT IN (
            'PHYSICAL STANDBY',
            'LOGICAL STANDBY'
        )
            THEN 'INFO - DATABASE IS NOT A STANDBY'

        WHEN EXISTS (
            SELECT 1
            FROM v$archive_gap
        )
            THEN 'CHECK - ARCHIVE GAP EXISTS'

        WHEN EXISTS (
            SELECT 1
            FROM v$managed_standby
            WHERE process LIKE 'MRP%'
              AND status = 'WAIT_FOR_GAP'
        )
            THEN 'CHECK - MRP WAITING FOR GAP'

        WHEN EXISTS (
            SELECT 1
            FROM v$managed_standby
            WHERE process LIKE 'MRP%'
              AND status = 'APPLYING_LOG'
        )
            THEN 'OK - MRP CURRENTLY APPLYING'

        WHEN EXISTS (
            SELECT 1
            FROM v$managed_standby
            WHERE process LIKE 'MRP%'
              AND status = 'WAIT_FOR_LOG'
        )
            THEN 'INFO - MRP WAITING FOR LOG'

        ELSE
            'CHECK - REVIEW MRP STATUS'
    END AS health_status
FROM v$database d;

PROMPT
PROMPT 26. QUICK APPLY RATE CHECK
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS applied_logs_24h,
    ROUND(
        SUM(blocks * block_size) / 1024 / 1024,
        2
    ) AS applied_redo_mb_24h,
    ROUND(
        (
            SUM(blocks * block_size) / 1024 / 1024
        ) /
        NULLIF(
            (MAX(completion_time) - MIN(completion_time)) * 86400,
            0
        ),
        2
    ) AS apply_rate_mb_sec,
    CASE
        WHEN COUNT(*) = 0
            THEN 'CHECK - NO APPLIED REDO IN LAST 24 HOURS'
        WHEN EXISTS (
            SELECT 1
            FROM v$archive_gap
        )
            THEN 'CHECK - ARCHIVE GAP EXISTS'
        ELSE
            'INFO - CORRELATE RATE WITH APPLY LAG'
    END AS health_status
FROM v$archived_log
WHERE applied = 'YES'
  AND completion_time >= SYSDATE - 1
  AND blocks IS NOT NULL
  AND block_size IS NOT NULL;

PROMPT
PROMPT ================================================================
PROMPT STANDBY APPLY RATE DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Check current MRP status.
PROMPT 2. Review transport lag and apply lag.
PROMPT 3. Review apply finish time.
PROMPT 4. Check redo applied during the last 24 hours.
PROMPT 5. Review apply rate by RAC thread.
PROMPT 6. Compare received and applied sequences.
PROMPT 7. Check V$ARCHIVE_GAP.
PROMPT 8. Review slowest recent apply operations.
PROMPT 9. Check standby redo log activity.
PROMPT 10. Correlate apply rate with redo generation rate.
PROMPT 11. Review network and storage performance if apply falls behind.
PROMPT 12. Check MRP/RFS status before taking corrective action.
PROMPT
PROMPT IMPORTANT:
PROMPT - Apply rate calculated from V$ARCHIVED_LOG is an approximate
PROMPT   historical throughput indicator.
PROMPT - It is not a real-time MRP throughput metric.
PROMPT - V$ARCHIVED_LOG may contain multiple rows for a sequence.
PROMPT - Sequence difference is not a formal Data Guard lag measurement.
PROMPT - Use V$DATAGUARD_STATS for transport/apply lag.
PROMPT - A low apply rate is not automatically a problem if redo
PROMPT   generation is also low.
PROMPT - Apply rate can vary significantly with workload and redo size.
PROMPT - RAC environments should be evaluated per thread.
PROMPT - V$MANAGED_STANDBY is version-dependent; verify the target
PROMPT   Oracle release.
PROMPT - This script performs monitoring only.
PROMPT
PROMPT ================================================================
PROMPT END OF STANDBY APPLY RATE MONITOR
PROMPT ================================================================


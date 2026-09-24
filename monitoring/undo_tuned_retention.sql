-- ============================================================
-- Oracle DBA Toolkit
-- File   : undo_tuned_retention.sql
-- Purpose: Monitor Oracle tuned UNDO retention
-- Scope  : TUNED_UNDORETENTION, workload, query duration,
--          retention pressure and snapshot-too-old indicators
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN begin_time              FORMAT A20
COLUMN end_time                FORMAT A20
COLUMN maxquerysqlid           FORMAT A15
COLUMN tuned_status            FORMAT A20
COLUMN pressure_status         FORMAT A20

COLUMN configured_retention   FORMAT 999,999,999
COLUMN tuned_retention        FORMAT 999,999,999
COLUMN min_tuned_retention    FORMAT 999,999,999
COLUMN max_tuned_retention    FORMAT 999,999,999
COLUMN avg_tuned_retention    FORMAT 999,999,999
COLUMN maxquerylen             FORMAT 999,999,999
COLUMN retention_gap           FORMAT 999,999,999
COLUMN query_retention_ratio   FORMAT 990.99

COLUMN retention_minutes       FORMAT 999,999.99
COLUMN retention_hours         FORMAT 999,999.99
COLUMN query_minutes           FORMAT 999,999.99
COLUMN query_hours             FORMAT 999,999.99

COLUMN txncount                FORMAT 999,999,999
COLUMN undoblks                FORMAT 999,999,999,999
COLUMN undo_blocks_per_sec     FORMAT 999,999.99
COLUMN ssolderrcnt             FORMAT 999,999,999
COLUMN nospaceerrcnt           FORMAT 999,999,999

COLUMN sql_id                  FORMAT A15
COLUMN username                FORMAT A20
COLUMN machine                 FORMAT A25
COLUMN program                 FORMAT A35
COLUMN event                   FORMAT A45

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    name,
    db_unique_name,
    open_mode,
    database_role
FROM v$database;

SELECT
    instance_name,
    host_name,
    status,
    version,
    startup_time
FROM v$instance;

PROMPT
PROMPT ============================================================
PROMPT 2. UNDO CONFIGURATION
PROMPT ============================================================

SELECT
    name,
    value
FROM v$parameter
WHERE name IN (
    'undo_management',
    'undo_tablespace',
    'undo_retention'
)
ORDER BY name;

PROMPT
PROMPT ============================================================
PROMPT 3. CONFIGURED UNDO_RETENTION
PROMPT ============================================================

SELECT
    value AS configured_retention,
    ROUND(value / 60, 2) AS retention_minutes,
    ROUND(value / 3600, 2) AS retention_hours
FROM v$parameter
WHERE name = 'undo_retention';

PROMPT
PROMPT ============================================================
PROMPT 4. CURRENT TUNED UNDO RETENTION
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    tuned_undoretention,
    ROUND(
        tuned_undoretention / 60,
        2
    ) AS retention_minutes,
    ROUND(
        tuned_undoretention / 3600,
        2
    ) AS retention_hours,
    maxquerylen,
    ssolderrcnt,
    nospaceerrcnt
FROM v$undostat
ORDER BY begin_time DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT 5. TUNED RETENTION - LAST 24 HOURS
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    tuned_undoretention,
    ROUND(
        tuned_undoretention / 60,
        2
    ) AS retention_minutes,
    ROUND(
        tuned_undoretention / 3600,
        2
    ) AS retention_hours,
    maxquerylen,
    maxquerysqlid,
    ssolderrcnt,
    nospaceerrcnt
FROM v$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 6. TUNED RETENTION - LAST 7 DAYS
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    tuned_undoretention,
    ROUND(
        tuned_undoretention / 60,
        2
    ) AS retention_minutes,
    ROUND(
        tuned_undoretention / 3600,
        2
    ) AS retention_hours,
    maxquerylen,
    maxquerysqlid,
    ssolderrcnt,
    nospaceerrcnt
FROM v$undostat
WHERE begin_time >= SYSDATE - 7
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 7. TUNED RETENTION STATISTICS
PROMPT ============================================================

SELECT
    ROUND(
        AVG(tuned_undoretention),
        2
    ) AS avg_tuned_retention,
    ROUND(
        MIN(tuned_undoretention),
        2
    ) AS min_tuned_retention,
    ROUND(
        MAX(tuned_undoretention),
        2
    ) AS max_tuned_retention,
    ROUND(
        AVG(tuned_undoretention) / 60,
        2
    ) AS avg_retention_minutes,
    ROUND(
        MIN(tuned_undoretention) / 60,
        2
    ) AS min_retention_minutes,
    ROUND(
        MAX(tuned_undoretention) / 60,
        2
    ) AS max_retention_minutes,
    ROUND(
        AVG(tuned_undoretention) / 3600,
        2
    ) AS avg_retention_hours
FROM v$undostat
WHERE begin_time >= SYSDATE - 7;

PROMPT
PROMPT ============================================================
PROMPT 8. CONFIGURED VS TUNED RETENTION
PROMPT ============================================================

SELECT
    p.value AS configured_retention,
    ROUND(p.value / 60, 2)
        AS configured_minutes,
    ROUND(p.value / 3600, 2)
        AS configured_hours,
    ROUND(AVG(u.tuned_undoretention), 2)
        AS avg_tuned_retention,
    ROUND(AVG(u.tuned_undoretention) / 60, 2)
        AS avg_tuned_minutes,
    ROUND(AVG(u.tuned_undoretention) / 3600, 2)
        AS avg_tuned_hours,
    ROUND(
        AVG(u.tuned_undoretention) - p.value,
        2
    ) AS tuned_minus_configured
FROM v$parameter p
CROSS JOIN v$undostat u
WHERE p.name = 'undo_retention'
  AND u.begin_time >= SYSDATE - 7
GROUP BY p.value;

PROMPT
PROMPT ============================================================
PROMPT 9. TUNED RETENTION VS LONGEST QUERY
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    tuned_undoretention,
    maxquerylen,
    ROUND(
        tuned_undoretention / 60,
        2
    ) AS retention_minutes,
    ROUND(
        maxquerylen / 60,
        2
    ) AS query_minutes,
    ROUND(
        maxquerylen /
        NULLIF(tuned_undoretention, 0),
        2
    ) AS query_retention_ratio,
    CASE
        WHEN maxquerylen > tuned_undoretention
            THEN 'WATCH'
        ELSE 'NORMAL'
    END AS tuned_status,
    maxquerysqlid,
    ssolderrcnt,
    nospaceerrcnt
FROM v$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY query_retention_ratio DESC;

PROMPT
PROMPT ============================================================
PROMPT 10. QUERY LONGER THAN TUNED RETENTION
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    maxquerylen,
    tuned_undoretention,
    maxquerylen - tuned_undoretention
        AS retention_gap,
    ROUND(
        maxquerylen / 60,
        2
    ) AS query_minutes,
    ROUND(
        tuned_undoretention / 60,
        2
    ) AS retention_minutes,
    maxquerysqlid,
    ssolderrcnt,
    nospaceerrcnt
FROM v$undostat
WHERE begin_time >= SYSDATE - 7
  AND maxquerylen > tuned_undoretention
ORDER BY retention_gap DESC;

PROMPT
PROMPT ============================================================
PROMPT 11. HIGHEST TUNED RETENTION PERIODS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        begin_time,
        end_time,
        tuned_undoretention,
        ROUND(
            tuned_undoretention / 60,
            2
        ) AS retention_minutes,
        ROUND(
            tuned_undoretention / 3600,
            2
        ) AS retention_hours,
        maxquerylen,
        maxquerysqlid,
        ssolderrcnt,
        nospaceerrcnt
    FROM v$undostat
    WHERE begin_time >= SYSDATE - 7
    ORDER BY tuned_undoretention DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT ============================================================
PROMPT 12. LOWEST TUNED RETENTION PERIODS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        begin_time,
        end_time,
        tuned_undoretention,
        ROUND(
            tuned_undoretention / 60,
            2
        ) AS retention_minutes,
        ROUND(
            tuned_undoretention / 3600,
            2
        ) AS retention_hours,
        maxquerylen,
        maxquerysqlid,
        ssolderrcnt,
        nospaceerrcnt
    FROM v$undostat
    WHERE begin_time >= SYSDATE - 7
    ORDER BY tuned_undoretention
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT ============================================================
PROMPT 13. TUNED RETENTION TREND
PROMPT ============================================================

SELECT
    TRUNC(begin_time, 'HH24') AS hour_start,
    ROUND(
        AVG(tuned_undoretention),
        2
    ) AS avg_tuned_retention,
    ROUND(
        MIN(tuned_undoretention),
        2
    ) AS min_tuned_retention,
    ROUND(
        MAX(tuned_undoretention),
        2
    ) AS max_tuned_retention,
    ROUND(
        AVG(maxquerylen),
        2
    ) AS avg_query_seconds,
    MAX(maxquerylen) AS longest_query_seconds
FROM v$undostat
WHERE begin_time >= SYSDATE - 7
GROUP BY TRUNC(begin_time, 'HH24')
ORDER BY hour_start DESC;

PROMPT
PROMPT ============================================================
PROMPT 14. UNDO GENERATION VS TUNED RETENTION
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    undoblks,
    txncount,
    tuned_undoretention,
    maxquerylen,
    ROUND(
        undoblks /
        NULLIF(
            (end_time - begin_time) * 86400,
            0
        ),
        2
    ) AS undo_blocks_per_sec,
    ssolderrcnt,
    nospaceerrcnt
FROM v$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 15. HIGH UNDO GENERATION PERIODS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        begin_time,
        end_time,
        undoblks,
        txncount,
        tuned_undoretention,
        maxquerylen,
        ROUND(
            undoblks /
            NULLIF(
                (end_time - begin_time) * 86400,
                0
            ),
            2
        ) AS undo_blocks_per_sec,
        ssolderrcnt,
        nospaceerrcnt
    FROM v$undostat
    WHERE begin_time >= SYSDATE - 7
    ORDER BY undoblks DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT ============================================================
PROMPT 16. SNAPSHOT TOO OLD INDICATORS
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    ssolderrcnt,
    maxquerylen,
    tuned_undoretention,
    maxquerysqlid
FROM v$undostat
WHERE ssolderrcnt > 0
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 17. UNDO SPACE PRESSURE
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    nospaceerrcnt,
    undoblks,
    txncount,
    tuned_undoretention,
    maxquerylen
FROM v$undostat
WHERE nospaceerrcnt > 0
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 18. RETENTION STEAL / REUSE ACTIVITY
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    unxpstealcnt,
    expstealcnt,
    unxpblkrelcnt,
    expblkrelcnt,
    ssolderrcnt,
    nospaceerrcnt
FROM v$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 19. UNDO TABLESPACE CAPACITY
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(
        SUM(df.bytes) / 1024 / 1024,
        2
    ) AS total_mb,
    ROUND(
        SUM(df.bytes - NVL(f.free_bytes, 0))
        / 1024 / 1024,
        2
    ) AS used_mb,
    ROUND(
        SUM(NVL(f.free_bytes, 0))
        / 1024 / 1024,
        2
    ) AS free_mb,
    ROUND(
        SUM(df.bytes - NVL(f.free_bytes, 0))
        / NULLIF(SUM(df.bytes), 0)
        * 100,
        2
    ) AS used_pct
FROM dba_data_files df
LEFT JOIN (
    SELECT
        tablespace_name,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY tablespace_name
) f
    ON f.tablespace_name = df.tablespace_name
WHERE df.tablespace_name IN (
    SELECT tablespace_name
    FROM dba_tablespaces
    WHERE contents = 'UNDO'
)
GROUP BY df.tablespace_name
ORDER BY used_pct DESC;

PROMPT
PROMPT ============================================================
PROMPT 20. UNDO EXTENT STATUS
PROMPT ============================================================

SELECT
    tablespace_name,
    status,
    ROUND(
        SUM(bytes) / 1024 / 1024,
        2
    ) AS undo_mb
FROM dba_undo_extents
GROUP BY
    tablespace_name,
    status
ORDER BY
    tablespace_name,
    status;

PROMPT
PROMPT ============================================================
PROMPT 21. LONG-RUNNING TRANSACTIONS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        s.sid,
        s.serial# AS serial,
        s.username,
        t.start_time,
        t.used_ublk,
        t.used_urec,
        ROUND(
            t.used_ublk * ts.block_size
            / 1024 / 1024,
            2
        ) AS undo_mb,
        s.sql_id,
        s.status,
        s.event,
        s.machine
    FROM v$transaction t
    JOIN v$session s
        ON s.taddr = t.addr
    JOIN dba_tablespaces ts
        ON ts.contents = 'UNDO'
    ORDER BY t.used_ublk DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT ============================================================
PROMPT 22. SQL IDs ASSOCIATED WITH LONGEST QUERIES
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        maxquerysqlid AS sql_id,
        MAX(maxquerylen) AS max_query_seconds,
        MAX(tuned_undoretention) AS max_tuned_retention,
        SUM(ssolderrcnt) AS snapshot_too_old_errors
    FROM v$undostat
    WHERE begin_time >= SYSDATE - 7
      AND maxquerysqlid IS NOT NULL
    GROUP BY maxquerysqlid
    ORDER BY max_query_seconds DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT ============================================================
PROMPT 23. LONGEST QUERY SQL TEXT
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        u.maxquerysqlid AS sql_id,
        MAX(u.maxquerylen) AS max_query_seconds,
        MAX(u.tuned_undoretention) AS tuned_retention_seconds,
        SUBSTR(
            MAX(q.sql_text)
            KEEP (
                DENSE_RANK LAST
                ORDER BY u.maxquerylen
            ),
            1,
            1000
        ) AS sql_text
    FROM v$undostat u
    LEFT JOIN v$sql q
        ON q.sql_id = u.maxquerysqlid
    WHERE u.begin_time >= SYSDATE - 7
      AND u.maxquerysqlid IS NOT NULL
    GROUP BY u.maxquerysqlid
    ORDER BY max_query_seconds DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT ============================================================
PROMPT 24. CURRENT UNDO RETENTION SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS intervals,
    ROUND(
        AVG(tuned_undoretention),
        2
    ) AS avg_tuned_retention,
    ROUND(
        MIN(tuned_undoretention),
        2
    ) AS min_tuned_retention,
    ROUND(
        MAX(tuned_undoretention),
        2
    ) AS max_tuned_retention,
    MAX(maxquerylen) AS longest_query_seconds,
    SUM(ssolderrcnt) AS snapshot_too_old_errors,
    SUM(nospaceerrcnt) AS undo_space_errors,
    SUM(undoblks) AS total_undo_blocks
FROM v$undostat
WHERE begin_time >= SYSDATE - 1;

PROMPT
PROMPT ============================================================
PROMPT 25. TUNED UNDO RETENTION HEALTH
PROMPT ============================================================

SELECT
    CASE
        WHEN SUM(nospaceerrcnt) > 0
            THEN 'CRITICAL - UNDO SPACE ERRORS'

        WHEN SUM(ssolderrcnt) > 0
            THEN 'WARNING - SNAPSHOT TOO OLD'

        WHEN MAX(maxquerylen) >
             MAX(tuned_undoretention)
            THEN 'WATCH - QUERY EXCEEDS TUNED RETENTION'

        WHEN MIN(tuned_undoretention) <
             (
                 SELECT value
                 FROM v$parameter
                 WHERE name = 'undo_retention'
             )
            THEN 'INFO - TUNED RETENTION BELOW CONFIGURED TARGET'

        ELSE 'HEALTHY'
    END AS tuned_retention_status,

    ROUND(
        AVG(tuned_undoretention),
        2
    ) AS avg_tuned_retention_seconds,

    MAX(maxquerylen) AS longest_query_seconds,

    SUM(ssolderrcnt) AS snapshot_too_old_errors,

    SUM(nospaceerrcnt) AS undo_space_errors

FROM v$undostat
WHERE begin_time >= SYSDATE - 1;

PROMPT
PROMPT ============================================================
PROMPT DBA QUICK CHECK
PROMPT ============================================================
PROMPT
PROMPT 1. Check configured UNDO_RETENTION.
PROMPT 2. Review TUNED_UNDORETENTION from V$UNDOSTAT.
PROMPT 3. Compare MAXQUERYLEN with TUNED_UNDORETENTION.
PROMPT 4. Check for SNAPSHOT TOO OLD errors.
PROMPT 5. Check for UNDO space errors.
PROMPT 6. Review high UNDO generation intervals.
PROMPT 7. Check long-running transactions.
PROMPT 8. Review UNDO tablespace capacity.
PROMPT 9. Check whether retention is being pressured by workload.
PROMPT 10. Identify SQL associated with the longest queries.
PROMPT 11. Do not increase UNDO_RETENTION blindly.
PROMPT 12. Ensure sufficient UNDO capacity before targeting
PROMPT     higher retention.
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT NOTES
PROMPT ============================================================
PROMPT
PROMPT - TUNED_UNDORETENTION is Oracle's tuned retention value.
PROMPT - It can differ from the configured UNDO_RETENTION value.
PROMPT - TUNED_UNDORETENTION is workload and space dependent.
PROMPT - MAXQUERYLEN is the longest query observed in an interval.
PROMPT - A query longer than tuned retention is a risk indicator,
PROMPT   not proof of a failure.
PROMPT - SSOLDERRCNT indicates snapshot-too-old errors.
PROMPT - NOSPACEERRCNT indicates UNDO space pressure.
PROMPT - Retention must be considered together with UNDO capacity.
PROMPT - High tuned retention is not automatically a problem.
PROMPT - Low tuned retention is not automatically an incident.
PROMPT - Thresholds in this toolkit are diagnostic heuristics.
PROMPT - This script is READ-ONLY.
PROMPT - For RAC, use GV$ views and INST_ID correlation where
PROMPT   appropriate.
PROMPT
PROMPT ============================================================
PROMPT END OF TUNED UNDO RETENTION CHECK
PROMPT ============================================================



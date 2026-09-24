-- ============================================================
-- Oracle DBA Toolkit
-- File   : undo_retention.sql
-- Purpose: Monitor UNDO retention configuration and effectiveness
-- Scope  : UNDO_RETENTION, tuned retention, query duration,
--          snapshot-too-old risk, retention pressure
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN name                    FORMAT A30
COLUMN value                   FORMAT A30
COLUMN tablespace_name         FORMAT A25
COLUMN retention               FORMAT A15
COLUMN begin_time              FORMAT A20
COLUMN end_time                FORMAT A20
COLUMN maxquerysqlid           FORMAT A15
COLUMN maxquerylen             FORMAT 999,999,999
COLUMN tuned_undoretention     FORMAT 999,999,999
COLUMN undo_retention_seconds  FORMAT 999,999,999
COLUMN retention_gap_seconds   FORMAT 999,999,999
COLUMN query_retention_ratio   FORMAT 990.99
COLUMN ssolderrcnt             FORMAT 999,999,999
COLUMN nospaceerrcnt           FORMAT 999,999,999
COLUMN undoblks                FORMAT 999,999,999,999
COLUMN txncount                FORMAT 999,999,999
COLUMN status_label            FORMAT A20
COLUMN undo_mb                 FORMAT 999,999,999.99
COLUMN free_mb                 FORMAT 999,999,999.99
COLUMN used_mb                 FORMAT 999,999,999.99
COLUMN used_pct                FORMAT 990.99

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
PROMPT 3. UNDO_RETENTION CONFIGURATION
PROMPT ============================================================

SELECT
    name,
    value AS undo_retention_seconds,
    ROUND(value / 60, 2) AS retention_minutes,
    ROUND(value / 3600, 2) AS retention_hours
FROM v$parameter
WHERE name = 'undo_retention';

PROMPT
PROMPT ============================================================
PROMPT 4. UNDO TABLESPACE RETENTION SETTING
PROMPT ============================================================

SELECT
    tablespace_name,
    status,
    retention,
    bigfile
FROM dba_tablespaces
WHERE contents = 'UNDO'
ORDER BY tablespace_name;

PROMPT
PROMPT ============================================================
PROMPT 5. TUNED UNDO RETENTION - LAST 24 HOURS
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    tuned_undoretention,
    ROUND(tuned_undoretention / 60, 2) AS tuned_retention_minutes,
    ROUND(tuned_undoretention / 3600, 2) AS tuned_retention_hours,
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
    ROUND(tuned_undoretention / 60, 2) AS tuned_retention_minutes,
    ROUND(tuned_undoretention / 3600, 2) AS tuned_retention_hours,
    maxquerylen,
    maxquerysqlid,
    ssolderrcnt,
    nospaceerrcnt
FROM v$undostat
WHERE begin_time >= SYSDATE - 7
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 7. RETENTION VS LONGEST QUERY
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    maxquerylen,
    tuned_undoretention,
    ROUND(
        maxquerylen / NULLIF(tuned_undoretention, 0),
        2
    ) AS query_retention_ratio,
    maxquerysqlid,
    ssolderrcnt,
    nospaceerrcnt,
    CASE
        WHEN maxquerylen > tuned_undoretention
            THEN 'WATCH'
        ELSE 'NORMAL'
    END AS status_label
FROM v$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY query_retention_ratio DESC;

PROMPT
PROMPT ============================================================
PROMPT 8. INTERVALS WHERE QUERY EXCEEDED TUNED RETENTION
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    maxquerylen,
    tuned_undoretention,
    maxquerylen - tuned_undoretention
        AS retention_gap_seconds,
    ROUND(
        maxquerylen / NULLIF(tuned_undoretention, 0),
        2
    ) AS query_retention_ratio,
    maxquerysqlid,
    ssolderrcnt,
    nospaceerrcnt
FROM v$undostat
WHERE begin_time >= SYSDATE - 7
  AND maxquerylen > tuned_undoretention
ORDER BY retention_gap_seconds DESC;

PROMPT
PROMPT ============================================================
PROMPT 9. SNAPSHOT TOO OLD HISTORY
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
PROMPT 10. UNDO SPACE ERRORS
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    nospaceerrcnt,
    tuned_undoretention,
    undoblks,
    txncount
FROM v$undostat
WHERE nospaceerrcnt > 0
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 11. HIGHEST TUNED RETENTION INTERVALS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        begin_time,
        end_time,
        tuned_undoretention,
        ROUND(tuned_undoretention / 60, 2)
            AS retention_minutes,
        ROUND(tuned_undoretention / 3600, 2)
            AS retention_hours,
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
PROMPT 12. LOW TUNED RETENTION INTERVALS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        begin_time,
        end_time,
        tuned_undoretention,
        ROUND(tuned_undoretention / 60, 2)
            AS retention_minutes,
        ROUND(tuned_undoretention / 3600, 2)
            AS retention_hours,
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
PROMPT 13. AVERAGE / MIN / MAX TUNED RETENTION
PROMPT ============================================================

SELECT
    ROUND(AVG(tuned_undoretention), 2)
        AS avg_retention_seconds,
    ROUND(MIN(tuned_undoretention), 2)
        AS min_retention_seconds,
    ROUND(MAX(tuned_undoretention), 2)
        AS max_retention_seconds,
    ROUND(AVG(tuned_undoretention) / 60, 2)
        AS avg_retention_minutes,
    ROUND(AVG(tuned_undoretention) / 3600, 2)
        AS avg_retention_hours
FROM v$undostat
WHERE begin_time >= SYSDATE - 7;

PROMPT
PROMPT ============================================================
PROMPT 14. UNDO GENERATION VS RETENTION
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    undoblks,
    txncount,
    tuned_undoretention,
    maxquerylen,
    ssolderrcnt,
    nospaceerrcnt,
    ROUND(
        undoblks /
        NULLIF(
            ((end_time - begin_time) * 86400),
            0
        ),
        2
    ) AS undo_blocks_per_sec
FROM v$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 15. HIGH UNDO GENERATION WITH LOW RETENTION
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
        ssolderrcnt,
        nospaceerrcnt,
        ROUND(
            undoblks /
            NULLIF(
                ((end_time - begin_time) * 86400),
                0
            ),
            2
        ) AS undo_blocks_per_sec
    FROM v$undostat
    WHERE begin_time >= SYSDATE - 7
    ORDER BY undoblks DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT ============================================================
PROMPT 16. UNDO TABLESPACE CAPACITY
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
PROMPT 17. UNDO EXTENT STATUS
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
PROMPT 18. ACTIVE / UNEXPIRED / EXPIRED UNDO
PROMPT ============================================================

SELECT
    tablespace_name,
    ROUND(
        SUM(
            CASE
                WHEN status = 'ACTIVE' THEN bytes
                ELSE 0
            END
        ) / 1024 / 1024,
        2
    ) AS active_mb,
    ROUND(
        SUM(
            CASE
                WHEN status = 'UNEXPIRED' THEN bytes
                ELSE 0
            END
        ) / 1024 / 1024,
        2
    ) AS unexpired_mb,
    ROUND(
        SUM(
            CASE
                WHEN status = 'EXPIRED' THEN bytes
                ELSE 0
            END
        ) / 1024 / 1024,
        2
    ) AS expired_mb
FROM dba_undo_extents
GROUP BY tablespace_name
ORDER BY active_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 19. LONG-RUNNING TRANSACTIONS
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
PROMPT 20. LONGEST QUERY SQL IDs
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
PROMPT 21. LONGEST QUERY SQL TEXT
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
PROMPT 22. UNDO RETENTION RELATED WAIT EVENTS
PROMPT ============================================================

SELECT
    event,
    total_waits,
    ROUND(
        time_waited / 100,
        2
    ) AS time_waited_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) /
        100,
        4
    ) AS avg_wait_sec
FROM v$system_event
WHERE LOWER(event) LIKE '%undo%'
   OR LOWER(event) LIKE '%snapshot too old%'
ORDER BY time_waited DESC;

PROMPT
PROMPT ============================================================
PROMPT 23. CURRENT UNDO-RELATED WAITERS
PROMPT ============================================================

SELECT
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    state,
    seconds_in_wait,
    blocking_session,
    machine,
    program
FROM v$session
WHERE status = 'ACTIVE'
  AND (
       LOWER(event) LIKE '%undo%'
       OR LOWER(event) LIKE '%snapshot too old%'
      )
ORDER BY seconds_in_wait DESC;

PROMPT
PROMPT ============================================================
PROMPT 24. UNDO RETENTION HEALTH SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS intervals,
    ROUND(
        AVG(tuned_undoretention),
        2
    ) AS avg_tuned_retention_sec,
    ROUND(
        MIN(tuned_undoretention),
        2
    ) AS min_tuned_retention_sec,
    ROUND(
        MAX(tuned_undoretention),
        2
    ) AS max_tuned_retention_sec,
    MAX(maxquerylen) AS longest_query_sec,
    SUM(ssolderrcnt) AS snapshot_too_old_errors,
    SUM(nospaceerrcnt) AS undo_space_errors
FROM v$undostat
WHERE begin_time >= SYSDATE - 1;

PROMPT
PROMPT ============================================================
PROMPT 25. OVERALL UNDO RETENTION STATUS
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
        ELSE 'HEALTHY'
    END AS retention_status,
    SUM(ssolderrcnt) AS snapshot_too_old_errors,
    SUM(nospaceerrcnt) AS undo_space_errors,
    MAX(maxquerylen) AS longest_query_seconds,
    MAX(tuned_undoretention) AS tuned_retention_seconds
FROM v$undostat
WHERE begin_time >= SYSDATE - 1;

PROMPT
PROMPT ============================================================
PROMPT DBA QUICK CHECK
PROMPT ============================================================
PROMPT
PROMPT 1. Check the configured UNDO_RETENTION value.
PROMPT 2. Check TUNED_UNDORETENTION from V$UNDOSTAT.
PROMPT 3. Compare MAXQUERYLEN with TUNED_UNDORETENTION.
PROMPT 4. Check for SNAPSHOT TOO OLD errors.
PROMPT 5. Check for UNDO space errors.
PROMPT 6. Review UNDO generation during peak workload.
PROMPT 7. Check long-running transactions.
PROMPT 8. Check UNDO tablespace capacity and headroom.
PROMPT 9. Review ACTIVE / UNEXPIRED / EXPIRED UNDO.
PROMPT 10. Identify SQL associated with the longest queries.
PROMPT 11. Do not increase UNDO_RETENTION blindly.
PROMPT 12. Retention must be evaluated together with workload
PROMPT     and available UNDO capacity.
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT NOTES
PROMPT ============================================================
PROMPT
PROMPT - UNDO_RETENTION is a target retention setting.
PROMPT - TUNED_UNDORETENTION reflects Oracle's tuned retention.
PROMPT - TUNED_UNDORETENTION can differ from UNDO_RETENTION.
PROMPT - MAXQUERYLEN is the longest query observed in an interval.
PROMPT - A query longer than tuned retention is a risk indicator,
PROMPT   but does not by itself prove a problem.
PROMPT - Snapshot-too-old errors require workload investigation.
PROMPT - Larger retention requires sufficient UNDO space.
PROMPT - AUTOEXTEND and underlying storage capacity matter.
PROMPT - High UNDO usage is not automatically an incident.
PROMPT - Thresholds in this toolkit are diagnostic heuristics.
PROMPT - This script is READ-ONLY.
PROMPT - For RAC, consider GV$UNDOSTAT / GV$TRANSACTION /
PROMPT   GV$SESSION where appropriate.
PROMPT
PROMPT ============================================================
PROMPT END OF UNDO RETENTION CHECK
PROMPT ============================================================


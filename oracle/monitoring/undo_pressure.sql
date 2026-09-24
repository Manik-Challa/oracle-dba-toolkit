-- ============================================================
-- Oracle DBA Toolkit
-- File   : undo_pressure.sql
-- Purpose: Monitor UNDO pressure and retention health
-- Scope  : UNDO space, retention, V$UNDOSTAT, errors, workload
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN tablespace_name       FORMAT A25
COLUMN status                FORMAT A12
COLUMN retention             FORMAT A15
COLUMN begin_time            FORMAT A20
COLUMN end_time              FORMAT A20
COLUMN undo_mb               FORMAT 999,999,999.99
COLUMN used_mb               FORMAT 999,999,999.99
COLUMN free_mb               FORMAT 999,999,999.99
COLUMN total_mb              FORMAT 999,999,999.99
COLUMN used_pct              FORMAT 990.99
COLUMN txncount              FORMAT 999,999,999
COLUMN maxquerylen           FORMAT 999,999,999
COLUMN maxquerysqlid         FORMAT A15
COLUMN undoblks              FORMAT 999,999,999,999
COLUMN ssolderrcnt           FORMAT 999,999,999
COLUMN nospaceerrcnt         FORMAT 999,999,999
COLUMN tuned_undoretention   FORMAT 999,999,999
COLUMN unxpstealcnt          FORMAT 999,999,999
COLUMN expstealcnt           FORMAT 999,999,999
COLUMN unxpblkrelcnt         FORMAT 999,999,999
COLUMN expblkrelcnt          FORMAT 999,999,999
COLUMN activeblks            FORMAT 999,999,999
COLUMN unexpiredblks         FORMAT 999,999,999
COLUMN expiredblks           FORMAT 999,999,999
COLUMN status_label          FORMAT A15

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
PROMPT 2. UNDO TABLESPACE CONFIGURATION
PROMPT ============================================================

SELECT
    tablespace_name,
    status,
    contents,
    extent_management,
    retention,
    bigfile
FROM dba_tablespaces
WHERE contents = 'UNDO'
ORDER BY tablespace_name;

PROMPT
PROMPT ============================================================
PROMPT 3. CURRENT UNDO TABLESPACE CAPACITY
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(SUM(df.bytes) / 1024 / 1024, 2) AS total_mb,
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
        (
            SUM(df.bytes - NVL(f.free_bytes, 0))
            / NULLIF(SUM(df.bytes), 0)
        ) * 100,
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
PROMPT 4. UNDO DATAFILE AUTOEXTEND / HEADROOM
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024, 2) AS current_mb,
    ROUND(
        CASE
            WHEN df.maxbytes > 0
            THEN df.maxbytes / 1024 / 1024
            ELSE df.bytes / 1024 / 1024
        END,
        2
    ) AS max_mb,
    CASE
        WHEN df.autoextensible = 'YES' THEN 'YES'
        ELSE 'NO'
    END AS autoextend,
    ROUND(
        CASE
            WHEN df.maxbytes > df.bytes
            THEN (df.maxbytes - df.bytes) / 1024 / 1024
            ELSE 0
        END,
        2
    ) AS headroom_mb
FROM dba_data_files df
WHERE df.tablespace_name IN (
    SELECT tablespace_name
    FROM dba_tablespaces
    WHERE contents = 'UNDO'
)
ORDER BY df.tablespace_name, df.file_id;

PROMPT
PROMPT ============================================================
PROMPT 5. CURRENT UNDO SEGMENT USAGE
PROMPT ============================================================

SELECT
    tablespace_name,
    status,
    ROUND(
        SUM(bytes) / 1024 / 1024,
        2
    ) AS undo_segment_mb
FROM dba_undo_extents
GROUP BY
    tablespace_name,
    status
ORDER BY
    tablespace_name,
    status;

PROMPT
PROMPT ============================================================
PROMPT 6. UNDO ACTIVE / UNEXPIRED / EXPIRED SPACE
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
PROMPT 7. UNDO STATISTICS - LAST 24 HOURS
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    txncount,
    undoblks,
    maxquerylen,
    maxquerysqlid,
    ssolderrcnt,
    nospaceerrcnt,
    tuned_undoretention
FROM v$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 8. UNDO STATISTICS - LAST 7 DAYS
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    txncount,
    undoblks,
    maxquerylen,
    maxquerysqlid,
    ssolderrcnt,
    nospaceerrcnt,
    tuned_undoretention
FROM v$undostat
WHERE begin_time >= SYSDATE - 7
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 9. CURRENT UNDO PRESSURE SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS intervals,
    SUM(txncount) AS total_transactions,
    SUM(undoblks) AS total_undo_blocks,
    SUM(ssolderrcnt) AS snapshot_too_old_errors,
    SUM(nospaceerrcnt) AS undo_space_errors,
    MAX(maxquerylen) AS longest_query_seconds,
    MAX(tuned_undoretention) AS max_tuned_retention
FROM v$undostat
WHERE begin_time >= SYSDATE - 1;

PROMPT
PROMPT ============================================================
PROMPT 10. UNDO PRESSURE BY TIME INTERVAL
PROMPT ============================================================

SELECT
    begin_time,
    txncount,
    undoblks,
    ssolderrcnt,
    nospaceerrcnt,
    maxquerylen,
    tuned_undoretention,
    CASE
        WHEN nospaceerrcnt > 0
            THEN 'CRITICAL'
        WHEN ssolderrcnt > 0
            THEN 'WARNING'
        WHEN maxquerylen > tuned_undoretention
            THEN 'WATCH'
        ELSE 'NORMAL'
    END AS status_label
FROM v$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 11. SNAPSHOT TOO OLD ERRORS
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
PROMPT 12. UNDO SPACE ERRORS
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    nospaceerrcnt,
    undoblks,
    txncount,
    tuned_undoretention
FROM v$undostat
WHERE nospaceerrcnt > 0
ORDER BY begin_time DESC;

PROMPT
PROMPT ============================================================
PROMPT 13. LONGEST QUERIES VS TUNED RETENTION
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    maxquerylen,
    tuned_undoretention,
    ROUND(
        maxquerylen / NULLIF(tuned_undoretention, 0),
        2
    ) AS query_to_retention_ratio,
    maxquerysqlid,
    ssolderrcnt,
    nospaceerrcnt
FROM v$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY query_to_retention_ratio DESC;

PROMPT
PROMPT ============================================================
PROMPT 14. HIGH UNDO GENERATION INTERVALS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        begin_time,
        end_time,
        txncount,
        undoblks,
        ROUND(
            undoblks /
            NULLIF(
                ((end_time - begin_time) * 86400),
                0
            ),
            2
        ) AS undo_blocks_per_sec,
        ssolderrcnt,
        nospaceerrcnt
    FROM v$undostat
    WHERE begin_time >= SYSDATE - 1
    ORDER BY undoblks DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT ============================================================
PROMPT 15. HIGHEST TRANSACTION RATE INTERVALS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        begin_time,
        end_time,
        txncount,
        undoblks,
        ROUND(
            txncount /
            NULLIF(
                ((end_time - begin_time) * 86400),
                0
            ),
            2
        ) AS transactions_per_sec,
        ssolderrcnt,
        nospaceerrcnt
    FROM v$undostat
    WHERE begin_time >= SYSDATE - 1
    ORDER BY txncount DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT ============================================================
PROMPT 16. UNDO STEAL / REUSE ACTIVITY
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
PROMPT 17. ACTIVE TRANSACTIONS
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
WHERE ROWNUM <= 50;

PROMPT
PROMPT ============================================================
PROMPT 18. LONG-RUNNING TRANSACTIONS
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    ROUND(
        (
            SYSDATE -
            TO_DATE(
                t.start_time,
                'MM/DD/RR HH24:MI:SS'
            )
        ) * 24 * 60,
        2
    ) AS age_minutes,
    ROUND(
        t.used_ublk * ts.block_size
        / 1024 / 1024,
        2
    ) AS undo_mb,
    t.used_urec,
    s.sql_id,
    s.status,
    s.event,
    s.machine
FROM v$transaction t
JOIN v$session s
    ON s.taddr = t.addr
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO'
WHERE (
    SYSDATE -
    TO_DATE(
        t.start_time,
        'MM/DD/RR HH24:MI:SS'
    )
) * 24 * 60 >= 30
ORDER BY age_minutes DESC;

PROMPT
PROMPT ============================================================
PROMPT 19. UNDO-RELATED SYSTEM WAIT EVENTS
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
PROMPT 20. CURRENT SESSIONS WAITING ON UNDO-RELATED EVENTS
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
PROMPT 21. TOP SQL ASSOCIATED WITH LONG QUERIES
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        maxquerysqlid AS sql_id,
        MAX(maxquerylen) AS max_query_seconds,
        MAX(ssolderrcnt) AS snapshot_too_old_errors
    FROM v$undostat
    WHERE begin_time >= SYSDATE - 7
      AND maxquerysqlid IS NOT NULL
    GROUP BY maxquerysqlid
    ORDER BY max_query_seconds DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT ============================================================
PROMPT 22. UNDO RETENTION TARGET
PROMPT ============================================================

SELECT
    name,
    value AS undo_retention_seconds
FROM v$parameter
WHERE name = 'undo_retention';

PROMPT
PROMPT ============================================================
PROMPT 23. UNDO MANAGEMENT
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
PROMPT 24. UNDO TABLESPACE HEALTH
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
    ) AS used_pct,
    CASE
        WHEN
            SUM(df.bytes - NVL(f.free_bytes, 0))
            / NULLIF(SUM(df.bytes), 0)
            * 100 >= 95
        THEN 'CRITICAL'
        WHEN
            SUM(df.bytes - NVL(f.free_bytes, 0))
            / NULLIF(SUM(df.bytes), 0)
            * 100 >= 90
        THEN 'WARNING'
        ELSE 'HEALTHY'
    END AS status_label
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
PROMPT 25. OVERALL UNDO PRESSURE HEALTH
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
    END AS undo_pressure_status,
    SUM(nospaceerrcnt) AS undo_space_errors,
    SUM(ssolderrcnt) AS snapshot_too_old_errors,
    MAX(maxquerylen) AS longest_query_seconds,
    MAX(tuned_undoretention) AS tuned_retention_seconds
FROM v$undostat
WHERE begin_time >= SYSDATE - 1;

PROMPT
PROMPT ============================================================
PROMPT DBA QUICK CHECK
PROMPT ============================================================
PROMPT
PROMPT 1. Check current UNDO tablespace utilization.
PROMPT 2. Check ACTIVE / UNEXPIRED / EXPIRED UNDO space.
PROMPT 3. Review V$UNDOSTAT for SSOLDERRCNT.
PROMPT 4. Review V$UNDOSTAT for NOSPACEERRCNT.
PROMPT 5. Compare MAXQUERYLEN with TUNED_UNDORETENTION.
PROMPT 6. Identify periods of high UNDO generation.
PROMPT 7. Identify long-running transactions.
PROMPT 8. Check whether batch jobs are generating large UNDO volumes.
PROMPT 9. Check for blocking and transaction contention.
PROMPT 10. Review UNDO datafile AUTOEXTEND and available headroom.
PROMPT 11. Investigate workload before simply increasing UNDO size.
PROMPT 12. Do not kill transactions solely because UNDO usage is high.
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT NOTES
PROMPT ============================================================
PROMPT
PROMPT - High UNDO usage does not automatically indicate a problem.
PROMPT - UNDO pressure can be caused by long transactions or high DML.
PROMPT - Snapshot-too-old errors require retention/workload analysis.
PROMPT - NOSPACEERRCNT indicates UNDO space pressure in V$UNDOSTAT.
PROMPT - TUNED_UNDORETENTION is Oracle's tuned retention value.
PROMPT - MAXQUERYLEN exceeding tuned retention is a useful warning
PROMPT   indicator but does not by itself prove a problem.
PROMPT - Current tablespace utilization and historical UNDO pressure
PROMPT   should be analyzed together.
PROMPT - Capacity thresholds below are DBA Toolkit heuristics.
PROMPT - This script is READ-ONLY.
PROMPT - For RAC, consider GV$ views and INST_ID correlation.
PROMPT
PROMPT ============================================================
PROMPT END OF UNDO PRESSURE CHECK
PROMPT ============================================================


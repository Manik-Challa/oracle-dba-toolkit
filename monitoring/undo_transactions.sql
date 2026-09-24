-- ============================================================
-- Oracle DBA Toolkit
-- File   : undo_transactions.sql
-- Purpose: Monitor active transactions and UNDO consumption
-- Scope  : Transactions, UNDO blocks, sessions, SQL, age
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN username          FORMAT A20
COLUMN machine           FORMAT A25
COLUMN program           FORMAT A35
COLUMN service_name      FORMAT A25
COLUMN sql_id            FORMAT A15
COLUMN prev_sql_id       FORMAT A15
COLUMN status             FORMAT A12
COLUMN start_time        FORMAT A20
COLUMN transaction_age   FORMAT 999,999,999.99
COLUMN used_ublk         FORMAT 999,999,999
COLUMN used_urec         FORMAT 999,999,999
COLUMN undo_mb           FORMAT 999,999,999.99
COLUMN undo_gb           FORMAT 999,999.99
COLUMN event             FORMAT A45
COLUMN wait_class        FORMAT A20
COLUMN tablespace_name   FORMAT A25
COLUMN xid               FORMAT A25
COLUMN sql_text          FORMAT A100 WORD_WRAPPED

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
PROMPT 3. UNDO DATAFILE CAPACITY
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024, 2) AS size_mb,
    CASE
        WHEN df.maxbytes = 0 THEN df.bytes
        ELSE df.maxbytes
    END AS max_bytes,
    CASE
        WHEN df.maxbytes = 0 THEN 'NO'
        ELSE 'YES'
    END AS autoextend_enabled,
    CASE
        WHEN df.maxbytes > df.bytes
        THEN ROUND((df.maxbytes - df.bytes) / 1024 / 1024, 2)
        ELSE 0
    END AS headroom_mb
FROM dba_data_files df
JOIN dba_tablespaces t
    ON t.tablespace_name = df.tablespace_name
WHERE t.contents = 'UNDO'
ORDER BY df.tablespace_name, df.file_id;

PROMPT
PROMPT ============================================================
PROMPT 4. CURRENT ACTIVE TRANSACTIONS
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    t.status,
    t.used_ublk,
    t.used_urec,
    ROUND(
        t.used_ublk * ts.block_size / 1024 / 1024,
        2
    ) AS undo_mb,
    ROUND(
        t.used_ublk * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS undo_gb
FROM v$transaction t
JOIN v$session s
    ON s.taddr = t.addr
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO'
ORDER BY t.used_ublk DESC;

PROMPT
PROMPT ============================================================
PROMPT 5. TOP TRANSACTIONS BY UNDO BLOCKS
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
            t.used_ublk * ts.block_size / 1024 / 1024,
            2
        ) AS undo_mb,
        ROUND(
            t.used_ublk * ts.block_size / 1024 / 1024 / 1024,
            2
        ) AS undo_gb,
        s.status,
        s.sql_id,
        s.machine,
        s.program
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
PROMPT 6. TRANSACTION AGE
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    ROUND(
        (SYSDATE - TO_DATE(t.start_time, 'MM/DD/RR HH24:MI:SS'))
        * 24 * 60,
        2
    ) AS transaction_age_minutes,
    t.used_ublk,
    t.used_urec,
    ROUND(
        t.used_ublk * ts.block_size / 1024 / 1024,
        2
    ) AS undo_mb,
    s.sql_id,
    s.status,
    s.machine
FROM v$transaction t
JOIN v$session s
    ON s.taddr = t.addr
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO'
ORDER BY transaction_age_minutes DESC;

PROMPT
PROMPT ============================================================
PROMPT 7. LONG-RUNNING TRANSACTIONS >= 30 MINUTES
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    ROUND(
        (SYSDATE - TO_DATE(t.start_time, 'MM/DD/RR HH24:MI:SS'))
        * 24 * 60,
        2
    ) AS age_minutes,
    ROUND(
        t.used_ublk * ts.block_size / 1024 / 1024,
        2
    ) AS undo_mb,
    t.used_urec,
    s.status,
    s.sql_id,
    s.event,
    s.machine,
    s.program
FROM v$transaction t
JOIN v$session s
    ON s.taddr = t.addr
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO'
WHERE (SYSDATE - TO_DATE(t.start_time, 'MM/DD/RR HH24:MI:SS'))
      * 24 * 60 >= 30
ORDER BY age_minutes DESC;

PROMPT
PROMPT ============================================================
PROMPT 8. LONG-RUNNING TRANSACTIONS >= 2 HOURS
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    ROUND(
        (SYSDATE - TO_DATE(t.start_time, 'MM/DD/RR HH24:MI:SS'))
        * 24,
        2
    ) AS age_hours,
    ROUND(
        t.used_ublk * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS undo_gb,
    t.used_urec,
    s.sql_id,
    s.status,
    s.event,
    s.machine,
    s.program
FROM v$transaction t
JOIN v$session s
    ON s.taddr = t.addr
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO'
WHERE (SYSDATE - TO_DATE(t.start_time, 'MM/DD/RR HH24:MI:SS'))
      * 24 >= 2
ORDER BY age_hours DESC;

PROMPT
PROMPT ============================================================
PROMPT 9. TRANSACTIONS USING >= 1 GB UNDO
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    ROUND(
        t.used_ublk * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS undo_gb,
    t.used_ublk,
    t.used_urec,
    s.sql_id,
    s.status,
    s.machine,
    s.program
FROM v$transaction t
JOIN v$session s
    ON s.taddr = t.addr
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO'
WHERE t.used_ublk * ts.block_size / 1024 / 1024 / 1024 >= 1
ORDER BY undo_gb DESC;

PROMPT
PROMPT ============================================================
PROMPT 10. TRANSACTIONS USING >= 5 GB UNDO
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    ROUND(
        t.used_ublk * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS undo_gb,
    t.used_ublk,
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
WHERE t.used_ublk * ts.block_size / 1024 / 1024 / 1024 >= 5
ORDER BY undo_gb DESC;

PROMPT
PROMPT ============================================================
PROMPT 11. TRANSACTIONS BY USER
PROMPT ============================================================

SELECT
    s.username,
    COUNT(*) AS transaction_count,
    SUM(t.used_ublk) AS undo_blocks,
    SUM(t.used_urec) AS undo_records,
    ROUND(
        SUM(t.used_ublk * ts.block_size)
        / 1024 / 1024,
        2
    ) AS undo_mb,
    ROUND(
        SUM(t.used_ublk * ts.block_size)
        / 1024 / 1024 / 1024,
        2
    ) AS undo_gb
FROM v$transaction t
JOIN v$session s
    ON s.taddr = t.addr
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO'
WHERE s.username IS NOT NULL
GROUP BY s.username
ORDER BY undo_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 12. TRANSACTIONS BY SQL_ID
PROMPT ============================================================

SELECT
    s.sql_id,
    COUNT(*) AS transaction_count,
    SUM(t.used_ublk) AS undo_blocks,
    SUM(t.used_urec) AS undo_records,
    ROUND(
        SUM(t.used_ublk * ts.block_size)
        / 1024 / 1024,
        2
    ) AS undo_mb,
    ROUND(
        SUM(t.used_ublk * ts.block_size)
        / 1024 / 1024 / 1024,
        2
    ) AS undo_gb
FROM v$transaction t
JOIN v$session s
    ON s.taddr = t.addr
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO'
WHERE s.sql_id IS NOT NULL
GROUP BY s.sql_id
ORDER BY undo_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 13. TRANSACTIONS WITH CURRENT SQL
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    t.start_time,
    ROUND(
        t.used_ublk * ts.block_size / 1024 / 1024,
        2
    ) AS undo_mb,
    t.used_ublk,
    t.used_urec,
    s.status,
    s.event,
    s.wait_class
FROM v$transaction t
JOIN v$session s
    ON s.taddr = t.addr
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO'
WHERE s.sql_id IS NOT NULL
ORDER BY undo_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 14. TRANSACTION SQL TEXT
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        s.sid,
        s.serial# AS serial,
        s.username,
        s.sql_id,
        ROUND(
            t.used_ublk * ts.block_size / 1024 / 1024,
            2
        ) AS undo_mb,
        t.used_urec,
        SUBSTR(q.sql_text, 1, 1000) AS sql_text
    FROM v$transaction t
    JOIN v$session s
        ON s.taddr = t.addr
    JOIN dba_tablespaces ts
        ON ts.contents = 'UNDO'
    LEFT JOIN v$sql q
        ON q.sql_id = s.sql_id
    ORDER BY undo_mb DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT ============================================================
PROMPT 15. TRANSACTION PREVIOUS SQL
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        s.sid,
        s.serial# AS serial,
        s.username,
        s.sql_id,
        s.prev_sql_id,
        ROUND(
            t.used_ublk * ts.block_size / 1024 / 1024,
            2
        ) AS undo_mb,
        t.used_urec,
        SUBSTR(q.sql_text, 1, 1000) AS previous_sql_text
    FROM v$transaction t
    JOIN v$session s
        ON s.taddr = t.addr
    JOIN dba_tablespaces ts
        ON ts.contents = 'UNDO'
    LEFT JOIN v$sql q
        ON q.sql_id = s.prev_sql_id
    ORDER BY undo_mb DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT ============================================================
PROMPT 16. ACTIVE TRANSACTIONS WITH WAIT EVENTS
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    ROUND(
        t.used_ublk * ts.block_size / 1024 / 1024,
        2
    ) AS undo_mb,
    t.used_urec,
    s.sql_id,
    s.event,
    s.wait_class,
    s.state,
    s.seconds_in_wait,
    s.machine,
    s.program
FROM v$transaction t
JOIN v$session s
    ON s.taddr = t.addr
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO'
WHERE s.status = 'ACTIVE'
ORDER BY undo_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 17. TRANSACTIONS WITH ROW LOCK CONTENTION
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    ROUND(
        t.used_ublk * ts.block_size / 1024 / 1024,
        2
    ) AS undo_mb,
    t.used_urec,
    s.sql_id,
    s.event,
    s.blocking_session,
    s.machine
FROM v$transaction t
JOIN v$session s
    ON s.taddr = t.addr
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO'
WHERE s.event LIKE '%enq: TX%'
ORDER BY undo_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 18. UNDO CONSUMERS BY MACHINE
PROMPT ============================================================

SELECT
    s.machine,
    COUNT(*) AS transaction_count,
    ROUND(
        SUM(t.used_ublk * ts.block_size)
        / 1024 / 1024,
        2
    ) AS undo_mb,
    ROUND(
        SUM(t.used_ublk * ts.block_size)
        / 1024 / 1024 / 1024,
        2
    ) AS undo_gb
FROM v$transaction t
JOIN v$session s
    ON s.taddr = t.addr
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO'
WHERE s.machine IS NOT NULL
GROUP BY s.machine
ORDER BY undo_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 19. UNDO STATISTICS
PROMPT ============================================================

SELECT
    begin_time,
    end_time,
    txncount,
    maxquerylen,
    maxquerysqlid,
    undoblks,
    ssolderrcnt,
    nospaceerrcnt,
    tuned_undoretention
FROM v$undostat
ORDER BY begin_time DESC
FETCH FIRST 24 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT 20. UNDO PRESSURE INDICATORS
PROMPT ============================================================

SELECT
    SUM(ssolderrcnt) AS snapshot_too_old_errors,
    SUM(nospaceerrcnt) AS undo_space_errors,
    MAX(maxquerylen) AS longest_query_seconds,
    MAX(tuned_undoretention) AS max_tuned_retention
FROM v$undostat;

PROMPT
PROMPT ============================================================
PROMPT 21. RECENT UNDO-RELATED WAIT EVENTS
PROMPT ============================================================

SELECT
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
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
PROMPT 22. TOP UNDO CONSUMING TRANSACTIONS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        s.sid,
        s.serial# AS serial,
        s.username,
        ROUND(
            t.used_ublk * ts.block_size
            / 1024 / 1024 / 1024,
            2
        ) AS undo_gb,
        t.used_ublk,
        t.used_urec,
        t.start_time,
        s.sql_id,
        s.status,
        s.machine,
        s.program
    FROM v$transaction t
    JOIN v$session s
        ON s.taddr = t.addr
    JOIN dba_tablespaces ts
        ON ts.contents = 'UNDO'
    ORDER BY undo_gb DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT ============================================================
PROMPT 23. UNDO TRANSACTION SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS active_transactions,
    SUM(t.used_ublk) AS total_undo_blocks,
    SUM(t.used_urec) AS total_undo_records,
    ROUND(
        SUM(t.used_ublk * ts.block_size)
        / 1024 / 1024,
        2
    ) AS total_undo_mb,
    ROUND(
        SUM(t.used_ublk * ts.block_size)
        / 1024 / 1024 / 1024,
        2
    ) AS total_undo_gb
FROM v$transaction t
JOIN dba_tablespaces ts
    ON ts.contents = 'UNDO';

PROMPT
PROMPT ============================================================
PROMPT 24. QUICK UNDO TRANSACTION HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN SUM(nospaceerrcnt) > 0
            THEN 'CRITICAL - UNDO SPACE ERRORS'
        WHEN SUM(ssolderrcnt) > 0
            THEN 'WARNING - SNAPSHOT TOO OLD'
        WHEN MAX(maxquerylen) > 7200
            THEN 'WATCH - LONG QUERY'
        ELSE 'HEALTHY'
    END AS undo_transaction_health
FROM v$undostat;

PROMPT
PROMPT ============================================================
PROMPT DBA CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT 1. Identify long-running transactions.
PROMPT 2. Identify transactions consuming large amounts of UNDO.
PROMPT 3. Map SID/SERIAL# to SQL_ID and SQL text.
PROMPT 4. Check whether the transaction is active or idle.
PROMPT 5. Check for blocking and row-lock contention.
PROMPT 6. Review V$UNDOSTAT for snapshot-too-old errors.
PROMPT 7. Check NO SPACE errors in the UNDO tablespace.
PROMPT 8. Review UNDO retention and workload requirements.
PROMPT 9. Check whether batch jobs are generating excessive UNDO.
PROMPT 10. Do not kill a transaction solely because it uses large UNDO.
PROMPT 11. Investigate transaction age, workload, SQL, and business impact.
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT NOTES
PROMPT ============================================================
PROMPT
PROMPT - USED_UBLK represents UNDO blocks currently used by a transaction.
PROMPT - USED_UREC represents UNDO records currently used.
PROMPT - Large UNDO usage does not automatically indicate a problem.
PROMPT - Long-running transactions can retain UNDO needed by queries.
PROMPT - Snapshot-too-old errors require workload and retention analysis.
PROMPT - V$UNDOSTAT contains interval-based UNDO statistics.
PROMPT - Thresholds should be adapted to the database workload.
PROMPT - This script is READ-ONLY.
PROMPT - For RAC, consider GV$TRANSACTION and GV$SESSION with INST_ID.
PROMPT
PROMPT ============================================================
PROMPT END OF UNDO TRANSACTIONS CHECK
PROMPT ============================================================


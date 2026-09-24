```sql id="k7x2mp"
-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_undo_usage.sql
-- Purpose: RAC-wide UNDO usage and pressure monitoring
-- Scope  : UNDO capacity, usage, active transactions,
--          long transactions, retention, UNDO pressure,
--          snapshot-too-old indicators and instance comparison
--
-- IMPORTANT:
-- - UNDO statistics are cumulative/historical depending on view.
-- - GV$UNDOSTAT contains interval statistics.
-- - This script is READ-ONLY.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name  FORMAT A18
COLUMN host_name      FORMAT A30
COLUMN tablespace_name FORMAT A25
COLUMN username       FORMAT A25
COLUMN status         FORMAT A15
COLUMN sql_id         FORMAT A15
COLUMN event          FORMAT A60
COLUMN wait_class     FORMAT A20
COLUMN machine        FORMAT A35
COLUMN program        FORMAT A40
COLUMN service_name   FORMAT A35
COLUMN begin_time     FORMAT A20
COLUMN end_time       FORMAT A20

PROMPT
PROMPT ============================================================
PROMPT 1. RAC INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    inst_id,
    instance_number,
    instance_name,
    host_name,
    status,
    database_status,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 2. UNDO TABLESPACE CONFIGURATION
PROMPT ============================================================

SELECT
    inst_id,
    tablespace_name,
    status,
    contents,
    extent_management,
    retention
FROM gv$tablespace
WHERE contents = 'UNDO'
ORDER BY inst_id, tablespace_name;


PROMPT
PROMPT ============================================================
PROMPT 3. UNDO DATAFILE CAPACITY
PROMPT ============================================================

SELECT
    inst_id,
    tablespace_name,
    COUNT(*) AS datafiles,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(SUM(maxbytes) / 1024 / 1024 / 1024, 2) AS max_gb,
    SUM(
        CASE
            WHEN autoextensible = 'YES' THEN 1
            ELSE 0
        END
    ) AS autoextend_files
FROM gv$datafile
WHERE tablespace_name IN
(
    SELECT tablespace_name
    FROM dba_tablespaces
    WHERE contents = 'UNDO'
)
GROUP BY
    inst_id,
    tablespace_name
ORDER BY
    inst_id,
    tablespace_name;


PROMPT
PROMPT ============================================================
PROMPT 4. UNDO USED / FREE SPACE
PROMPT ============================================================

SELECT
    inst_id,
    tablespace_name,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(
        SUM(
            CASE
                WHEN status = 'EXPIRED' THEN bytes
                ELSE 0
            END
        ) / 1024 / 1024 / 1024,
        2
    ) AS expired_gb,
    ROUND(
        SUM(
            CASE
                WHEN status = 'UNEXPIRED' THEN bytes
                ELSE 0
            END
        ) / 1024 / 1024 / 1024,
        2
    ) AS unexpired_gb
FROM gv$undostat
GROUP BY
    inst_id,
    tablespace_name
ORDER BY
    inst_id;


PROMPT
PROMPT ============================================================
PROMPT 5. UNDO EXTENT STATUS
PROMPT ============================================================

SELECT tablespace_name, status, COUNT(*) AS extent_count, ROUND( SUM(bytes) / 1024 / 1024 / 1024, 2 ) AS size_gb FROM dba_undo_extents GROUP BY tablespace_name, status ORDER BY tablespace_name, status;


PROMPT
PROMPT ============================================================
PROMPT 6. UNDO STATISTICS - LAST 24 HOURS
PROMPT ============================================================

SELECT
    inst_id,
    TO_CHAR(begin_time, 'YYYY-MM-DD HH24:MI') AS begin_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI') AS end_time,
    undoblks,
    txncount,
    maxquerylen,
    ssolderrcnt,
    nospaceerrcnt,
    unxpstealcnt,
    expstealcnt,
    unxpblkreucnt,
    expblkreucnt,
    tuned_undoretention
FROM gv$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY
    inst_id,
    begin_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. UNDO GENERATION BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    ROUND(
        SUM(undoblks) * 8192 / 1024 / 1024 / 1024,
        2
    ) AS undo_generated_gb,
    SUM(txncount) AS transactions,
    MAX(maxquerylen) AS longest_query_sec,
    SUM(ssolderrcnt) AS snapshot_too_old_errors,
    SUM(nospaceerrcnt) AS no_space_errors
FROM gv$undostat
WHERE begin_time >= SYSDATE - 1
GROUP BY inst_id
ORDER BY undo_generated_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. UNDO GENERATION - LAST 7 DAYS
PROMPT ============================================================

SELECT
    inst_id,
    ROUND(
        SUM(undoblks) * 8192 / 1024 / 1024 / 1024,
        2
    ) AS undo_generated_gb,
    SUM(txncount) AS transactions,
    MAX(maxquerylen) AS longest_query_sec,
    SUM(ssolderrcnt) AS snapshot_too_old_errors,
    SUM(nospaceerrcnt) AS no_space_errors
FROM gv$undostat
WHERE begin_time >= SYSDATE - 7
GROUP BY inst_id
ORDER BY undo_generated_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. CURRENT ACTIVE TRANSACTIONS
PROMPT ============================================================

SELECT
    t.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    t.used_ublk AS undo_blocks,
    ROUND(
        t.used_ublk * 8192 / 1024 / 1024,
        2
    ) AS undo_mb,
    t.used_urec AS undo_records,
    t.status,
    s.sql_id,
    s.event,
    s.wait_class,
    s.machine,
    s.program
FROM gv$transaction t
JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND t.addr = s.taddr
ORDER BY
    t.used_ublk DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 10. TOP UNDO-CONSUMING TRANSACTIONS
PROMPT ============================================================

SELECT
    t.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    ROUND(
        t.used_ublk * 8192 / 1024 / 1024,
        2
    ) AS undo_mb,
    t.used_urec AS undo_records,
    s.sql_id,
    s.status,
    s.event,
    s.service_name,
    s.machine
FROM gv$transaction t
JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND t.addr = s.taddr
ORDER BY t.used_ublk DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 11. LONG-RUNNING TRANSACTIONS
PROMPT ============================================================

SELECT
    t.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    ROUND(
        (SYSDATE -
         TO_DATE(
             t.start_time,
             'MM/DD/RR HH24:MI:SS'
         )) * 24,
        2
    ) AS transaction_hours,
    ROUND(
        t.used_ublk * 8192 / 1024 / 1024,
        2
    ) AS undo_mb,
    t.used_urec AS undo_records,
    s.sql_id,
    s.event,
    s.machine,
    s.program
FROM gv$transaction t
JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND t.addr = s.taddr
WHERE
    (SYSDATE -
     TO_DATE(
         t.start_time,
         'MM/DD/RR HH24:MI:SS'
     )) * 24 >= 0.5
ORDER BY transaction_hours DESC;


PROMPT
PROMPT ============================================================
PROMPT 12. TRANSACTIONS USING MORE THAN 1 GB UNDO
PROMPT ============================================================

SELECT
    t.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    ROUND(
        t.used_ublk * 8192 / 1024 / 1024 / 1024,
        2
    ) AS undo_gb,
    t.used_urec,
    s.sql_id,
    s.status,
    s.event,
    s.service_name,
    s.machine
FROM gv$transaction t
JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND t.addr = s.taddr
WHERE
    t.used_ublk * 8192 / 1024 / 1024 / 1024 >= 1
ORDER BY undo_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 13. UNDO RETENTION CONFIGURATION
PROMPT ============================================================

SELECT
    inst_id,
    name,
    value,
    display_value
FROM gv$parameter
WHERE name IN
(
    'undo_management',
    'undo_retention',
    'undo_tablespace'
)
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 14. TUNED UNDO RETENTION
PROMPT ============================================================

SELECT
    inst_id,
    ROUND(AVG(tuned_undoretention), 2) AS avg_tuned_retention_sec,
    MAX(tuned_undoretention) AS max_tuned_retention_sec,
    MIN(tuned_undoretention) AS min_tuned_retention_sec
FROM gv$undostat
WHERE begin_time >= SYSDATE - 1
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 15. LONGEST QUERY VS TUNED RETENTION
PROMPT ============================================================

SELECT
    inst_id,
    MAX(maxquerylen) AS longest_query_sec,
    MAX(tuned_undoretention) AS tuned_retention_sec,
    CASE
        WHEN MAX(maxquerylen) >
             MAX(tuned_undoretention)
        THEN 'REVIEW - QUERY EXCEEDS TUNED RETENTION'
        ELSE 'OK'
    END AS retention_check
FROM gv$undostat
WHERE begin_time >= SYSDATE - 1
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 16. SNAPSHOT TOO OLD ERRORS
PROMPT ============================================================

SELECT
    inst_id,
    SUM(ssolderrcnt) AS snapshot_too_old_errors,
    MAX(ssolderrcnt) AS max_interval_errors,
    MAX(maxquerylen) AS longest_query_sec
FROM gv$undostat
WHERE begin_time >= SYSDATE - 7
GROUP BY inst_id
ORDER BY snapshot_too_old_errors DESC;


PROMPT
PROMPT ============================================================
PROMPT 17. UNDO SPACE ERRORS
PROMPT ============================================================

SELECT
    inst_id,
    SUM(nospaceerrcnt) AS no_space_errors,
    MAX(nospaceerrcnt) AS max_interval_no_space_errors,
    SUM(unxpstealcnt) AS unexpired_extents_stolen,
    SUM(expstealcnt) AS expired_extents_stolen
FROM gv$undostat
WHERE begin_time >= SYSDATE - 7
GROUP BY inst_id
ORDER BY no_space_errors DESC;


PROMPT
PROMPT ============================================================
PROMPT 18. UNDO BLOCK REUSE / STEAL ACTIVITY
PROMPT ============================================================

SELECT
    inst_id,
    SUM(unxpblkreucnt) AS unexpired_blocks_reused,
    SUM(expblkreucnt) AS expired_blocks_reused,
    SUM(unxpstealcnt) AS unexpired_extents_stolen,
    SUM(expstealcnt) AS expired_extents_stolen
FROM gv$undostat
WHERE begin_time >= SYSDATE - 7
GROUP BY inst_id
ORDER BY
    unexpired_blocks_reused DESC;


PROMPT
PROMPT ============================================================
PROMPT 19. UNDO PRESSURE BY INTERVAL
PROMPT ============================================================

SELECT
    inst_id,
    TO_CHAR(begin_time, 'YYYY-MM-DD HH24:MI') AS begin_time,
    undoblks,
    txncount,
    maxquerylen,
    tuned_undoretention,
    ssolderrcnt,
    nospaceerrcnt,
    unxpstealcnt,
    expstealcnt,
    CASE
        WHEN nospaceerrcnt > 0
            THEN 'CRITICAL - NO UNDO SPACE'
        WHEN ssolderrcnt > 0
            THEN 'WARNING - SNAPSHOT TOO OLD'
        WHEN unxpstealcnt > 0
            THEN 'REVIEW - UNEXPIRED SPACE STOLEN'
        ELSE 'NORMAL'
    END AS pressure_status
FROM gv$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY
    inst_id,
    begin_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 20. UNDO GENERATION RATE INDICATOR
PROMPT ============================================================

SELECT
    inst_id,
    TO_CHAR(begin_time, 'YYYY-MM-DD HH24:MI') AS begin_time,
    undoblks,
    ROUND(
        undoblks /
        NULLIF(
            (end_time - begin_time) * 86400,
            0
        ),
        2
    ) AS undo_blocks_per_sec,
    ROUND(
        undoblks * 8192 /
        NULLIF(
            (end_time - begin_time) * 86400,
            0
        ) /
        1024 / 1024,
        2
    ) AS undo_mb_per_sec
FROM gv$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY
    inst_id,
    begin_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 21. HIGH UNDO GENERATION INTERVALS
PROMPT ============================================================

SELECT
    inst_id,
    TO_CHAR(begin_time, 'YYYY-MM-DD HH24:MI') AS begin_time,
    undoblks,
    txncount,
    ROUND(
        undoblks * 8192 / 1024 / 1024,
        2
    ) AS undo_generated_mb,
    maxquerylen,
    tuned_undoretention
FROM gv$undostat
WHERE begin_time >= SYSDATE - 1
ORDER BY undoblks DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 22. ACTIVE TRANSACTIONS BY RAC INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    COUNT(*) AS active_transactions,
    ROUND(
        SUM(t.used_ublk) * 8192 / 1024 / 1024,
        2
    ) AS undo_mb,
    SUM(t.used_urec) AS undo_records
FROM gv$transaction t
JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND t.addr = s.taddr
GROUP BY s.inst_id
ORDER BY undo_mb DESC;


PROMPT
PROMPT ============================================================
PROMPT 23. UNDO USAGE BY USER
PROMPT ============================================================

SELECT
    s.inst_id,
    s.username,
    COUNT(*) AS transactions,
    ROUND(
        SUM(t.used_ublk) * 8192 / 1024 / 1024,
        2
    ) AS undo_mb,
    SUM(t.used_urec) AS undo_records
FROM gv$transaction t
JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND t.addr = s.taddr
WHERE s.username IS NOT NULL
GROUP BY
    s.inst_id,
    s.username
ORDER BY undo_mb DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 24. UNDO CONSUMERS BY SERVICE
PROMPT ============================================================

SELECT
    s.inst_id,
    s.service_name,
    COUNT(*) AS transactions,
    ROUND(
        SUM(t.used_ublk) * 8192 / 1024 / 1024,
        2
    ) AS undo_mb,
    SUM(t.used_urec) AS undo_records
FROM gv$transaction t
JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND t.addr = s.taddr
GROUP BY
    s.inst_id,
    s.service_name
ORDER BY undo_mb DESC;


PROMPT
PROMPT ============================================================
PROMPT 25. TRANSACTIONS WITH CURRENT WAITS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    ROUND(
        t.used_ublk * 8192 / 1024 / 1024,
        2
    ) AS undo_mb,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.service_name,
    s.machine
FROM gv$transaction t
JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND t.addr = s.taddr
WHERE s.status = 'ACTIVE'
  AND s.state = 'WAITING'
  AND s.wait_class <> 'Idle'
ORDER BY
    t.used_ublk DESC,
    s.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 26. TRANSACTIONS INVOLVED IN BLOCKING
PROMPT ============================================================

SELECT
    w.inst_id AS waiter_inst,
    w.sid AS waiter_sid,
    w.username AS waiter_user,
    w.sql_id AS waiter_sql_id,
    ROUND(
        tw.used_ublk * 8192 / 1024 / 1024,
        2
    ) AS waiter_undo_mb,
    w.event AS waiter_event,
    w.seconds_in_wait,

    b.inst_id AS blocker_inst,
    b.sid AS blocker_sid,
    b.username AS blocker_user,
    b.sql_id AS blocker_sql_id,
    ROUND(
        tb.used_ublk * 8192 / 1024 / 1024,
        2
    ) AS blocker_undo_mb,
    b.machine AS blocker_machine
FROM gv$session w
JOIN gv$session b
    ON b.inst_id = w.blocking_instance
   AND b.sid = w.blocking_session
LEFT JOIN gv$transaction tw
    ON tw.inst_id = w.inst_id
   AND tw.addr = w.taddr
LEFT JOIN gv$transaction tb
    ON tb.inst_id = b.inst_id
   AND tb.addr = b.taddr
WHERE w.blocking_session IS NOT NULL
ORDER BY
    w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 27. UNDO STATISTICS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS intervals,
    ROUND(
        SUM(undoblks) * 8192 / 1024 / 1024 / 1024,
        2
    ) AS undo_generated_gb,
    SUM(txncount) AS transactions,
    MAX(maxquerylen) AS longest_query_sec,
    MAX(tuned_undoretention) AS max_tuned_retention_sec,
    SUM(ssolderrcnt) AS snapshot_too_old,
    SUM(nospaceerrcnt) AS no_space_errors
FROM gv$undostat
WHERE begin_time >= SYSDATE - 7
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 28. RAC UNDO HEALTH SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    CASE
        WHEN SUM(nospaceerrcnt) > 0
            THEN 'CRITICAL - UNDO NO SPACE ERRORS'
        WHEN SUM(ssolderrcnt) > 0
            THEN 'WARNING - SNAPSHOT TOO OLD'
        WHEN SUM(unxpstealcnt) > 0
            THEN 'WARNING - UNEXPIRED UNDO STOLEN'
        WHEN MAX(maxquerylen) >
             MAX(tuned_undoretention)
            THEN 'REVIEW - QUERY VS RETENTION'
        ELSE 'HEALTHY - NO MAJOR UNDO ERRORS'
    END AS health_status
FROM gv$undostat
WHERE begin_time >= SYSDATE - 7
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 29. RAC UNDO INSTANCE COMPARISON
PROMPT ============================================================

SELECT
    u.inst_id,
    i.instance_name,
    i.host_name,
    ROUND(
        SUM(u.undoblks) * 8192 / 1024 / 1024 / 1024,
        2
    ) AS undo_generated_gb,
    SUM(u.txncount) AS transactions,
    MAX(u.maxquerylen) AS longest_query_sec,
    SUM(u.ssolderrcnt) AS snapshot_too_old,
    SUM(u.nospaceerrcnt) AS no_space_errors,
    SUM(u.unxpstealcnt) AS unexpired_stolen
FROM gv$undostat u
JOIN gv$instance i
    ON i.inst_id = u.inst_id
WHERE u.begin_time >= SYSDATE - 7
GROUP BY
    u.inst_id,
    i.instance_name,
    i.host_name
ORDER BY undo_generated_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 30. QUICK RAC UNDO CHECK
PROMPT ============================================================

SELECT
    inst_id,
    ROUND(
        SUM(undoblks) * 8192 / 1024 / 1024 / 1024,
        2
    ) AS undo_generated_gb,
    SUM(txncount) AS transactions,
    MAX(maxquerylen) AS longest_query_sec,
    MAX(tuned_undoretention) AS tuned_retention_sec,
    SUM(ssolderrcnt) AS snapshot_too_old,
    SUM(nospaceerrcnt) AS no_space_errors,
    CASE
        WHEN SUM(nospaceerrcnt) > 0
            THEN 'CRITICAL'
        WHEN SUM(ssolderrcnt) > 0
            THEN 'WARNING'
        ELSE 'OK'
    END AS status
FROM gv$undostat
WHERE begin_time >= SYSDATE - 1
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 31. DBA UNDO INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT 1. Check UNDO tablespace and datafile capacity.
PROMPT 2. Check current UNDO-consuming transactions.
PROMPT 3. Identify long-running transactions.
PROMPT 4. Identify transactions using significant UNDO.
PROMPT 5. Check UNDO generation by RAC instance.
PROMPT 6. Check UNDO generation rate.
PROMPT 7. Check snapshot-too-old errors.
PROMPT 8. Check UNDO no-space errors.
PROMPT 9. Check unexpired UNDO stealing/reuse.
PROMPT 10. Compare longest query with tuned retention.
PROMPT 11. Review active transactions by service/user.
PROMPT 12. Check transactions involved in blocking.
PROMPT 13. Compare UNDO workload across RAC instances.
PROMPT 14. Correlate high UNDO generation with DML workload.
PROMPT 15. Review application transactions before changing retention.
PROMPT
PROMPT ============================================================
PROMPT Important Notes:
PROMPT
PROMPT - GV$UNDOSTAT contains interval-level UNDO statistics.
PROMPT - UNDO generation is workload-dependent.
PROMPT - High UNDO generation does not automatically indicate
PROMPT   an UNDO problem.
PROMPT - Long transactions can retain UNDO for extended periods.
PROMPT - Snapshot-too-old errors require workload and retention
PROMPT   analysis.
PROMPT - NO SPACE errors are stronger evidence of UNDO pressure.
PROMPT - Unexpired UNDO stealing can indicate retention pressure.
PROMPT - Tuned retention is dynamic and workload-dependent.
PROMPT - RAC instances can have different UNDO workloads.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC UNDO USAGE MONITORING COMPLETE
PROMPT ============================================================
 
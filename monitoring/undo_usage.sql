-- ============================================================
-- Oracle DBA Toolkit
-- Script  : undo_usage.sql
-- Purpose : Monitor UNDO tablespace usage and transactions
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100
SET TRIMSPOOL ON

COLUMN TABLESPACE_NAME FORMAT A25
COLUMN TOTAL_MB FORMAT 999,999,999
COLUMN USED_MB FORMAT 999,999,999
COLUMN FREE_MB FORMAT 999,999,999
COLUMN PCT_USED FORMAT 999.99

PROMPT
PROMPT ============================================================
PROMPT                  UNDO TABLESPACE USAGE
PROMPT ============================================================
PROMPT

SELECT
    df.tablespace_name,
    ROUND(df.total_mb, 2) AS total_mb,
    ROUND(
        df.total_mb - NVL(fs.free_mb, 0),
        2
    ) AS used_mb,
    ROUND(
        NVL(fs.free_mb, 0),
        2
    ) AS free_mb,
    ROUND(
        (
            (df.total_mb - NVL(fs.free_mb, 0))
            / df.total_mb
        ) * 100,
        2
    ) AS pct_used
FROM
    (
        SELECT
            tablespace_name,
            SUM(bytes) / 1024 / 1024 AS total_mb
        FROM
            dba_data_files
        WHERE
            contents = 'UNDO'
        GROUP BY
            tablespace_name
    ) df
LEFT JOIN
    (
        SELECT
            tablespace_name,
            SUM(bytes) / 1024 / 1024 AS free_mb
        FROM
            dba_free_space
        GROUP BY
            tablespace_name
    ) fs
ON
    df.tablespace_name = fs.tablespace_name
ORDER BY
    pct_used DESC;

PROMPT
PROMPT ============================================================
PROMPT                 UNDO TABLESPACE DETAILS
PROMPT ============================================================
PROMPT

COLUMN TABLESPACE_NAME FORMAT A25
COLUMN STATUS FORMAT A10
COLUMN RETENTION FORMAT A15

SELECT
    tablespace_name,
    status,
    retention
FROM
    dba_tablespaces
WHERE
    contents = 'UNDO';

PROMPT
PROMPT ============================================================
PROMPT                 ACTIVE UNDO TRANSACTIONS
PROMPT ============================================================
PROMPT

COLUMN SID FORMAT 99999
COLUMN SERIAL FORMAT 99999
COLUMN USERNAME FORMAT A20
COLUMN START_TIME FORMAT A20
COLUMN USED_UBLK FORMAT 999,999,999
COLUMN USED_UREC FORMAT 999,999,999
COLUMN STATUS FORMAT A12

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    t.used_ublk,
    t.used_urec,
    t.status
FROM
    v$transaction t
JOIN
    v$session s
ON
    t.addr = s.taddr
ORDER BY
    t.used_ublk DESC;

PROMPT
PROMPT ============================================================
PROMPT                 TOP UNDO CONSUMING SESSIONS
PROMPT ============================================================
PROMPT

COLUMN SID FORMAT 99999
COLUMN SERIAL FORMAT 99999
COLUMN USERNAME FORMAT A20
COLUMN UNDO_BLOCKS FORMAT 999,999,999
COLUMN UNDO_RECORDS FORMAT 999,999,999
COLUMN SQL_ID FORMAT A15

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.used_ublk AS undo_blocks,
    t.used_urec AS undo_records,
    s.sql_id
FROM
    v$transaction t
JOIN
    v$session s
ON
    t.addr = s.taddr
ORDER BY
    t.used_ublk DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 LONG-RUNNING TRANSACTIONS
PROMPT ============================================================
PROMPT

COLUMN SID FORMAT 99999
COLUMN SERIAL FORMAT 99999
COLUMN USERNAME FORMAT A20
COLUMN START_TIME FORMAT A20
COLUMN HOURS_RUNNING FORMAT 999,999.99

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    ROUND(
        (SYSDATE - TO_DATE(t.start_time, 'MM/DD/YY HH24:MI:SS'))
        * 24,
        2
    ) AS hours_running,
    t.used_ublk,
    t.used_urec
FROM
    v$transaction t
JOIN
    v$session s
ON
    t.addr = s.taddr
WHERE
    t.start_time IS NOT NULL
ORDER BY
    hours_running DESC;

PROMPT
PROMPT ============================================================
PROMPT                 UNDO STATISTICS
PROMPT ============================================================
PROMPT

COLUMN BEGIN_TIME FORMAT A20
COLUMN END_TIME FORMAT A20
COLUMN TXNCOUNT FORMAT 999,999,999
COLUMN UNDOBLKS FORMAT 999,999,999
COLUMN MAXQUERYLEN FORMAT 999,999,999
COLUMN MAXQUERYSQLID FORMAT A15

SELECT
    TO_CHAR(begin_time, 'YYYY-MM-DD HH24:MI') AS begin_time,
    TO_CHAR(end_time, 'YYYY-MM-DD HH24:MI') AS end_time,
    txncount,
    undoblks,
    maxquerylen,
    maxquerysqlid
FROM
    v$undostat
ORDER BY
    begin_time DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 UNDO USAGE MONITORING COMPLETE
PROMPT ============================================================

-- ============================================================
-- Oracle DBA Toolkit
-- Script  : session_usage.sql
-- Purpose : Monitor Oracle session resource usage
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET VERIFY OFF

COLUMN SID FORMAT 99999
COLUMN SERIAL FORMAT 99999
COLUMN USERNAME FORMAT A20
COLUMN STATUS FORMAT A10
COLUMN SQL_ID FORMAT A15
COLUMN CPU_SEC FORMAT 999,999,999.99
COLUMN LOGICAL_READS FORMAT 999,999,999,999
COLUMN PHYSICAL_READS FORMAT 999,999,999
COLUMN PHYSICAL_WRITES FORMAT 999,999,999
COLUMN PGA_MB FORMAT 999,999.99
COLUMN USED_UBLK FORMAT 999,999,999
COLUMN USED_UREC FORMAT 999,999,999
COLUMN EVENT FORMAT A45
COLUMN WAIT_CLASS FORMAT A20
COLUMN MACHINE FORMAT A35
COLUMN PROGRAM FORMAT A40

PROMPT
PROMPT ============================================================
PROMPT                 SESSION RESOURCE USAGE
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    ROUND(
        stm.value / 1000000,
        2
    ) AS cpu_sec,
    s.machine,
    s.program
FROM
    v$session s
JOIN
    v$sess_time_model stm
ON
    stm.sid = s.sid
WHERE
    s.username IS NOT NULL
    AND stm.stat_name = 'DB CPU'
ORDER BY
    stm.value DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 SESSION LOGICAL / PHYSICAL I/O
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    ss.value AS logical_reads,
    sr.value AS physical_reads,
    sw.value AS physical_writes
FROM
    v$session s
LEFT JOIN
    v$sesstat ss
ON
    ss.sid = s.sid
LEFT JOIN
    v$statname sn
ON
    sn.statistic# = ss.statistic#
    AND sn.name = 'session logical reads'
LEFT JOIN
    v$sesstat sr
ON
    sr.sid = s.sid
LEFT JOIN
    v$statname rn
ON
    rn.statistic# = sr.statistic#
    AND rn.name = 'physical reads'
LEFT JOIN
    v$sesstat sw
ON
    sw.sid = s.sid
LEFT JOIN
    v$statname wn
ON
    wn.statistic# = sw.statistic#
    AND wn.name = 'physical writes'
WHERE
    s.username IS NOT NULL
    AND
    (
        ss.value > 0
        OR sr.value > 0
        OR sw.value > 0
    )
ORDER BY
    ss.value DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 TOP PGA CONSUMING SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    ROUND(p.pga_used_mem / 1024 / 1024, 2) AS pga_mb,
    s.sql_id,
    s.machine,
    s.program
FROM
    v$session s
JOIN
    v$process p
ON
    s.paddr = p.addr
WHERE
    s.username IS NOT NULL
ORDER BY
    p.pga_used_mem DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 SESSION WAIT ACTIVITY
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.machine,
    s.program
FROM
    v$session s
WHERE
    s.username IS NOT NULL
    AND s.status = 'ACTIVE'
    AND s.wait_class <> 'Idle'
ORDER BY
    s.seconds_in_wait DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 SESSION TRANSACTION USAGE
PROMPT ============================================================
PROMPT

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
WHERE
    s.username IS NOT NULL
ORDER BY
    t.used_ublk DESC;

PROMPT
PROMPT ============================================================
PROMPT                 ACTIVE SESSION DETAILS
PROMPT ============================================================
PROMPT

SELECT
    sid,
    serial# AS serial,
    username,
    status,
    sql_id,
    sql_child_number,
    event,
    wait_class,
    state,
    seconds_in_wait,
    last_call_et,
    machine,
    program
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
ORDER BY
    last_call_et DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 SESSION SQL DETAILS
PROMPT ============================================================
PROMPT

COLUMN SQL_TEXT FORMAT A100 WORD_WRAPPED

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    q.executions,
    ROUND(q.cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(q.elapsed_time / 1000000, 2) AS elapsed_sec,
    q.buffer_gets,
    q.disk_reads,
    q.sql_text
FROM
    v$session s
JOIN
    v$sql q
ON
    s.sql_id = q.sql_id
WHERE
    s.username IS NOT NULL
    AND s.sql_id IS NOT NULL
ORDER BY
    q.cpu_time DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 SESSION USAGE COMPLETE
PROMPT ============================================================


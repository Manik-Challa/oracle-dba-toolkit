-- ============================================================
-- Oracle DBA Toolkit
-- Script  : session_io.sql
-- Purpose : Monitor Oracle session-level I/O activity
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
COLUMN LOGICAL_READS FORMAT 999,999,999,999
COLUMN PHYSICAL_READS FORMAT 999,999,999,999
COLUMN PHYSICAL_WRITES FORMAT 999,999,999,999
COLUMN CONSISTENT_GETS FORMAT 999,999,999,999
COLUMN DB_BLOCK_GETS FORMAT 999,999,999,999
COLUMN DIRECT_READS FORMAT 999,999,999
COLUMN DIRECT_WRITES FORMAT 999,999,999
COLUMN READ_MB FORMAT 999,999,999.99
COLUMN WRITE_MB FORMAT 999,999,999.99
COLUMN MACHINE FORMAT A35
COLUMN PROGRAM FORMAT A40

PROMPT
PROMPT ============================================================
PROMPT                 SESSION I/O SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    COUNT(*) AS user_sessions,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_sessions
FROM
    v$session
WHERE
    username IS NOT NULL;

PROMPT
PROMPT ============================================================
PROMPT                 TOP SESSIONS BY LOGICAL READS
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    MAX(CASE WHEN sn.name = 'session logical reads'
             THEN ss.value END) AS logical_reads,
    MAX(CASE WHEN sn.name = 'consistent gets'
             THEN ss.value END) AS consistent_gets,
    MAX(CASE WHEN sn.name = 'db block gets'
             THEN ss.value END) AS db_block_gets,
    s.machine,
    s.program
FROM
    v$session s
JOIN
    v$sesstat ss
ON
    ss.sid = s.sid
JOIN
    v$statname sn
ON
    sn.statistic# = ss.statistic#
WHERE
    s.username IS NOT NULL
    AND sn.name IN
    (
        'session logical reads',
        'consistent gets',
        'db block gets'
    )
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    s.machine,
    s.program
ORDER BY
    logical_reads DESC NULLS LAST
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 TOP SESSIONS BY PHYSICAL READS
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    MAX(CASE WHEN sn.name = 'physical reads'
             THEN ss.value END) AS physical_reads,
    MAX(CASE WHEN sn.name = 'physical reads direct'
             THEN ss.value END) AS direct_reads,
    s.machine,
    s.program
FROM
    v$session s
JOIN
    v$sesstat ss
ON
    ss.sid = s.sid
JOIN
    v$statname sn
ON
    sn.statistic# = ss.statistic#
WHERE
    s.username IS NOT NULL
    AND sn.name IN
    (
        'physical reads',
        'physical reads direct'
    )
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    s.machine,
    s.program
ORDER BY
    physical_reads DESC NULLS LAST
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 TOP SESSIONS BY PHYSICAL WRITES
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    MAX(CASE WHEN sn.name = 'physical writes'
             THEN ss.value END) AS physical_writes,
    MAX(CASE WHEN sn.name = 'physical writes direct'
             THEN ss.value END) AS direct_writes,
    s.machine,
    s.program
FROM
    v$session s
JOIN
    v$sesstat ss
ON
    ss.sid = s.sid
JOIN
    v$statname sn
ON
    sn.statistic# = ss.statistic#
WHERE
    s.username IS NOT NULL
    AND sn.name IN
    (
        'physical writes',
        'physical writes direct'
    )
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    s.machine,
    s.program
ORDER BY
    physical_writes DESC NULLS LAST
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 SESSION I/O BY USER
PROMPT ============================================================
PROMPT

SELECT
    s.username,
    COUNT(*) AS sessions,
    SUM(
        CASE
            WHEN sn.name = 'session logical reads'
            THEN ss.value
            ELSE 0
        END
    ) AS logical_reads,
    SUM(
        CASE
            WHEN sn.name = 'physical reads'
            THEN ss.value
            ELSE 0
        END
    ) AS physical_reads,
    SUM(
        CASE
            WHEN sn.name = 'physical writes'
            THEN ss.value
            ELSE 0
        END
    ) AS physical_writes
FROM
    v$session s
JOIN
    v$sesstat ss
ON
    ss.sid = s.sid
JOIN
    v$statname sn
ON
    sn.statistic# = ss.statistic#
WHERE
    s.username IS NOT NULL
    AND sn.name IN
    (
        'session logical reads',
        'physical reads',
        'physical writes'
    )
GROUP BY
    s.username
ORDER BY
    physical_reads DESC,
    logical_reads DESC;

PROMPT
PROMPT ============================================================
PROMPT                 CURRENT I/O WAITING SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    sid,
    serial# AS serial,
    username,
    status,
    sql_id,
    event,
    wait_class,
    seconds_in_wait,
    machine,
    program
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
    AND wait_class = 'User I/O'
ORDER BY
    seconds_in_wait DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 TOP SQL BY DISK READS
PROMPT ============================================================
PROMPT

COLUMN SQL_TEXT FORMAT A90 WORD_WRAPPED

SELECT
    sql_id,
    executions,
    disk_reads,
    buffer_gets,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    sql_text
FROM
(
    SELECT
        sql_id,
        executions,
        disk_reads,
        buffer_gets,
        cpu_time,
        elapsed_time,
        sql_text
    FROM
        v$sql
    WHERE
        executions > 0
    ORDER BY
        disk_reads DESC
)
WHERE
    ROWNUM <= 20;

PROMPT
PROMPT ============================================================
PROMPT                 DATABASE I/O SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    name AS statistic,
    value
FROM
    v$sysstat
WHERE
    name IN
    (
        'session logical reads',
        'physical reads',
        'physical writes',
        'physical reads direct',
        'physical writes direct'
    )
ORDER BY
    name;

PROMPT
PROMPT ============================================================
PROMPT                 SESSION I/O MONITORING COMPLETE
PROMPT ============================================================


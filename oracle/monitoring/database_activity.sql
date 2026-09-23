-- ============================================================
-- Oracle DBA Toolkit
-- Script  : database_activity.sql
-- Purpose : Monitor overall Oracle database activity
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100
SET TRIMSPOOL ON

COLUMN STAT_NAME FORMAT A45
COLUMN VALUE FORMAT 999,999,999,999,999
COLUMN SESSIONS FORMAT 999,999
COLUMN USERNAME FORMAT A20
COLUMN STATUS FORMAT A10
COLUMN MACHINE FORMAT A35
COLUMN PROGRAM FORMAT A40
COLUMN SQL_ID FORMAT A15
COLUMN EVENT FORMAT A50
COLUMN WAIT_CLASS FORMAT A20

PROMPT
PROMPT ============================================================
PROMPT                 DATABASE ACTIVITY SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    name AS database_name,
    open_mode,
    database_role
FROM
    v$database;

SELECT
    instance_name,
    host_name,
    status,
    active_state
FROM
    v$instance;

PROMPT
PROMPT ============================================================
PROMPT                 SESSION ACTIVITY
PROMPT ============================================================
PROMPT

SELECT
    status,
    COUNT(*) AS sessions
FROM
    v$session
WHERE
    username IS NOT NULL
GROUP BY
    status
ORDER BY
    sessions DESC;

PROMPT
PROMPT                 ACTIVE SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    COUNT(*) AS active_sessions
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE';

PROMPT
PROMPT                 ACTIVE SESSIONS BY USER
PROMPT ============================================================
PROMPT

SELECT
    username,
    COUNT(*) AS active_sessions
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
GROUP BY
    username
ORDER BY
    active_sessions DESC;

PROMPT
PROMPT ============================================================
PROMPT                 CURRENT ACTIVE SESSIONS
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
    machine,
    program
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
ORDER BY
    username,
    sid;

PROMPT
PROMPT ============================================================
PROMPT                 CURRENT WAIT ACTIVITY
PROMPT ============================================================
PROMPT

SELECT
    event,
    wait_class,
    COUNT(*) AS sessions
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
    AND wait_class <> 'Idle'
GROUP BY
    event,
    wait_class
ORDER BY
    sessions DESC;

PROMPT
PROMPT ============================================================
PROMPT                 TOP SQL BY EXECUTIONS
PROMPT ============================================================
PROMPT

COLUMN SQL_TEXT FORMAT A80 WORD_WRAPPED

SELECT
    sql_id,
    executions,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    sql_text
FROM
(
    SELECT
        sql_id,
        executions,
        elapsed_time,
        cpu_time,
        sql_text
    FROM
        v$sql
    WHERE
        executions > 0
    ORDER BY
        executions DESC
)
WHERE
    ROWNUM <= 20;

PROMPT
PROMPT ============================================================
PROMPT                 LOGICAL / PHYSICAL I/O
PROMPT ============================================================
PROMPT

SELECT
    name AS stat_name,
    value
FROM
    v$sysstat
WHERE
    name IN
    (
        'session logical reads',
        'physical reads',
        'physical writes',
        'db block gets',
        'consistent gets',
        'consistent changes'
    )
ORDER BY
    name;

PROMPT
PROMPT ============================================================
PROMPT                 TRANSACTION ACTIVITY
PROMPT ============================================================
PROMPT

SELECT
    name AS stat_name,
    value
FROM
    v$sysstat
WHERE
    name IN
    (
        'user commits',
        'user rollbacks',
        'user calls',
        'execute count',
        'parse count (total)',
        'parse count (hard)'
    )
ORDER BY
    name;

PROMPT
PROMPT ============================================================
PROMPT                 LOGON ACTIVITY
PROMPT ============================================================
PROMPT

SELECT
    name AS stat_name,
    value
FROM
    v$sysstat
WHERE
    name IN
    (
        'logons cumulative',
        'logons current'
    )
ORDER BY
    name;

PROMPT
PROMPT ============================================================
PROMPT                 OPEN TRANSACTIONS
PROMPT ============================================================
PROMPT

SELECT
    COUNT(*) AS active_transactions
FROM
    v$transaction;

PROMPT
PROMPT                 TOP ACTIVE TRANSACTIONS
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
ORDER BY
    t.used_ublk DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 REDO ACTIVITY
PROMPT ============================================================
PROMPT

SELECT
    name AS stat_name,
    value
FROM
    v$sysstat
WHERE
    name IN
    (
        'redo size',
        'redo entries',
        'redo writes'
    )
ORDER BY
    name;

PROMPT
PROMPT ============================================================
PROMPT                 DATABASE ACTIVITY COMPLETE
PROMPT ============================================================


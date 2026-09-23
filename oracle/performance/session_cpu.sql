-- ============================================================
-- Oracle DBA Toolkit
-- Script  : session_cpu.sql
-- Purpose : Monitor Oracle session-level CPU utilization
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
COLUMN ELAPSED_SEC FORMAT 999,999,999.99
COLUMN CPU_PCT FORMAT 999.99
COLUMN CPU_PER_EXEC FORMAT 999,999.99
COLUMN EXECUTIONS FORMAT 999,999,999
COLUMN EVENT FORMAT A50
COLUMN WAIT_CLASS FORMAT A20
COLUMN MACHINE FORMAT A35
COLUMN PROGRAM FORMAT A40

PROMPT
PROMPT ============================================================
PROMPT                 SESSION CPU SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    COUNT(*) AS user_sessions,
    SUM(
        CASE
            WHEN status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_sessions
FROM
    v$session
WHERE
    username IS NOT NULL;

PROMPT
PROMPT ============================================================
PROMPT                 TOP CPU CONSUMING SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    ROUND(stm.value / 1000000, 2) AS cpu_sec,
    s.event,
    s.wait_class,
    s.machine,
    s.program
FROM
    v$sess_time_model stm
JOIN
    v$session s
ON
    s.sid = stm.sid
WHERE
    stm.stat_name = 'DB CPU'
    AND s.username IS NOT NULL
ORDER BY
    stm.value DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 ACTIVE CPU SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    ROUND(stm.value / 1000000, 2) AS cpu_sec,
    s.last_call_et AS active_seconds,
    s.event,
    s.wait_class,
    s.machine,
    s.program
FROM
    v$sess_time_model stm
JOIN
    v$session s
ON
    s.sid = stm.sid
WHERE
    stm.stat_name = 'DB CPU'
    AND s.username IS NOT NULL
    AND s.status = 'ACTIVE'
ORDER BY
    stm.value DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 CPU BY DATABASE USER
PROMPT ============================================================
PROMPT

SELECT
    s.username,
    COUNT(*) AS sessions,
    ROUND(
        SUM(
            CASE
                WHEN stm.stat_name = 'DB CPU'
                THEN stm.value
                ELSE 0
            END
        ) / 1000000,
        2
    ) AS cpu_sec
FROM
    v$session s
JOIN
    v$sess_time_model stm
ON
    stm.sid = s.sid
WHERE
    s.username IS NOT NULL
    AND stm.stat_name = 'DB CPU'
GROUP BY
    s.username
ORDER BY
    cpu_sec DESC;

PROMPT
PROMPT ============================================================
PROMPT                 TOP SQL BY CPU
PROMPT ============================================================
PROMPT

COLUMN SQL_TEXT FORMAT A90 WORD_WRAPPED

SELECT
    sql_id,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(
        cpu_time / NULLIF(executions, 0) / 1000000,
        2
    ) AS cpu_per_exec,
    buffer_gets,
    disk_reads,
    sql_text
FROM
(
    SELECT
        sql_id,
        executions,
        cpu_time,
        elapsed_time,
        buffer_gets,
        disk_reads,
        sql_text
    FROM
        v$sql
    WHERE
        executions > 0
    ORDER BY
        cpu_time DESC
)
WHERE
    ROWNUM <= 20;

PROMPT
PROMPT ============================================================
PROMPT                 CPU VS ELAPSED TIME
PROMPT ============================================================
PROMPT

SELECT
    sql_id,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(
        CASE
            WHEN elapsed_time > 0
            THEN cpu_time / elapsed_time * 100
        END,
        2
    ) AS cpu_pct_of_elapsed,
    sql_text
FROM
(
    SELECT
        sql_id,
        executions,
        cpu_time,
        elapsed_time,
        sql_text
    FROM
        v$sql
    WHERE
        executions > 0
    ORDER BY
        cpu_time DESC
)
WHERE
    ROWNUM <= 20;

PROMPT
PROMPT ============================================================
PROMPT                 RESOURCE MANAGER CPU WAIT
PROMPT ============================================================
PROMPT

SELECT
    sid,
    serial# AS serial,
    username,
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
    AND event = 'resmgr:cpu quantum'
ORDER BY
    seconds_in_wait DESC;

PROMPT
PROMPT ============================================================
PROMPT                 CPU-RELATED WAIT EVENTS
PROMPT ============================================================
PROMPT

SELECT
    event,
    wait_class,
    COUNT(*) AS sessions,
    MAX(seconds_in_wait) AS max_wait_sec
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
    AND wait_class <> 'Idle'
    AND
    (
        LOWER(event) LIKE '%cpu%'
        OR LOWER(event) LIKE '%scheduler%'
    )
GROUP BY
    event,
    wait_class
ORDER BY
    sessions DESC;

PROMPT
PROMPT ============================================================
PROMPT                 TOP CPU SESSIONS WITH SQL
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    ROUND(stm.value / 1000000, 2) AS cpu_sec,
    q.executions,
    ROUND(q.cpu_time / 1000000, 2) AS sql_cpu_sec,
    ROUND(q.elapsed_time / 1000000, 2) AS sql_elapsed_sec,
    q.sql_text
FROM
    v$sess_time_model stm
JOIN
    v$session s
ON
    s.sid = stm.sid
JOIN
    v$sql q
ON
    q.sql_id = s.sql_id
WHERE
    stm.stat_name = 'DB CPU'
    AND s.username IS NOT NULL
    AND s.sql_id IS NOT NULL
ORDER BY
    stm.value DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 SESSION CPU MONITORING COMPLETE
PROMPT ============================================================


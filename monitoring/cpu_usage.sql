-- ============================================================
-- Oracle DBA Toolkit
-- Script  : cpu_usage.sql
-- Purpose : Monitor Oracle database CPU utilization
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100
SET TRIMSPOOL ON

COLUMN STAT_NAME FORMAT A40
COLUMN CPU_SEC FORMAT 999,999,999,999.99
COLUMN PCT_OF_DB_TIME FORMAT 999.99

COLUMN SID FORMAT 99999
COLUMN SERIAL FORMAT 99999
COLUMN USERNAME FORMAT A20
COLUMN SQL_ID FORMAT A15
COLUMN CPU_SECONDS FORMAT 999,999,999.99
COLUMN ELAPSED_SECONDS FORMAT 999,999,999.99
COLUMN PROGRAM FORMAT A35

PROMPT
PROMPT ============================================================
PROMPT                 DATABASE CPU SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    stat_name,
    ROUND(value / 1000000, 2) AS cpu_sec
FROM
    v$sys_time_model
WHERE
    stat_name IN
    (
        'DB CPU',
        'DB time'
    )
ORDER BY
    value DESC;

PROMPT
PROMPT ============================================================
PROMPT                 CPU VS DB TIME
PROMPT ============================================================
PROMPT

SELECT
    ROUND(
        MAX(
            CASE
                WHEN stat_name = 'DB CPU'
                THEN value
            END
        ) / 1000000,
        2
    ) AS db_cpu_sec,

    ROUND(
        MAX(
            CASE
                WHEN stat_name = 'DB time'
                THEN value
            END
        ) / 1000000,
        2
    ) AS db_time_sec,

    ROUND(
        MAX(
            CASE
                WHEN stat_name = 'DB CPU'
                THEN value
            END
        )
        /
        NULLIF(
            MAX(
                CASE
                    WHEN stat_name = 'DB time'
                    THEN value
                END
            ),
            0
        ) * 100,
        2
    ) AS pct_of_db_time
FROM
    v$sys_time_model;

PROMPT
PROMPT ============================================================
PROMPT                 TOP CPU CONSUMING SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    ROUND(
        stm.value / 1000000,
        2
    ) AS cpu_seconds,
    s.program
FROM
    v$sess_time_model stm
JOIN
    v$session s
ON
    stm.sid = s.sid
WHERE
    stm.stat_name = 'DB CPU'
    AND s.username IS NOT NULL
ORDER BY
    stm.value DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 TOP SQL BY CPU TIME
PROMPT ============================================================
PROMPT

COLUMN SQL_TEXT FORMAT A80 WORD_WRAPPED
COLUMN EXECUTIONS FORMAT 999,999,999
COLUMN CPU_SEC FORMAT 999,999,999.99
COLUMN ELAPSED_SEC FORMAT 999,999,999.99
COLUMN CPU_PER_EXEC_SEC FORMAT 999,999.99

SELECT
    sql_id,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(
        cpu_time / NULLIF(executions, 0) / 1000000,
        2
    ) AS cpu_per_exec_sec,
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
PROMPT                 CPU-RELATED WAIT EVENTS
PROMPT ============================================================
PROMPT

COLUMN EVENT FORMAT A55
COLUMN WAIT_CLASS FORMAT A20
COLUMN WAITING_SESSIONS FORMAT 999,999

SELECT
    event,
    wait_class,
    COUNT(*) AS waiting_sessions
FROM
    v$session
WHERE
    username IS NOT NULL
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
    waiting_sessions DESC;

PROMPT
PROMPT ============================================================
PROMPT                 CPU CONSUMING SQL SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    COUNT(*) AS active_cpu_sessions
FROM
    v$session
WHERE
    username IS NOT NULL
    AND status = 'ACTIVE'
    AND state = 'WAITING'
    AND event = 'resmgr:cpu quantum';

PROMPT
PROMPT ============================================================
PROMPT                 CPU MONITORING COMPLETE
PROMPT ============================================================


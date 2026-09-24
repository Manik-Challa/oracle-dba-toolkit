-- ============================================================
-- Oracle DBA Toolkit
-- Script  : db_time.sql
-- Purpose : Monitor DB Time, DB CPU and database workload
-- Requires: Appropriate access to V$SYS_TIME_MODEL / V$SESS_TIME_MODEL
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100
SET TRIMSPOOL ON

COLUMN STAT_NAME FORMAT A40
COLUMN VALUE_SEC FORMAT 999,999,999,999.99
COLUMN PCT_OF_DB_TIME FORMAT 999.99

PROMPT
PROMPT ============================================================
PROMPT                 DATABASE TIME MODEL
PROMPT ============================================================
PROMPT

SELECT
    stat_name,
    ROUND(value / 1000000, 2) AS value_sec
FROM
    v$sys_time_model
WHERE
    stat_name IN
    (
        'DB time',
        'DB CPU',
        'background elapsed time',
        'background cpu time'
    )
ORDER BY
    value DESC;

PROMPT
PROMPT ============================================================
PROMPT                 DB CPU VS DB TIME
PROMPT ============================================================
PROMPT

SELECT
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
        ) / 1000000,
        2
    ) AS db_cpu_sec,

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
    ) AS cpu_pct_of_db_time
FROM
    v$sys_time_model;

PROMPT
PROMPT ============================================================
PROMPT                 TOP SESSIONS BY DB TIME
PROMPT ============================================================
PROMPT

COLUMN SID FORMAT 99999
COLUMN SERIAL FORMAT 99999
COLUMN USERNAME FORMAT A20
COLUMN DB_TIME_SEC FORMAT 999,999,999.99
COLUMN DB_CPU_SEC FORMAT 999,999,999.99
COLUMN SQL_ID FORMAT A15

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    ROUND(
        MAX(
            CASE
                WHEN stm.stat_name = 'DB time'
                THEN stm.value
            END
        ) / 1000000,
        2
    ) AS db_time_sec,
    ROUND(
        MAX(
            CASE
                WHEN stm.stat_name = 'DB CPU'
                THEN stm.value
            END
        ) / 1000000,
        2
    ) AS db_cpu_sec,
    s.sql_id
FROM
    v$sess_time_model stm
JOIN
    v$session s
ON
    s.sid = stm.sid
WHERE
    s.username IS NOT NULL
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.sql_id
ORDER BY
    db_time_sec DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 TOP SQL BY ELAPSED TIME
PROMPT ============================================================
PROMPT

COLUMN SQL_ID FORMAT A15
COLUMN EXECUTIONS FORMAT 999,999,999
COLUMN ELAPSED_SEC FORMAT 999,999,999.99
COLUMN CPU_SEC FORMAT 999,999,999.99
COLUMN SQL_TEXT FORMAT A70 WORD_WRAPPED

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
        elapsed_time DESC
)
WHERE
    ROWNUM <= 10;

PROMPT
PROMPT ============================================================
PROMPT                 CURRENT NON-IDLE WAITS
PROMPT ============================================================
PROMPT

COLUMN EVENT FORMAT A50
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
GROUP BY
    event,
    wait_class
ORDER BY
    waiting_sessions DESC
FETCH FIRST 10 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 DB TIME MONITORING COMPLETE
PROMPT ============================================================


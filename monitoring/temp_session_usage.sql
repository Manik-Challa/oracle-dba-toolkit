-- ============================================================================
-- Oracle DBA Toolkit
-- File   : temp_session_usage.sql
-- Purpose: Monitor TEMP usage by Oracle sessions
-- Author : Manik Challa
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN username             FORMAT A25
COLUMN machine              FORMAT A30
COLUMN program              FORMAT A40
COLUMN service_name         FORMAT A25
COLUMN status                FORMAT A12
COLUMN sql_id                FORMAT A15
COLUMN event                FORMAT A40
COLUMN wait_class            FORMAT A20
COLUMN tablespace            FORMAT A20
COLUMN sql_text              FORMAT A80 WORD_WRAPPED
COLUMN temp_mb              FORMAT 999,999,990.99
COLUMN temp_gb              FORMAT 999,990.99
COLUMN max_temp_mb          FORMAT 999,999,990.99
COLUMN max_temp_gb          FORMAT 999,990.99
COLUMN pga_mb               FORMAT 999,999,990.99
COLUMN elapsed_min          FORMAT 999,990.99
COLUMN sid                  FORMAT 999999
COLUMN serial               FORMAT 999999
COLUMN inst_id              FORMAT 999
COLUMN blocks               FORMAT 999,999,999,999
COLUMN status_flag          FORMAT A12

PROMPT
PROMPT ============================================================================
PROMPT ORACLE DBA TOOLKIT - TEMP SESSION USAGE
PROMPT ============================================================================


-- ============================================================================
-- 1. DATABASE / INSTANCE INFORMATION
-- ============================================================================

PROMPT
PROMPT [1] DATABASE / INSTANCE INFORMATION
PROMPT ============================================================================

SELECT
    d.name AS database_name,
    i.instance_name,
    i.instance_number,
    i.host_name,
    i.status,
    i.version,
    i.startup_time
FROM v$database d
CROSS JOIN v$instance i;


-- ============================================================================
-- 2. CURRENT TEMP USAGE BY SESSION
-- ============================================================================

PROMPT
PROMPT [2] CURRENT TEMP USAGE BY SESSION
PROMPT ============================================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.machine,
    s.program,
    s.service_name,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS temp_gb
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    s.machine,
    s.program,
    s.service_name
ORDER BY temp_mb DESC;


-- ============================================================================
-- 3. TOP 50 TEMP CONSUMING SESSIONS
-- ============================================================================

PROMPT
PROMPT [3] TOP 50 TEMP CONSUMING SESSIONS
PROMPT ============================================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS temp_gb,
    s.machine,
    s.program
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    s.machine,
    s.program
ORDER BY temp_mb DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 4. TEMP USAGE BY USER
-- ============================================================================

PROMPT
PROMPT [4] TEMP USAGE BY USER
PROMPT ============================================================================

SELECT
    NVL(s.username, 'UNKNOWN') AS username,
    COUNT(DISTINCT s.sid) AS sessions,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS temp_gb
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY NVL(s.username, 'UNKNOWN')
ORDER BY temp_mb DESC;


-- ============================================================================
-- 5. TEMP USAGE BY TABLESPACE
-- ============================================================================

PROMPT
PROMPT [5] TEMP USAGE BY TABLESPACE
PROMPT ============================================================================

SELECT
    u.tablespace,
    COUNT(DISTINCT u.session_addr) AS sessions,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS temp_gb
FROM v$tempseg_usage u
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY
    u.tablespace,
    ts.block_size
ORDER BY temp_mb DESC;


-- ============================================================================
-- 6. TEMP USAGE BY SEGMENT TYPE
-- ============================================================================

PROMPT
PROMPT [6] TEMP USAGE BY SEGMENT TYPE
PROMPT ============================================================================

SELECT
    u.segtype,
    COUNT(*) AS segments,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS temp_gb
FROM v$tempseg_usage u
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY
    u.segtype,
    ts.block_size
ORDER BY temp_mb DESC;


-- ============================================================================
-- 7. TEMP USAGE BY SESSION + SQL
-- ============================================================================

PROMPT
PROMPT [7] TEMP USAGE BY SESSION AND SQL
PROMPT ============================================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.status,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    s.event,
    s.wait_class,
    s.machine,
    s.program
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    s.status,
    s.event,
    s.wait_class,
    s.machine,
    s.program
ORDER BY temp_mb DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 8. TEMP USERS WITH ACTIVE SQL
-- ============================================================================

PROMPT
PROMPT [8] TEMP CONSUMERS WITH ACTIVE SQL
PROMPT ============================================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    s.event,
    s.wait_class,
    s.machine,
    s.program
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
WHERE s.status = 'ACTIVE'
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    s.event,
    s.wait_class,
    s.machine,
    s.program
ORDER BY temp_mb DESC;


-- ============================================================================
-- 9. SESSIONS USING MORE THAN 1 GB TEMP
-- ============================================================================

PROMPT
PROMPT [9] SESSIONS USING MORE THAN 1 GB TEMP
PROMPT ============================================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.status,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS temp_gb,
    s.machine,
    s.program,
    CASE
        WHEN SUM(u.blocks) * ts.block_size
             >= 10 * 1024 * 1024 * 1024
            THEN 'CRITICAL'
        WHEN SUM(u.blocks) * ts.block_size
             >= 5 * 1024 * 1024 * 1024
            THEN 'HIGH'
        WHEN SUM(u.blocks) * ts.block_size
             >= 1 * 1024 * 1024 * 1024
            THEN 'WATCH'
        ELSE 'NORMAL'
    END AS status_flag
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    s.status,
    s.machine,
    s.program
HAVING SUM(u.blocks) * ts.block_size
       >= 1 * 1024 * 1024 * 1024
ORDER BY temp_gb DESC;


-- ============================================================================
-- 10. TEMP CONSUMERS WITH SQL TEXT
-- ============================================================================

PROMPT
PROMPT [10] TEMP CONSUMERS WITH SQL TEXT
PROMPT ============================================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    SUBSTR(q.sql_text, 1, 1000) AS sql_text
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
LEFT JOIN v$sql q
    ON q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    ts.block_size,
    q.sql_text
ORDER BY temp_mb DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================================
-- 11. TEMP CONSUMERS WITH SQL EXECUTION DETAILS
-- ============================================================================

PROMPT
PROMPT [11] TEMP CONSUMERS - SQL EXECUTION DETAILS
PROMPT ============================================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    q.executions,
    ROUND(
        q.elapsed_time / 1000000,
        2
    ) AS elapsed_sec,
    ROUND(
        q.cpu_time / 1000000,
        2
    ) AS cpu_sec,
    q.disk_reads,
    q.buffer_gets,
    q.rows_processed
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
LEFT JOIN v$sql q
    ON q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    ts.block_size,
    q.executions,
    q.elapsed_time,
    q.cpu_time,
    q.disk_reads,
    q.buffer_gets,
    q.rows_processed
ORDER BY temp_mb DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 12. TEMP USAGE BY MACHINE
-- ============================================================================

PROMPT
PROMPT [12] TEMP USAGE BY CLIENT MACHINE
PROMPT ============================================================================

SELECT
    s.machine,
    COUNT(DISTINCT s.sid) AS sessions,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS temp_gb
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY s.machine
ORDER BY temp_mb DESC;


-- ============================================================================
-- 13. TEMP USAGE BY PROGRAM
-- ============================================================================

PROMPT
PROMPT [13] TEMP USAGE BY PROGRAM
PROMPT ============================================================================

SELECT
    s.program,
    COUNT(DISTINCT s.sid) AS sessions,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS temp_gb
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY s.program
ORDER BY temp_mb DESC;


-- ============================================================================
-- 14. TEMP USAGE BY SERVICE
-- ============================================================================

PROMPT
PROMPT [14] TEMP USAGE BY SERVICE
PROMPT ============================================================================

SELECT
    s.service_name,
    COUNT(DISTINCT s.sid) AS sessions,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS temp_gb
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY s.service_name
ORDER BY temp_mb DESC;


-- ============================================================================
-- 15. TEMP / SORT WAIT EVENTS
-- ============================================================================

PROMPT
PROMPT [15] TEMP / SORT RELATED WAIT EVENTS
PROMPT ============================================================================

SELECT
    event,
    total_waits,
    ROUND(
        time_waited / 100,
        2
    ) AS time_waited_sec,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN time_waited / total_waits / 100
        END,
        2
    ) AS avg_wait_sec
FROM v$system_event
WHERE
       LOWER(event) LIKE '%temp%'
    OR LOWER(event) LIKE '%sort%'
    OR LOWER(event) LIKE '%direct path%'
ORDER BY time_waited DESC;


-- ============================================================================
-- 16. CURRENT TEMP / SORT WAITERS
-- ============================================================================

PROMPT
PROMPT [16] CURRENT TEMP / SORT WAITERS
PROMPT ============================================================================

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
FROM v$session
WHERE state = 'WAITING'
  AND
  (
       LOWER(event) LIKE '%temp%'
    OR LOWER(event) LIKE '%sort%'
    OR LOWER(event) LIKE '%direct path%'
  )
ORDER BY seconds_in_wait DESC;


-- ============================================================================
-- 17. TEMP USAGE BY SEGMENT TYPE AND USER
-- ============================================================================

PROMPT
PROMPT [17] TEMP USAGE BY USER AND SEGMENT TYPE
PROMPT ============================================================================

SELECT
    NVL(s.username, 'UNKNOWN') AS username,
    u.segtype,
    COUNT(*) AS segments,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS temp_gb
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY
    NVL(s.username, 'UNKNOWN'),
    u.segtype,
    ts.block_size
ORDER BY temp_mb DESC;


-- ============================================================================
-- 18. TEMP USAGE SUMMARY
-- ============================================================================

PROMPT
PROMPT [18] TEMP USAGE SUMMARY
PROMPT ============================================================================

SELECT
    COUNT(DISTINCT s.sid) AS temp_sessions,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS total_temp_used_mb,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS total_temp_used_gb
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace;


-- ============================================================================
-- 19. TOP TEMP CONSUMER
-- ============================================================================

PROMPT
PROMPT [19] TOP TEMP CONSUMER
PROMPT ============================================================================

SELECT *
FROM
(
    SELECT
        s.sid,
        s.serial# AS serial,
        s.username,
        s.sql_id,
        ROUND(
            SUM(u.blocks) * ts.block_size
            / 1024 / 1024 / 1024,
            2
        ) AS temp_gb,
        s.machine,
        s.program
    FROM v$tempseg_usage u
    JOIN v$session s
        ON s.saddr = u.session_addr
    JOIN dba_tablespaces ts
        ON ts.tablespace_name = u.tablespace
    GROUP BY
        s.sid,
        s.serial#,
        s.username,
        s.sql_id,
        ts.block_size,
        s.machine,
        s.program
    ORDER BY temp_gb DESC
)
WHERE ROWNUM = 1;


-- ============================================================================
-- 20. QUICK DBA CHECK
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT QUICK TEMP SESSION CHECK
PROMPT ============================================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    ROUND(
        SUM(u.blocks) * ts.block_size
        / 1024 / 1024 / 1024,
        2
    ) AS temp_gb,
    s.status,
    s.event,
    s.machine,
    s.program
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    ts.block_size,
    s.status,
    s.event,
    s.machine,
    s.program
ORDER BY temp_gb DESC
FETCH FIRST 20 ROWS ONLY;


-- ============================================================================
-- DBA CHECKLIST
-- ============================================================================
--
-- 1. Identify sessions consuming the most TEMP.
-- 2. Identify the SQL_ID responsible for heavy TEMP usage.
-- 3. Check whether the SQL is doing a large SORT, HASH JOIN,
--    GROUP BY, ORDER BY, CREATE INDEX, or other TEMP-intensive operation.
-- 4. Review the execution plan for the SQL_ID.
-- 5. Check whether multiple sessions are consuming TEMP simultaneously.
-- 6. Correlate TEMP usage with application batch jobs.
-- 7. Check TEMP tablespace capacity using tempfile_usage.sql.
-- 8. Check TEMP-related wait events.
-- 9. Investigate sudden TEMP growth rather than reacting to normal
--    workload-driven TEMP usage.
-- 10. Avoid killing sessions solely because they consume TEMP.
--
-- IMPORTANT:
-- * V$TEMPSEG_USAGE shows currently allocated TEMP segments.
-- * TEMP usage can change rapidly during SQL execution.
-- * TEMP consumption alone does not prove a problem.
-- * Large SORT/HASH operations may legitimately require substantial TEMP.
-- * SQL_ID should be correlated with execution plans and workload.
-- * The 1 GB / 5 GB / 10 GB thresholds are DBA Toolkit heuristics.
-- * This script is READ-ONLY and does not kill or alter sessions.
--
-- ============================================================================
-- END OF SCRIPT
-- ============================================================================

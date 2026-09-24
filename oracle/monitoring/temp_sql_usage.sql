-- ============================================================
-- Oracle DBA Toolkit
-- File   : temp_sql_usage.sql
-- Purpose: Monitor SQL statements consuming TEMP space
-- Scope  : SQL-level TEMP usage, SQL text, sessions, users
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN username        FORMAT A20
COLUMN machine         FORMAT A25
COLUMN program         FORMAT A35
COLUMN service_name    FORMAT A25
COLUMN sql_id          FORMAT A15
COLUMN child_number    FORMAT 99999
COLUMN sql_text        FORMAT A100 WORD_WRAPPED
COLUMN tablespace      FORMAT A20
COLUMN segtype         FORMAT A15
COLUMN temp_mb         FORMAT 999,999,999.99
COLUMN temp_gb         FORMAT 999,999.99
COLUMN executions      FORMAT 999,999,999
COLUMN elapsed_sec     FORMAT 999,999,999.99
COLUMN cpu_sec         FORMAT 999,999,999.99
COLUMN disk_reads      FORMAT 999,999,999
COLUMN buffer_gets     FORMAT 999,999,999
COLUMN rows_processed  FORMAT 999,999,999
COLUMN status          FORMAT A10
COLUMN event           FORMAT A45
COLUMN wait_class      FORMAT A20

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
PROMPT 2. CURRENT TEMP USAGE BY SQL ID
PROMPT ============================================================

SELECT
    s.username,
    u.sql_id,
    u.sql_id AS current_sql_id,
    u.segtype,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS temp_gb,
    COUNT(*) AS temp_segments
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
WHERE u.sql_id IS NOT NULL
GROUP BY
    s.username,
    u.sql_id,
    u.segtype,
    ts.block_size
ORDER BY temp_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 3. TOP SQL STATEMENTS CONSUMING TEMP
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        u.sql_id,
        s.username,
        ROUND(
            SUM(u.blocks) * ts.block_size / 1024 / 1024,
            2
        ) AS temp_mb,
        ROUND(
            SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
            2
        ) AS temp_gb,
        COUNT(*) AS temp_segments
    FROM v$tempseg_usage u
    JOIN v$session s
        ON s.saddr = u.session_addr
    JOIN dba_tablespaces ts
        ON ts.tablespace_name = u.tablespace
    WHERE u.sql_id IS NOT NULL
    GROUP BY
        u.sql_id,
        s.username,
        ts.block_size
    ORDER BY temp_mb DESC
)
WHERE ROWNUM <= 50;

PROMPT
PROMPT ============================================================
PROMPT 4. TEMP USAGE BY SQL AND SEGMENT TYPE
PROMPT ============================================================

SELECT
    u.sql_id,
    u.segtype,
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
WHERE u.sql_id IS NOT NULL
GROUP BY
    u.sql_id,
    u.segtype,
    ts.block_size
ORDER BY temp_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 5. TEMP USAGE BY SQL / USER / MACHINE
PROMPT ============================================================

SELECT
    u.sql_id,
    s.username,
    s.machine,
    s.program,
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
WHERE u.sql_id IS NOT NULL
GROUP BY
    u.sql_id,
    s.username,
    s.machine,
    s.program,
    ts.block_size
ORDER BY temp_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 6. TEMP-USING SQL WITH SQL EXECUTION STATISTICS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        u.sql_id,
        s.username,
        ROUND(
            SUM(u.blocks) * ts.block_size / 1024 / 1024,
            2
        ) AS temp_mb,
        q.executions,
        ROUND(q.elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(q.cpu_time / 1000000, 2) AS cpu_sec,
        q.buffer_gets,
        q.disk_reads,
        q.rows_processed
    FROM v$tempseg_usage u
    JOIN v$session s
        ON s.saddr = u.session_addr
    JOIN dba_tablespaces ts
        ON ts.tablespace_name = u.tablespace
    LEFT JOIN v$sql q
        ON q.sql_id = u.sql_id
    WHERE u.sql_id IS NOT NULL
    GROUP BY
        u.sql_id,
        s.username,
        ts.block_size,
        q.executions,
        q.elapsed_time,
        q.cpu_time,
        q.buffer_gets,
        q.disk_reads,
        q.rows_processed
    ORDER BY temp_mb DESC
)
WHERE ROWNUM <= 50;

PROMPT
PROMPT ============================================================
PROMPT 7. TEMP-USING SQL TEXT
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        u.sql_id,
        s.username,
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
        ON q.sql_id = u.sql_id
    WHERE u.sql_id IS NOT NULL
    GROUP BY
        u.sql_id,
        s.username,
        ts.block_size,
        q.sql_text
    ORDER BY temp_mb DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT ============================================================
PROMPT 8. SQL WITH HIGH TEMP + HIGH PHYSICAL READS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        u.sql_id,
        s.username,
        ROUND(
            SUM(u.blocks) * ts.block_size / 1024 / 1024,
            2
        ) AS temp_mb,
        q.executions,
        q.disk_reads,
        q.buffer_gets,
        ROUND(q.elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(q.cpu_time / 1000000, 2) AS cpu_sec
    FROM v$tempseg_usage u
    JOIN v$session s
        ON s.saddr = u.session_addr
    JOIN dba_tablespaces ts
        ON ts.tablespace_name = u.tablespace
    JOIN v$sql q
        ON q.sql_id = u.sql_id
    WHERE u.sql_id IS NOT NULL
    GROUP BY
        u.sql_id,
        s.username,
        ts.block_size,
        q.executions,
        q.disk_reads,
        q.buffer_gets,
        q.elapsed_time,
        q.cpu_time
    ORDER BY temp_mb DESC, q.disk_reads DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT ============================================================
PROMPT 9. TEMP-USING SQL WITH ACTIVE SESSIONS
PROMPT ============================================================

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
    s.status,
    s.sql_id,
    ts.block_size,
    s.event,
    s.wait_class,
    s.machine,
    s.program
ORDER BY temp_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 10. TEMP-USING SQL WITH SORT/HASH RELATED SEGMENTS
PROMPT ============================================================

SELECT
    u.sql_id,
    u.segtype,
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
WHERE u.sql_id IS NOT NULL
  AND u.segtype IN (
        'SORT',
        'HASH',
        'DATA',
        'INDEX'
      )
GROUP BY
    u.sql_id,
    u.segtype,
    ts.block_size
ORDER BY temp_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 11. TOP SQL BY TEMP CONSUMPTION >= 1 GB
PROMPT ============================================================

SELECT
    u.sql_id,
    s.username,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
        2
    ) AS temp_gb,
    s.status,
    s.machine,
    s.program
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
GROUP BY
    u.sql_id,
    s.username,
    ts.block_size,
    s.status,
    s.machine,
    s.program
HAVING SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024 >= 1
ORDER BY temp_gb DESC;

PROMPT
PROMPT ============================================================
PROMPT 12. TOP SQL BY TEMP CONSUMPTION >= 5 GB
PROMPT ============================================================

SELECT
    u.sql_id,
    s.username,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
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
    u.sql_id,
    s.username,
    ts.block_size,
    s.status,
    s.event,
    s.machine,
    s.program
HAVING SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024 >= 5
ORDER BY temp_gb DESC;

PROMPT
PROMPT ============================================================
PROMPT 13. TEMP SQL + CURRENT WAIT EVENT
PROMPT ============================================================

SELECT
    u.sql_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    ROUND(
        SUM(u.blocks) * ts.block_size / 1024 / 1024,
        2
    ) AS temp_mb,
    s.event,
    s.wait_class,
    s.state,
    s.seconds_in_wait
FROM v$tempseg_usage u
JOIN v$session s
    ON s.saddr = u.session_addr
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace
WHERE s.status = 'ACTIVE'
GROUP BY
    u.sql_id,
    s.sid,
    s.serial#,
    s.username,
    ts.block_size,
    s.event,
    s.wait_class,
    s.state,
    s.seconds_in_wait
ORDER BY temp_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 14. TEMP-RELATED WAIT EVENTS
PROMPT ============================================================

SELECT
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        time_waited / NULLIF(total_waits, 0) / 100,
        4
    ) AS avg_wait_sec
FROM v$system_event
WHERE event LIKE '%direct path%temp%'
   OR event LIKE '%direct path%sort%'
   OR event LIKE '%direct path%read temp%'
   OR event LIKE '%direct path%write temp%'
ORDER BY time_waited DESC;

PROMPT
PROMPT ============================================================
PROMPT 15. CURRENT TEMP-RELATED WAITERS
PROMPT ============================================================

SELECT
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    state,
    seconds_in_wait,
    machine,
    program
FROM v$session
WHERE status = 'ACTIVE'
  AND (
       event LIKE '%direct path%temp%'
       OR event LIKE '%direct path%sort%'
       OR event LIKE '%direct path%read temp%'
       OR event LIKE '%direct path%write temp%'
      )
ORDER BY seconds_in_wait DESC;

PROMPT
PROMPT ============================================================
PROMPT 16. TEMP SQL BY USER
PROMPT ============================================================

SELECT
    s.username,
    COUNT(DISTINCT u.sql_id) AS sql_count,
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
WHERE s.username IS NOT NULL
GROUP BY
    s.username,
    ts.block_size
ORDER BY temp_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 17. TEMP SQL BY TABLESPACE
PROMPT ============================================================

SELECT
    u.tablespace,
    COUNT(DISTINCT u.sql_id) AS sql_count,
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

PROMPT
PROMPT ============================================================
PROMPT 18. TOP SQL BY CURRENT TEMP + EXECUTION COST
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        u.sql_id,
        s.username,
        ROUND(
            SUM(u.blocks) * ts.block_size / 1024 / 1024,
            2
        ) AS temp_mb,
        q.executions,
        ROUND(
            q.elapsed_time /
            NULLIF(q.executions, 0) /
            1000000,
            4
        ) AS elapsed_sec_per_exec,
        ROUND(
            q.cpu_time /
            NULLIF(q.executions, 0) /
            1000000,
            4
        ) AS cpu_sec_per_exec,
        q.disk_reads,
        q.buffer_gets
    FROM v$tempseg_usage u
    JOIN v$session s
        ON s.saddr = u.session_addr
    JOIN dba_tablespaces ts
        ON ts.tablespace_name = u.tablespace
    JOIN v$sql q
        ON q.sql_id = u.sql_id
    GROUP BY
        u.sql_id,
        s.username,
        ts.block_size,
        q.executions,
        q.elapsed_time,
        q.cpu_time,
        q.disk_reads,
        q.buffer_gets
    ORDER BY temp_mb DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT ============================================================
PROMPT 19. TEMP USAGE SUMMARY
PROMPT ============================================================

SELECT
    COUNT(DISTINCT u.sql_id) AS active_temp_sql,
    COUNT(DISTINCT u.session_addr) AS temp_sessions,
    ROUND(
        SUM(u.blocks * ts.block_size) / 1024 / 1024,
        2
    ) AS total_temp_mb,
    ROUND(
        SUM(u.blocks * ts.block_size) / 1024 / 1024 / 1024,
        2
    ) AS total_temp_gb
FROM v$tempseg_usage u
JOIN dba_tablespaces ts
    ON ts.tablespace_name = u.tablespace;

PROMPT
PROMPT ============================================================
PROMPT 20. TOP TEMP-CONSUMING SQL
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        u.sql_id,
        s.username,
        ROUND(
            SUM(u.blocks) * ts.block_size / 1024 / 1024 / 1024,
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
        u.sql_id,
        s.username,
        ts.block_size,
        s.status,
        s.event,
        s.machine,
        s.program
    ORDER BY temp_gb DESC
)
WHERE ROWNUM = 1;

PROMPT
PROMPT ============================================================
PROMPT DBA QUICK CHECK
PROMPT ============================================================
PROMPT
PROMPT 1. Identify the SQL_ID consuming the most TEMP.
PROMPT 2. Check the SQL text and execution plan for that SQL_ID.
PROMPT 3. Determine whether SORT/HASH operations are spilling to TEMP.
PROMPT 4. Check PGA/workarea sizing and execution plan.
PROMPT 5. Check whether the SQL is doing large ORDER BY/GROUP BY operations.
PROMPT 6. Check HASH JOIN / SORT operations and cardinality estimates.
PROMPT 7. Check TEMP tablespace capacity and AUTOEXTEND configuration.
PROMPT 8. Check whether multiple sessions are consuming TEMP simultaneously.
PROMPT 9. Do not kill a session solely because it is using TEMP.
PROMPT 10. Investigate workload, SQL plan, PGA, and TEMP capacity together.
PROMPT
PROMPT ============================================================
PROMPT HEALTH / ALERT GUIDANCE
PROMPT ============================================================
PROMPT
PROMPT > 1 GB TEMP per SQL    : WATCH
PROMPT >= 5 GB TEMP per SQL   : HIGH
PROMPT >= 10 GB TEMP per SQL  : CRITICAL
PROMPT
PROMPT These thresholds are DBA Toolkit heuristics, not Oracle standards.
PROMPT
PROMPT IMPORTANT:
PROMPT - V$TEMPSEG_USAGE shows CURRENTLY allocated TEMP segments.
PROMPT - TEMP usage can change rapidly during SQL execution.
PROMPT - Large TEMP usage does not automatically indicate a problem.
PROMPT - Large SORT/HASH operations may legitimately use TEMP.
PROMPT - Check SQL execution plan and PGA/workarea behavior.
PROMPT - Do not kill sessions solely based on TEMP consumption.
PROMPT - For RAC, consider GV$TEMPSEG_USAGE and GV$SESSION with INST_ID.
PROMPT
PROMPT ============================================================
PROMPT END OF TEMP SQL USAGE CHECK
PROMPT ============================================================


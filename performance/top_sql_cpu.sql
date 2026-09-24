-- ============================================================================
-- Oracle DBA Toolkit
-- Script  : top_sql_cpu.sql
-- Purpose : Identify SQL statements consuming the most database CPU
-- Author  : Manik Challa
-- Usage   : SQL*Plus / SQLcl
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN sql_id              FORMAT A15
COLUMN plan_hash_value     FORMAT 9999999999
COLUMN executions          FORMAT 999999999999
COLUMN cpu_sec             FORMAT 999999999999.99
COLUMN elapsed_sec         FORMAT 999999999999.99
COLUMN cpu_per_exec_ms     FORMAT 999999999999.99
COLUMN elapsed_per_exec_ms FORMAT 999999999999.99
COLUMN buffer_gets        FORMAT 999999999999
COLUMN disk_reads         FORMAT 999999999999
COLUMN rows_processed     FORMAT 999999999999
COLUMN parsing_schema     FORMAT A20
COLUMN module             FORMAT A30
COLUMN sql_text            FORMAT A100 WORD_WRAPPED

PROMPT
PROMPT ================================================================
PROMPT ORACLE TOP SQL BY CPU
PROMPT ================================================================
PROMPT

-- ============================================================================
-- 1. Top SQL by Total CPU Time
-- ============================================================================

PROMPT
PROMPT [1] TOP SQL BY TOTAL CPU TIME
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        buffer_gets,
        disk_reads,
        rows_processed,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
    ORDER BY cpu_time DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 2. Top SQL by CPU per Execution
-- ============================================================================

PROMPT
PROMPT [2] TOP SQL BY CPU PER EXECUTION
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND(
            cpu_time / executions / 1000,
            2
        ) AS cpu_per_exec_ms,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        buffer_gets,
        disk_reads,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
    ORDER BY cpu_time / executions DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 3. Top SQL by CPU Percentage of Elapsed Time
-- ============================================================================

PROMPT
PROMPT [3] SQL WITH HIGH CPU / ELAPSED RATIO
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(
            CASE
                WHEN elapsed_time > 0
                THEN cpu_time / elapsed_time * 100
                ELSE 0
            END,
            2
        ) AS cpu_pct_elapsed,
        buffer_gets,
        disk_reads,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
      AND elapsed_time > 0
    ORDER BY cpu_time / elapsed_time DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 4. Top SQL by Total CPU and High Execution Count
-- ============================================================================

PROMPT
PROMPT [4] HIGH CPU SQL WITH EXECUTION COUNTS
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND(cpu_time / executions / 1000, 2) AS cpu_per_exec_ms,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        buffer_gets,
        disk_reads,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
    ORDER BY cpu_time DESC, executions DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 5. Top SQL by Logical Reads and CPU
-- ============================================================================

PROMPT
PROMPT [5] CPU-HEAVY SQL WITH HIGH LOGICAL READS
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        buffer_gets,
        ROUND(
            buffer_gets / executions,
            2
        ) AS buffer_gets_per_exec,
        disk_reads,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
    ORDER BY cpu_time DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 6. Top SQL by CPU per Row Processed
-- ============================================================================

PROMPT
PROMPT [6] CPU PER ROW PROCESSED
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        rows_processed,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND(
            CASE
                WHEN rows_processed > 0
                THEN cpu_time / rows_processed / 1000
                ELSE 0
            END,
            4
        ) AS cpu_per_row_ms,
        buffer_gets,
        disk_reads,
        parsing_schema_name AS parsing_schema,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
      AND rows_processed > 0
    ORDER BY cpu_time / rows_processed DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 7. SQL with High CPU and High Disk Reads
-- ============================================================================

PROMPT
PROMPT [7] SQL WITH HIGH CPU AND PHYSICAL READS
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        buffer_gets,
        disk_reads,
        ROUND(
            CASE
                WHEN executions > 0
                THEN cpu_time / executions / 1000
                ELSE 0
            END,
            2
        ) AS cpu_per_exec_ms,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
      AND disk_reads > 0
    ORDER BY cpu_time DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 8. Top CPU by Parsing Schema
-- ============================================================================

PROMPT
PROMPT [8] CPU USAGE BY PARSING SCHEMA
PROMPT

SELECT
    parsing_schema_name AS parsing_schema,
    COUNT(*) AS sql_count,
    SUM(executions) AS executions,
    ROUND(SUM(cpu_time) / 1000000, 2) AS cpu_sec,
    ROUND(SUM(elapsed_time) / 1000000, 2) AS elapsed_sec,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads
FROM v$sql
WHERE parsing_schema_name IS NOT NULL
GROUP BY parsing_schema_name
ORDER BY SUM(cpu_time) DESC;

-- ============================================================================
-- 9. Top CPU by Module
-- ============================================================================

PROMPT
PROMPT [9] CPU USAGE BY MODULE
PROMPT

SELECT
    NVL(module, 'UNKNOWN') AS module,
    COUNT(*) AS sql_count,
    SUM(executions) AS executions,
    ROUND(SUM(cpu_time) / 1000000, 2) AS cpu_sec,
    ROUND(SUM(elapsed_time) / 1000000, 2) AS elapsed_sec,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads
FROM v$sql
GROUP BY NVL(module, 'UNKNOWN')
ORDER BY SUM(cpu_time) DESC;

-- ============================================================================
-- 10. SQL Currently Running with High CPU
-- ============================================================================

PROMPT
PROMPT [10] ACTIVE SESSIONS RUNNING CPU-HEAVY SQL
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.sql_child_number,
    s.event,
    s.wait_class,
    s.machine,
    s.program,
    q.executions,
    ROUND(q.cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(q.elapsed_time / 1000000, 2) AS elapsed_sec,
    SUBSTR(q.sql_text, 1, 100) AS sql_text
FROM v$session s
JOIN v$sql q
  ON q.sql_id = s.sql_id
 AND q.child_number = s.sql_child_number
WHERE s.status = 'ACTIVE'
  AND s.username IS NOT NULL
ORDER BY q.cpu_time DESC
FETCH FIRST 20 ROWS ONLY;

-- ============================================================================
-- 11. Top SQL with High CPU and Multiple Child Cursors
-- ============================================================================

PROMPT
PROMPT [11] CPU-HEAVY SQL WITH MULTIPLE CHILD CURSORS
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        version_count,
        executions,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND(
            CASE
                WHEN executions > 0
                THEN cpu_time / executions / 1000
                ELSE 0
            END,
            2
        ) AS cpu_per_exec_ms,
        parsing_schema_name AS parsing_schema,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sqlarea
    WHERE executions > 0
      AND version_count > 1
    ORDER BY cpu_time DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 12. CPU-Related Wait Events
-- ============================================================================

PROMPT
PROMPT [12] CPU / RESOURCE MANAGER RELATED WAITS
PROMPT

SELECT
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN (time_waited / total_waits) / 100
            ELSE 0
        END,
        4
    ) AS avg_wait_sec
FROM v$system_event
WHERE event LIKE '%CPU%'
   OR event = 'resmgr:cpu quantum'
ORDER BY time_waited DESC;

PROMPT
PROMPT ================================================================
PROMPT TOP SQL CPU INVESTIGATION COMPLETE
PROMPT ================================================================
PROMPT
PROMPT DBA CHECKLIST:
PROMPT 1. Identify SQL with the highest total CPU consumption.
PROMPT 2. Check CPU per execution for expensive individual executions.
PROMPT 3. Review logical reads and physical reads.
PROMPT 4. Compare CPU time with elapsed time.
PROMPT 5. Check execution count for frequently executed SQL.
PROMPT 6. Review SQL plan and execution statistics.
PROMPT 7. Check for multiple child cursors when version_count is high.
PROMPT 8. Correlate high CPU SQL with active sessions and wait events.
PROMPT 9. Use SQL Monitor / AWR / ASH where licensed and appropriate.
PROMPT
PROMPT Note: V$SQL CPU_TIME and related counters are cumulative for
PROMPT the cursor in the shared pool. They are not instantaneous CPU
PROMPT rates. Use before/after snapshots for rate calculations.
PROMPT
PROMPT ================================================================


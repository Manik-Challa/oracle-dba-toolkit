-- ============================================================================
-- Oracle DBA Toolkit
-- Script  : top_sql_elapsed.sql
-- Purpose : Identify SQL statements consuming the most elapsed time
-- Author  : Manik Challa
-- Usage   : SQL*Plus / SQLcl
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN sql_id               FORMAT A15
COLUMN plan_hash_value      FORMAT 9999999999
COLUMN executions           FORMAT 999999999999
COLUMN elapsed_sec          FORMAT 999999999999.99
COLUMN cpu_sec              FORMAT 999999999999.99
COLUMN elapsed_per_exec_ms  FORMAT 999999999999.99
COLUMN cpu_per_exec_ms      FORMAT 999999999999.99
COLUMN buffer_gets          FORMAT 999999999999
COLUMN disk_reads           FORMAT 999999999999
COLUMN rows_processed       FORMAT 999999999999
COLUMN parsing_schema       FORMAT A20
COLUMN module               FORMAT A30
COLUMN sql_text             FORMAT A100 WORD_WRAPPED

PROMPT
PROMPT ================================================================
PROMPT ORACLE TOP SQL BY ELAPSED TIME
PROMPT ================================================================
PROMPT

-- ============================================================================
-- 1. Top SQL by Total Elapsed Time
-- ============================================================================

PROMPT
PROMPT [1] TOP SQL BY TOTAL ELAPSED TIME
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        buffer_gets,
        disk_reads,
        rows_processed,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
    ORDER BY elapsed_time DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 2. Top SQL by Elapsed Time per Execution
-- ============================================================================

PROMPT
PROMPT [2] TOP SQL BY ELAPSED TIME PER EXECUTION
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(
            elapsed_time / executions / 1000,
            2
        ) AS elapsed_per_exec_ms,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND(
            cpu_time / executions / 1000,
            2
        ) AS cpu_per_exec_ms,
        buffer_gets,
        disk_reads,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
    ORDER BY elapsed_time / executions DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 3. SQL with Highest Non-CPU Elapsed Time
-- ============================================================================

PROMPT
PROMPT [3] SQL WITH HIGH NON-CPU ELAPSED TIME
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND(
            (elapsed_time - cpu_time) / 1000000,
            2
        ) AS non_cpu_elapsed_sec,
        ROUND(
            CASE
                WHEN elapsed_time > 0
                THEN (elapsed_time - cpu_time)
                     / elapsed_time * 100
                ELSE 0
            END,
            2
        ) AS non_cpu_pct,
        buffer_gets,
        disk_reads,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
      AND elapsed_time > cpu_time
    ORDER BY (elapsed_time - cpu_time) DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 4. Top SQL by Elapsed Time with High Execution Count
-- ============================================================================

PROMPT
PROMPT [4] HIGH EXECUTION COUNT SQL BY ELAPSED TIME
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(
            elapsed_time / executions / 1000,
            2
        ) AS elapsed_per_exec_ms,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        buffer_gets,
        disk_reads,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
    ORDER BY elapsed_time DESC, executions DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 5. Top SQL by Elapsed Time and Physical Reads
-- ============================================================================

PROMPT
PROMPT [5] SQL WITH HIGH ELAPSED TIME AND PHYSICAL READS
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        buffer_gets,
        disk_reads,
        ROUND(
            CASE
                WHEN executions > 0
                THEN disk_reads / executions
                ELSE 0
            END,
            2
        ) AS disk_reads_per_exec,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
      AND disk_reads > 0
    ORDER BY elapsed_time DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 6. Top SQL by Elapsed Time and Logical Reads
-- ============================================================================

PROMPT
PROMPT [6] SQL WITH HIGH ELAPSED TIME AND LOGICAL READS
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        buffer_gets,
        ROUND(
            CASE
                WHEN executions > 0
                THEN buffer_gets / executions
                ELSE 0
            END,
            2
        ) AS buffer_gets_per_exec,
        disk_reads,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
    ORDER BY elapsed_time DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 7. Active Sessions Running High Elapsed-Time SQL
-- ============================================================================

PROMPT
PROMPT [7] ACTIVE SESSIONS RUNNING HIGH ELAPSED-TIME SQL
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
    s.seconds_in_wait,
    q.executions,
    ROUND(q.elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(q.cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(
        CASE
            WHEN q.executions > 0
            THEN q.elapsed_time / q.executions / 1000
            ELSE 0
        END,
        2
    ) AS elapsed_per_exec_ms,
    s.machine,
    s.program,
    SUBSTR(q.sql_text, 1, 100) AS sql_text
FROM v$session s
JOIN v$sql q
  ON q.sql_id = s.sql_id
 AND q.child_number = s.sql_child_number
WHERE s.status = 'ACTIVE'
  AND s.username IS NOT NULL
ORDER BY q.elapsed_time DESC
FETCH FIRST 20 ROWS ONLY;

-- ============================================================================
-- 8. Top Elapsed Time by Parsing Schema
-- ============================================================================

PROMPT
PROMPT [8] ELAPSED TIME BY PARSING SCHEMA
PROMPT

SELECT
    parsing_schema_name AS parsing_schema,
    COUNT(*) AS sql_count,
    SUM(executions) AS executions,
    ROUND(SUM(elapsed_time) / 1000000, 2) AS elapsed_sec,
    ROUND(SUM(cpu_time) / 1000000, 2) AS cpu_sec,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads
FROM v$sql
WHERE parsing_schema_name IS NOT NULL
GROUP BY parsing_schema_name
ORDER BY SUM(elapsed_time) DESC;

-- ============================================================================
-- 9. Elapsed Time by Module
-- ============================================================================

PROMPT
PROMPT [9] ELAPSED TIME BY MODULE
PROMPT

SELECT
    NVL(module, 'UNKNOWN') AS module,
    COUNT(*) AS sql_count,
    SUM(executions) AS executions,
    ROUND(SUM(elapsed_time) / 1000000, 2) AS elapsed_sec,
    ROUND(SUM(cpu_time) / 1000000, 2) AS cpu_sec,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads
FROM v$sql
GROUP BY NVL(module, 'UNKNOWN')
ORDER BY SUM(elapsed_time) DESC;

-- ============================================================================
-- 10. SQL with High Elapsed Time and Low CPU Percentage
-- ============================================================================

PROMPT
PROMPT [10] SQL WITH HIGH WAIT / NON-CPU TIME
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        plan_hash_value,
        executions,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND(
            CASE
                WHEN elapsed_time > 0
                THEN cpu_time / elapsed_time * 100
                ELSE 0
            END,
            2
        ) AS cpu_pct_elapsed,
        ROUND(
            (elapsed_time - cpu_time) / 1000000,
            2
        ) AS wait_time_sec,
        buffer_gets,
        disk_reads,
        parsing_schema_name AS parsing_schema,
        module,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE executions > 0
      AND elapsed_time > cpu_time
    ORDER BY (elapsed_time - cpu_time) DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 11. SQL with Multiple Child Cursors
-- ============================================================================

PROMPT
PROMPT [11] HIGH ELAPSED SQL WITH MULTIPLE CHILD CURSORS
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        version_count,
        executions,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(
            CASE
                WHEN executions > 0
                THEN elapsed_time / executions / 1000
                ELSE 0
            END,
            2
        ) AS elapsed_per_exec_ms,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        invalidations,
        loads,
        parsing_schema_name AS parsing_schema,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sqlarea
    WHERE executions > 0
      AND version_count > 1
    ORDER BY elapsed_time DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 12. Top Elapsed-Time Wait Events
-- ============================================================================

PROMPT
PROMPT [12] SYSTEM WAIT EVENTS
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
WHERE wait_class <> 'Idle'
ORDER BY time_waited DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ================================================================
PROMPT TOP SQL ELAPSED TIME INVESTIGATION COMPLETE
PROMPT ================================================================
PROMPT
PROMPT DBA CHECKLIST:
PROMPT 1. Identify SQL with the highest total elapsed time.
PROMPT 2. Check elapsed time per execution.
PROMPT 3. Compare CPU time with elapsed time.
PROMPT 4. Investigate SQL with high non-CPU elapsed time.
PROMPT 5. Review wait events for I/O, locks, concurrency and other waits.
PROMPT 6. Check logical and physical I/O for expensive SQL.
PROMPT 7. Review execution plans for high-impact SQL.
PROMPT 8. Check SQL with multiple child cursors.
PROMPT 9. Correlate SQL_ID with active sessions and application modules.
PROMPT
PROMPT Note: V$SQL ELAPSED_TIME and CPU_TIME are cumulative values
PROMPT for the cursor in the shared pool. They are not instantaneous
PROMPT rates. Use before/after snapshots for interval measurements.
PROMPT
PROMPT ================================================================


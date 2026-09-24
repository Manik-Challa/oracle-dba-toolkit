-- ============================================================
-- Oracle DBA Toolkit
-- SQL Execution Statistics
--
-- Purpose:
--   Monitor SQL execution counts and execution efficiency.
--
-- Key metrics:
--   - Executions
--   - Executions per hour (approx.)
--   - Elapsed time
--   - CPU time
--   - Buffer gets
--   - Physical reads
--   - Rows processed
--   - Per-execution statistics
--
-- Notes:
--   V$SQL statistics are cumulative for the cursor lifetime.
--   They are not instantaneous execution rates.
--   For accurate rates, compare snapshots over time.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN sql_id              FORMAT A15
COLUMN parsing_schema_name FORMAT A22
COLUMN module              FORMAT A25
COLUMN executions          FORMAT 999,999,999,999
COLUMN execs_per_hour      FORMAT 999,999,990.00
COLUMN elapsed_sec         FORMAT 999,999,999,990.00
COLUMN elapsed_per_exec    FORMAT 999,999,990.000
COLUMN cpu_sec             FORMAT 999,999,999,990.00
COLUMN cpu_per_exec        FORMAT 999,999,990.000
COLUMN buffer_gets        FORMAT 999,999,999,999
COLUMN gets_per_exec      FORMAT 999,999,990.00
COLUMN disk_reads         FORMAT 999,999,999,999
COLUMN reads_per_exec     FORMAT 999,999,990.00
COLUMN rows_processed     FORMAT 999,999,999,999
COLUMN rows_per_exec      FORMAT 999,999,990.00
COLUMN sql_text            FORMAT A80 WORD_WRAPPED

PROMPT
PROMPT ============================================================
PROMPT 1. TOP SQL BY EXECUTION COUNT
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        sql_id,
        parsing_schema_name,
        executions,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND((elapsed_time / NULLIF(executions, 0)) / 1000000, 3)
            AS elapsed_per_exec,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND((cpu_time / NULLIF(executions, 0)) / 1000000, 3)
            AS cpu_per_exec,
        buffer_gets,
        ROUND(buffer_gets / NULLIF(executions, 0), 2)
            AS gets_per_exec,
        disk_reads,
        ROUND(disk_reads / NULLIF(executions, 0), 2)
            AS reads_per_exec,
        rows_processed,
        ROUND(rows_processed / NULLIF(executions, 0), 2)
            AS rows_per_exec
    FROM v$sql
    WHERE executions > 0
    ORDER BY executions DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 2. EXECUTION FREQUENCY - APPROXIMATE EXECUTIONS PER HOUR
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        sql_id,
        parsing_schema_name,
        executions,
        ROUND(
            executions /
            NULLIF(
                (SYSDATE - TO_DATE(first_load_time, 'YYYY-MM-DD/HH24:MI:SS'))
                * 24,
                0
            ),
            2
        ) AS execs_per_hour,
        first_load_time,
        module
    FROM v$sql
    WHERE executions > 0
      AND first_load_time IS NOT NULL
    ORDER BY execs_per_hour DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 3. HIGH EXECUTIONS + HIGH LOGICAL I/O
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        sql_id,
        parsing_schema_name,
        executions,
        buffer_gets,
        ROUND(buffer_gets / NULLIF(executions, 0), 2)
            AS gets_per_exec,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec
    FROM v$sql
    WHERE executions > 1000
    ORDER BY buffer_gets DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 4. HIGH EXECUTIONS + PHYSICAL READS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        sql_id,
        parsing_schema_name,
        executions,
        disk_reads,
        ROUND(disk_reads / NULLIF(executions, 0), 2)
            AS reads_per_exec,
        buffer_gets,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec
    FROM v$sql
    WHERE executions > 100
    ORDER BY disk_reads DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 5. HIGH EXECUTIONS + CPU CONSUMPTION
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        sql_id,
        parsing_schema_name,
        executions,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND((cpu_time / NULLIF(executions, 0)) / 1000000, 3)
            AS cpu_per_exec,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        buffer_gets
    FROM v$sql
    WHERE executions > 100
    ORDER BY cpu_time DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 6. HIGH EXECUTION COUNT BUT LOW PER-EXECUTION COST
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        sql_id,
        parsing_schema_name,
        executions,
        ROUND(
            (elapsed_time / NULLIF(executions, 0)) / 1000000,
            6
        ) AS elapsed_per_exec,
        ROUND(
            (cpu_time / NULLIF(executions, 0)) / 1000000,
            6
        ) AS cpu_per_exec,
        ROUND(buffer_gets / NULLIF(executions, 0), 2)
            AS gets_per_exec,
        module
    FROM v$sql
    WHERE executions > 10000
    ORDER BY executions DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 7. SQL EXECUTIONS BY PARSING SCHEMA
PROMPT ============================================================

SELECT
    parsing_schema_name,
    COUNT(*) AS sql_count,
    SUM(executions) AS total_executions,
    ROUND(SUM(elapsed_time) / 1000000, 2) AS elapsed_sec,
    ROUND(SUM(cpu_time) / 1000000, 2) AS cpu_sec,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads
FROM v$sql
WHERE executions > 0
GROUP BY parsing_schema_name
ORDER BY total_executions DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. SQL EXECUTIONS BY MODULE
PROMPT ============================================================

SELECT
    NVL(module, '<NULL>') AS module,
    COUNT(*) AS sql_count,
    SUM(executions) AS total_executions,
    ROUND(SUM(elapsed_time) / 1000000, 2) AS elapsed_sec,
    ROUND(SUM(cpu_time) / 1000000, 2) AS cpu_sec,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads
FROM v$sql
WHERE executions > 0
GROUP BY module
ORDER BY total_executions DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. ACTIVE SESSIONS RUNNING FREQUENTLY EXECUTED SQL
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    q.executions,
    ROUND(q.elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(q.cpu_time / 1000000, 2) AS cpu_sec,
    s.event,
    s.wait_class,
    s.machine,
    s.program
FROM v$session s
JOIN v$sql q
    ON q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND q.executions > 0
ORDER BY q.executions DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. SQL WITH MULTIPLE CHILD CURSORS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        sql_id,
        COUNT(*) AS child_count,
        SUM(executions) AS total_executions,
        ROUND(SUM(elapsed_time) / 1000000, 2) AS elapsed_sec,
        ROUND(SUM(cpu_time) / 1000000, 2) AS cpu_sec,
        MIN(parsing_schema_name) AS parsing_schema_name
    FROM v$sql
    GROUP BY sql_id
    HAVING COUNT(*) > 1
    ORDER BY child_count DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 11. EXECUTION STATISTICS WITH SQL TEXT
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        sql_id,
        parsing_schema_name,
        executions,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        ROUND(
            (elapsed_time / NULLIF(executions, 0)) / 1000000,
            3
        ) AS elapsed_per_exec,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND(
            (cpu_time / NULLIF(executions, 0)) / 1000000,
            3
        ) AS cpu_per_exec,
        buffer_gets,
        disk_reads,
        rows_processed,
        sql_text
    FROM v$sql
    WHERE executions > 0
    ORDER BY executions DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 12. EXECUTION STATISTICS SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS sql_count,
    SUM(executions) AS total_executions,
    ROUND(SUM(elapsed_time) / 1000000, 2) AS total_elapsed_sec,
    ROUND(SUM(cpu_time) / 1000000, 2) AS total_cpu_sec,
    SUM(buffer_gets) AS total_buffer_gets,
    SUM(disk_reads) AS total_disk_reads,
    SUM(rows_processed) AS total_rows_processed
FROM v$sql
WHERE executions > 0;


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION NOTES
PROMPT ============================================================
PROMPT
PROMPT 1. High executions alone do not indicate a problem.
PROMPT 2. Check executions together with elapsed time and CPU.
PROMPT 3. Review buffer gets per execution for logical I/O efficiency.
PROMPT 4. Review physical reads per execution for I/O-heavy SQL.
PROMPT 5. High execution count with low per-execution cost may indicate
PROMPT    SQL that is called excessively by the application.
PROMPT 6. Check multiple child cursors when execution/parse activity
PROMPT    appears unexpectedly high.
PROMPT 7. V$SQL counters are cumulative for the cursor lifetime.
PROMPT 8. Use before/after snapshots for accurate execution rates.
PROMPT 9. For historical analysis, consider AWR views when available
PROMPT    and appropriately licensed.
PROMPT
PROMPT ============================================================
PROMPT END OF SQL EXECUTION STATISTICS
PROMPT ============================================================


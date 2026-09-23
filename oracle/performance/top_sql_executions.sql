-- ============================================================
-- Oracle DBA Toolkit
-- Script   : top_sql_executions.sql
-- Purpose  : Identify SQL statements with highest execution
--            frequency and repeatedly executed SQL
-- Author   : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN sql_id             FORMAT A15
COLUMN parsing_schema     FORMAT A20
COLUMN module             FORMAT A25
COLUMN executions         FORMAT 999,999,999,999
COLUMN execs_per_hour     FORMAT 999,999,999.99
COLUMN elapsed_sec        FORMAT 999,999,999.99
COLUMN elapsed_per_exec   FORMAT 999,999,999.99
COLUMN cpu_sec            FORMAT 999,999,999.99
COLUMN cpu_per_exec       FORMAT 999,999,999.99
COLUMN buffer_gets       FORMAT 999,999,999,999
COLUMN gets_per_exec     FORMAT 999,999,999.99
COLUMN disk_reads        FORMAT 999,999,999,999
COLUMN reads_per_exec    FORMAT 999,999,999.99
COLUMN sql_text           FORMAT A100 WORD_WRAPPED

PROMPT
PROMPT ============================================================
PROMPT TOP SQL BY TOTAL EXECUTIONS
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(
        elapsed_time / NULLIF(executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(
        cpu_time / NULLIF(executions, 0) / 1000,
        2
    ) AS cpu_per_exec_ms,
    buffer_gets,
    disk_reads,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
ORDER BY executions DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT TOP SQL BY EXECUTIONS PER HOUR
PROMPT ============================================================
PROMPT Based on SQL cursor elapsed lifetime since FIRST_LOAD_TIME.
PROMPT This is an approximate rate, not a precise workload rate.
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    ROUND(
        executions /
        NULLIF(
            (SYSDATE - first_load_time) * 24,
            0
        ),
        2
    ) AS execs_per_hour,
    ROUND(
        elapsed_time / NULLIF(executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    ROUND(
        cpu_time / NULLIF(executions, 0) / 1000,
        2
    ) AS cpu_per_exec_ms,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
  AND first_load_time IS NOT NULL
ORDER BY execs_per_hour DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT HIGH EXECUTION SQL WITH HIGH BUFFER GETS
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    buffer_gets,
    ROUND(
        buffer_gets / NULLIF(executions, 0),
        2
    ) AS gets_per_exec,
    disk_reads,
    ROUND(
        disk_reads / NULLIF(executions, 0),
        2
    ) AS reads_per_exec,
    ROUND(
        elapsed_time / NULLIF(executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions >= 100
  AND buffer_gets > 0
ORDER BY executions DESC, buffer_gets DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT HIGH EXECUTION SQL WITH PHYSICAL READS
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    disk_reads,
    ROUND(
        disk_reads / NULLIF(executions, 0),
        2
    ) AS reads_per_exec,
    buffer_gets,
    ROUND(
        buffer_gets / NULLIF(executions, 0),
        2
    ) AS gets_per_exec,
    ROUND(
        elapsed_time / NULLIF(executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions >= 100
  AND disk_reads > 0
ORDER BY executions DESC, disk_reads DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT HIGH EXECUTION SQL WITH HIGH CPU
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(
        cpu_time / NULLIF(executions, 0) / 1000,
        2
    ) AS cpu_per_exec_ms,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(
        elapsed_time / NULLIF(executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions >= 100
  AND cpu_time > 0
ORDER BY executions DESC, cpu_time DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH HIGH EXECUTIONS BUT LOW COST PER EXECUTION
PROMPT ============================================================
PROMPT Useful for finding "small but frequently executed" SQL.
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    ROUND(
        elapsed_time / NULLIF(executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    ROUND(
        cpu_time / NULLIF(executions, 0) / 1000,
        2
    ) AS cpu_per_exec_ms,
    ROUND(
        buffer_gets / NULLIF(executions, 0),
        2
    ) AS gets_per_exec,
    ROUND(
        disk_reads / NULLIF(executions, 0),
        2
    ) AS reads_per_exec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions >= 1000
ORDER BY executions DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT EXECUTIONS BY PARSING SCHEMA
PROMPT ============================================================

SELECT
    parsing_schema_name AS parsing_schema,
    COUNT(*) AS sql_count,
    SUM(executions) AS executions,
    ROUND(
        SUM(executions) /
        NULLIF(COUNT(*), 0),
        2
    ) AS avg_exec_per_sql,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads
FROM v$sql
WHERE parsing_schema_name IS NOT NULL
GROUP BY parsing_schema_name
ORDER BY executions DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT EXECUTIONS BY MODULE
PROMPT ============================================================

SELECT
    NVL(module, 'UNKNOWN') AS module,
    COUNT(*) AS sql_count,
    SUM(executions) AS executions,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads,
    ROUND(
        SUM(buffer_gets) /
        NULLIF(SUM(executions), 0),
        2
    ) AS gets_per_exec
FROM v$sql
GROUP BY NVL(module, 'UNKNOWN')
ORDER BY executions DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT ACTIVE SESSIONS RUNNING FREQUENTLY EXECUTED SQL
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.event,
    s.wait_class,
    s.machine,
    s.module,
    q.executions,
    q.buffer_gets,
    q.disk_reads,
    ROUND(
        q.elapsed_time / NULLIF(q.executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    SUBSTR(q.sql_text, 1, 100) AS sql_text
FROM v$session s
JOIN v$sql q
    ON q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
ORDER BY q.executions DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH MULTIPLE CHILD CURSORS
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(*) AS child_cursors,
    SUM(executions) AS executions,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads,
    ROUND(
        SUM(elapsed_time) / 1000000,
        2
    ) AS elapsed_sec,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
GROUP BY sql_id
HAVING COUNT(*) > 1
ORDER BY executions DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT EXECUTION SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS sql_count,
    SUM(executions) AS total_executions,
    SUM(buffer_gets) AS total_buffer_gets,
    SUM(disk_reads) AS total_disk_reads,
    ROUND(
        SUM(buffer_gets) /
        NULLIF(SUM(executions), 0),
        2
    ) AS avg_gets_per_exec,
    ROUND(
        SUM(disk_reads) /
        NULLIF(SUM(executions), 0),
        2
    ) AS avg_reads_per_exec
FROM v$sql
WHERE executions > 0;


PROMPT
PROMPT ============================================================
PROMPT DBA NOTES
PROMPT ============================================================
PROMPT
PROMPT High execution count does not automatically mean bad SQL.
PROMPT
PROMPT Look for SQL that combines:
PROMPT
PROMPT   - Very high EXECUTIONS
PROMPT   - High BUFFER_GETS
PROMPT   - High DISK_READS
PROMPT   - High CPU_TIME
PROMPT   - High ELAPSED_TIME
PROMPT   - High cost per execution
PROMPT
PROMPT A SQL executed millions of times may consume significant
PROMPT database resources even when each individual execution
PROMPT appears inexpensive.
PROMPT
PROMPT Important:
PROMPT V$SQL execution counts are cumulative for the cursor.
PROMPT They are not an instantaneous execution rate.
PROMPT
PROMPT FIRST_LOAD_TIME based execution/hour is approximate because
PROMPT the cursor may have been aged out, reloaded, or reset.
PROMPT
PROMPT For accurate workload rates, compare V$SQL snapshots
PROMPT over a defined time interval or use AWR when licensed.
PROMPT
PROMPT ============================================================


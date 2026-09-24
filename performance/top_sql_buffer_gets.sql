-- ============================================================
-- Oracle DBA Toolkit
-- Script   : top_sql_buffer_gets.sql
-- Purpose  : Identify SQL statements with highest buffer gets
--            (logical I/O)
-- Author   : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN sql_id           FORMAT A15
COLUMN parsing_schema   FORMAT A20
COLUMN module           FORMAT A25
COLUMN executions       FORMAT 999,999,999
COLUMN buffer_gets      FORMAT 999,999,999,999
COLUMN gets_per_exec    FORMAT 999,999,999.99
COLUMN rows_processed   FORMAT 999,999,999,999
COLUMN elapsed_sec      FORMAT 999,999,999.99
COLUMN cpu_sec          FORMAT 999,999,999.99
COLUMN sql_text         FORMAT A100 WORD_WRAPPED

PROMPT
PROMPT ============================================================
PROMPT TOP SQL BY TOTAL BUFFER GETS
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    buffer_gets,
    ROUND(buffer_gets / NULLIF(executions, 0), 2) AS gets_per_exec,
    rows_processed,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
ORDER BY buffer_gets DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT TOP SQL BY BUFFER GETS PER EXECUTION
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    buffer_gets,
    ROUND(buffer_gets / NULLIF(executions, 0), 2) AS gets_per_exec,
    rows_processed,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
  AND buffer_gets > 0
ORDER BY buffer_gets / NULLIF(executions, 0) DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT TOP SQL WITH HIGH BUFFER GETS AND HIGH EXECUTION COUNT
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    buffer_gets,
    ROUND(buffer_gets / NULLIF(executions, 0), 2) AS gets_per_exec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions >= 100
  AND buffer_gets > 0
ORDER BY buffer_gets DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT TOP SQL BY BUFFER GETS PER SECOND OF ELAPSED TIME
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    buffer_gets,
    ROUND(
        buffer_gets /
        NULLIF(elapsed_time / 1000000, 0),
        2
    ) AS gets_per_sec,
    ROUND(buffer_gets / NULLIF(executions, 0), 2) AS gets_per_exec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
  AND elapsed_time > 0
  AND buffer_gets > 0
ORDER BY gets_per_sec DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT TOP SQL BY BUFFER GETS WITH PHYSICAL READS
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    buffer_gets,
    disk_reads,
    ROUND(buffer_gets / NULLIF(executions, 0), 2) AS gets_per_exec,
    ROUND(disk_reads / NULLIF(executions, 0), 2) AS reads_per_exec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
  AND buffer_gets > 0
  AND disk_reads > 0
ORDER BY buffer_gets DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT BUFFER GETS BY PARSING SCHEMA
PROMPT ============================================================

SELECT
    parsing_schema_name AS parsing_schema,
    COUNT(*) AS sql_count,
    SUM(executions) AS executions,
    SUM(buffer_gets) AS buffer_gets,
    ROUND(
        SUM(buffer_gets) /
        NULLIF(SUM(executions), 0),
        2
    ) AS gets_per_exec
FROM v$sql
WHERE parsing_schema_name IS NOT NULL
GROUP BY parsing_schema_name
ORDER BY buffer_gets DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT BUFFER GETS BY MODULE
PROMPT ============================================================

SELECT
    NVL(module, 'UNKNOWN') AS module,
    COUNT(*) AS sql_count,
    SUM(executions) AS executions,
    SUM(buffer_gets) AS buffer_gets,
    ROUND(
        SUM(buffer_gets) /
        NULLIF(SUM(executions), 0),
        2
    ) AS gets_per_exec
FROM v$sql
GROUP BY NVL(module, 'UNKNOWN')
ORDER BY buffer_gets DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT ACTIVE SESSIONS RUNNING HIGH BUFFER-GET SQL
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
    SUBSTR(q.sql_text, 1, 100) AS sql_text
FROM v$session s
JOIN v$sql q
    ON q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
ORDER BY q.buffer_gets DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT BUFFER GETS SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS sql_count,
    SUM(executions) AS executions,
    SUM(buffer_gets) AS total_buffer_gets,
    ROUND(
        SUM(buffer_gets) /
        NULLIF(SUM(executions), 0),
        2
    ) AS avg_gets_per_exec
FROM v$sql
WHERE executions > 0;


PROMPT
PROMPT ============================================================
PROMPT DBA NOTES
PROMPT ============================================================
PROMPT
PROMPT Buffer Gets = Logical I/O.
PROMPT High buffer gets can indicate:
PROMPT   - Full table/index scans
PROMPT   - Inefficient execution plans
PROMPT   - Missing or ineffective indexes
PROMPT   - Excessive SQL executions
PROMPT   - Poor join methods
PROMPT   - Large result processing
PROMPT
PROMPT Important:
PROMPT V$SQL buffer_gets values are cumulative for the cursor.
PROMPT They are NOT instantaneous IOPS or a time-based rate.
PROMPT For rate analysis, compare snapshots over a time interval.
PROMPT
PROMPT ============================================================


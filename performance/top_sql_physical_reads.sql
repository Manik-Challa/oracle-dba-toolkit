-- ============================================================
-- Oracle DBA Toolkit
-- Script   : top_sql_physical_reads.sql
-- Purpose  : Identify SQL statements with highest physical reads
--            and disk I/O activity
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
COLUMN executions         FORMAT 999,999,999
COLUMN disk_reads         FORMAT 999,999,999,999
COLUMN reads_per_exec     FORMAT 999,999,999.99
COLUMN buffer_gets        FORMAT 999,999,999,999
COLUMN elapsed_sec        FORMAT 999,999,999.99
COLUMN cpu_sec            FORMAT 999,999,999.99
COLUMN sql_text            FORMAT A100 WORD_WRAPPED

PROMPT
PROMPT ============================================================
PROMPT TOP SQL BY TOTAL PHYSICAL READS
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    disk_reads,
    buffer_gets,
    ROUND(disk_reads / NULLIF(executions, 0), 2) AS reads_per_exec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
  AND disk_reads > 0
ORDER BY disk_reads DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT TOP SQL BY PHYSICAL READS PER EXECUTION
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    disk_reads,
    ROUND(disk_reads / NULLIF(executions, 0), 2) AS reads_per_exec,
    buffer_gets,
    ROUND(buffer_gets / NULLIF(executions, 0), 2) AS gets_per_exec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
  AND disk_reads > 0
ORDER BY disk_reads / NULLIF(executions, 0) DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT TOP SQL WITH HIGH PHYSICAL READS AND HIGH EXECUTION COUNT
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    disk_reads,
    ROUND(disk_reads / NULLIF(executions, 0), 2) AS reads_per_exec,
    buffer_gets,
    ROUND(buffer_gets / NULLIF(executions, 0), 2) AS gets_per_exec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions >= 100
  AND disk_reads > 0
ORDER BY disk_reads DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT TOP SQL BY PHYSICAL READS PER SECOND
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    disk_reads,
    ROUND(
        disk_reads /
        NULLIF(elapsed_time / 1000000, 0),
        2
    ) AS reads_per_sec,
    ROUND(
        disk_reads /
        NULLIF(executions, 0),
        2
    ) AS reads_per_exec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
  AND disk_reads > 0
  AND elapsed_time > 0
ORDER BY reads_per_sec DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH HIGH PHYSICAL READS AND HIGH LOGICAL I/O
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    disk_reads,
    buffer_gets,
    ROUND(
        disk_reads / NULLIF(buffer_gets, 0) * 100,
        2
    ) AS physical_read_pct,
    ROUND(
        disk_reads / NULLIF(executions, 0),
        2
    ) AS reads_per_exec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
  AND disk_reads > 0
  AND buffer_gets > 0
ORDER BY disk_reads DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT TOP SQL BY PHYSICAL READS AND CPU
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    disk_reads,
    buffer_gets,
    ROUND(disk_reads / NULLIF(executions, 0), 2) AS reads_per_exec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
  AND disk_reads > 0
ORDER BY disk_reads DESC, cpu_time DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT PHYSICAL READS BY PARSING SCHEMA
PROMPT ============================================================

SELECT
    parsing_schema_name AS parsing_schema,
    COUNT(*) AS sql_count,
    SUM(executions) AS executions,
    SUM(disk_reads) AS disk_reads,
    SUM(buffer_gets) AS buffer_gets,
    ROUND(
        SUM(disk_reads) /
        NULLIF(SUM(executions), 0),
        2
    ) AS reads_per_exec
FROM v$sql
WHERE parsing_schema_name IS NOT NULL
GROUP BY parsing_schema_name
ORDER BY disk_reads DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT PHYSICAL READS BY MODULE
PROMPT ============================================================

SELECT
    NVL(module, 'UNKNOWN') AS module,
    COUNT(*) AS sql_count,
    SUM(executions) AS executions,
    SUM(disk_reads) AS disk_reads,
    SUM(buffer_gets) AS buffer_gets,
    ROUND(
        SUM(disk_reads) /
        NULLIF(SUM(executions), 0),
        2
    ) AS reads_per_exec
FROM v$sql
GROUP BY NVL(module, 'UNKNOWN')
ORDER BY disk_reads DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT ACTIVE SESSIONS RUNNING SQL WITH PHYSICAL READS
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
    q.disk_reads,
    q.buffer_gets,
    ROUND(
        q.disk_reads / NULLIF(q.executions, 0),
        2
    ) AS reads_per_exec,
    SUBSTR(q.sql_text, 1, 100) AS sql_text
FROM v$session s
JOIN v$sql q
    ON q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND q.disk_reads > 0
ORDER BY q.disk_reads DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT PHYSICAL READS SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS sql_count,
    SUM(executions) AS executions,
    SUM(disk_reads) AS total_disk_reads,
    SUM(buffer_gets) AS total_buffer_gets,
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
PROMPT Disk Reads = Physical reads associated with the SQL cursor.
PROMPT High physical reads may indicate:
PROMPT   - Large table or index scans
PROMPT   - Poor execution plans
PROMPT   - Inefficient joins
PROMPT   - Insufficient caching
PROMPT   - High-volume reporting queries
PROMPT   - Repeated execution of I/O-intensive SQL
PROMPT
PROMPT Check these together:
PROMPT   DISK_READS
PROMPT   BUFFER_GETS
PROMPT   EXECUTIONS
PROMPT   READS_PER_EXEC
PROMPT   ELAPSED_TIME
PROMPT   CPU_TIME
PROMPT
PROMPT Important:
PROMPT V$SQL DISK_READS is cumulative for the cursor lifetime.
PROMPT It is NOT an instantaneous disk I/O rate.
PROMPT For rate analysis, compare snapshots over time.
PROMPT
PROMPT ============================================================

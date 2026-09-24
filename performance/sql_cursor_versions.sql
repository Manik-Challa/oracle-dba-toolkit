-- ============================================================
-- Oracle DBA Toolkit
-- Script   : sql_cursor_versions.sql
-- Purpose  : Identify SQL statements with multiple child
--            cursors and investigate cursor proliferation
-- Author   : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN sql_id                 FORMAT A15
COLUMN parsing_schema         FORMAT A20
COLUMN module                 FORMAT A25
COLUMN child_number           FORMAT 99999
COLUMN plan_hash_value        FORMAT 999999999999
COLUMN executions             FORMAT 999,999,999,999
COLUMN child_cursors          FORMAT 999,999
COLUMN buffer_gets            FORMAT 999,999,999,999
COLUMN disk_reads             FORMAT 999,999,999,999
COLUMN elapsed_sec            FORMAT 999,999,999.99
COLUMN cpu_sec                FORMAT 999,999,999.99
COLUMN sql_text               FORMAT A100 WORD_WRAPPED


PROMPT
PROMPT ============================================================
PROMPT SQL WITH MULTIPLE CHILD CURSORS
PROMPT ============================================================
PROMPT Identifies SQL_IDs with more than one child cursor.
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(*) AS child_cursors,
    COUNT(DISTINCT plan_hash_value) AS plan_count,
    SUM(executions) AS executions,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads,
    ROUND(SUM(elapsed_time) / 1000000, 2) AS elapsed_sec,
    ROUND(SUM(cpu_time) / 1000000, 2) AS cpu_sec,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
GROUP BY sql_id
HAVING COUNT(*) > 1
ORDER BY child_cursors DESC, executions DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH HIGH CHILD CURSOR COUNT
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(*) AS child_cursors,
    COUNT(DISTINCT plan_hash_value) AS plan_count,
    SUM(executions) AS executions,
    ROUND(
        SUM(elapsed_time) / 1000000,
        2
    ) AS elapsed_sec,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
GROUP BY sql_id
HAVING COUNT(*) >= 5
ORDER BY child_cursors DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT CHILD CURSOR DETAILS
PROMPT ============================================================

SELECT
    sql_id,
    child_number,
    plan_hash_value,
    parsing_schema_name AS parsing_schema,
    executions,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(
        elapsed_time /
        NULLIF(executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    buffer_gets,
    disk_reads,
    first_load_time,
    last_load_time,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE sql_id IN
(
    SELECT sql_id
    FROM v$sql
    GROUP BY sql_id
    HAVING COUNT(*) > 1
)
ORDER BY sql_id, child_number;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH MULTIPLE CHILD CURSORS AND MULTIPLE PLANS
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(*) AS child_cursors,
    COUNT(DISTINCT plan_hash_value) AS plan_count,
    SUM(executions) AS executions,
    ROUND(
        SUM(elapsed_time) /
        NULLIF(SUM(executions), 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    ROUND(
        SUM(buffer_gets) /
        NULLIF(SUM(executions), 0),
        2
    ) AS gets_per_exec,
    ROUND(
        SUM(disk_reads) /
        NULLIF(SUM(executions), 0),
        2
    ) AS reads_per_exec,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
GROUP BY sql_id
HAVING COUNT(*) > 1
   AND COUNT(DISTINCT plan_hash_value) > 1
ORDER BY child_cursors DESC, executions DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT CHILD CURSORS WITH HIGH EXECUTION COUNTS
PROMPT ============================================================

SELECT
    sql_id,
    child_number,
    plan_hash_value,
    executions,
    ROUND(
        elapsed_time /
        NULLIF(executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    ROUND(
        cpu_time /
        NULLIF(executions, 0) / 1000,
        2
    ) AS cpu_per_exec_ms,
    ROUND(
        buffer_gets /
        NULLIF(executions, 0),
        2
    ) AS gets_per_exec,
    ROUND(
        disk_reads /
        NULLIF(executions, 0),
        2
    ) AS reads_per_exec,
    plan_hash_value,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 1000
ORDER BY executions DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT CHILD CURSOR VERSION SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS total_child_cursors,
    COUNT(DISTINCT sql_id) AS sql_with_children,
    COUNT(DISTINCT plan_hash_value) AS distinct_plans,
    SUM(executions) AS total_executions,
    SUM(buffer_gets) AS total_buffer_gets,
    SUM(disk_reads) AS total_disk_reads
FROM v$sql;


PROMPT
PROMPT ============================================================
PROMPT CHILD CURSOR DISTRIBUTION BY SQL_ID
PROMPT ============================================================

SELECT
    child_cursor_count,
    COUNT(*) AS sql_count
FROM
(
    SELECT
        sql_id,
        COUNT(*) AS child_cursor_count
    FROM v$sql
    GROUP BY sql_id
)
GROUP BY child_cursor_count
ORDER BY child_cursor_count DESC;


PROMPT
PROMPT ============================================================
PROMPT HIGH CHILD CURSOR SQL BY PARSING SCHEMA
PROMPT ============================================================

SELECT
    parsing_schema_name AS parsing_schema,
    COUNT(DISTINCT sql_id) AS sql_count,
    COUNT(*) AS child_cursors,
    SUM(executions) AS executions,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads
FROM v$sql
WHERE parsing_schema_name IS NOT NULL
GROUP BY parsing_schema_name
ORDER BY child_cursors DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT HIGH CHILD CURSOR SQL BY MODULE
PROMPT ============================================================

SELECT
    NVL(module, 'UNKNOWN') AS module,
    COUNT(DISTINCT sql_id) AS sql_count,
    COUNT(*) AS child_cursors,
    SUM(executions) AS executions,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads
FROM v$sql
GROUP BY NVL(module, 'UNKNOWN')
ORDER BY child_cursors DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT CHILD CURSORS WITH DIFFERENT PLAN HASH VALUES
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(*) AS child_cursors,
    COUNT(DISTINCT plan_hash_value) AS plan_count,
    MIN(plan_hash_value) AS first_plan_hash,
    MAX(plan_hash_value) AS last_plan_hash,
    SUM(executions) AS executions,
    ROUND(
        SUM(elapsed_time) / NULLIF(SUM(executions), 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
GROUP BY sql_id
HAVING COUNT(*) > 1
   AND COUNT(DISTINCT plan_hash_value) > 1
ORDER BY child_cursors DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT CURSOR VERSION INVESTIGATION
PROMPT ============================================================
PROMPT
PROMPT Common causes of multiple child cursors include:
PROMPT
PROMPT   - Different optimizer environments
PROMPT   - Bind variable related differences
PROMPT   - Different NLS settings
PROMPT   - Different schema/object environments
PROMPT   - Authorization differences
PROMPT   - Different optimizer settings
PROMPT   - Bind mismatch / datatype mismatch
PROMPT   - Cursor sharing related conditions
PROMPT
PROMPT ============================================================
PROMPT
PROMPT Useful Oracle views:
PROMPT
PROMPT   V$SQL
PROMPT   V$SQL_SHARED_CURSOR
PROMPT   V$SQLAREA
PROMPT   V$SESSION
PROMPT
PROMPT V$SQL_SHARED_CURSOR can be used to investigate the
PROMPT specific reason Oracle created additional child cursors.
PROMPT
PROMPT ============================================================
PROMPT DBA NOTES
PROMPT ============================================================
PROMPT
PROMPT Multiple child cursors are NOT automatically a problem.
PROMPT
PROMPT Investigate when high child cursor counts are combined with:
PROMPT
PROMPT   - High parse activity
PROMPT   - High CPU
PROMPT   - Shared pool pressure
PROMPT   - Excessive memory usage
PROMPT   - Many executions
PROMPT   - Different execution plans
PROMPT
PROMPT V$SQL contains information currently available in the
PROMPT shared pool. Entries can disappear after aging or restart.
PROMPT
PROMPT ============================================================


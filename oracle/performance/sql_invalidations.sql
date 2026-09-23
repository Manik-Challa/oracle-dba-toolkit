-- ============================================================
-- Oracle DBA Toolkit
-- Script   : sql_invalidations.sql
-- Purpose  : Monitor SQL invalidations, reloads, and cursor
--            activity that may contribute to repeated parsing
-- Author   : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN sql_id               FORMAT A15
COLUMN parsing_schema       FORMAT A20
COLUMN module               FORMAT A25
COLUMN plan_hash_value      FORMAT 999999999999
COLUMN executions           FORMAT 999,999,999,999
COLUMN invalidations        FORMAT 999,999,999
COLUMN loads                FORMAT 999,999,999
COLUMN loads_per_exec       FORMAT 999,999,999.99
COLUMN invalid_per_exec     FORMAT 999,999,999.99
COLUMN elapsed_sec          FORMAT 999,999,999.99
COLUMN cpu_sec              FORMAT 999,999,999.99
COLUMN first_load_time      FORMAT A20
COLUMN last_load_time       FORMAT A20
COLUMN sql_text             FORMAT A100 WORD_WRAPPED


PROMPT
PROMPT ============================================================
PROMPT SQL WITH INVALIDATIONS
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    plan_hash_value,
    executions,
    invalidations,
    loads,
    ROUND(
        invalidations /
        NULLIF(executions, 0),
        4
    ) AS invalid_per_exec,
    ROUND(
        loads /
        NULLIF(executions, 0),
        4
    ) AS loads_per_exec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    first_load_time,
    last_load_time,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE invalidations > 0
ORDER BY invalidations DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT TOP SQL BY INVALIDATION COUNT
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(*) AS child_cursors,
    SUM(invalidations) AS invalidations,
    SUM(loads) AS loads,
    SUM(executions) AS executions,
    ROUND(
        SUM(invalidations) /
        NULLIF(SUM(executions), 0),
        4
    ) AS invalid_per_exec,
    ROUND(
        SUM(elapsed_time) / 1000000,
        2
    ) AS elapsed_sec,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
GROUP BY sql_id
HAVING SUM(invalidations) > 0
ORDER BY invalidations DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH HIGH INVALIDATIONS AND HIGH EXECUTIONS
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(*) AS child_cursors,
    SUM(executions) AS executions,
    SUM(invalidations) AS invalidations,
    SUM(loads) AS loads,
    ROUND(
        SUM(invalidations) /
        NULLIF(SUM(executions), 0),
        4
    ) AS invalid_per_exec,
    ROUND(
        SUM(loads) /
        NULLIF(SUM(executions), 0),
        4
    ) AS loads_per_exec,
    ROUND(
        SUM(elapsed_time) / 1000000,
        2
    ) AS elapsed_sec,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
GROUP BY sql_id
HAVING SUM(invalidations) > 0
   AND SUM(executions) > 100
ORDER BY invalidations DESC, executions DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH HIGH LOADS
PROMPT ============================================================
PROMPT High LOADS can indicate cursor reload activity.
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    plan_hash_value,
    executions,
    loads,
    invalidations,
    ROUND(
        loads /
        NULLIF(executions, 0),
        4
    ) AS loads_per_exec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    first_load_time,
    last_load_time,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE loads > 0
ORDER BY loads DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH HIGH LOADS PER EXECUTION
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name AS parsing_schema,
    executions,
    loads,
    invalidations,
    ROUND(
        loads /
        NULLIF(executions, 0),
        4
    ) AS loads_per_exec,
    ROUND(
        invalidations /
        NULLIF(executions, 0),
        4
    ) AS invalid_per_exec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
  AND loads > 0
ORDER BY loads / NULLIF(executions, 0) DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT INVALIDATIONS BY PARSING SCHEMA
PROMPT ============================================================

SELECT
    parsing_schema_name AS parsing_schema,
    COUNT(DISTINCT sql_id) AS sql_count,
    SUM(invalidations) AS invalidations,
    SUM(loads) AS loads,
    SUM(executions) AS executions,
    ROUND(
        SUM(invalidations) /
        NULLIF(SUM(executions), 0),
        4
    ) AS invalid_per_exec
FROM v$sql
WHERE parsing_schema_name IS NOT NULL
GROUP BY parsing_schema_name
ORDER BY invalidations DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT INVALIDATIONS BY MODULE
PROMPT ============================================================

SELECT
    NVL(module, 'UNKNOWN') AS module,
    COUNT(DISTINCT sql_id) AS sql_count,
    SUM(invalidations) AS invalidations,
    SUM(loads) AS loads,
    SUM(executions) AS executions,
    ROUND(
        SUM(invalidations) /
        NULLIF(SUM(executions), 0),
        4
    ) AS invalid_per_exec
FROM v$sql
GROUP BY NVL(module, 'UNKNOWN')
ORDER BY invalidations DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT INVALIDATED SQL WITH MULTIPLE CHILD CURSORS
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(*) AS child_cursors,
    COUNT(DISTINCT plan_hash_value) AS plan_count,
    SUM(invalidations) AS invalidations,
    SUM(loads) AS loads,
    SUM(executions) AS executions,
    ROUND(
        SUM(elapsed_time) /
        NULLIF(SUM(executions), 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
GROUP BY sql_id
HAVING SUM(invalidations) > 0
   AND COUNT(*) > 1
ORDER BY invalidations DESC, child_cursors DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT INVALIDATED SQL WITH MULTIPLE PLANS
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(DISTINCT plan_hash_value) AS plan_count,
    SUM(invalidations) AS invalidations,
    SUM(loads) AS loads,
    SUM(executions) AS executions,
    ROUND(
        SUM(elapsed_time) /
        NULLIF(SUM(executions), 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
GROUP BY sql_id
HAVING SUM(invalidations) > 0
   AND COUNT(DISTINCT plan_hash_value) > 1
ORDER BY invalidations DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT INVALIDATED SQL - CURRENTLY ACTIVE
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    q.plan_hash_value,
    q.executions,
    q.invalidations,
    q.loads,
    ROUND(
        q.elapsed_time /
        NULLIF(q.executions, 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
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
  AND q.invalidations > 0
ORDER BY q.invalidations DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT INVALIDATION / LOAD SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS sql_cursors,
    COUNT(DISTINCT sql_id) AS sql_count,
    SUM(executions) AS executions,
    SUM(invalidations) AS invalidations,
    SUM(loads) AS loads,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads
FROM v$sql;


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT When SQL invalidations are high:
PROMPT
PROMPT 1. Identify the SQL_ID.
PROMPT 2. Check INVALIDATIONS and LOADS.
PROMPT 3. Check child cursor count.
PROMPT 4. Check for multiple PLAN_HASH_VALUE values.
PROMPT 5. Check recent object/statistics changes.
PROMPT 6. Check DDL activity affecting referenced objects.
PROMPT 7. Check optimizer statistics activity.
PROMPT 8. Check shared pool pressure and cursor aging.
PROMPT 9. Review V$SQL_SHARED_CURSOR.
PROMPT 10. Review historical information when available.
PROMPT
PROMPT ============================================================
PROMPT COMMON INVALIDATION SOURCES
PROMPT ============================================================
PROMPT
PROMPT SQL cursors can become invalid because of events such as:
PROMPT
PROMPT   - Object DDL changes
PROMPT   - Object dependency changes
PROMPT   - Statistics changes
PROMPT   - Privilege changes
PROMPT   - Synonym changes
PROMPT   - Environment/optimizer changes
PROMPT   - Explicit cursor invalidation
PROMPT
PROMPT ============================================================
PROMPT DBA NOTES
PROMPT ============================================================
PROMPT
PROMPT INVALIDATIONS and LOADS are cumulative statistics associated
PROMPT with the cursor information available in V$SQL.
PROMPT
PROMPT A non-zero INVALIDATIONS value does not automatically mean
PROMPT there is a performance problem.
PROMPT
PROMPT Investigate when invalidations are combined with:
PROMPT
PROMPT   - High parse activity
PROMPT   - High CPU
PROMPT   - High execution frequency
PROMPT   - Many child cursors
PROMPT   - Frequent plan changes
PROMPT   - Shared pool pressure
PROMPT
PROMPT V$SQL contains current shared-pool information and can change
PROMPT as cursors are aged out or the instance is restarted.
PROMPT
PROMPT ============================================================


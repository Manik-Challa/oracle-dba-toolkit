-- ============================================================
-- Oracle DBA Toolkit
-- Script   : sql_plan_changes.sql
-- Purpose  : Identify SQL statements with plan changes,
--            multiple plans, and potential plan instability
-- Author   : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN sql_id             FORMAT A15
COLUMN plan_hash_value    FORMAT 999999999999
COLUMN parsing_schema     FORMAT A20
COLUMN module             FORMAT A25
COLUMN executions         FORMAT 999,999,999,999
COLUMN elapsed_sec        FORMAT 999,999,999.99
COLUMN cpu_sec            FORMAT 999,999,999.99
COLUMN buffer_gets        FORMAT 999,999,999,999
COLUMN disk_reads         FORMAT 999,999,999,999
COLUMN first_load_time    FORMAT A20
COLUMN last_load_time     FORMAT A20
COLUMN sql_text           FORMAT A100 WORD_WRAPPED


PROMPT
PROMPT ============================================================
PROMPT SQL STATEMENTS WITH MULTIPLE PLAN HASH VALUES
PROMPT ============================================================
PROMPT Multiple plan hash values can indicate plan instability.
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(DISTINCT plan_hash_value) AS plan_count,
    SUM(executions) AS executions,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads,
    ROUND(SUM(elapsed_time) / 1000000, 2) AS elapsed_sec,
    ROUND(SUM(cpu_time) / 1000000, 2) AS cpu_sec,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
WHERE sql_id IS NOT NULL
GROUP BY sql_id
HAVING COUNT(DISTINCT plan_hash_value) > 1
ORDER BY elapsed_sec DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT PLAN HASH VALUES BY SQL_ID
PROMPT ============================================================

SELECT
    sql_id,
    plan_hash_value,
    COUNT(*) AS child_cursors,
    SUM(executions) AS executions,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads,
    ROUND(SUM(elapsed_time) / 1000000, 2) AS elapsed_sec,
    ROUND(SUM(cpu_time) / 1000000, 2) AS cpu_sec,
    MIN(first_load_time) AS first_load_time,
    MAX(last_load_time) AS last_load_time,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
WHERE sql_id IS NOT NULL
GROUP BY
    sql_id,
    plan_hash_value
HAVING COUNT(*) > 0
ORDER BY sql_id, elapsed_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH MULTIPLE CHILD CURSORS
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(*) AS child_cursors,
    COUNT(DISTINCT plan_hash_value) AS plan_count,
    SUM(executions) AS executions,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads,
    ROUND(SUM(elapsed_time) / 1000000, 2) AS elapsed_sec,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
GROUP BY sql_id
HAVING COUNT(*) > 1
ORDER BY child_cursors DESC, executions DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT PLAN PERFORMANCE COMPARISON
PROMPT ============================================================
PROMPT Compare elapsed time and logical/physical I/O by plan.
PROMPT ============================================================

SELECT
    sql_id,
    plan_hash_value,
    SUM(executions) AS executions,

    ROUND(
        SUM(elapsed_time) / 1000000,
        2
    ) AS elapsed_sec,

    ROUND(
        SUM(elapsed_time) /
        NULLIF(SUM(executions), 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,

    ROUND(
        SUM(cpu_time) / 1000000,
        2
    ) AS cpu_sec,

    ROUND(
        SUM(cpu_time) /
        NULLIF(SUM(executions), 0) / 1000,
        2
    ) AS cpu_per_exec_ms,

    SUM(buffer_gets) AS buffer_gets,

    ROUND(
        SUM(buffer_gets) /
        NULLIF(SUM(executions), 0),
        2
    ) AS gets_per_exec,

    SUM(disk_reads) AS disk_reads,

    ROUND(
        SUM(disk_reads) /
        NULLIF(SUM(executions), 0),
        2
    ) AS reads_per_exec

FROM v$sql
WHERE executions > 0
GROUP BY
    sql_id,
    plan_hash_value
HAVING COUNT(*) > 0
ORDER BY sql_id, elapsed_per_exec_ms DESC;


PROMPT
PROMPT ============================================================
PROMPT SQL WITH SIGNIFICANT PLAN PERFORMANCE DIFFERENCES
PROMPT ============================================================
PROMPT Shows SQL where different plans have substantially
PROMPT different elapsed time per execution.
PROMPT ============================================================

SELECT
    sql_id,
    plan_hash_value,
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

    ROUND(
        SUM(cpu_time) /
        NULLIF(SUM(executions), 0) / 1000,
        2
    ) AS cpu_per_exec_ms,

    MIN(first_load_time) AS first_load_time,
    MAX(last_load_time) AS last_load_time,

    SUBSTR(MAX(sql_text), 1, 100) AS sql_text

FROM v$sql
WHERE executions > 0
GROUP BY
    sql_id,
    plan_hash_value
ORDER BY elapsed_per_exec_ms DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT RECENTLY LOADED SQL WITH PLAN HASH
PROMPT ============================================================

SELECT
    sql_id,
    plan_hash_value,
    parsing_schema_name AS parsing_schema,
    executions,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    buffer_gets,
    disk_reads,
    first_load_time,
    last_load_time,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE first_load_time IS NOT NULL
ORDER BY first_load_time DESC
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
PROMPT SQL WITH HIGH EXECUTIONS AND MULTIPLE PLANS
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(DISTINCT plan_hash_value) AS plan_count,
    SUM(executions) AS executions,
    ROUND(
        SUM(elapsed_time) / NULLIF(SUM(executions), 0) / 1000,
        2
    ) AS elapsed_per_exec_ms,
    ROUND(
        SUM(cpu_time) / NULLIF(SUM(executions), 0) / 1000,
        2
    ) AS cpu_per_exec_ms,
    ROUND(
        SUM(buffer_gets) / NULLIF(SUM(executions), 0),
        2
    ) AS gets_per_exec,
    SUBSTR(MAX(sql_text), 1, 100) AS sql_text
FROM v$sql
WHERE executions >= 100
GROUP BY sql_id
HAVING COUNT(DISTINCT plan_hash_value) > 1
ORDER BY executions DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT PLAN CHANGES - ACTIVE SQL
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    q.plan_hash_value,
    q.executions,
    ROUND(q.elapsed_time / 1000000, 2) AS elapsed_sec,
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
ORDER BY q.elapsed_time DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT SQL PLAN CHANGE INVESTIGATION CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT When a SQL becomes slower:
PROMPT
PROMPT 1. Check SQL_ID.
PROMPT 2. Check PLAN_HASH_VALUE.
PROMPT 3. Check for multiple child cursors.
PROMPT 4. Compare elapsed time per execution.
PROMPT 5. Compare buffer gets per execution.
PROMPT 6. Compare physical reads per execution.
PROMPT 7. Check CPU time per execution.
PROMPT 8. Check optimizer/environment differences.
PROMPT 9. Review statistics and object changes.
PROMPT 10. Compare historical plans when available.
PROMPT
PROMPT Useful sources for historical plan analysis:
PROMPT   - DBA_HIST_SQLSTAT
PROMPT   - DBA_HIST_SQL_PLAN
PROMPT   - DBA_HIST_SNAPSHOT
PROMPT
PROMPT ============================================================
PROMPT DBA NOTES
PROMPT ============================================================
PROMPT
PROMPT PLAN_HASH_VALUE identifies an execution plan shape.
PROMPT
PROMPT A SQL_ID can have multiple PLAN_HASH_VALUE values.
PROMPT This may indicate:
PROMPT   - Different optimizer plans
PROMPT   - Different child cursors
PROMPT   - Different optimizer environments
PROMPT   - Bind-related behavior
PROMPT   - Object/statistics changes
PROMPT
PROMPT Multiple plans are not automatically a problem.
PROMPT Investigate whether the plans have materially different
PROMPT performance before taking corrective action.
PROMPT
PROMPT V$SQL contains current shared-pool information.
PROMPT Historical plan information may require AWR and the
PROMPT appropriate Diagnostics Pack licensing.
PROMPT
PROMPT ============================================================


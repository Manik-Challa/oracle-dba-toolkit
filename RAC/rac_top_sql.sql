-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_top_sql.sql
-- Purpose: Identify top SQL across Oracle RAC instances
-- Scope  : CPU, elapsed time, logical I/O, physical I/O,
--          executions, active SQL, waits and RAC distribution
--
-- IMPORTANT:
-- V$SQL statistics are cumulative for the cursor lifetime.
-- For true rates, collect multiple samples and calculate deltas.
--
-- This script is READ-ONLY.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name       FORMAT A18
COLUMN host_name           FORMAT A30
COLUMN sql_id              FORMAT A15
COLUMN plan_hash_value     FORMAT 999999999999999
COLUMN parsing_schema_name FORMAT A25
COLUMN module              FORMAT A30
COLUMN service_name        FORMAT A35
COLUMN event               FORMAT A65
COLUMN wait_class          FORMAT A20
COLUMN username            FORMAT A25
COLUMN machine             FORMAT A35
COLUMN program             FORMAT A40
COLUMN sql_text            FORMAT A100 WORD_WRAP

PROMPT
PROMPT ============================================================
PROMPT 1. RAC INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    inst_id,
    instance_number,
    instance_name,
    host_name,
    status,
    database_status,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 2. TOP SQL BY CPU TIME
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_seconds,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_seconds,
    ROUND(
        cpu_time /
        NULLIF(executions, 0) / 1000000,
        4
    ) AS cpu_sec_per_exec,
    buffer_gets,
    disk_reads,
    parsing_schema_name,
    module
FROM gv$sql
WHERE executions > 0
ORDER BY cpu_time DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 3. TOP SQL BY ELAPSED TIME
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_seconds,
    ROUND(
        elapsed_time /
        NULLIF(executions, 0) / 1000000,
        4
    ) AS elapsed_sec_per_exec,
    ROUND(cpu_time / 1000000, 2) AS cpu_seconds,
    buffer_gets,
    disk_reads,
    parsing_schema_name,
    module
FROM gv$sql
WHERE executions > 0
ORDER BY elapsed_time DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 4. TOP SQL BY BUFFER GETS
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    buffer_gets,
    ROUND(
        buffer_gets /
        NULLIF(executions, 0),
        2
    ) AS buffer_gets_per_exec,
    disk_reads,
    ROUND(cpu_time / 1000000, 2) AS cpu_seconds,
    parsing_schema_name,
    module
FROM gv$sql
WHERE executions > 0
ORDER BY buffer_gets DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 5. TOP SQL BY PHYSICAL READS
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    disk_reads,
    ROUND(
        disk_reads /
        NULLIF(executions, 0),
        2
    ) AS disk_reads_per_exec,
    buffer_gets,
    ROUND(cpu_time / 1000000, 2) AS cpu_seconds,
    parsing_schema_name,
    module
FROM gv$sql
WHERE executions > 0
ORDER BY disk_reads DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 6. TOP SQL BY EXECUTION COUNT
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    ROUND(
        elapsed_time / 1000000,
        2
    ) AS elapsed_seconds,
    ROUND(
        cpu_time / 1000000,
        2
    ) AS cpu_seconds,
    buffer_gets,
    disk_reads,
    parsing_schema_name,
    module
FROM gv$sql
WHERE executions > 0
ORDER BY executions DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 7. TOP SQL BY CPU PER EXECUTION
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    ROUND(
        cpu_time /
        NULLIF(executions, 0) / 1000000,
        4
    ) AS cpu_sec_per_exec,
    ROUND(
        elapsed_time /
        NULLIF(executions, 0) / 1000000,
        4
    ) AS elapsed_sec_per_exec,
    buffer_gets,
    disk_reads,
    parsing_schema_name,
    module
FROM gv$sql
WHERE executions > 0
ORDER BY
    cpu_time /
    NULLIF(executions, 0) DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 8. TOP SQL BY ELAPSED TIME PER EXECUTION
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    ROUND(
        elapsed_time /
        NULLIF(executions, 0) / 1000000,
        4
    ) AS elapsed_sec_per_exec,
    ROUND(
        cpu_time /
        NULLIF(executions, 0) / 1000000,
        4
    ) AS cpu_sec_per_exec,
    buffer_gets,
    disk_reads,
    parsing_schema_name,
    module
FROM gv$sql
WHERE executions > 0
ORDER BY
    elapsed_time /
    NULLIF(executions, 0) DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 9. TOP SQL BY PHYSICAL READS PER EXECUTION
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    disk_reads,
    ROUND(
        disk_reads /
        NULLIF(executions, 0),
        2
    ) AS disk_reads_per_exec,
    ROUND(
        buffer_gets /
        NULLIF(executions, 0),
        2
    ) AS buffer_gets_per_exec,
    parsing_schema_name,
    module
FROM gv$sql
WHERE executions > 0
ORDER BY
    disk_reads /
    NULLIF(executions, 0) DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 10. TOP SQL BY LOGICAL I/O PER EXECUTION
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    buffer_gets,
    ROUND(
        buffer_gets /
        NULLIF(executions, 0),
        2
    ) AS buffer_gets_per_exec,
    disk_reads,
    ROUND(cpu_time / 1000000, 2) AS cpu_seconds,
    parsing_schema_name,
    module
FROM gv$sql
WHERE executions > 0
ORDER BY
    buffer_gets /
    NULLIF(executions, 0) DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 11. TOP SQL BY CPU + I/O
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_seconds,
    disk_reads,
    buffer_gets,
    ROUND(
        cpu_time / 1000000 +
        disk_reads,
        2
    ) AS cpu_io_score,
    parsing_schema_name,
    module
FROM gv$sql
WHERE executions > 0
ORDER BY
    cpu_time / 1000000 +
    disk_reads DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 12. ACTIVE SQL BY RAC INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.sql_child_number,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.service_name,
    s.machine,
    s.program
FROM gv$session s
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
ORDER BY
    s.inst_id,
    s.seconds_in_wait DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 13. ACTIVE SQL WITH SQL DETAILS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.sql_child_number,
    ROUND(
        q.cpu_time / 1000000,
        2
    ) AS sql_cpu_seconds,
    ROUND(
        q.elapsed_time / 1000000,
        2
    ) AS sql_elapsed_seconds,
    q.executions,
    q.buffer_gets,
    q.disk_reads,
    s.event,
    s.wait_class,
    s.service_name
FROM gv$session s
JOIN gv$sql q
    ON q.inst_id = s.inst_id
   AND q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
ORDER BY
    q.cpu_time DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 14. TOP SQL BY SERVICE
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    sql_id,
    COUNT(*) AS active_sessions,
    ROUND(
        MAX(q.cpu_time) / 1000000,
        2
    ) AS cpu_seconds,
    ROUND(
        MAX(q.elapsed_time) / 1000000,
        2
    ) AS elapsed_seconds
FROM gv$session s
JOIN gv$sql q
    ON q.inst_id = s.inst_id
   AND q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
GROUP BY
    inst_id,
    service_name,
    sql_id
ORDER BY active_sessions DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 15. SQL DISTRIBUTION ACROSS RAC INSTANCES
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(DISTINCT inst_id) AS instance_count,
    SUM(executions) AS total_executions,
    ROUND(
        SUM(cpu_time) / 1000000,
        2
    ) AS total_cpu_seconds,
    ROUND(
        SUM(elapsed_time) / 1000000,
        2
    ) AS total_elapsed_seconds,
    SUM(buffer_gets) AS total_buffer_gets,
    SUM(disk_reads) AS total_disk_reads
FROM gv$sql
WHERE executions > 0
GROUP BY sql_id
HAVING COUNT(DISTINCT inst_id) > 1
ORDER BY total_cpu_seconds DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 16. SQL RUNNING ON MULTIPLE RAC INSTANCES
PROMPT ============================================================

SELECT
    sql_id,
    inst_id,
    plan_hash_value,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_seconds,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_seconds,
    buffer_gets,
    disk_reads,
    parsing_schema_name,
    module
FROM gv$sql
WHERE sql_id IN
(
    SELECT sql_id
    FROM gv$sql
    WHERE executions > 0
    GROUP BY sql_id
    HAVING COUNT(DISTINCT inst_id) > 1
)
ORDER BY
    sql_id,
    inst_id;


PROMPT
PROMPT ============================================================
PROMPT 17. SQL WITH MULTIPLE PLAN HASH VALUES ACROSS RAC
PROMPT ============================================================

SELECT
    sql_id,
    COUNT(DISTINCT plan_hash_value) AS plan_count,
    COUNT(DISTINCT inst_id) AS instance_count,
    SUM(executions) AS total_executions,
    ROUND(
        SUM(cpu_time) / 1000000,
        2
    ) AS total_cpu_seconds,
    ROUND(
        SUM(elapsed_time) / 1000000,
        2
    ) AS total_elapsed_seconds
FROM gv$sql
WHERE executions > 0
GROUP BY sql_id
HAVING COUNT(DISTINCT plan_hash_value) > 1
ORDER BY total_cpu_seconds DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 18. CACHE FUSION / GC WAITS BY SQL
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sql_id,
    COUNT(*) AS waiting_sessions,
    SUM(s.seconds_in_wait) AS total_wait_seconds,
    MAX(s.seconds_in_wait) AS max_wait_seconds,
    MIN(s.service_name) AS service_name
FROM gv$session s
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND s.state = 'WAITING'
  AND LOWER(s.event) LIKE 'gc %'
GROUP BY
    s.inst_id,
    s.sql_id
ORDER BY
    total_wait_seconds DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 19. CURRENT SQL WAITERS BY WAIT CLASS
PROMPT ============================================================

SELECT
    inst_id,
    wait_class,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
GROUP BY
    inst_id,
    wait_class
ORDER BY
    inst_id,
    waiting_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 20. SQL RESOURCE CONSUMPTION BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    SUM(executions) AS executions,
    ROUND(
        SUM(cpu_time) / 1000000,
        2
    ) AS cpu_seconds,
    ROUND(
        SUM(elapsed_time) / 1000000,
        2
    ) AS elapsed_seconds,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads,
    SUM(rows_processed) AS rows_processed
FROM gv$sql
GROUP BY inst_id
ORDER BY cpu_seconds DESC;


PROMPT
PROMPT ============================================================
PROMPT 21. SQL HEALTH SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS sql_cursors,
    COUNT(
        DISTINCT sql_id
    ) AS distinct_sql,
    SUM(executions) AS executions,
    ROUND(
        SUM(cpu_time) / 1000000,
        2
    ) AS cpu_seconds,
    ROUND(
        SUM(elapsed_time) / 1000000,
        2
    ) AS elapsed_seconds,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads
FROM gv$sql
GROUP BY inst_id
ORDER BY cpu_seconds DESC;


PROMPT
PROMPT ============================================================
PROMPT 22. TOP SQL TEXT
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_seconds,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_seconds,
    buffer_gets,
    disk_reads,
    parsing_schema_name,
    SUBSTR(sql_text, 1, 200) AS sql_text
FROM gv$sql
WHERE executions > 0
ORDER BY cpu_time DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 23. SQL BY USER / SCHEMA
PROMPT ============================================================

SELECT
    inst_id,
    parsing_schema_name,
    COUNT(DISTINCT sql_id) AS sql_count,
    SUM(executions) AS executions,
    ROUND(
        SUM(cpu_time) / 1000000,
        2
    ) AS cpu_seconds,
    ROUND(
        SUM(elapsed_time) / 1000000,
        2
    ) AS elapsed_seconds,
    SUM(buffer_gets) AS buffer_gets,
    SUM(disk_reads) AS disk_reads
FROM gv$sql
WHERE executions > 0
GROUP BY
    inst_id,
    parsing_schema_name
ORDER BY cpu_seconds DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 24. TOP SQL BY SERVICE / INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    s.service_name,
    q.sql_id,
    q.plan_hash_value,
    q.executions,
    ROUND(q.cpu_time / 1000000, 2) AS cpu_seconds,
    ROUND(q.elapsed_time / 1000000, 2) AS elapsed_seconds,
    q.buffer_gets,
    q.disk_reads
FROM gv$session s
JOIN gv$sql q
    ON q.inst_id = s.inst_id
   AND q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
WHERE s.username IS NOT NULL
  AND q.executions > 0
ORDER BY q.cpu_time DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 25. QUICK RAC TOP SQL CHECK
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_seconds,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_seconds,
    buffer_gets,
    disk_reads
FROM gv$sql
WHERE executions > 0
ORDER BY cpu_time DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 26. DBA TOP SQL INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT When investigating RAC SQL performance:
PROMPT
PROMPT 1. Identify top SQL by CPU.
PROMPT 2. Identify top SQL by elapsed time.
PROMPT 3. Check CPU per execution.
PROMPT 4. Check elapsed time per execution.
PROMPT 5. Check logical I/O per execution.
PROMPT 6. Check physical reads per execution.
PROMPT 7. Identify SQL with active sessions.
PROMPT 8. Check SQL distribution across RAC instances.
PROMPT 9. Check for multiple plan hash values.
PROMPT 10. Review Cache Fusion / gc* waits.
PROMPT 11. Check service and client distribution.
PROMPT 12. Compare SQL performance between instances.
PROMPT 13. Review execution plans before making changes.
PROMPT 14. Use AWR/ASH for historical analysis when available.
PROMPT 15. Do NOT tune SQL based on a single cumulative metric.
PROMPT
PROMPT ============================================================
PROMPT Important Notes:
PROMPT
PROMPT - V$SQL metrics are cumulative for the cursor lifetime.
PROMPT - High CPU does not automatically mean inefficient SQL.
PROMPT - High elapsed time may be caused by waits.
PROMPT - High buffer gets may be expected for some workloads.
PROMPT - High physical reads require workload/access-path context.
PROMPT - Multiple plans do not automatically mean a problem.
PROMPT - GC waits may indicate RAC block shipping or workload
PROMPT   behavior and require further correlation.
PROMPT - Use AWR/ASH for historical SQL analysis if licensed.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC TOP SQL MONITORING COMPLETE
PROMPT ============================================================
 
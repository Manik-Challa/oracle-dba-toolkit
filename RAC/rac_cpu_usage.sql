-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_cpu_usage.sql
-- Purpose: Monitor CPU usage across Oracle RAC instances
-- Scope  : DB CPU, DB Time, CPU sessions, CPU SQL,
--          Resource Manager waits and instance comparison
--
-- IMPORTANT:
-- Oracle CPU statistics are generally cumulative since startup.
-- True CPU utilization/rate requires interval-based sampling.
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
COLUMN stat_name           FORMAT A55
COLUMN username            FORMAT A25
COLUMN service_name        FORMAT A35
COLUMN machine             FORMAT A35
COLUMN program             FORMAT A40
COLUMN sql_id              FORMAT A15
COLUMN event               FORMAT A65
COLUMN wait_class          FORMAT A20

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
PROMPT 2. DB CPU AND DB TIME BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    stat_name,
    ROUND(value / 1000000, 2) AS seconds
FROM gv$sys_time_model
WHERE stat_name IN
(
    'DB CPU',
    'DB time'
)
ORDER BY
    inst_id,
    stat_name;


PROMPT
PROMPT ============================================================
PROMPT 3. CPU / DB TIME SUMMARY BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    ROUND(
        MAX(
            CASE
                WHEN stat_name = 'DB CPU'
                THEN value
            END
        ) / 1000000,
        2
    ) AS db_cpu_sec,
    ROUND(
        MAX(
            CASE
                WHEN stat_name = 'DB time'
                THEN value
            END
        ) / 1000000,
        2
    ) AS db_time_sec,
    ROUND(
        MAX(
            CASE
                WHEN stat_name = 'DB CPU'
                THEN value
            END
        )
        /
        NULLIF(
            MAX(
                CASE
                    WHEN stat_name = 'DB time'
                    THEN value
                END
            ),
            0
        ) * 100,
        2
    ) AS cpu_pct_of_db_time
FROM gv$sys_time_model
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 4. CPU USED BY USER SESSIONS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.username,
    COUNT(*) AS sessions,
    ROUND(
        SUM(st.value) / 1000000,
        2
    ) AS cpu_seconds
FROM gv$session s
JOIN gv$sesstat st
    ON st.inst_id = s.inst_id
   AND st.sid = s.sid
JOIN gv$statname sn
    ON sn.inst_id = st.inst_id
   AND sn.statistic# = st.statistic#
WHERE s.username IS NOT NULL
  AND sn.name = 'CPU used by this session'
GROUP BY
    s.inst_id,
    s.username
ORDER BY cpu_seconds DESC;


PROMPT
PROMPT ============================================================
PROMPT 5. TOP CPU-CONSUMING SESSIONS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    ROUND(
        st.value / 1000000,
        2
    ) AS cpu_seconds,
    s.service_name,
    s.machine,
    s.program
FROM gv$session s
JOIN gv$sesstat st
    ON st.inst_id = s.inst_id
   AND st.sid = s.sid
JOIN gv$statname sn
    ON sn.inst_id = st.inst_id
   AND sn.statistic# = st.statistic#
WHERE s.username IS NOT NULL
  AND sn.name = 'CPU used by this session'
ORDER BY st.value DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 6. ACTIVE CPU-CONSUMING SESSIONS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    ROUND(
        st.value / 1000000,
        2
    ) AS cpu_seconds,
    s.event,
    s.wait_class,
    s.service_name,
    s.machine,
    s.program
FROM gv$session s
JOIN gv$sesstat st
    ON st.inst_id = s.inst_id
   AND st.sid = s.sid
JOIN gv$statname sn
    ON sn.inst_id = st.inst_id
   AND sn.statistic# = st.statistic#
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND sn.name = 'CPU used by this session'
ORDER BY st.value DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 7. CPU BY RAC INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    COUNT(*) AS user_sessions,
    ROUND(
        SUM(st.value) / 1000000,
        2
    ) AS cpu_seconds,
    ROUND(
        AVG(st.value) / 1000000,
        2
    ) AS avg_cpu_seconds_per_session
FROM gv$session s
JOIN gv$sesstat st
    ON st.inst_id = s.inst_id
   AND st.sid = s.sid
JOIN gv$statname sn
    ON sn.inst_id = st.inst_id
   AND sn.statistic# = st.statistic#
WHERE s.username IS NOT NULL
  AND sn.name = 'CPU used by this session'
GROUP BY s.inst_id
ORDER BY cpu_seconds DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. CPU BY SERVICE AND INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    s.service_name,
    COUNT(*) AS sessions,
    ROUND(
        SUM(st.value) / 1000000,
        2
    ) AS cpu_seconds
FROM gv$session s
JOIN gv$sesstat st
    ON st.inst_id = s.inst_id
   AND st.sid = s.sid
JOIN gv$statname sn
    ON sn.inst_id = st.inst_id
   AND sn.statistic# = st.statistic#
WHERE s.username IS NOT NULL
  AND sn.name = 'CPU used by this session'
GROUP BY
    s.inst_id,
    s.service_name
ORDER BY cpu_seconds DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. CPU BY MACHINE / CLIENT
PROMPT ============================================================

SELECT
    s.inst_id,
    s.machine,
    COUNT(*) AS sessions,
    ROUND(
        SUM(st.value) / 1000000,
        2
    ) AS cpu_seconds
FROM gv$session s
JOIN gv$sesstat st
    ON st.inst_id = s.inst_id
   AND st.sid = s.sid
JOIN gv$statname sn
    ON sn.inst_id = st.inst_id
   AND sn.statistic# = st.statistic#
WHERE s.username IS NOT NULL
  AND sn.name = 'CPU used by this session'
GROUP BY
    s.inst_id,
    s.machine
ORDER BY cpu_seconds DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 10. TOP SQL BY CPU
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
    disk_reads
FROM gv$sql
WHERE executions > 0
ORDER BY cpu_time DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 11. TOP SQL BY CPU PER EXECUTION
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_seconds,
    ROUND(
        cpu_time /
        NULLIF(executions, 0) / 1000000,
        4
    ) AS cpu_sec_per_exec,
    ROUND(
        elapsed_time /
        NULLIF(executions, 0) / 1000000,
        4
    ) AS elapsed_sec_per_exec
FROM gv$sql
WHERE executions > 0
ORDER BY
    cpu_time /
    NULLIF(executions, 0) DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 12. CPU BY SQL / RAC INSTANCE
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
    ROUND(
        SUM(buffer_gets) / 1000000,
        2
    ) AS buffer_gets_millions,
    SUM(disk_reads) AS disk_reads
FROM gv$sql
GROUP BY inst_id
ORDER BY cpu_seconds DESC;


PROMPT
PROMPT ============================================================
PROMPT 13. CPU-HEAVY ACTIVE SQL
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.service_name,
    ROUND(
        q.cpu_time / 1000000,
        2
    ) AS sql_cpu_seconds,
    q.executions,
    ROUND(
        q.cpu_time /
        NULLIF(q.executions, 0) / 1000000,
        4
    ) AS cpu_sec_per_exec,
    s.machine,
    s.program
FROM gv$session s
JOIN gv$sql q
    ON q.inst_id = s.inst_id
   AND q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND q.executions > 0
ORDER BY q.cpu_time DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 14. RESOURCE MANAGER CPU THROTTLING
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS total_wait_sec,
    ROUND(
        (time_waited /
         NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'resmgr:cpu%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. CURRENT RESOURCE MANAGER CPU WAITERS
PROMPT ============================================================

SELECT
    inst_id,
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    seconds_in_wait,
    service_name,
    machine,
    program
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'resmgr:cpu%'
ORDER BY seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 16. CPU BY WAIT CLASS / INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    wait_class,
    COUNT(*) AS active_sessions
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
GROUP BY
    inst_id,
    wait_class
ORDER BY
    inst_id,
    active_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 17. CURRENT CPU-RELATED SESSION ACTIVITY
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS active_sessions,
    SUM(
        CASE
            WHEN state = 'WAITING'
            THEN 1
            ELSE 0
        END
    ) AS waiting_sessions,
    SUM(
        CASE
            WHEN wait_class = 'User I/O'
            THEN 1
            ELSE 0
        END
    ) AS user_io_waiters,
    SUM(
        CASE
            WHEN wait_class = 'Concurrency'
            THEN 1
            ELSE 0
        END
    ) AS concurrency_waiters,
    SUM(
        CASE
            WHEN wait_class = 'Cluster'
            THEN 1
            ELSE 0
        END
    ) AS cluster_waiters
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 18. CPU RESOURCE LIMITS
PROMPT ============================================================

SELECT
    inst_id,
    resource_name,
    current_utilization,
    max_utilization,
    limit_value
FROM gv$resource_limit
WHERE resource_name IN
(
    'sessions',
    'processes'
)
ORDER BY
    inst_id,
    resource_name;


PROMPT
PROMPT ============================================================
PROMPT 19. INSTANCE CPU COMPARISON
PROMPT ============================================================

WITH cpu_data AS
(
    SELECT
        s.inst_id,
        COUNT(*) AS user_sessions,
        SUM(st.value) AS cpu_value
    FROM gv$session s
    JOIN gv$sesstat st
        ON st.inst_id = s.inst_id
       AND st.sid = s.sid
    JOIN gv$statname sn
        ON sn.inst_id = st.inst_id
       AND sn.statistic# = st.statistic#
    WHERE s.username IS NOT NULL
      AND sn.name = 'CPU used by this session'
    GROUP BY s.inst_id
)
SELECT
    c.inst_id,
    i.instance_name,
    i.host_name,
    c.user_sessions,
    ROUND(c.cpu_value / 1000000, 2) AS cpu_seconds,
    ROUND(
        c.cpu_value /
        NULLIF(c.user_sessions, 0) / 1000000,
        2
    ) AS avg_cpu_sec_per_session
FROM cpu_data c
JOIN gv$instance i
    ON i.inst_id = c.inst_id
ORDER BY c.cpu_value DESC;


PROMPT
PROMPT ============================================================
PROMPT 20. CPU HEALTH SUMMARY
PROMPT ============================================================

WITH cpu_data AS
(
    SELECT
        s.inst_id,
        COUNT(*) AS user_sessions,
        SUM(st.value) AS cpu_value
    FROM gv$session s
    JOIN gv$sesstat st
        ON st.inst_id = s.inst_id
       AND st.sid = s.sid
    JOIN gv$statname sn
        ON sn.inst_id = st.inst_id
       AND sn.statistic# = st.statistic#
    WHERE s.username IS NOT NULL
      AND sn.name = 'CPU used by this session'
    GROUP BY s.inst_id
)
SELECT
    c.inst_id,
    i.instance_name,
    i.host_name,
    c.user_sessions,
    ROUND(c.cpu_value / 1000000, 2) AS cpu_seconds,
    CASE
        WHEN i.status <> 'OPEN'
            THEN 'WARNING - INSTANCE NOT OPEN'

        WHEN c.cpu_value > 3600000000
            THEN 'REVIEW - HIGH CUMULATIVE CPU'

        ELSE
            'NO OBVIOUS DATABASE-SIDE CPU ALERT'
    END AS health_status
FROM cpu_data c
JOIN gv$instance i
    ON i.inst_id = c.inst_id
ORDER BY c.cpu_value DESC;


PROMPT
PROMPT ============================================================
PROMPT 21. QUICK RAC CPU CHECK
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status,
    ROUND(
        MAX(
            CASE
                WHEN tm.stat_name = 'DB CPU'
                THEN tm.value
            END
        ) / 1000000,
        2
    ) AS db_cpu_sec,
    ROUND(
        MAX(
            CASE
                WHEN tm.stat_name = 'DB time'
                THEN tm.value
            END
        ) / 1000000,
        2
    ) AS db_time_sec
FROM gv$instance i
JOIN gv$sys_time_model tm
    ON tm.inst_id = i.inst_id
GROUP BY
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 22. DBA CPU INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT If RAC CPU usage appears high:
PROMPT
PROMPT 1. Compare DB CPU across RAC instances.
PROMPT 2. Compare DB Time across instances.
PROMPT 3. Identify top CPU-consuming sessions.
PROMPT 4. Identify top CPU-consuming SQL.
PROMPT 5. Check CPU per execution.
PROMPT 6. Check active CPU-heavy SQL.
PROMPT 7. Check Resource Manager CPU waits.
PROMPT 8. Compare CPU by service.
PROMPT 9. Compare CPU by client machine.
PROMPT 10. Check Cache Fusion / gc* waits.
PROMPT 11. Check User I/O and Concurrency waits.
PROMPT 12. Review service and connection distribution.
PROMPT 13. Compare instance workload before taking action.
PROMPT 14. Correlate with OS CPU/load metrics.
PROMPT 15. Use interval samples for actual CPU utilization.
PROMPT
PROMPT ============================================================
PROMPT Important Notes:
PROMPT
PROMPT - CPU used by this session is cumulative for the session.
PROMPT - V$SQL CPU_TIME is cumulative for the cursor.
PROMPT - DB CPU and DB Time are cumulative since instance startup.
PROMPT - Cumulative CPU seconds are NOT OS CPU utilization percent.
PROMPT - High DB CPU does not automatically mean a database problem.
PROMPT - Resource Manager CPU waits indicate CPU throttling/queuing,
PROMPT   not all forms of CPU consumption.
PROMPT - For OS CPU utilization, correlate with mpstat/top/sar.
PROMPT - RAC CPU imbalance may be caused by service placement,
PROMPT   application routing or workload characteristics.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC CPU USAGE MONITORING COMPLETE
PROMPT ============================================================
 
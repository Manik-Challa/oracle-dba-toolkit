-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_instance_load.sql
-- Purpose: Monitor RAC instance workload and load distribution
-- Scope  : Sessions, CPU, DB time, waits, transactions, I/O,
--          SQL activity and instance-level comparison
--
-- IMPORTANT:
-- Most V$ statistics are cumulative since instance startup.
-- For true rates (CPU/sec, IOPS/sec, executions/sec), collect
-- multiple samples and calculate deltas.
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
COLUMN status              FORMAT A15
COLUMN database_status     FORMAT A20
COLUMN event               FORMAT A65
COLUMN wait_class          FORMAT A20
COLUMN username            FORMAT A25
COLUMN service_name        FORMAT A35
COLUMN machine             FORMAT A35
COLUMN program             FORMAT A40
COLUMN sql_id              FORMAT A15
COLUMN stat_name           FORMAT A55

PROMPT
PROMPT ============================================================
PROMPT 1. RAC INSTANCE STATUS
PROMPT ============================================================

SELECT
    inst_id,
    instance_number,
    instance_name,
    host_name,
    version,
    status,
    database_status,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 2. INSTANCE UPTIME / LOAD CONTEXT
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    database_status,
    ROUND(
        (SYSDATE - startup_time) * 24,
        2
    ) AS uptime_hours,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 3. SESSION LOAD BY INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    i.host_name,
    COUNT(*) AS total_sessions,
    SUM(
        CASE
            WHEN s.username IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS user_sessions,
    SUM(
        CASE
            WHEN s.status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_sessions,
    SUM(
        CASE
            WHEN s.username IS NOT NULL
             AND s.status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_user_sessions,
    SUM(
        CASE
            WHEN s.state = 'WAITING'
             AND s.status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS waiting_sessions
FROM gv$session s
JOIN gv$instance i
    ON i.inst_id = s.inst_id
GROUP BY
    s.inst_id,
    i.instance_name,
    i.host_name
ORDER BY s.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 4. ACTIVE SESSIONS BY INSTANCE
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
            WHEN state = 'WAITING'
             AND wait_class = 'User I/O'
            THEN 1
            ELSE 0
        END
    ) AS user_io_waiters,
    SUM(
        CASE
            WHEN state = 'WAITING'
             AND wait_class = 'Concurrency'
            THEN 1
            ELSE 0
        END
    ) AS concurrency_waiters
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 5. ACTIVE SESSIONS BY SERVICE / INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS active_sessions,
    COUNT(DISTINCT username) AS active_users,
    COUNT(DISTINCT machine) AS client_machines
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
GROUP BY
    inst_id,
    service_name
ORDER BY
    service_name,
    inst_id;


PROMPT
PROMPT ============================================================
PROMPT 6. SESSION DISTRIBUTION PERCENTAGE
PROMPT ============================================================

WITH instance_sessions AS
(
    SELECT
        inst_id,
        COUNT(*) AS user_sessions
    FROM gv$session
    WHERE username IS NOT NULL
    GROUP BY inst_id
),
total_sessions AS
(
    SELECT
        SUM(user_sessions) AS total_user_sessions
    FROM instance_sessions
)
SELECT
    ins.inst_id,
    i.instance_name,
    i.host_name,
    ins.user_sessions,
    ts.total_user_sessions,
    ROUND(
        ins.user_sessions * 100 /
        NULLIF(ts.total_user_sessions, 0),
        2
    ) AS session_pct
FROM instance_sessions ins
JOIN total_sessions ts
    ON 1 = 1
JOIN gv$instance i
    ON i.inst_id = ins.inst_id
ORDER BY ins.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 7. CPU / DB TIME BY INSTANCE
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
PROMPT 8. CPU / DB TIME SUMMARY
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
PROMPT 9. TOP NON-IDLE WAIT EVENTS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS total_wait_sec,
    ROUND(
        (time_waited /
         NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM
(
    SELECT
        inst_id,
        event,
        wait_class,
        total_waits,
        time_waited,
        ROW_NUMBER() OVER
        (
            PARTITION BY inst_id
            ORDER BY time_waited DESC
        ) AS rn
    FROM gv$system_event
    WHERE wait_class <> 'Idle'
)
WHERE rn <= 10
ORDER BY
    inst_id,
    total_wait_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. CURRENT WAITERS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS waiting_sessions,
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
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 11. CACHE FUSION / GC LOAD BY INSTANCE
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
WHERE LOWER(event) LIKE 'gc %'
ORDER BY
    inst_id,
    time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 12. I/O LOAD BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value
FROM gv$sysstat
WHERE LOWER(name) IN
(
    'physical reads',
    'physical writes',
    'physical read total bytes',
    'physical write total bytes',
    'session logical reads'
)
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 13. TRANSACTION LOAD BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS active_transactions,
    SUM(
        CASE
            WHEN status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_status_transactions,
    MAX(start_time) AS oldest_transaction_start
FROM gv$transaction
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 14. REDO LOAD BY INSTANCE / THREAD
PROMPT ============================================================

SELECT
    l.thread# AS thread,
    SUM(l.bytes) / 1024 / 1024 AS total_log_mb,
    COUNT(*) AS log_groups,
    SUM(
        CASE
            WHEN l.status = 'CURRENT'
            THEN 1
            ELSE 0
        END
    ) AS current_groups
FROM gv$log l
GROUP BY l.thread#
ORDER BY l.thread#;


PROMPT
PROMPT ============================================================
PROMPT 15. TOP CPU SESSIONS BY INSTANCE
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
WHERE sn.name = 'CPU used by this session'
  AND s.username IS NOT NULL
ORDER BY st.value DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 16. TOP SQL BY CPU / INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
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
PROMPT 17. TOP SQL BY ELAPSED TIME / INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    plan_hash_value,
    executions,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(
        elapsed_time /
        NULLIF(executions, 0) / 1000000,
        4
    ) AS elapsed_sec_per_exec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    buffer_gets,
    disk_reads
FROM gv$sql
WHERE executions > 0
ORDER BY elapsed_time DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 18. SQL EXECUTION LOAD BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    SUM(executions) AS total_executions,
    SUM(rows_processed) AS rows_processed,
    ROUND(
        SUM(cpu_time) / 1000000,
        2
    ) AS cpu_seconds,
    ROUND(
        SUM(elapsed_time) / 1000000,
        2
    ) AS elapsed_seconds
FROM gv$sql
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 19. INSTANCE RESOURCE LIMITS
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
    'processes',
    'transactions'
)
ORDER BY
    inst_id,
    resource_name;


PROMPT
PROMPT ============================================================
PROMPT 20. SERVICE LOAD BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS user_sessions,
    SUM(
        CASE
            WHEN status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_sessions,
    COUNT(DISTINCT username) AS users,
    COUNT(DISTINCT machine) AS client_machines
FROM gv$session
WHERE username IS NOT NULL
GROUP BY
    inst_id,
    service_name
ORDER BY
    service_name,
    inst_id;


PROMPT
PROMPT ============================================================
PROMPT 21. INSTANCE LOAD COMPARISON
PROMPT ============================================================

WITH load_data AS
(
    SELECT
        s.inst_id,
        COUNT(*) AS user_sessions,
        SUM(
            CASE
                WHEN s.status = 'ACTIVE'
                THEN 1
                ELSE 0
            END
        ) AS active_sessions,
        SUM(
            CASE
                WHEN s.status = 'ACTIVE'
                 AND s.state = 'WAITING'
                 AND s.wait_class <> 'Idle'
                THEN 1
                ELSE 0
            END
        ) AS non_idle_waiters
    FROM gv$session s
    WHERE s.username IS NOT NULL
    GROUP BY s.inst_id
)
SELECT
    l.inst_id,
    i.instance_name,
    i.host_name,
    l.user_sessions,
    l.active_sessions,
    l.non_idle_waiters,
    ROUND(
        l.active_sessions * 100 /
        NULLIF(l.user_sessions, 0),
        2
    ) AS active_pct
FROM load_data l
JOIN gv$instance i
    ON i.inst_id = l.inst_id
ORDER BY
    l.active_sessions DESC,
    l.non_idle_waiters DESC;


PROMPT
PROMPT ============================================================
PROMPT 22. INSTANCE LOAD HEALTH SUMMARY
PROMPT ============================================================

WITH load_data AS
(
    SELECT
        inst_id,
        COUNT(*) AS user_sessions,
        SUM(
            CASE
                WHEN status = 'ACTIVE'
                THEN 1
                ELSE 0
            END
        ) AS active_sessions,
        SUM(
            CASE
                WHEN status = 'ACTIVE'
                 AND state = 'WAITING'
                 AND wait_class <> 'Idle'
                THEN 1
                ELSE 0
            END
        ) AS non_idle_waiters
    FROM gv$session
    WHERE username IS NOT NULL
    GROUP BY inst_id
)
SELECT
    l.inst_id,
    i.instance_name,
    i.host_name,
    l.user_sessions,
    l.active_sessions,
    l.non_idle_waiters,
    CASE
        WHEN i.status <> 'OPEN'
            THEN 'WARNING - INSTANCE NOT OPEN'

        WHEN l.active_sessions >= 1000
            THEN 'REVIEW - HIGH ACTIVE SESSION COUNT'

        WHEN l.non_idle_waiters >= 500
            THEN 'REVIEW - HIGH WAITING SESSION COUNT'

        ELSE
            'NO OBVIOUS DATABASE-SIDE LOAD ALERT'
    END AS health_status
FROM load_data l
JOIN gv$instance i
    ON i.inst_id = l.inst_id
ORDER BY
    l.active_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 23. QUICK RAC LOAD CHECK
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status,
    COUNT(s.sid) AS total_sessions,
    SUM(
        CASE
            WHEN s.username IS NOT NULL
             AND s.status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_user_sessions,
    SUM(
        CASE
            WHEN s.username IS NOT NULL
             AND s.status = 'ACTIVE'
             AND s.state = 'WAITING'
             AND s.wait_class <> 'Idle'
            THEN 1
            ELSE 0
        END
    ) AS non_idle_waiters
FROM gv$instance i
LEFT JOIN gv$session s
    ON s.inst_id = i.inst_id
GROUP BY
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 24. DBA INSTANCE LOAD INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT If one RAC instance appears significantly busier:
PROMPT
PROMPT 1. Compare active sessions across instances.
PROMPT 2. Compare services and connection distribution.
PROMPT 3. Check CPU and DB Time by instance.
PROMPT 4. Review top wait events by instance.
PROMPT 5. Review Cache Fusion / gc* waits.
PROMPT 6. Compare physical I/O and logical I/O.
PROMPT 7. Compare top CPU SQL by instance.
PROMPT 8. Compare top elapsed-time SQL by instance.
PROMPT 9. Check session/process resource utilization.
PROMPT 10. Check transaction and UNDO activity.
PROMPT 11. Check service placement and connection pools.
PROMPT 12. Review SCAN/listener/service registration.
PROMPT 13. Check application routing and connection balancing.
PROMPT 14. Correlate with OS CPU/load/network/I/O metrics.
PROMPT 15. Do NOT assume session imbalance alone means RAC
PROMPT     or SCAN is unhealthy.
PROMPT
PROMPT ============================================================
PROMPT Important Notes:
PROMPT
PROMPT - V$ statistics are generally cumulative since startup.
PROMPT - CPU/IO/execute rates require time-based samples/deltas.
PROMPT - High active sessions do not automatically mean a problem.
PROMPT - RAC workload may intentionally be asymmetric.
PROMPT - Service placement can intentionally concentrate workload.
PROMPT - GC waits are normal RAC activity and require context.
PROMPT - Database-side load does not replace OS/Clusterware checks.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC INSTANCE LOAD MONITORING COMPLETE
PROMPT ============================================================
 
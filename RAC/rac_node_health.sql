-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_node_health.sql
-- Purpose: Monitor Oracle RAC node / instance health
-- Scope  : Instance status, uptime, CPU, sessions, processes,
--          waits, transactions, services, load and health
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name       FORMAT A18
COLUMN host_name           FORMAT A30
COLUMN version             FORMAT A15
COLUMN status              FORMAT A15
COLUMN database_status     FORMAT A20
COLUMN startup_time        FORMAT A20
COLUMN resource_name       FORMAT A25
COLUMN current_utilization FORMAT 999999999
COLUMN max_utilization     FORMAT 999999999
COLUMN limit_value         FORMAT A15
COLUMN event               FORMAT A65
COLUMN wait_class          FORMAT A20
COLUMN username            FORMAT A20
COLUMN service_name        FORMAT A30
COLUMN machine             FORMAT A30
COLUMN program             FORMAT A35

PROMPT
PROMPT ============================================================
PROMPT 1. RAC INSTANCE / NODE STATUS
PROMPT ============================================================

SELECT
    inst_id,
    instance_number,
    instance_name,
    host_name,
    version,
    status,
    database_status,
    parallel,
    thread# AS thread,
    archiver,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 2. INSTANCE UPTIME
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    startup_time,
    ROUND(
        (SYSDATE - startup_time) * 24,
        2
    ) AS uptime_hours
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 3. SESSION RESOURCE USAGE
PROMPT ============================================================

SELECT
    inst_id,
    resource_name,
    current_utilization,
    max_utilization,
    limit_value
FROM gv$resource_limit
WHERE resource_name IN
      ('sessions', 'processes', 'transactions')
ORDER BY inst_id, resource_name;


PROMPT
PROMPT ============================================================
PROMPT 4. SESSION DISTRIBUTION BY RAC INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    i.host_name,
    COUNT(*) AS total_sessions,
    SUM(
        CASE
            WHEN s.status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_sessions,
    SUM(
        CASE
            WHEN s.status = 'INACTIVE' THEN 1
            ELSE 0
        END
    ) AS inactive_sessions,
    SUM(
        CASE
            WHEN s.type = 'USER' THEN 1
            ELSE 0
        END
    ) AS user_sessions,
    SUM(
        CASE
            WHEN s.type = 'BACKGROUND' THEN 1
            ELSE 0
        END
    ) AS background_sessions
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
PROMPT 5. ACTIVE SESSIONS BY INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    COUNT(*) AS active_sessions
FROM gv$session s
JOIN gv$instance i
    ON i.inst_id = s.inst_id
WHERE s.status = 'ACTIVE'
  AND s.type = 'USER'
GROUP BY
    s.inst_id,
    i.instance_name
ORDER BY active_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 6. ACTIVE SESSIONS BY USER AND INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    s.username,
    COUNT(*) AS active_sessions
FROM gv$session s
JOIN gv$instance i
    ON i.inst_id = s.inst_id
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
GROUP BY
    s.inst_id,
    i.instance_name,
    s.username
ORDER BY active_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. CURRENT NON-IDLE WAITS BY INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    s.event,
    s.wait_class,
    COUNT(*) AS waiting_sessions
FROM gv$session s
JOIN gv$instance i
    ON i.inst_id = s.inst_id
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND s.state = 'WAITING'
  AND s.wait_class <> 'Idle'
GROUP BY
    s.inst_id,
    i.instance_name,
    s.event,
    s.wait_class
ORDER BY waiting_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. LONGEST CURRENT WAITS
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.wait_class,
    s.state,
    s.seconds_in_wait,
    s.service_name,
    s.machine
FROM gv$session s
JOIN gv$instance i
    ON i.inst_id = s.inst_id
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND s.state = 'WAITING'
  AND s.wait_class <> 'Idle'
ORDER BY s.seconds_in_wait DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 9. CPU / RESOURCE MANAGER WAITERS
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS cpu_waiters,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND (
        LOWER(event) LIKE '%resmgr%'
        OR LOWER(event) LIKE '%cpu quantum%'
      )
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 10. ACTIVE TRANSACTIONS BY INSTANCE
PROMPT ============================================================

SELECT
    t.inst_id,
    i.instance_name,
    COUNT(*) AS active_transactions,
    SUM(NVL(t.used_ublk, 0)) AS undo_blocks
FROM gv$transaction t
JOIN gv$instance i
    ON i.inst_id = t.inst_id
GROUP BY
    t.inst_id,
    i.instance_name
ORDER BY active_transactions DESC;


PROMPT
PROMPT ============================================================
PROMPT 11. LONG-RUNNING TRANSACTIONS
PROMPT ============================================================

SELECT
    t.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    t.start_time,
    t.used_ublk,
    t.used_urec,
    s.sql_id,
    s.status,
    s.event
FROM gv$transaction t
JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND t.addr = s.taddr
WHERE t.start_time IS NOT NULL
ORDER BY t.used_ublk DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 12. REDO THREAD STATUS
PROMPT ============================================================

SELECT
    inst_id,
    thread#,
    status,
    enabled,
    instance,
    groups_count,
    sequence#
FROM gv$thread
ORDER BY thread#;


PROMPT
PROMPT ============================================================
PROMPT 13. INSTANCE SERVICES
PROMPT ============================================================

SELECT
    inst_id,
    name AS service_name,
    network_name,
    enabled,
    aq_ha_notifications,
    clb_goal,
    goal,
    dtp
FROM gv$services
ORDER BY name, inst_id;


PROMPT
PROMPT ============================================================
PROMPT 14. SERVICE SESSION DISTRIBUTION
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS sessions,
    SUM(
        CASE
            WHEN status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_sessions
FROM gv$session
WHERE username IS NOT NULL
GROUP BY
    inst_id,
    service_name
ORDER BY service_name, inst_id;


PROMPT
PROMPT ============================================================
PROMPT 15. INSTANCE SYSTEM LOAD
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    logons_current,
    user_commits,
    user_rollbacks,
    execute_count,
    user_calls,
    parse_count_total,
    parse_count_hard
FROM gv$sysstat
PIVOT
(
    MAX(value)
    FOR name IN
    (
        'logons current' AS logons_current,
        'user commits' AS user_commits,
        'user rollbacks' AS user_rollbacks,
        'execute count' AS execute_count,
        'user calls' AS user_calls,
        'parse count (total)' AS parse_count_total,
        'parse count (hard)' AS parse_count_hard
    )
)
JOIN gv$instance i
    ON i.inst_id = inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 16. DATABASE TIME / CPU BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    stat_name,
    ROUND(value / 1000000, 2) AS seconds
FROM gv$sess_time_model
WHERE stat_name IN
      ('DB CPU', 'DB time')
ORDER BY inst_id, stat_name;


PROMPT
PROMPT ============================================================
PROMPT 17. TOP SQL BY CPU PER INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    executions,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    buffer_gets,
    disk_reads,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM gv$sql
WHERE executions > 0
ORDER BY cpu_time DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 18. TOP SQL BY ELAPSED TIME PER INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    executions,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    buffer_gets,
    disk_reads,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM gv$sql
WHERE executions > 0
ORDER BY elapsed_time DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 19. RAC INTERCONNECT / CACHE FUSION WAITS
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
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 20. BLOCKED SESSIONS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS blocked_sessions,
    MAX(seconds_in_wait) AS longest_wait_seconds
FROM gv$session
WHERE blocking_session IS NOT NULL
GROUP BY inst_id
ORDER BY blocked_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 21. INSTANCE HEALTH SUMMARY
PROMPT ============================================================

WITH session_stats AS
(
    SELECT
        inst_id,
        COUNT(*) AS total_sessions,
        SUM(
            CASE
                WHEN status = 'ACTIVE'
                AND type = 'USER'
                THEN 1
                ELSE 0
            END
        ) AS active_sessions,
        SUM(
            CASE
                WHEN blocking_session IS NOT NULL
                THEN 1
                ELSE 0
            END
        ) AS blocked_sessions
    FROM gv$session
    GROUP BY inst_id
),
resource_stats AS
(
    SELECT
        inst_id,
        MAX(
            CASE
                WHEN resource_name = 'sessions'
                THEN current_utilization
            END
        ) AS sessions_used,
        MAX(
            CASE
                WHEN resource_name = 'sessions'
                THEN TO_NUMBER(NULLIF(limit_value, 'UNLIMITED'))
            END
        ) AS sessions_limit,
        MAX(
            CASE
                WHEN resource_name = 'processes'
                THEN current_utilization
            END
        ) AS processes_used,
        MAX(
            CASE
                WHEN resource_name = 'processes'
                THEN TO_NUMBER(NULLIF(limit_value, 'UNLIMITED'))
            END
        ) AS processes_limit
    FROM gv$resource_limit
    GROUP BY inst_id
)
SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status,
    ss.total_sessions,
    ss.active_sessions,
    ss.blocked_sessions,
    rs.sessions_used,
    rs.sessions_limit,
    rs.processes_used,
    rs.processes_limit,
    CASE
        WHEN i.status <> 'OPEN'
            THEN 'WARNING - INSTANCE NOT OPEN'
        WHEN ss.blocked_sessions > 0
            THEN 'REVIEW - BLOCKED SESSIONS'
        WHEN rs.sessions_limit IS NOT NULL
         AND rs.sessions_used / NULLIF(rs.sessions_limit, 0) >= .90
            THEN 'WARNING - SESSION UTILIZATION HIGH'
        WHEN rs.processes_limit IS NOT NULL
         AND rs.processes_used / NULLIF(rs.processes_limit, 0) >= .90
            THEN 'WARNING - PROCESS UTILIZATION HIGH'
        ELSE 'NO OBVIOUS NODE ISSUE'
    END AS health_status
FROM gv$instance i
LEFT JOIN session_stats ss
    ON ss.inst_id = i.inst_id
LEFT JOIN resource_stats rs
    ON rs.inst_id = i.inst_id
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 22. QUICK RAC NODE CHECK
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status,
    i.database_status,
    NVL(s.active_sessions, 0) AS active_sessions,
    NVL(s.blocked_sessions, 0) AS blocked_sessions
FROM gv$instance i
LEFT JOIN
(
    SELECT
        inst_id,
        SUM(
            CASE
                WHEN status = 'ACTIVE'
                 AND type = 'USER'
                THEN 1
                ELSE 0
            END
        ) AS active_sessions,
        SUM(
            CASE
                WHEN blocking_session IS NOT NULL
                THEN 1
                ELSE 0
            END
        ) AS blocked_sessions
    FROM gv$session
    GROUP BY inst_id
) s
    ON s.inst_id = i.inst_id
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 23. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT If a RAC node appears unhealthy:
PROMPT
PROMPT 1. Verify GV$INSTANCE status and database_status.
PROMPT 2. Check instance uptime for unexpected restarts.
PROMPT 3. Review sessions/processes resource utilization.
PROMPT 4. Compare active sessions across RAC instances.
PROMPT 5. Check current non-idle waits.
PROMPT 6. Check blocked sessions and blocking transactions.
PROMPT 7. Review CPU and DB time by instance.
PROMPT 8. Check top CPU and elapsed-time SQL.
PROMPT 9. Review GCS / Cache Fusion waits.
PROMPT 10. Check service distribution and connection routing.
PROMPT 11. Check transactions and UNDO consumption.
PROMPT 12. Review redo thread status.
PROMPT 13. Correlate with OS CPU, memory, disk and network metrics.
PROMPT 14. Check CRS, VIP, SCAN and listener status when required.
PROMPT 15. Do NOT assume a node issue from database metrics alone.
PROMPT
PROMPT ============================================================
PROMPT Notes:
PROMPT - Database views provide database-side node health.
PROMPT - They do not replace CRS/Clusterware or OS checks.
PROMPT - High session/load values are workload dependent.
PROMPT - Cache Fusion waits can be normal RAC activity.
PROMPT - Resource utilization thresholds are investigation triggers.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC NODE HEALTH MONITORING COMPLETE
PROMPT ============================================================
 
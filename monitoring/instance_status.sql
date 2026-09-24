-- ============================================================
-- Oracle DBA Toolkit
-- Instance Status Monitoring
--
-- Purpose:
--   Monitor Oracle instance status, uptime, sessions,
--   processes, RAC instances, and basic resource usage.
--
-- Key checks:
--   - Instance status
--   - Instance name / host
--   - Startup time / uptime
--   - Database status
--   - Active sessions
--   - Process / session utilization
--   - RAC instance status
--   - Instance resource limits
--
-- Notes:
--   This script is diagnostic only.
--   No startup, shutdown, kill, or configuration changes
--   are performed.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name       FORMAT A18
COLUMN host_name           FORMAT A35
COLUMN version             FORMAT A18
COLUMN status              FORMAT A15
COLUMN database_status     FORMAT A20
COLUMN startup_time        FORMAT A20
COLUMN uptime              FORMAT A30
COLUMN uptime_days         FORMAT 999,999,990.00
COLUMN db_name             FORMAT A20
COLUMN db_unique_name      FORMAT A25
COLUMN open_mode           FORMAT A20
COLUMN database_role       FORMAT A20
COLUMN resource_name       FORMAT A25
COLUMN current_utilization FORMAT 999,999,999
COLUMN max_utilization     FORMAT 999,999,999
COLUMN limit_value         FORMAT A20
COLUMN utilization_pct     FORMAT 999.99
COLUMN machine             FORMAT A35

PROMPT
PROMPT ============================================================
PROMPT 1. CURRENT INSTANCE STATUS
PROMPT ============================================================

SELECT
    instance_name,
    host_name,
    version,
    status,
    database_status,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time,
    FLOOR(SYSDATE - startup_time) || ' days ' ||
    FLOOR(MOD((SYSDATE - startup_time) * 24, 24)) || ' hours ' ||
    FLOOR(MOD((SYSDATE - startup_time) * 1440, 60)) || ' minutes'
        AS uptime,
    ROUND(SYSDATE - startup_time, 2) AS uptime_days
FROM v$instance;


PROMPT
PROMPT ============================================================
PROMPT 2. DATABASE + INSTANCE STATUS
PROMPT ============================================================

SELECT
    i.instance_name,
    i.host_name,
    i.status AS instance_status,
    i.database_status,
    d.name AS db_name,
    d.db_unique_name,
    d.open_mode,
    d.database_role
FROM v$instance i
CROSS JOIN v$database d;


PROMPT
PROMPT ============================================================
PROMPT 3. INSTANCE STARTUP INFORMATION
PROMPT ============================================================

SELECT
    instance_name,
    instance_number,
    host_name,
    status,
    database_status,
    startup_time,
    logins,
    parallel,
    thread#
FROM v$instance;


PROMPT
PROMPT ============================================================
PROMPT 4. ACTIVE SESSION SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS total_user_sessions,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END)
        AS active_sessions,
    SUM(CASE WHEN status = 'INACTIVE' THEN 1 ELSE 0 END)
        AS inactive_sessions
FROM v$session
WHERE type = 'USER';


PROMPT
PROMPT ============================================================
PROMPT 5. SESSIONS BY STATUS
PROMPT ============================================================

SELECT
    status,
    COUNT(*) AS session_count
FROM v$session
WHERE type = 'USER'
GROUP BY status
ORDER BY session_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 6. PROCESS / SESSION RESOURCE UTILIZATION
PROMPT ============================================================

SELECT
    resource_name,
    current_utilization,
    max_utilization,
    limit_value,
    ROUND(
        CASE
            WHEN REGEXP_LIKE(limit_value, '^[0-9]+$')
            THEN
                current_utilization /
                NULLIF(TO_NUMBER(limit_value), 0) * 100
        END,
        2
    ) AS utilization_pct
FROM v$resource_limit
WHERE resource_name IN ('processes', 'sessions')
ORDER BY resource_name;


PROMPT
PROMPT ============================================================
PROMPT 7. PROCESS LIMIT DETAILS
PROMPT ============================================================

SELECT
    resource_name,
    current_utilization,
    max_utilization,
    limit_value
FROM v$resource_limit
WHERE resource_name = 'processes';


PROMPT
PROMPT ============================================================
PROMPT 8. SESSION LIMIT DETAILS
PROMPT ============================================================

SELECT
    resource_name,
    current_utilization,
    max_utilization,
    limit_value
FROM v$resource_limit
WHERE resource_name = 'sessions';


PROMPT
PROMPT ============================================================
PROMPT 9. TOP USER SESSIONS BY MACHINE
PROMPT ============================================================

SELECT
    machine,
    COUNT(*) AS session_count,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END)
        AS active_sessions,
    SUM(CASE WHEN status = 'INACTIVE' THEN 1 ELSE 0 END)
        AS inactive_sessions
FROM v$session
WHERE type = 'USER'
GROUP BY machine
ORDER BY session_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. TOP USER SESSIONS BY PROGRAM
PROMPT ============================================================

SELECT
    program,
    COUNT(*) AS session_count,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END)
        AS active_sessions
FROM v$session
WHERE type = 'USER'
GROUP BY program
ORDER BY session_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 11. SESSION UTILIZATION BY USER
PROMPT ============================================================

SELECT
    NVL(username, '<NULL>') AS username,
    COUNT(*) AS session_count,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END)
        AS active_sessions,
    SUM(CASE WHEN status = 'INACTIVE' THEN 1 ELSE 0 END)
        AS inactive_sessions
FROM v$session
WHERE type = 'USER'
GROUP BY username
ORDER BY session_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 12. RAC INSTANCE STATUS
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    instance_number,
    host_name,
    status,
    database_status,
    logins,
    thread#,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time,
    ROUND(SYSDATE - startup_time, 2) AS uptime_days
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 13. RAC INSTANCE STATUS SUMMARY
PROMPT ============================================================

SELECT
    status,
    database_status,
    COUNT(*) AS instance_count
FROM gv$instance
GROUP BY status, database_status
ORDER BY status, database_status;


PROMPT
PROMPT ============================================================
PROMPT 14. RECENTLY STARTED INSTANCES
PROMPT     Instances restarted within the last 24 hours.
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time,
    ROUND((SYSDATE - startup_time) * 24, 2) AS uptime_hours
FROM gv$instance
WHERE startup_time >= SYSDATE - 1
ORDER BY startup_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. INSTANCE STATUS CHECK
PROMPT ============================================================

SELECT
    instance_name,
    CASE
        WHEN status = 'OPEN'
         AND database_status = 'NORMAL'
        THEN 'OK'
        ELSE 'CHECK'
    END AS health_status,
    status AS instance_status,
    database_status
FROM v$instance;


PROMPT
PROMPT ============================================================
PROMPT 16. INSTANCE HEALTH SUMMARY
PROMPT ============================================================

SELECT
    i.instance_name,
    i.host_name,
    i.status,
    i.database_status,
    d.open_mode,
    d.database_role,
    ROUND(SYSDATE - i.startup_time, 2) AS uptime_days,
    (
        SELECT COUNT(*)
        FROM v$session s
        WHERE s.type = 'USER'
    ) AS user_sessions,
    (
        SELECT COUNT(*)
        FROM v$session s
        WHERE s.type = 'USER'
          AND s.status = 'ACTIVE'
    ) AS active_sessions
FROM v$instance i
CROSS JOIN v$database d;


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION NOTES
PROMPT ============================================================
PROMPT
PROMPT 1. INSTANCE_STATUS = OPEN normally indicates the instance
PROMPT    is available for database operations.
PROMPT
PROMPT 2. DATABASE_STATUS = NORMAL indicates normal database status.
PROMPT
PROMPT 3. Check STARTUP_TIME to identify recent instance restarts.
PROMPT
PROMPT 4. Review V$RESOURCE_LIMIT for process/session pressure.
PROMPT
PROMPT 5. Compare CURRENT_UTILIZATION and MAX_UTILIZATION with
PROMPT    the configured limit.
PROMPT
PROMPT 6. High session counts should be correlated with application
PROMPT    connection pooling and workload.
PROMPT
PROMPT 7. In RAC, always review GV$INSTANCE for every instance.
PROMPT
PROMPT 8. Unexpected instance restarts should be correlated with:
PROMPT       - alert.log
PROMPT       - OS reboot history
PROMPT       - Clusterware events
PROMPT       - database errors
PROMPT       - patching / maintenance activity
PROMPT
PROMPT 9. A high process/session utilization percentage does not
PROMPT    automatically mean the database is unhealthy.
PROMPT
PROMPT 10. This script is diagnostic only and does not perform
PROMPT     any database changes.
PROMPT
PROMPT ============================================================
PROMPT END OF INSTANCE STATUS MONITORING
PROMPT ============================================================


-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_listener_status.sql
-- Purpose: Monitor Oracle RAC listener configuration and health
-- Scope  : Local/remote listeners, service registration,
--          connection distribution, listener-related waits,
--          services and RAC instance comparison
--
-- IMPORTANT:
-- Database SQL provides database-side listener visibility only.
-- For authoritative listener status use:
--
--   srvctl status listener
--   srvctl config listener
--   srvctl status scan_listener
--   srvctl config scan_listener
--   lsnrctl status
--   crsctl status resource -t
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name       FORMAT A18
COLUMN host_name           FORMAT A30
COLUMN parameter_name      FORMAT A35
COLUMN parameter_value     FORMAT A100
COLUMN service_name        FORMAT A35
COLUMN network_name        FORMAT A45
COLUMN event               FORMAT A65
COLUMN wait_class          FORMAT A20
COLUMN machine             FORMAT A35
COLUMN program             FORMAT A40
COLUMN status              FORMAT A20
COLUMN database_status     FORMAT A20
COLUMN listener_name       FORMAT A35

PROMPT
PROMPT ============================================================
PROMPT 1. RAC INSTANCE INFORMATION
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
PROMPT 2. LOCAL LISTENER CONFIGURATION
PROMPT ============================================================

SELECT
    inst_id,
    name AS parameter_name,
    value AS parameter_value
FROM gv$parameter
WHERE name = 'local_listener'
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 3. REMOTE LISTENER / SCAN CONFIGURATION
PROMPT ============================================================

SELECT
    inst_id,
    name AS parameter_name,
    value AS parameter_value
FROM gv$parameter
WHERE name = 'remote_listener'
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 4. ALL LISTENER-RELATED PARAMETERS
PROMPT ============================================================

SELECT
    inst_id,
    name AS parameter_name,
    value AS parameter_value
FROM gv$parameter
WHERE LOWER(name) LIKE '%listener%'
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================
PROMPT 5. RAC SERVICES
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
PROMPT 6. SERVICE REGISTRATION / SESSION DISTRIBUTION
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    i.host_name,
    s.service_name,
    COUNT(*) AS session_count,
    SUM(
        CASE
            WHEN s.status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_sessions,
    COUNT(DISTINCT s.machine) AS client_machines
FROM gv$session s
JOIN gv$instance i
    ON i.inst_id = s.inst_id
WHERE s.username IS NOT NULL
GROUP BY
    s.inst_id,
    i.instance_name,
    i.host_name,
    s.service_name
ORDER BY
    s.service_name,
    s.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 7. SERVICE CONNECTION DISTRIBUTION
PROMPT ============================================================

WITH service_sessions AS
(
    SELECT
        inst_id,
        service_name,
        COUNT(*) AS session_count
    FROM gv$session
    WHERE username IS NOT NULL
    GROUP BY
        inst_id,
        service_name
),
service_totals AS
(
    SELECT
        service_name,
        SUM(session_count) AS total_sessions
    FROM service_sessions
    GROUP BY service_name
)
SELECT
    ss.inst_id,
    ss.service_name,
    ss.session_count,
    st.total_sessions,
    ROUND(
        ss.session_count * 100 /
        NULLIF(st.total_sessions, 0),
        2
    ) AS session_pct
FROM service_sessions ss
JOIN service_totals st
    ON st.service_name = ss.service_name
ORDER BY
    ss.service_name,
    ss.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 8. SERVICES USING ONLY ONE INSTANCE
PROMPT ============================================================

SELECT
    service_name,
    COUNT(DISTINCT inst_id) AS instance_count,
    COUNT(*) AS session_count
FROM gv$session
WHERE username IS NOT NULL
GROUP BY service_name
HAVING COUNT(DISTINCT inst_id) = 1
ORDER BY service_name;


PROMPT
PROMPT ============================================================
PROMPT 9. USER CONNECTIONS BY INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    i.host_name,
    COUNT(*) AS user_sessions,
    COUNT(DISTINCT s.machine) AS client_machines,
    COUNT(DISTINCT s.service_name) AS services
FROM gv$session s
JOIN gv$instance i
    ON i.inst_id = s.inst_id
WHERE s.username IS NOT NULL
GROUP BY
    s.inst_id,
    i.instance_name,
    i.host_name
ORDER BY s.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 10. CLIENT / PROGRAM CONNECTION DISTRIBUTION
PROMPT ============================================================

SELECT
    inst_id,
    machine,
    program,
    service_name,
    COUNT(*) AS session_count,
    SUM(
        CASE
            WHEN status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_sessions
FROM gv$session
WHERE username IS NOT NULL
GROUP BY
    inst_id,
    machine,
    program,
    service_name
ORDER BY session_count DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 11. SERVICES WITH NO CURRENT USER SESSIONS
PROMPT ============================================================

SELECT
    svc.inst_id,
    svc.name AS service_name,
    svc.network_name,
    svc.enabled
FROM gv$services svc
WHERE NOT EXISTS
(
    SELECT 1
    FROM gv$session s
    WHERE s.inst_id = svc.inst_id
      AND s.username IS NOT NULL
      AND s.service_name = svc.name
)
ORDER BY
    svc.name,
    svc.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 12. LISTENER / SQL*NET WAIT EVENTS
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
FROM gv$system_event
WHERE LOWER(event) LIKE '%listener%'
   OR LOWER(event) LIKE '%sql*net%'
   OR LOWER(event) LIKE '%network%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 13. CURRENT NETWORK / LISTENER WAITERS
PROMPT ============================================================

SELECT
    inst_id,
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    state,
    seconds_in_wait,
    service_name,
    machine,
    program
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND (
        LOWER(event) LIKE '%listener%'
        OR LOWER(event) LIKE '%sql*net%'
        OR LOWER(event) LIKE '%network%'
      )
ORDER BY seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. SQL*NET STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value
FROM gv$sysstat
WHERE LOWER(name) LIKE '%sql*net%'
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================
PROMPT 15. LOGON / CONNECTION ACTIVITY
PROMPT ============================================================

SELECT
    inst_id,
    name AS stat_name,
    value
FROM gv$sysstat
WHERE LOWER(name) IN
(
    'logons current',
    'logons cumulative',
    'user calls'
)
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================
PROMPT 16. CURRENT SESSION RESOURCE USAGE
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
ORDER BY inst_id, resource_name;


PROMPT
PROMPT ============================================================
PROMPT 17. BLOCKED SESSIONS BY INSTANCE
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
PROMPT 18. RAC LISTENER DATABASE-SIDE HEALTH SUMMARY
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status AS instance_status,
    i.database_status,
    COUNT(s.sid) AS total_sessions,
    SUM(
        CASE
            WHEN s.username IS NOT NULL
            THEN 1
            ELSE 0
        END
    ) AS user_sessions,
    SUM(
        CASE
            WHEN s.username IS NOT NULL
             AND s.status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_sessions,
    CASE
        WHEN i.status <> 'OPEN'
            THEN 'WARNING - INSTANCE NOT OPEN'
        WHEN i.database_status <> 'NORMAL'
            THEN 'REVIEW - DATABASE STATUS'
        ELSE
            'DATABASE SIDE CHECK OK'
    END AS health_status
FROM gv$instance i
LEFT JOIN gv$session s
    ON s.inst_id = i.inst_id
GROUP BY
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status,
    i.database_status
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 19. QUICK LISTENER CHECK
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    database_status
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 20. DBA LISTENER INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT If RAC listener connectivity is reported as unhealthy:
PROMPT
PROMPT 1. Check local listener status:
PROMPT      srvctl status listener
PROMPT
PROMPT 2. Check listener configuration:
PROMPT      srvctl config listener
PROMPT
PROMPT 3. Check SCAN listener status:
PROMPT      srvctl status scan_listener
PROMPT
PROMPT 4. Check SCAN listener configuration:
PROMPT      srvctl config scan_listener
PROMPT
PROMPT 5. Check listener endpoints:
PROMPT      lsnrctl status
PROMPT
PROMPT 6. Check all Clusterware resources:
PROMPT      crsctl status resource -t
PROMPT
PROMPT 7. Check LOCAL_LISTENER on each RAC instance.
PROMPT
PROMPT 8. Check REMOTE_LISTENER / SCAN configuration.
PROMPT
PROMPT 9. Verify service registration with listeners.
PROMPT
PROMPT 10. Check service distribution across RAC instances.
PROMPT 11. Check listener.log for registration/connectivity errors.
PROMPT 12. Check DNS resolution for SCAN/VIP names.
PROMPT 13. Check client-to-VIP/SCAN network connectivity.
PROMPT 14. Check session/process resource limits.
PROMPT 15. Check whether connection imbalance is intentional.
PROMPT 16. Correlate database symptoms with Clusterware and OS data.
PROMPT 17. Do NOT conclude listener failure from SQL views alone.
PROMPT
PROMPT ============================================================
PROMPT Useful external commands:
PROMPT
PROMPT srvctl status listener
PROMPT srvctl config listener
PROMPT srvctl status scan_listener
PROMPT srvctl config scan_listener
PROMPT
PROMPT lsnrctl status
PROMPT
PROMPT crsctl status resource -t
PROMPT
PROMPT ============================================================
PROMPT Notes:
PROMPT - Listener resources are managed by Oracle Clusterware.
PROMPT - GV$ views provide database-side registration and
PROMPT   connection visibility.
PROMPT - They do not directly prove listener process health.
PROMPT - SQL*Net/network waits require OS and application correlation.
PROMPT - A service on one instance may be intentional.
PROMPT - Session imbalance does not automatically indicate a
PROMPT   listener/load-balancing problem.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC LISTENER STATUS MONITORING COMPLETE
PROMPT ============================================================
 
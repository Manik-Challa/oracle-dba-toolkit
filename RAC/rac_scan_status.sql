-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_scan_status.sql
-- Purpose: Monitor Oracle RAC SCAN configuration and connectivity
-- Scope  : SCAN parameters, listeners, services, registrations,
--          connection distribution and network wait indicators
--
-- IMPORTANT:
-- This SQL script provides database-side visibility only.
-- Authoritative SCAN resource status requires:
--   srvctl status scan
--   srvctl config scan
--   srvctl status scan_listener
--   srvctl config scan_listener
--   crsctl status resource -t
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name       FORMAT A18
COLUMN host_name           FORMAT A30
COLUMN parameter_name      FORMAT A30
COLUMN parameter_value     FORMAT A100
COLUMN service_name        FORMAT A35
COLUMN network_name        FORMAT A45
COLUMN machine             FORMAT A35
COLUMN program             FORMAT A40
COLUMN event               FORMAT A65
COLUMN wait_class          FORMAT A20
COLUMN status              FORMAT A20
COLUMN database_status     FORMAT A20

PROMPT
PROMPT ============================================================
PROMPT 1. RAC INSTANCE / NODE INFORMATION
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
PROMPT 2. REMOTE LISTENER / SCAN CONFIGURATION
PROMPT ============================================================

SELECT
    inst_id,
    name AS parameter_name,
    value AS parameter_value
FROM gv$parameter
WHERE name IN
(
    'remote_listener',
    'local_listener',
    'listener_networks'
)
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================
PROMPT 3. ALL LISTENER-RELATED PARAMETERS
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
PROMPT 4. RAC SERVICES / NETWORK NAMES
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
PROMPT 5. SERVICE REGISTRATION BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS registered_sessions,
    SUM(
        CASE
            WHEN status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_sessions,
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
PROMPT 6. SERVICE SESSION DISTRIBUTION
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
PROMPT 7. SERVICES USING ONLY ONE INSTANCE
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
PROMPT 8. CURRENT USER CONNECTIONS BY INSTANCE
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
PROMPT 9. CLIENT CONNECTIONS BY SERVICE
PROMPT ============================================================

SELECT
    service_name,
    machine,
    program,
    COUNT(*) AS session_count,
    COUNT(DISTINCT inst_id) AS instances_used,
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
    service_name,
    machine,
    program
ORDER BY session_count DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 10. DATABASE SERVICES WITH NO CURRENT USER SESSIONS
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
PROMPT 11. SQL*NET / NETWORK WAIT EVENTS
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
WHERE LOWER(event) LIKE '%sql*net%'
   OR LOWER(event) LIKE '%listener%'
   OR LOWER(event) LIKE '%network%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 12. CURRENT NETWORK WAITERS
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
        LOWER(event) LIKE '%sql*net%'
        OR LOWER(event) LIKE '%listener%'
        OR LOWER(event) LIKE '%network%'
      )
ORDER BY seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 13. SQL*NET SYSTEM STATISTICS
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
PROMPT 14. LOGON ACTIVITY BY INSTANCE
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
PROMPT 15. INSTANCE SESSION DISTRIBUTION
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    i.status,
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
    ) AS active_user_sessions
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
PROMPT 16. SERVICE LOAD BALANCE SUMMARY
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
        SUM(session_count) AS total_sessions,
        COUNT(*) AS instance_count
    FROM service_sessions
    GROUP BY service_name
)
SELECT
    ss.service_name,
    ss.inst_id,
    ss.session_count,
    st.total_sessions,
    st.instance_count,
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
PROMPT 17. CURRENT BLOCKED SESSIONS BY INSTANCE
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
PROMPT 18. SCAN / SERVICE DATABASE-SIDE HEALTH SUMMARY
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
PROMPT 19. QUICK SCAN DATABASE CHECK
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
PROMPT 20. DBA SCAN INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT If SCAN connectivity or load balancing is reported as unhealthy:
PROMPT
PROMPT 1. Check SCAN configuration:
PROMPT      srvctl config scan
PROMPT
PROMPT 2. Check SCAN VIP/resource status:
PROMPT      srvctl status scan
PROMPT
PROMPT 3. Check SCAN listeners:
PROMPT      srvctl config scan_listener
PROMPT      srvctl status scan_listener
PROMPT
PROMPT 4. Check all Clusterware resources:
PROMPT      crsctl status resource -t
PROMPT
PROMPT 5. Check SCAN listener endpoints:
PROMPT      lsnrctl status
PROMPT
PROMPT 6. Verify remote_listener on all RAC instances.
PROMPT
PROMPT 7. Verify service registration with SCAN listeners.
PROMPT
PROMPT 8. Check service distribution across RAC instances.
PROMPT
PROMPT 9. Check client connection distribution.
PROMPT
PROMPT 10. Check DNS resolution for SCAN names.
PROMPT
PROMPT 11. Verify SCAN resolves to the expected number of addresses.
PROMPT
PROMPT 12. Check network connectivity from application hosts.
PROMPT
PROMPT 13. Review listener and Clusterware logs for registration failures.
PROMPT
PROMPT 14. Check service placement and preferred/available instances.
PROMPT
PROMPT 15. Do NOT conclude SCAN failure from database views alone.
PROMPT
PROMPT
PROMPT ============================================================
PROMPT Example external checks:
PROMPT
PROMPT nslookup <SCAN_NAME>
PROMPT
PROMPT srvctl config scan
PROMPT srvctl status scan
PROMPT srvctl config scan_listener
PROMPT srvctl status scan_listener
PROMPT crsctl status resource -t
PROMPT
PROMPT ============================================================
PROMPT Notes:
PROMPT - SCAN VIP/listener resources are managed by Clusterware.
PROMPT - GV$ views provide database-side registration and connection
PROMPT   visibility but do not directly prove SCAN resource health.
PROMPT - A service using only one instance may be intentional.
PROMPT - Session imbalance does not automatically indicate SCAN failure.
PROMPT - SQL*Net/network waits require application and OS correlation.
PROMPT - DNS configuration is an important part of SCAN connectivity.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC SCAN STATUS MONITORING COMPLETE
PROMPT ============================================================
 
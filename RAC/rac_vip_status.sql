```sql
-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_vip_status.sql
-- Purpose: Monitor Oracle RAC VIP configuration and status
-- Scope  : VIP-related configuration, node mapping, services,
--          SCAN visibility and database-side connectivity checks
--
-- IMPORTANT:
-- This SQL script provides database-side visibility only.
-- Actual VIP resource state must be verified with:
--   srvctl status vip
--   crsctl status resource
--   srvctl config vip
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name       FORMAT A18
COLUMN host_name           FORMAT A30
COLUMN network_name        FORMAT A40
COLUMN service_name        FORMAT A30
COLUMN vip_name            FORMAT A30
COLUMN parameter_name      FORMAT A35
COLUMN parameter_value     FORMAT A100
COLUMN status              FORMAT A20
COLUMN database_status     FORMAT A20
COLUMN listener_status     FORMAT A20
COLUMN machine             FORMAT A30
COLUMN program             FORMAT A35

PROMPT
PROMPT ============================================================
PROMPT 1. RAC INSTANCE / NODE INFORMATION
PROMPT ============================================================

SELECT
    inst_id,
    instance_number,
    instance_name,
    host_name,
    status,
    database_status,
    version,
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
WHERE name IN
(
    'local_listener',
    'remote_listener'
)
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================
PROMPT 3. LISTENER NETWORK CONFIGURATION
PROMPT ============================================================

SELECT
    inst_id,
    name AS parameter_name,
    value AS parameter_value
FROM gv$parameter
WHERE name LIKE '%listener%'
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================
PROMPT 4. RAC SERVICES AND NETWORK NAMES
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
PROMPT 5. SERVICE TO INSTANCE DISTRIBUTION
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    i.host_name,
    s.service_name,
    COUNT(*) AS session_count,
    SUM(
        CASE
            WHEN s.status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_sessions
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
PROMPT 6. CURRENT USER CONNECTIONS BY INSTANCE
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
PROMPT 7. REMOTE CLIENT CONNECTIONS
PROMPT ============================================================

SELECT
    inst_id,
    machine,
    program,
    service_name,
    COUNT(*) AS session_count,
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
    machine,
    program,
    service_name
ORDER BY session_count DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 8. CLIENT CONNECTIONS BY SERVICE
PROMPT ============================================================

SELECT
    service_name,
    COUNT(*) AS session_count,
    COUNT(DISTINCT machine) AS client_machines,
    COUNT(DISTINCT inst_id) AS instances_used,
    SUM(
        CASE
            WHEN status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_sessions
FROM gv$session
WHERE username IS NOT NULL
GROUP BY service_name
ORDER BY session_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. CONNECTIONS BY CLIENT MACHINE AND INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    machine,
    COUNT(*) AS session_count,
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
    machine
ORDER BY session_count DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 10. DATABASE SERVICES WITH NO USER SESSIONS
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
PROMPT 11. CURRENT NETWORK / LISTENER RELATED WAITS
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
PROMPT 12. CURRENT NETWORK-RELATED WAITERS
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
PROMPT 13. SQL*NET MESSAGE STATISTICS
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
PROMPT 14. SESSION CONNECTION / LOGON ACTIVITY
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
PROMPT 15. INSTANCE CONNECTION SUMMARY
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
            WHEN s.username IS NOT NULL THEN 1
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
PROMPT 16. SERVICE CONNECTION BALANCE
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
PROMPT 17. SERVICES USING ONLY ONE RAC INSTANCE
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
PROMPT 18. VIP / SCAN RELATED PARAMETERS
PROMPT ============================================================

SELECT
    inst_id,
    name AS parameter_name,
    value AS parameter_value
FROM gv$parameter
WHERE LOWER(name) IN
(
    'local_listener',
    'remote_listener',
    'listener_networks'
)
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================
PROMPT 19. RAC VIP DATABASE-SIDE HEALTH SUMMARY
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
PROMPT 20. QUICK VIP CONNECTIVITY CHECK
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
PROMPT 21. DBA VIP INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT If RAC VIP connectivity is reported as unhealthy:
PROMPT
PROMPT 1. Check VIP resource status:
PROMPT      srvctl status vip
PROMPT
PROMPT 2. Check VIP configuration:
PROMPT      srvctl config vip
PROMPT
PROMPT 3. Check all Clusterware resources:
PROMPT      crsctl status resource -t
PROMPT
PROMPT 4. Check SCAN VIP/listener resources:
PROMPT      srvctl status scan
PROMPT      srvctl status scan_listener
PROMPT
PROMPT 5. Check local listeners:
PROMPT      srvctl status listener
PROMPT
PROMPT 6. Check listener endpoints and registrations:
PROMPT      lsnrctl status
PROMPT
PROMPT 7. Check local_listener and remote_listener parameters.
PROMPT
PROMPT 8. Check service distribution across RAC instances.
PROMPT
PROMPT 9. Check client connection failures and application logs.
PROMPT
PROMPT 10. Check DNS resolution for VIP/SCAN names.
PROMPT
PROMPT 11. Check network interface and IP configuration at OS level.
PROMPT
PROMPT 12. Check VIP relocation/failover history in Clusterware logs.
PROMPT 13. Correlate with node/network failures.
PROMPT 14. Do NOT conclude VIP failure from database views alone.
PROMPT
PROMPT ============================================================
PROMPT Notes:
PROMPT - Oracle SQL views do not directly prove VIP resource health.
PROMPT - VIP state is managed by Oracle Clusterware.
PROMPT - Use srvctl/crsctl for authoritative VIP status.
PROMPT - Database session distribution helps identify routing symptoms.
PROMPT - A service using one instance may be intentional.
PROMPT - Network waits do not automatically indicate VIP failure.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC VIP STATUS MONITORING COMPLETE
PROMPT ============================================================
 
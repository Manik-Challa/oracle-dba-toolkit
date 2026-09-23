-- ============================================================
-- Oracle DBA Toolkit
-- Database Services Status Monitoring
--
-- Purpose:
--   Monitor Oracle database services and their availability.
--
-- Key checks:
--   - Service name
--   - Network name
--   - Service status
--   - PDB association
--   - RAC instance distribution
--   - Service workload
--   - Service session count
--   - Service configuration
--
-- Notes:
--   Run from CDB$ROOT when monitoring a multitenant database.
--   GV$ views provide visibility across RAC instances.
--   This script is diagnostic only.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN service_name       FORMAT A30
COLUMN network_name      FORMAT A35
COLUMN pdb_name          FORMAT A30
COLUMN instance_name     FORMAT A20
COLUMN host_name         FORMAT A35
COLUMN status             FORMAT A15
COLUMN enabled            FORMAT A12
COLUMN goal               FORMAT A15
COLUMN clb_goal           FORMAT A15
COLUMN aq_ha_notification FORMAT A20
COLUMN session_count      FORMAT 999,999,999
COLUMN active_sessions    FORMAT 999,999,999
COLUMN instance_count     FORMAT 999
COLUMN con_id             FORMAT 999

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE SERVICES
PROMPT ============================================================

SELECT
    name AS service_name,
    network_name,
    con_id,
    enabled,
    goal,
    clb_goal,
    aq_ha_notification
FROM v$services
ORDER BY con_id, name;


PROMPT
PROMPT ============================================================
PROMPT 2. SERVICES BY CONTAINER / PDB
PROMPT ============================================================

SELECT
    s.con_id,
    NVL(p.name, 'CDB$ROOT') AS pdb_name,
    s.name AS service_name,
    s.network_name,
    s.enabled
FROM v$services s
LEFT JOIN v$pdbs p
    ON p.con_id = s.con_id
ORDER BY s.con_id, s.name;


PROMPT
PROMPT ============================================================
PROMPT 3. RAC SERVICE DISTRIBUTION
PROMPT ============================================================

SELECT
    inst_id,
    name AS service_name,
    network_name,
    con_id,
    enabled
FROM gv$services
ORDER BY name, inst_id;


PROMPT
PROMPT ============================================================
PROMPT 4. SERVICE INSTANCE COUNT
PROMPT ============================================================

SELECT
    name AS service_name,
    con_id,
    COUNT(DISTINCT inst_id) AS instance_count
FROM gv$services
GROUP BY name, con_id
ORDER BY instance_count DESC, service_name;


PROMPT
PROMPT ============================================================
PROMPT 5. SERVICE TO INSTANCE MAPPING
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    i.host_name,
    s.name AS service_name,
    s.network_name,
    s.con_id,
    s.enabled
FROM gv$services s
JOIN gv$instance i
    ON i.inst_id = s.inst_id
ORDER BY s.name, s.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 6. SERVICE SESSION COUNT
PROMPT ============================================================

SELECT
    NVL(s.service_name, '<NO SERVICE>') AS service_name,
    COUNT(*) AS session_count,
    SUM(
        CASE
            WHEN s.status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_sessions
FROM gv$session s
WHERE s.type = 'USER'
GROUP BY s.service_name
ORDER BY session_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. SERVICE SESSION COUNT BY INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    NVL(s.service_name, '<NO SERVICE>') AS service_name,
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
WHERE s.type = 'USER'
GROUP BY
    s.inst_id,
    i.instance_name,
    s.service_name
ORDER BY session_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. ACTIVE SESSIONS BY SERVICE
PROMPT ============================================================

SELECT
    NVL(service_name, '<NO SERVICE>') AS service_name,
    COUNT(*) AS active_sessions
FROM gv$session
WHERE type = 'USER'
  AND status = 'ACTIVE'
GROUP BY service_name
ORDER BY active_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. SERVICE SESSION DISTRIBUTION ACROSS RAC
PROMPT ============================================================

SELECT
    s.service_name,
    s.inst_id,
    i.instance_name,
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
WHERE s.type = 'USER'
  AND s.service_name IS NOT NULL
GROUP BY
    s.service_name,
    s.inst_id,
    i.instance_name
ORDER BY s.service_name, session_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. SERVICES WITH HIGH SESSION COUNTS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        NVL(service_name, '<NO SERVICE>') AS service_name,
        COUNT(*) AS session_count,
        SUM(
            CASE
                WHEN status = 'ACTIVE' THEN 1
                ELSE 0
            END
        ) AS active_sessions
    FROM gv$session
    WHERE type = 'USER'
    GROUP BY service_name
    ORDER BY session_count DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 11. ACTIVE SERVICE WORKLOAD
PROMPT ============================================================

SELECT
    NVL(service_name, '<NO SERVICE>') AS service_name,
    COUNT(*) AS active_sessions,
    SUM(
        CASE
            WHEN wait_class = 'User I/O' THEN 1
            ELSE 0
        END
    ) AS user_io_waits,
    SUM(
        CASE
            WHEN wait_class = 'Concurrency' THEN 1
            ELSE 0
        END
    ) AS concurrency_waits,
    SUM(
        CASE
            WHEN wait_class = 'Application' THEN 1
            ELSE 0
        END
    ) AS application_waits
FROM gv$session
WHERE type = 'USER'
  AND status = 'ACTIVE'
GROUP BY service_name
ORDER BY active_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 12. SERVICES BY PDB
PROMPT ============================================================

SELECT
    s.con_id,
    p.name AS pdb_name,
    s.name AS service_name,
    s.network_name,
    s.enabled
FROM gv$services s
JOIN v$pdbs p
    ON p.con_id = s.con_id
WHERE s.con_id > 2
ORDER BY p.name, s.name, s.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 13. SERVICE STATUS CHECK
PROMPT ============================================================

SELECT
    s.con_id,
    NVL(p.name, 'CDB$ROOT') AS pdb_name,
    s.name AS service_name,
    s.network_name,
    s.enabled,
    CASE
        WHEN s.enabled = 'ENABLED'
        THEN 'OK'
        ELSE 'CHECK'
    END AS health_status
FROM v$services s
LEFT JOIN v$pdbs p
    ON p.con_id = s.con_id
ORDER BY s.con_id, s.name;


PROMPT
PROMPT ============================================================
PROMPT 14. RAC SERVICE INSTANCE COVERAGE
PROMPT ============================================================

SELECT
    name AS service_name,
    con_id,
    COUNT(DISTINCT inst_id) AS instance_count,
    LISTAGG(DISTINCT inst_id, ', ')
        WITHIN GROUP (ORDER BY inst_id) AS instance_ids
FROM gv$services
GROUP BY name, con_id
ORDER BY name;


PROMPT
PROMPT ============================================================
PROMPT 15. USER SESSIONS WITHOUT A SERVICE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS sessions_without_service,
    SUM(
        CASE
            WHEN status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_sessions
FROM gv$session
WHERE type = 'USER'
  AND service_name IS NULL
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 16. SERVICE HEALTH SUMMARY
PROMPT ============================================================

SELECT
    COUNT(DISTINCT name) AS service_count,
    COUNT(DISTINCT inst_id) AS instance_count,
    COUNT(*) AS service_instance_entries
FROM gv$services;


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION NOTES
PROMPT ============================================================
PROMPT
PROMPT 1. V$SERVICES shows database services known to the instance.
PROMPT
PROMPT 2. GV$SERVICES provides service visibility across RAC instances.
PROMPT
PROMPT 3. Review service-to-instance mapping when users report
PROMPT    connection or workload-routing problems.
PROMPT
PROMPT 4. Check PDB association for application services in a
PROMPT    multitenant environment.
PROMPT
PROMPT 5. Review session distribution across RAC instances when
PROMPT    workload appears unexpectedly concentrated on one node.
PROMPT
PROMPT 6. High session counts do not automatically indicate a problem.
PROMPT    Correlate with application connection pooling and workload.
PROMPT
PROMPT 7. A service being visible in GV$SERVICES does not by itself
PROMPT    confirm that client connectivity is working.
PROMPT
PROMPT 8. For service-level connection problems, also check:
PROMPT       - srvctl status service
PROMPT       - listener status
PROMPT       - SCAN/listener configuration
PROMPT       - DNS
PROMPT       - tnsnames.ora
PROMPT       - application connection pool
PROMPT       - Clusterware events
PROMPT
PROMPT 9. For RAC service management, use SRVCTL/Clusterware commands
PROMPT    according to the environment. Do not modify services from
PROMPT    this monitoring script.
PROMPT
PROMPT 10. This script is diagnostic only.
PROMPT
PROMPT ============================================================
PROMPT END OF DATABASE SERVICES MONITORING
PROMPT ============================================================


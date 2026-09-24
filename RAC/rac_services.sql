-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_services.sql
-- Purpose: Monitor Oracle RAC services and instance distribution
-- Scope  : Services, instances, sessions, PDB association,
--          service load distribution and health
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

-- ============================================================
-- COLUMN FORMATS
-- ============================================================

COLUMN SERVICE_NAME             FORMAT A35
COLUMN NETWORK_NAME             FORMAT A50
COLUMN INSTANCE_NAME            FORMAT A20
COLUMN HOST_NAME                FORMAT A40
COLUMN PDB                      FORMAT A20
COLUMN ENABLED                  FORMAT A10
COLUMN GOAL                    FORMAT A15
COLUMN CLB_GOAL                FORMAT A15
COLUMN DTP                     FORMAT A10
COLUMN AQ_HA_NOTIFICATIONS      FORMAT A10

COLUMN STATUS                   FORMAT A15
COLUMN SERVICE_STATUS           FORMAT A20
COLUMN INSTANCE_STATUS          FORMAT A20

COLUMN SESSION_COUNT            FORMAT 999,999
COLUMN ACTIVE_SESSIONS          FORMAT 999,999
COLUMN INACTIVE_SESSIONS        FORMAT 999,999
COLUMN BLOCKED_SESSIONS         FORMAT 999,999

COLUMN CPU_SESSIONS             FORMAT 999,999
COLUMN NON_IDLE_SESSIONS        FORMAT 999,999
COLUMN TRANSACTIONS             FORMAT 999,999

COLUMN SESSION_PCT              FORMAT 990.99
COLUMN ACTIVE_PCT               FORMAT 990.99

COLUMN EVENT                    FORMAT A45
COLUMN WAIT_CLASS               FORMAT A20
COLUMN WAITERS                  FORMAT 999,999

COLUMN HEALTH_STATUS            FORMAT A50

PROMPT
PROMPT ============================================================
PROMPT ORACLE RAC SERVICES MONITORING
PROMPT ============================================================

-- ============================================================
-- 1. DATABASE INFORMATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE INFORMATION
PROMPT ============================================================

SELECT
    name,
    db_unique_name,
    open_mode,
    database_role
FROM v$database;

-- ============================================================
-- 2. RAC SERVICES CONFIGURATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. RAC SERVICES CONFIGURATION
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
ORDER BY
    name,
    inst_id;

-- ============================================================
-- 3. SERVICE / INSTANCE DISTRIBUTION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. SERVICE / INSTANCE DISTRIBUTION
PROMPT ============================================================

SELECT
    s.name AS service_name,
    i.instance_name,
    i.host_name,
    i.status AS instance_status,
    s.enabled,
    s.network_name,
    s.clb_goal,
    s.goal
FROM gv$services s
JOIN gv$instance i
    ON i.inst_id = s.inst_id
ORDER BY
    s.name,
    i.instance_name;

-- ============================================================
-- 4. SERVICE SESSION DISTRIBUTION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. SERVICE SESSION DISTRIBUTION
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS session_count,
    SUM(
        CASE
            WHEN status = 'ACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS active_sessions,
    SUM(
        CASE
            WHEN status = 'INACTIVE'
            THEN 1
            ELSE 0
        END
    ) AS inactive_sessions
FROM gv$session
WHERE username IS NOT NULL
GROUP BY
    inst_id,
    service_name
ORDER BY
    service_name,
    inst_id;

-- ============================================================
-- 5. SERVICE SESSION PERCENTAGE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. SERVICE SESSION DISTRIBUTION PERCENTAGE
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
)
SELECT
    inst_id,
    service_name,
    session_count,
    ROUND(
        session_count /
        NULLIF(
            SUM(session_count)
            OVER (PARTITION BY service_name),
            0
        ) * 100,
        2
    ) AS session_pct
FROM service_sessions
ORDER BY
    service_name,
    inst_id;

-- ============================================================
-- 6. ACTIVE SESSION DISTRIBUTION BY SERVICE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. ACTIVE SESSION DISTRIBUTION
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS active_sessions
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
GROUP BY
    inst_id,
    service_name
ORDER BY
    service_name,
    active_sessions DESC;

-- ============================================================
-- 7. BLOCKED SESSIONS BY SERVICE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. BLOCKED SESSIONS BY SERVICE
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS blocked_sessions
FROM gv$session
WHERE username IS NOT NULL
  AND blocking_session IS NOT NULL
GROUP BY
    inst_id,
    service_name
ORDER BY
    blocked_sessions DESC;

-- ============================================================
-- 8. CPU / RESOURCE MANAGER ACTIVITY BY SERVICE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. CPU / RESOURCE MANAGER ACTIVITY BY SERVICE
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS cpu_sessions
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND (
        wait_class = 'CPU'
        OR event = 'resmgr:cpu quantum'
      )
GROUP BY
    inst_id,
    service_name
ORDER BY
    cpu_sessions DESC;

-- ============================================================
-- 9. NON-IDLE WAITS BY SERVICE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. NON-IDLE WAITS BY SERVICE
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    event,
    wait_class,
    COUNT(*) AS waiters
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND wait_class <> 'Idle'
GROUP BY
    inst_id,
    service_name,
    event,
    wait_class
ORDER BY
    service_name,
    waiters DESC;

-- ============================================================
-- 10. TOP SERVICES BY SESSION COUNT
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. TOP SERVICES BY SESSION COUNT
PROMPT ============================================================

SELECT
    service_name,
    COUNT(*) AS session_count,
    SUM(
        CASE
            WHEN status = 'ACTIVE'
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
WHERE username IS NOT NULL
GROUP BY
    service_name
ORDER BY
    session_count DESC;

-- ============================================================
-- 11. SERVICE / PDB ASSOCIATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. SERVICE / PDB ASSOCIATION
PROMPT ============================================================

SELECT
    inst_id,
    name AS service_name,
    network_name,
    pdb,
    enabled,
    goal,
    clb_goal
FROM gv$services
ORDER BY
    pdb,
    name,
    inst_id;

-- ============================================================
-- 12. SERVICE CLIENT DISTRIBUTION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. SERVICE CLIENT DISTRIBUTION
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    machine,
    program,
    COUNT(*) AS session_count
FROM gv$session
WHERE username IS NOT NULL
GROUP BY
    inst_id,
    service_name,
    machine,
    program
ORDER BY
    service_name,
    session_count DESC;

-- ============================================================
-- 13. SERVICE TRANSACTIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. ACTIVE TRANSACTIONS BY SERVICE
PROMPT ============================================================

SELECT
    s.inst_id,
    s.service_name,
    COUNT(*) AS transactions
FROM gv$transaction t
JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND s.taddr = t.addr
WHERE s.username IS NOT NULL
GROUP BY
    s.inst_id,
    s.service_name
ORDER BY
    transactions DESC;

-- ============================================================
-- 14. SERVICE WAIT SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. SERVICE WAIT SUMMARY
PROMPT ============================================================

SELECT
    service_name,
    wait_class,
    COUNT(*) AS waiters
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND wait_class <> 'Idle'
GROUP BY
    service_name,
    wait_class
ORDER BY
    service_name,
    waiters DESC;

-- ============================================================
-- 15. SERVICE HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. RAC SERVICE HEALTH CHECK
PROMPT ============================================================

SELECT
    s.inst_id,
    s.name AS service_name,
    i.instance_name,
    i.host_name,
    i.status AS instance_status,
    s.enabled,
    CASE
        WHEN i.status <> 'OPEN'
            THEN 'WARNING - INSTANCE NOT OPEN'

        WHEN s.enabled <> 'ENABLED'
            THEN 'CHECK - SERVICE NOT ENABLED'

        ELSE 'OK'
    END AS health_status
FROM gv$services s
JOIN gv$instance i
    ON i.inst_id = s.inst_id
ORDER BY
    s.name,
    s.inst_id;

-- ============================================================
-- 16. SERVICES WITH NO CURRENT USER SESSIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. SERVICES WITH NO CURRENT USER SESSIONS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.name AS service_name,
    s.network_name,
    s.pdb,
    s.enabled
FROM gv$services s
WHERE NOT EXISTS
(
    SELECT 1
    FROM gv$session sess
    WHERE sess.inst_id = s.inst_id
      AND sess.service_name = s.name
      AND sess.username IS NOT NULL
)
ORDER BY
    s.name,
    s.inst_id;

-- ============================================================
-- 17. SERVICE INSTANCE LOAD
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. SERVICE INSTANCE LOAD
PROMPT ============================================================

WITH service_load AS
(
    SELECT
        inst_id,
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
        service_name
)
SELECT
    inst_id,
    service_name,
    session_count,
    active_sessions,
    ROUND(
        session_count /
        NULLIF(
            SUM(session_count)
            OVER (PARTITION BY service_name),
            0
        ) * 100,
        2
    ) AS session_pct
FROM service_load
ORDER BY
    service_name,
    inst_id;

-- ============================================================
-- 18. QUICK SERVICE CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. QUICK RAC SERVICE CHECK
PROMPT ============================================================

SELECT
    s.inst_id,
    s.name AS service_name,
    i.instance_name,
    i.status AS instance_status,
    s.enabled,
    COUNT(sess.sid) AS session_count,
    CASE
        WHEN i.status <> 'OPEN'
            THEN 'CHECK INSTANCE'

        WHEN s.enabled <> 'ENABLED'
            THEN 'CHECK SERVICE'

        ELSE 'OK'
    END AS health_status
FROM gv$services s
JOIN gv$instance i
    ON i.inst_id = s.inst_id
LEFT JOIN gv$session sess
    ON sess.inst_id = s.inst_id
   AND sess.service_name = s.name
   AND sess.username IS NOT NULL
GROUP BY
    s.inst_id,
    s.name,
    i.instance_name,
    i.status,
    s.enabled
ORDER BY
    s.name,
    s.inst_id;

-- ============================================================
-- 19. DBA CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT DBA CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT 1. Verify expected RAC services are enabled.
PROMPT 2. Verify services are available on the expected instances.
PROMPT 3. Review service/session distribution across instances.
PROMPT 4. Investigate unexpectedly uneven session distribution.
PROMPT 5. Review blocked sessions by service.
PROMPT 6. Review CPU and non-idle waits by service.
PROMPT 7. Check service-to-PDB association.
PROMPT 8. Review client machine/program distribution.
PROMPT 9. Check active transactions by service.
PROMPT 10. Correlate service issues with SCAN/listener/Clusterware.
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT NOTES
PROMPT ============================================================
PROMPT
PROMPT - This script is READ ONLY.
PROMPT - A service with zero sessions is not automatically a problem.
PROMPT - Session imbalance does not automatically indicate an issue;
PROMPT   connection pools, service configuration, workload and
PROMPT   client routing must be considered.
PROMPT - GV$SERVICES provides database-side service visibility.
PROMPT - Database-side service status does not replace checks of
PROMPT   SCAN listeners, local listeners and Clusterware.
PROMPT - Verify service configuration with srvctl when required.
PROMPT
PROMPT ============================================================
PROMPT END OF RAC SERVICES MONITORING
PROMPT ============================================================


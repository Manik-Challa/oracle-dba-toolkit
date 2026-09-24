-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_instance_status.sql
-- Purpose: Monitor Oracle RAC instance status and health
-- Scope  : RAC instances, startup time, host, status,
--          sessions, processes, services and instance load
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

-- ============================================================
-- COLUMN FORMATS
-- ============================================================

COLUMN INSTANCE_NUMBER       FORMAT 999
COLUMN INSTANCE_NAME         FORMAT A20
COLUMN HOST_NAME             FORMAT A40
COLUMN VERSION               FORMAT A20
COLUMN STATUS                FORMAT A15
COLUMN STARTUP_TIME          FORMAT A20
COLUMN DATABASE_STATUS       FORMAT A20
COLUMN PARALLEL              FORMAT A10
COLUMN THREAD                FORMAT 999
COLUMN ARCHIVER              FORMAT A15

COLUMN SESSIONS_CURRENT      FORMAT 999,999
COLUMN SESSIONS_HIGHWATER    FORMAT 999,999
COLUMN SESSIONS_LIMIT       FORMAT 999,999
COLUMN PROCESSES_CURRENT     FORMAT 999,999
COLUMN PROCESSES_LIMIT       FORMAT 999,999

COLUMN ACTIVE_SESSIONS       FORMAT 999,999
COLUMN BLOCKED_SESSIONS      FORMAT 999,999
COLUMN CPU_SESSIONS          FORMAT 999,999

COLUMN SERVICE_NAME         FORMAT A35
COLUMN NETWORK_NAME         FORMAT A50
COLUMN SERVICE_STATUS       FORMAT A15

COLUMN EVENT                 FORMAT A45
COLUMN WAIT_CLASS            FORMAT A20
COLUMN WAITERS               FORMAT 999,999

COLUMN LOAD_STATUS           FORMAT A30
COLUMN HEALTH_STATUS         FORMAT A50

PROMPT
PROMPT ============================================================
PROMPT ORACLE RAC INSTANCE STATUS
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
    database_role,
    protection_mode,
    force_logging
FROM v$database;

-- ============================================================
-- 2. RAC INSTANCE STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. RAC INSTANCE STATUS
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
    TO_CHAR(
        startup_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS startup_time
FROM gv$instance
ORDER BY
    inst_id;

-- ============================================================
-- 3. INSTANCE UPTIME
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. RAC INSTANCE UPTIME
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    TO_CHAR(
        startup_time,
        'YYYY-MM-DD HH24:MI:SS'
    ) AS startup_time,
    ROUND(
        (SYSDATE - startup_time),
        2
    ) AS uptime_days
FROM gv$instance
ORDER BY
    inst_id;

-- ============================================================
-- 4. INSTANCE SESSION / PROCESS USAGE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. SESSION / PROCESS USAGE BY INSTANCE
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,

    (
        SELECT COUNT(*)
        FROM gv$session s
        WHERE s.inst_id = i.inst_id
    ) AS sessions_current,

    (
        SELECT COUNT(*)
        FROM gv$process p
        WHERE p.inst_id = i.inst_id
    ) AS processes_current,

    (
        SELECT value
        FROM gv$parameter p
        WHERE p.inst_id = i.inst_id
          AND p.name = 'sessions'
    ) AS sessions_limit,

    (
        SELECT value
        FROM gv$parameter p
        WHERE p.inst_id = i.inst_id
          AND p.name = 'processes'
    ) AS processes_limit

FROM gv$instance i
ORDER BY
    i.inst_id;

-- ============================================================
-- 5. ACTIVE SESSIONS BY INSTANCE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. ACTIVE SESSIONS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS active_sessions
FROM gv$session
WHERE status = 'ACTIVE'
  AND username IS NOT NULL
GROUP BY
    inst_id
ORDER BY
    inst_id;

-- ============================================================
-- 6. BLOCKED SESSIONS BY INSTANCE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. BLOCKED SESSIONS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS blocked_sessions
FROM gv$session
WHERE blocking_session IS NOT NULL
GROUP BY
    inst_id
ORDER BY
    inst_id;

-- ============================================================
-- 7. CPU-RELATED ACTIVE SESSIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. CPU / RESOURCE MANAGER ACTIVE SESSIONS
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS cpu_sessions
FROM gv$session
WHERE status = 'ACTIVE'
  AND username IS NOT NULL
  AND (
        event = 'resmgr:cpu quantum'
        OR wait_class = 'CPU'
      )
GROUP BY
    inst_id
ORDER BY
    inst_id;

-- ============================================================
-- 8. TOP WAIT EVENTS BY INSTANCE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. TOP CURRENT WAIT EVENTS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    COUNT(*) AS waiters
FROM gv$session
WHERE status = 'ACTIVE'
  AND username IS NOT NULL
  AND wait_class <> 'Idle'
GROUP BY
    inst_id,
    event,
    wait_class
ORDER BY
    inst_id,
    waiters DESC;

-- ============================================================
-- 9. RAC SERVICES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. RAC SERVICES
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
-- 10. SERVICES WITH ACTIVE SESSIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. SERVICE SESSION DISTRIBUTION
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
    ) AS active_sessions
FROM gv$session
WHERE username IS NOT NULL
GROUP BY
    inst_id,
    service_name
ORDER BY
    service_name,
    inst_id;

-- ============================================================
-- 11. INSTANCE TRANSACTIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. ACTIVE TRANSACTIONS BY INSTANCE
PROMPT ============================================================

SELECT
    s.inst_id,
    COUNT(*) AS active_transactions
FROM gv$transaction t
JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND s.taddr = t.addr
GROUP BY
    s.inst_id
ORDER BY
    s.inst_id;

-- ============================================================
-- 12. REDO THREAD STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. RAC REDO THREAD STATUS
PROMPT ============================================================

SELECT
    thread#,
    status,
    enabled,
    groups
FROM v$thread
ORDER BY
    thread#;

-- ============================================================
-- 13. INSTANCE LOAD SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. INSTANCE LOAD SUMMARY
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,

    (
        SELECT COUNT(*)
        FROM gv$session s
        WHERE s.inst_id = i.inst_id
          AND s.status = 'ACTIVE'
          AND s.username IS NOT NULL
    ) AS active_sessions,

    (
        SELECT COUNT(*)
        FROM gv$session s
        WHERE s.inst_id = i.inst_id
          AND s.blocking_session IS NOT NULL
    ) AS blocked_sessions,

    (
        SELECT COUNT(*)
        FROM gv$session s
        WHERE s.inst_id = i.inst_id
          AND s.status = 'ACTIVE'
          AND s.username IS NOT NULL
          AND s.wait_class <> 'Idle'
    ) AS non_idle_sessions

FROM gv$instance i
ORDER BY
    i.inst_id;

-- ============================================================
-- 14. RAC INSTANCE HEALTH
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. RAC INSTANCE HEALTH
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    CASE
        WHEN status <> 'OPEN'
            THEN 'WARNING - INSTANCE NOT OPEN'

        WHEN database_status <> 'NORMAL'
            THEN 'WARNING - DATABASE STATUS NOT NORMAL'

        ELSE 'HEALTHY - INSTANCE OPEN'
    END AS health_status
FROM gv$instance
ORDER BY
    inst_id;

-- ============================================================
-- 15. INSTANCE DISTRIBUTION CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. ACTIVE SESSION DISTRIBUTION
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    active_sessions,
    ROUND(
        active_sessions /
        NULLIF(
            SUM(active_sessions) OVER (),
            0
        ) * 100,
        2
    ) AS active_session_pct
FROM
(
    SELECT
        i.inst_id,
        i.instance_name,
        (
            SELECT COUNT(*)
            FROM gv$session s
            WHERE s.inst_id = i.inst_id
              AND s.status = 'ACTIVE'
              AND s.username IS NOT NULL
        ) AS active_sessions
    FROM gv$instance i
)
ORDER BY
    inst_id;

-- ============================================================
-- 16. QUICK RAC CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. QUICK RAC CHECK
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    database_status,
    CASE
        WHEN status = 'OPEN'
         AND database_status = 'NORMAL'
        THEN 'OK'
        ELSE 'CHECK INSTANCE'
    END AS health_status
FROM gv$instance
ORDER BY
    inst_id;

-- ============================================================
-- 17. DBA CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT DBA CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT 1. Verify every RAC instance is OPEN.
PROMPT 2. Check DATABASE_STATUS = NORMAL.
PROMPT 3. Review instance startup times for unexpected restarts.
PROMPT 4. Compare active session distribution across instances.
PROMPT 5. Review blocked sessions by instance.
PROMPT 6. Check top non-idle wait events.
PROMPT 7. Review service/session distribution.
PROMPT 8. Verify RAC redo thread status.
PROMPT 9. Check session/process utilization.
PROMPT 10. Correlate abnormal instances with OS and cluster health.
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT NOTES
PROMPT ============================================================
PROMPT
PROMPT - This script is READ ONLY.
PROMPT - Active session distribution is informational only.
PROMPT - Uneven workload does not automatically indicate a problem;
PROMPT   service configuration and application workload must be
PROMPT   considered.
PROMPT - GV$ views provide RAC-wide visibility from the instance
PROMPT   where the query is executed.
PROMPT - For complete cluster diagnostics, correlate with
PROMPT   Clusterware, CRSCTL, OS and network information.
PROMPT
PROMPT ============================================================
PROMPT END OF RAC INSTANCE STATUS
PROMPT ============================================================


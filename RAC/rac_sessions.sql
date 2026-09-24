-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_sessions.sql
-- Purpose: Monitor Oracle RAC sessions across all instances
-- Scope  : Session distribution, activity, waits, blockers,
--          CPU, long-running sessions and session health
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN inst_id          FORMAT 999
COLUMN sid              FORMAT 999999
COLUMN serial           FORMAT 999999
COLUMN username         FORMAT A20
COLUMN status            FORMAT A10
COLUMN service_name     FORMAT A25
COLUMN machine          FORMAT A30
COLUMN program          FORMAT A35
COLUMN sql_id           FORMAT A15
COLUMN event             FORMAT A40
COLUMN wait_class        FORMAT A20
COLUMN module            FORMAT A30
COLUMN logon_time        FORMAT A20
COLUMN last_call_min     FORMAT 999999.99
COLUMN cpu_sec           FORMAT 99999999.99
COLUMN logical_reads    FORMAT 999999999999
COLUMN physical_reads   FORMAT 999999999999

PROMPT
PROMPT ============================================================
PROMPT RAC SESSION MONITORING
PROMPT ============================================================

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


PROMPT
PROMPT ============================================================
PROMPT 2. RAC INSTANCE SESSION SUMMARY
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    i.host_name,
    COUNT(*) AS total_sessions,
    SUM(CASE WHEN s.status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_sessions,
    SUM(CASE WHEN s.status = 'INACTIVE' THEN 1 ELSE 0 END) AS inactive_sessions,
    SUM(CASE WHEN s.type = 'BACKGROUND' THEN 1 ELSE 0 END) AS background_sessions,
    SUM(CASE WHEN s.type = 'USER' THEN 1 ELSE 0 END) AS user_sessions
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
PROMPT 3. USER SESSION DISTRIBUTION BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    username,
    COUNT(*) AS session_count,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_sessions,
    SUM(CASE WHEN status = 'INACTIVE' THEN 1 ELSE 0 END) AS inactive_sessions
FROM gv$session
WHERE username IS NOT NULL
GROUP BY
    inst_id,
    username
ORDER BY
    inst_id,
    session_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 4. ACTIVE RAC SESSIONS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.service_name,
    s.sql_id,
    s.event,
    s.wait_class,
    s.machine,
    s.program,
    s.module
FROM gv$session s
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
ORDER BY
    s.inst_id,
    s.username,
    s.sid;


PROMPT
PROMPT ============================================================
PROMPT 5. ACTIVE SESSIONS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS active_sessions
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 6. ACTIVE SESSIONS BY SERVICE
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
    inst_id;


PROMPT
PROMPT ============================================================
PROMPT 7. RAC SESSION WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    COUNT(*) AS waiting_sessions
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
GROUP BY
    inst_id,
    event,
    wait_class
ORDER BY
    waiting_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. TOP ACTIVE WAITING SESSIONS
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
    blocking_instance,
    blocking_session,
    machine,
    program
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
ORDER BY
    seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. RAC BLOCKING SESSIONS
PROMPT ============================================================

SELECT
    w.inst_id AS waiter_inst,
    w.sid AS waiter_sid,
    w.serial# AS waiter_serial,
    w.username AS waiter_user,
    w.event AS waiter_event,
    w.seconds_in_wait,
    w.blocking_instance AS blocker_inst,
    w.blocking_session AS blocker_sid,
    b.serial# AS blocker_serial,
    b.username AS blocker_user,
    b.status AS blocker_status,
    b.sql_id AS blocker_sql_id,
    b.machine AS blocker_machine
FROM gv$session w
LEFT JOIN gv$session b
    ON b.inst_id = w.blocking_instance
   AND b.sid = w.blocking_session
WHERE w.blocking_session IS NOT NULL
ORDER BY
    w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. SESSIONS WITH BLOCKING SESSION DETAILS
PROMPT ============================================================

SELECT
    w.inst_id AS waiter_inst,
    w.sid AS waiter_sid,
    w.serial# AS waiter_serial,
    w.username AS waiter_user,
    w.sql_id AS waiter_sql_id,
    b.inst_id AS blocker_inst,
    b.sid AS blocker_sid,
    b.serial# AS blocker_serial,
    b.username AS blocker_user,
    b.sql_id AS blocker_sql_id,
    b.status AS blocker_status
FROM gv$session w
JOIN gv$session b
    ON b.inst_id = w.blocking_instance
   AND b.sid = w.blocking_session
WHERE w.blocking_session IS NOT NULL
ORDER BY
    w.inst_id,
    w.sid;


PROMPT
PROMPT ============================================================
PROMPT 11. LONG-RUNNING ACTIVE SESSIONS
PROMPT ============================================================

SELECT
    inst_id,
    sid,
    serial# AS serial,
    username,
    status,
    service_name,
    sql_id,
    ROUND(last_call_et / 60, 2) AS last_call_min,
    event,
    wait_class,
    machine,
    program
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND last_call_et >= 600
ORDER BY
    last_call_et DESC;


PROMPT
PROMPT ============================================================
PROMPT 12. TOP SESSIONS BY CPU
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        s.inst_id,
        s.sid,
        s.serial# AS serial,
        s.username,
        s.sql_id,
        ROUND(st.value / 100, 2) AS cpu_sec,
        s.status,
        s.machine,
        s.program
    FROM gv$sesstat st
    JOIN gv$statname sn
        ON sn.inst_id = st.inst_id
       AND sn.statistic# = st.statistic#
    JOIN gv$session s
        ON s.inst_id = st.inst_id
       AND s.sid = st.sid
    WHERE sn.name = 'CPU used by this session'
      AND s.username IS NOT NULL
    ORDER BY st.value DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 13. TOP SESSIONS BY LOGICAL READS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        s.inst_id,
        s.sid,
        s.serial# AS serial,
        s.username,
        s.sql_id,
        st.value AS logical_reads,
        s.status,
        s.machine,
        s.program
    FROM gv$sesstat st
    JOIN gv$statname sn
        ON sn.inst_id = st.inst_id
       AND sn.statistic# = st.statistic#
    JOIN gv$session s
        ON s.inst_id = st.inst_id
       AND s.sid = st.sid
    WHERE sn.name = 'session logical reads'
      AND s.username IS NOT NULL
    ORDER BY st.value DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 14. TOP SESSIONS BY PHYSICAL READS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        s.inst_id,
        s.sid,
        s.serial# AS serial,
        s.username,
        s.sql_id,
        st.value AS physical_reads,
        s.status,
        s.machine,
        s.program
    FROM gv$sesstat st
    JOIN gv$statname sn
        ON sn.inst_id = st.inst_id
       AND sn.statistic# = st.statistic#
    JOIN gv$session s
        ON s.inst_id = st.inst_id
       AND s.sid = st.sid
    WHERE sn.name = 'physical reads'
      AND s.username IS NOT NULL
    ORDER BY st.value DESC
)
WHERE ROWNUM <= 20;


PROMPT
PROMPT ============================================================
PROMPT 15. SESSION DISTRIBUTION BY MACHINE
PROMPT ============================================================

SELECT
    inst_id,
    machine,
    COUNT(*) AS session_count,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_sessions
FROM gv$session
WHERE username IS NOT NULL
GROUP BY
    inst_id,
    machine
ORDER BY
    session_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 16. SESSION DISTRIBUTION BY PROGRAM
PROMPT ============================================================

SELECT
    inst_id,
    program,
    COUNT(*) AS session_count,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_sessions
FROM gv$session
WHERE username IS NOT NULL
GROUP BY
    inst_id,
    program
ORDER BY
    session_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 17. SESSIONS WITH ACTIVE TRANSACTIONS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    t.start_time,
    t.used_ublk,
    t.used_urec,
    s.machine,
    s.program
FROM gv$transaction t
JOIN gv$session s
    ON s.inst_id = t.inst_id
   AND t.addr = s.taddr
WHERE s.username IS NOT NULL
ORDER BY
    t.used_ublk DESC;


PROMPT
PROMPT ============================================================
PROMPT 18. RAC SESSION SUMMARY BY SERVICE
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    COUNT(*) AS total_sessions,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_sessions,
    SUM(CASE WHEN status = 'INACTIVE' THEN 1 ELSE 0 END) AS inactive_sessions,
    COUNT(DISTINCT username) AS distinct_users
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
PROMPT 19. RAC SESSION HEALTH SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS user_sessions,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_sessions,
    SUM(CASE WHEN blocking_session IS NOT NULL THEN 1 ELSE 0 END) AS blocked_sessions,
    SUM(CASE
            WHEN state = 'WAITING'
             AND wait_class <> 'Idle'
            THEN 1
            ELSE 0
        END) AS non_idle_waiters,
    COUNT(DISTINCT inst_id) AS instances_with_sessions,
    COUNT(DISTINCT username) AS distinct_users
FROM gv$session
WHERE username IS NOT NULL;


PROMPT
PROMPT ============================================================
PROMPT 20. INSTANCE-WISE ACTIVE SESSION HEALTH
PROMPT ============================================================

SELECT
    s.inst_id,
    i.instance_name,
    i.host_name,
    COUNT(*) AS active_sessions,
    SUM(CASE
            WHEN s.state = 'WAITING'
             AND s.wait_class <> 'Idle'
            THEN 1
            ELSE 0
        END) AS non_idle_waiters,
    SUM(CASE
            WHEN s.blocking_session IS NOT NULL
            THEN 1
            ELSE 0
        END) AS blocked_sessions
FROM gv$session s
JOIN gv$instance i
    ON i.inst_id = s.inst_id
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
GROUP BY
    s.inst_id,
    i.instance_name,
    i.host_name
ORDER BY s.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 21. QUICK RAC SESSION CHECK
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS user_sessions,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_sessions,
    SUM(CASE WHEN blocking_session IS NOT NULL THEN 1 ELSE 0 END) AS blocked_sessions
FROM gv$session
WHERE username IS NOT NULL
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT DBA CHECKLIST
PROMPT ============================================================
PROMPT 1. Check session distribution across RAC instances.
PROMPT 2. Review unexpected active-session concentration.
PROMPT 3. Investigate non-idle wait events.
PROMPT 4. Check blocking sessions and cross-instance blockers.
PROMPT 5. Review long-running active sessions.
PROMPT 6. Check top CPU-consuming sessions.
PROMPT 7. Check sessions generating high logical/physical I/O.
PROMPT 8. Review service-to-instance session distribution.
PROMPT 9. Investigate unusually high session counts by machine/program.
PROMPT 10. Check active transactions consuming significant UNDO.
PROMPT
PROMPT NOTE:
PROMPT - Session statistics are generally cumulative counters.
PROMPT - High CPU/I/O does not automatically indicate a problem.
PROMPT - Session imbalance across RAC instances may be intentional.
PROMPT - Validate service configuration and connection-pool behavior.
PROMPT - Use Clusterware/srvctl, SCAN and listener checks for
PROMPT   network/service-level validation.
PROMPT - This script is READ-ONLY and performs no session actions.
PROMPT ============================================================
 
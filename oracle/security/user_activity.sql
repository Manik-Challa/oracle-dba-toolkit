-- ================================================================
-- Oracle DBA Toolkit
-- Script : user_activity.sql
-- Purpose: Monitor Oracle User / Session Activity
-- Usage  : Run as SYS or a user with access to required V$ views
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN username FORMAT A25
COLUMN account_status FORMAT A25
COLUMN machine FORMAT A30
COLUMN program FORMAT A40
COLUMN module FORMAT A30
COLUMN service_name FORMAT A25
COLUMN sql_id FORMAT A15
COLUMN event FORMAT A45
COLUMN wait_class FORMAT A20
COLUMN osuser FORMAT A25
COLUMN terminal FORMAT A20
COLUMN status FORMAT A12

PROMPT
PROMPT ================================================================
PROMPT ORACLE USER ACTIVITY MONITOR
PROMPT ================================================================

PROMPT
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ----------------------------------------------------------------

SELECT
    d.name AS database_name,
    i.instance_name,
    i.host_name,
    i.status AS instance_status,
    d.open_mode,
    d.database_role
FROM v$database d
CROSS JOIN v$instance i;

PROMPT
PROMPT 2. USER ACCOUNT STATUS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    lock_date,
    expiry_date,
    created
FROM dba_users
WHERE username IS NOT NULL
ORDER BY
    CASE
        WHEN account_status LIKE '%LOCKED%' THEN 1
        WHEN account_status LIKE '%EXPIRED%' THEN 2
        ELSE 3
    END,
    username;

PROMPT
PROMPT 3. CURRENT USER SESSIONS
PROMPT ----------------------------------------------------------------

SELECT
    s.username,
    s.sid,
    s.serial# AS serial,
    s.status,
    s.logon_time,
    s.last_call_et AS last_call_sec,
    s.sql_id,
    s.event,
    s.wait_class,
    s.machine,
    s.program,
    s.module,
    s.service_name
FROM v$session s
WHERE s.username IS NOT NULL
ORDER BY
    CASE WHEN s.status = 'ACTIVE' THEN 1 ELSE 2 END,
    s.username,
    s.sid;

PROMPT
PROMPT 4. ACTIVE USER SESSIONS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    COUNT(*) AS active_sessions
FROM v$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
GROUP BY username
ORDER BY active_sessions DESC;

PROMPT
PROMPT 5. SESSION COUNT BY USER
PROMPT ----------------------------------------------------------------

SELECT
    username,
    COUNT(*) AS total_sessions,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_sessions,
    SUM(CASE WHEN status = 'INACTIVE' THEN 1 ELSE 0 END) AS inactive_sessions
FROM v$session
WHERE username IS NOT NULL
GROUP BY username
ORDER BY total_sessions DESC;

PROMPT
PROMPT 6. USER SESSIONS BY MACHINE
PROMPT ----------------------------------------------------------------

SELECT
    username,
    machine,
    COUNT(*) AS sessions
FROM v$session
WHERE username IS NOT NULL
GROUP BY username, machine
ORDER BY sessions DESC, username;

PROMPT
PROMPT 7. USER SESSIONS BY PROGRAM
PROMPT ----------------------------------------------------------------

SELECT
    username,
    program,
    COUNT(*) AS sessions
FROM v$session
WHERE username IS NOT NULL
GROUP BY username, program
ORDER BY sessions DESC, username;

PROMPT
PROMPT 8. USER SESSIONS BY SERVICE
PROMPT ----------------------------------------------------------------

SELECT
    username,
    service_name,
    COUNT(*) AS sessions
FROM v$session
WHERE username IS NOT NULL
GROUP BY username, service_name
ORDER BY sessions DESC, username;

PROMPT
PROMPT 9. ACTIVE USER SESSIONS / CURRENT WAITS
PROMPT ----------------------------------------------------------------

SELECT
    sid,
    serial# AS serial,
    username,
    sql_id,
    status,
    event,
    wait_class,
    seconds_in_wait,
    state,
    machine,
    program
FROM v$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
ORDER BY seconds_in_wait DESC;

PROMPT
PROMPT 10. TOP USERS BY CPU
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        s.username,
        ROUND(
            SUM(
                CASE
                    WHEN n.name = 'CPU used by this session'
                    THEN st.value
                    ELSE 0
                END
            ) / 100,
            2
        ) AS cpu_seconds,
        COUNT(DISTINCT s.sid) AS sessions
    FROM v$session s
    JOIN v$sesstat st
      ON s.sid = st.sid
    JOIN v$statname n
      ON st.statistic# = n.statistic#
    WHERE s.username IS NOT NULL
    GROUP BY s.username
    ORDER BY cpu_seconds DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 11. TOP USERS BY LOGICAL I/O
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        s.username,
        SUM(
            CASE
                WHEN n.name IN (
                    'session logical reads',
                    'consistent gets',
                    'db block gets'
                )
                THEN st.value
                ELSE 0
            END
        ) AS logical_reads,
        COUNT(DISTINCT s.sid) AS sessions
    FROM v$session s
    JOIN v$sesstat st
      ON s.sid = st.sid
    JOIN v$statname n
      ON st.statistic# = n.statistic#
    WHERE s.username IS NOT NULL
    GROUP BY s.username
    ORDER BY logical_reads DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 12. TOP USERS BY PHYSICAL READS
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        s.username,
        SUM(
            CASE
                WHEN n.name = 'physical reads'
                THEN st.value
                ELSE 0
            END
        ) AS physical_reads,
        COUNT(DISTINCT s.sid) AS sessions
    FROM v$session s
    JOIN v$sesstat st
      ON s.sid = st.sid
    JOIN v$statname n
      ON st.statistic# = n.statistic#
    WHERE s.username IS NOT NULL
    GROUP BY s.username
    ORDER BY physical_reads DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 13. TOP USERS BY PGA MEMORY
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        s.username,
        ROUND(
            SUM(
                CASE
                    WHEN n.name = 'session pga memory'
                    THEN st.value
                    ELSE 0
                END
            ) / 1024 / 1024,
            2
        ) AS pga_mb,
        COUNT(DISTINCT s.sid) AS sessions
    FROM v$session s
    JOIN v$sesstat st
      ON s.sid = st.sid
    JOIN v$statname n
      ON st.statistic# = n.statistic#
    WHERE s.username IS NOT NULL
    GROUP BY s.username
    ORDER BY pga_mb DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 14. USER TRANSACTIONS
PROMPT ----------------------------------------------------------------

SELECT
    s.username,
    s.sid,
    s.serial# AS serial,
    t.start_time,
    t.status AS transaction_status,
    t.used_ublk,
    t.used_urec,
    s.sql_id,
    s.machine,
    s.program
FROM v$transaction t
JOIN v$session s
  ON t.addr = s.taddr
WHERE s.username IS NOT NULL
ORDER BY t.used_ublk DESC;

PROMPT
PROMPT 15. USERS WITH OPEN TRANSACTIONS
PROMPT ----------------------------------------------------------------

SELECT
    s.username,
    COUNT(*) AS open_transactions
FROM v$transaction t
JOIN v$session s
  ON t.addr = s.taddr
WHERE s.username IS NOT NULL
GROUP BY s.username
ORDER BY open_transactions DESC;

PROMPT
PROMPT 16. USER SESSIONS WITH SQL
PROMPT ----------------------------------------------------------------

SELECT
    s.username,
    s.sid,
    s.serial# AS serial,
    s.sql_id,
    s.sql_child_number AS child_number,
    s.status,
    s.last_call_et AS last_call_sec,
    s.event,
    s.wait_class,
    s.machine,
    s.program,
    s.module
FROM v$session s
WHERE s.username IS NOT NULL
  AND s.sql_id IS NOT NULL
ORDER BY s.last_call_et DESC;

PROMPT
PROMPT 17. TOP SQL BY USER
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        s.username,
        q.sql_id,
        q.plan_hash_value,
        q.executions,
        q.buffer_gets,
        q.disk_reads,
        q.cpu_time,
        q.elapsed_time,
        q.parsing_schema_name,
        q.module
    FROM v$sql q
    JOIN v$session s
      ON s.sql_id = q.sql_id
     AND s.sql_child_number = q.child_number
    WHERE s.username IS NOT NULL
    ORDER BY q.cpu_time DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT 18. FAILED LOGIN ACTIVITY
PROMPT ----------------------------------------------------------------

SELECT
    username,
    userhost,
    returncode,
    timestamp,
    action_name,
    os_username
FROM unified_audit_trail
WHERE action_name LIKE '%LOGON%'
  AND returncode <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY event_timestamp DESC;

PROMPT
PROMPT 19. RECENT SUCCESSFUL LOGONS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    userhost,
    event_timestamp,
    os_username,
    authentication_type
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND returncode = 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY event_timestamp DESC;

PROMPT
PROMPT 20. USER ACTIVITY BY CLIENT
PROMPT ----------------------------------------------------------------

SELECT
    username,
    osuser,
    machine,
    program,
    module,
    COUNT(*) AS sessions
FROM v$session
WHERE username IS NOT NULL
GROUP BY
    username,
    osuser,
    machine,
    program,
    module
ORDER BY sessions DESC;

PROMPT
PROMPT 21. LONG-RUNNING ACTIVE USER SESSIONS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    sid,
    serial# AS serial,
    sql_id,
    ROUND(last_call_et / 60, 2) AS active_minutes,
    event,
    wait_class,
    machine,
    program,
    module
FROM v$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND last_call_et >= 600
ORDER BY last_call_et DESC;

PROMPT
PROMPT 22. USER SESSIONS WAITING ON USER I/O
PROMPT ----------------------------------------------------------------

SELECT
    username,
    sid,
    serial# AS serial,
    sql_id,
    event,
    seconds_in_wait,
    state,
    machine,
    program
FROM v$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND wait_class = 'User I/O'
ORDER BY seconds_in_wait DESC;

PROMPT
PROMPT 23. USER SESSIONS WAITING ON CONCURRENCY
PROMPT ----------------------------------------------------------------

SELECT
    username,
    sid,
    serial# AS serial,
    sql_id,
    event,
    seconds_in_wait,
    state,
    machine,
    program
FROM v$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND wait_class = 'Concurrency'
ORDER BY seconds_in_wait DESC;

PROMPT
PROMPT 24. USER ACTIVITY SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(DISTINCT username) AS active_users,
    COUNT(*) AS total_user_sessions,
    SUM(CASE WHEN status = 'ACTIVE' THEN 1 ELSE 0 END) AS active_sessions,
    SUM(CASE WHEN status = 'INACTIVE' THEN 1 ELSE 0 END) AS inactive_sessions
FROM v$session
WHERE username IS NOT NULL;

PROMPT
PROMPT ================================================================
PROMPT USER ACTIVITY DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Review active users and active sessions.
PROMPT 2. Check session concentration by user, machine and program.
PROMPT 3. Identify users generating high CPU.
PROMPT 4. Identify users generating high logical I/O.
PROMPT 5. Identify users generating high physical I/O.
PROMPT 6. Review users consuming large PGA memory.
PROMPT 7. Check users with open transactions.
PROMPT 8. Review long-running active sessions.
PROMPT 9. Review current User I/O and Concurrency waits.
PROMPT 10. Review recent successful and failed logons.
PROMPT 11. Correlate heavy users with SQL_ID and execution plans.
PROMPT
PROMPT IMPORTANT:
PROMPT - V$SESSION statistics are current/cumulative session counters.
PROMPT - CPU and I/O values are not interval rates unless sampled over time.
PROMPT - An inactive session is not automatically a problem.
PROMPT - A large session count can be normal for connection pools.
PROMPT - Unified Audit queries require Unified Auditing and appropriate
PROMPT   privileges.
PROMPT - Do not terminate sessions based only on this report.
PROMPT
PROMPT ================================================================
PROMPT END OF USER ACTIVITY MONITOR
PROMPT ================================================================

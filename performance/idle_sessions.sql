-- ============================================================================
-- Oracle DBA Toolkit
-- Script  : idle_sessions.sql
-- Purpose : Monitor inactive / idle Oracle sessions
-- Author  : Manik Challa
-- Usage   : SQL*Plus / SQLcl
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN sid              FORMAT 99999
COLUMN serial           FORMAT 999999
COLUMN username         FORMAT A20
COLUMN status           FORMAT A10
COLUMN sql_id           FORMAT A15
COLUMN event            FORMAT A40
COLUMN machine          FORMAT A30
COLUMN program          FORMAT A35
COLUMN module           FORMAT A30
COLUMN service_name     FORMAT A25
COLUMN last_call_min    FORMAT 999999.99
COLUMN idle_hours       FORMAT 999999.99
COLUMN logon_time       FORMAT A20
COLUMN transaction_status FORMAT A15

PROMPT
PROMPT ================================================================
PROMPT ORACLE IDLE SESSION MONITORING
PROMPT ================================================================
PROMPT

-- ============================================================================
-- 1. All Inactive User Sessions
-- ============================================================================

PROMPT
PROMPT [1] ALL INACTIVE USER SESSIONS
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    ROUND(s.last_call_et / 60, 2) AS last_call_min,
    ROUND(s.last_call_et / 3600, 2) AS idle_hours,
    s.logon_time,
    s.machine,
    s.program,
    s.module,
    s.service_name
FROM v$session s
WHERE s.username IS NOT NULL
  AND s.status = 'INACTIVE'
ORDER BY s.last_call_et DESC;

-- ============================================================================
-- 2. Sessions Idle More Than 30 Minutes
-- ============================================================================

PROMPT
PROMPT [2] SESSIONS IDLE MORE THAN 30 MINUTES
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    ROUND(s.last_call_et / 60, 2) AS idle_minutes,
    s.sql_id,
    s.machine,
    s.program,
    s.module,
    s.service_name,
    s.logon_time
FROM v$session s
WHERE s.username IS NOT NULL
  AND s.status = 'INACTIVE'
  AND s.last_call_et >= 1800
ORDER BY s.last_call_et DESC;

-- ============================================================================
-- 3. Sessions Idle More Than 2 Hours
-- ============================================================================

PROMPT
PROMPT [3] SESSIONS IDLE MORE THAN 2 HOURS
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    ROUND(s.last_call_et / 3600, 2) AS idle_hours,
    s.sql_id,
    s.machine,
    s.program,
    s.module,
    s.service_name,
    s.logon_time
FROM v$session s
WHERE s.username IS NOT NULL
  AND s.status = 'INACTIVE'
  AND s.last_call_et >= 7200
ORDER BY s.last_call_et DESC;

-- ============================================================================
-- 4. Idle Sessions with Open Transactions
-- ============================================================================

PROMPT
PROMPT [4] INACTIVE SESSIONS WITH OPEN TRANSACTIONS
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    ROUND(s.last_call_et / 60, 2) AS idle_minutes,
    t.start_time,
    t.status AS transaction_status,
    t.used_ublk,
    t.used_urec,
    s.machine,
    s.program,
    s.module
FROM v$session s
JOIN v$transaction t
  ON t.addr = s.taddr
WHERE s.username IS NOT NULL
  AND s.status = 'INACTIVE'
ORDER BY s.last_call_et DESC;

-- ============================================================================
-- 5. Idle Sessions with Blocking Activity
-- ============================================================================

PROMPT
PROMPT [5] INACTIVE SESSIONS THAT ARE BLOCKING OTHERS
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    ROUND(s.last_call_et / 60, 2) AS idle_minutes,
    COUNT(ws.sid) AS blocked_sessions,
    s.machine,
    s.program,
    s.module
FROM v$session s
JOIN v$session ws
  ON ws.blocking_session = s.sid
WHERE s.username IS NOT NULL
  AND s.status = 'INACTIVE'
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    s.last_call_et,
    s.machine,
    s.program,
    s.module
ORDER BY blocked_sessions DESC, idle_minutes DESC;

-- ============================================================================
-- 6. Idle Sessions by Database User
-- ============================================================================

PROMPT
PROMPT [6] IDLE SESSIONS BY DATABASE USER
PROMPT

SELECT
    username,
    COUNT(*) AS idle_sessions,
    ROUND(AVG(last_call_et) / 60, 2) AS avg_idle_minutes,
    ROUND(MAX(last_call_et) / 60, 2) AS max_idle_minutes
FROM v$session
WHERE username IS NOT NULL
  AND status = 'INACTIVE'
GROUP BY username
ORDER BY idle_sessions DESC;

-- ============================================================================
-- 7. Idle Sessions by Machine
-- ============================================================================

PROMPT
PROMPT [7] IDLE SESSIONS BY MACHINE
PROMPT

SELECT
    machine,
    COUNT(*) AS idle_sessions,
    ROUND(MAX(last_call_et) / 60, 2) AS max_idle_minutes
FROM v$session
WHERE username IS NOT NULL
  AND status = 'INACTIVE'
GROUP BY machine
ORDER BY idle_sessions DESC;

-- ============================================================================
-- 8. Idle Sessions by Program
-- ============================================================================

PROMPT
PROMPT [8] IDLE SESSIONS BY PROGRAM
PROMPT

SELECT
    program,
    COUNT(*) AS idle_sessions,
    ROUND(MAX(last_call_et) / 60, 2) AS max_idle_minutes
FROM v$session
WHERE username IS NOT NULL
  AND status = 'INACTIVE'
GROUP BY program
ORDER BY idle_sessions DESC;

-- ============================================================================
-- 9. Idle Sessions by Service
-- ============================================================================

PROMPT
PROMPT [9] IDLE SESSIONS BY SERVICE
PROMPT

SELECT
    service_name,
    COUNT(*) AS idle_sessions,
    ROUND(MAX(last_call_et) / 60, 2) AS max_idle_minutes
FROM v$session
WHERE username IS NOT NULL
  AND status = 'INACTIVE'
GROUP BY service_name
ORDER BY idle_sessions DESC;

-- ============================================================================
-- 10. Longest Idle Sessions
-- ============================================================================

PROMPT
PROMPT [10] LONGEST IDLE SESSIONS
PROMPT

SELECT
    sid,
    serial# AS serial,
    username,
    ROUND(last_call_et / 3600, 2) AS idle_hours,
    sql_id,
    machine,
    program,
    module,
    service_name,
    logon_time
FROM v$session
WHERE username IS NOT NULL
  AND status = 'INACTIVE'
ORDER BY last_call_et DESC
FETCH FIRST 25 ROWS ONLY;

-- ============================================================================
-- 11. Idle Session Summary
-- ============================================================================

PROMPT
PROMPT [11] IDLE SESSION SUMMARY
PROMPT

SELECT
    COUNT(*) AS total_idle_sessions,
    SUM(CASE WHEN last_call_et >= 1800 THEN 1 ELSE 0 END)
        AS idle_over_30min,
    SUM(CASE WHEN last_call_et >= 7200 THEN 1 ELSE 0 END)
        AS idle_over_2hr,
    SUM(CASE WHEN taddr IS NOT NULL THEN 1 ELSE 0 END)
        AS idle_with_transaction
FROM v$session
WHERE username IS NOT NULL
  AND status = 'INACTIVE';

-- ============================================================================
-- 12. Idle Sessions with Last SQL
-- ============================================================================

PROMPT
PROMPT [12] IDLE SESSIONS WITH LAST SQL
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    ROUND(s.last_call_et / 60, 2) AS idle_minutes,
    s.sql_id,
    s.prev_sql_id,
    SUBSTR(q.sql_text, 1, 120) AS previous_sql,
    s.machine,
    s.program,
    s.module
FROM v$session s
LEFT JOIN v$sql q
       ON q.sql_id = s.prev_sql_id
      AND q.child_number = s.prev_child_number
WHERE s.username IS NOT NULL
  AND s.status = 'INACTIVE'
ORDER BY s.last_call_et DESC;

PROMPT
PROMPT ================================================================
PROMPT IDLE SESSION INVESTIGATION COMPLETE
PROMPT ================================================================
PROMPT
PROMPT DBA CHECKLIST:
PROMPT 1. Identify long-idle sessions.
PROMPT 2. Check whether an inactive session owns an open transaction.
PROMPT 3. Check whether an idle session is blocking other sessions.
PROMPT 4. Review application, machine, module and service information.
PROMPT 5. Check connection-pool configuration for excessive idle sessions.
PROMPT 6. Review database profile IDLE_TIME where appropriate.
PROMPT 7. Confirm application behavior before terminating sessions.
PROMPT 8. Do not kill idle sessions solely because they are inactive.

 

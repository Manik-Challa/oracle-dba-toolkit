-- ================================================================
-- Oracle DBA Toolkit
-- Script : audit_failures.sql
-- Purpose: Monitor Oracle Audit Failures / Security Events
-- Usage  : Run as SYS or a user with access to UNIFIED_AUDIT_TRAIL
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN username FORMAT A30
COLUMN userhost FORMAT A35
COLUMN os_username FORMAT A25
COLUMN action_name FORMAT A35
COLUMN object_schema FORMAT A25
COLUMN object_name FORMAT A35
COLUMN return_code FORMAT 10
COLUMN event_timestamp FORMAT A30
COLUMN sql_text FORMAT A80
COLUMN error_message FORMAT A100

PROMPT
PROMPT ================================================================
PROMPT ORACLE AUDIT FAILURE MONITOR
PROMPT ================================================================

PROMPT
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ----------------------------------------------------------------

SELECT
    d.name AS database_name,
    i.instance_name,
    i.host_name,
    i.version,
    i.status AS instance_status,
    d.open_mode,
    d.database_role
FROM v$database d
CROSS JOIN v$instance i;


PROMPT
PROMPT 2. FAILED AUDIT EVENTS - LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    event_timestamp,
    username,
    userhost,
    action_name,
    return_code,
    object_schema,
    object_name
FROM unified_audit_trail
WHERE return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY event_timestamp DESC;


PROMPT
PROMPT 3. FAILED LOGONS - LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    event_timestamp,
    username,
    userhost,
    os_username,
    return_code,
    authentication_type
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY event_timestamp DESC;


PROMPT
PROMPT 4. FAILED LOGONS BY USER
PROMPT ----------------------------------------------------------------

SELECT
    username,
    COUNT(*) AS failed_logons
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY username
ORDER BY failed_logons DESC;


PROMPT
PROMPT 5. FAILED LOGONS BY HOST
PROMPT ----------------------------------------------------------------

SELECT
    userhost,
    COUNT(*) AS failed_logons
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY userhost
ORDER BY failed_logons DESC;


PROMPT
PROMPT 6. FAILED LOGONS BY USER AND HOST
PROMPT ----------------------------------------------------------------

SELECT
    username,
    userhost,
    COUNT(*) AS failed_logons
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY username, userhost
ORDER BY failed_logons DESC;


PROMPT
PROMPT 7. MOST COMMON FAILURE RETURN CODES
PROMPT ----------------------------------------------------------------

SELECT
    return_code,
    COUNT(*) AS failure_count
FROM unified_audit_trail
WHERE return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY return_code
ORDER BY failure_count DESC;


PROMPT
PROMPT 8. FAILURE RETURN CODES BY USER
PROMPT ----------------------------------------------------------------

SELECT
    username,
    return_code,
    COUNT(*) AS failure_count
FROM unified_audit_trail
WHERE return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY username, return_code
ORDER BY failure_count DESC;


PROMPT
PROMPT 9. FAILED OPERATIONS BY ACTION
PROMPT ----------------------------------------------------------------

SELECT
    action_name,
    COUNT(*) AS failure_count
FROM unified_audit_trail
WHERE return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY action_name
ORDER BY failure_count DESC;


PROMPT
PROMPT 10. FAILED OPERATIONS BY USER
PROMPT ----------------------------------------------------------------

SELECT
    username,
    action_name,
    COUNT(*) AS failure_count
FROM unified_audit_trail
WHERE return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY username, action_name
ORDER BY failure_count DESC;


PROMPT
PROMPT 11. FAILED OPERATIONS BY OBJECT
PROMPT ----------------------------------------------------------------

SELECT
    object_schema,
    object_name,
    action_name,
    COUNT(*) AS failure_count
FROM unified_audit_trail
WHERE return_code <> 0
  AND object_name IS NOT NULL
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY
    object_schema,
    object_name,
    action_name
ORDER BY failure_count DESC;


PROMPT
PROMPT 12. FAILED EVENTS BY SOURCE HOST
PROMPT ----------------------------------------------------------------

SELECT
    userhost,
    action_name,
    COUNT(*) AS failure_count
FROM unified_audit_trail
WHERE return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY userhost, action_name
ORDER BY failure_count DESC;


PROMPT
PROMPT 13. REPEATED FAILED LOGONS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    userhost,
    COUNT(*) AS failed_attempts,
    MIN(event_timestamp) AS first_failure,
    MAX(event_timestamp) AS last_failure
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY username, userhost
HAVING COUNT(*) >= 5
ORDER BY failed_attempts DESC;


PROMPT
PROMPT 14. USERS WITH HIGH FAILED LOGIN COUNTS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    COUNT(*) AS failed_attempts,
    COUNT(DISTINCT userhost) AS source_hosts
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY username
HAVING COUNT(*) >= 5
ORDER BY failed_attempts DESC;


PROMPT
PROMPT 15. HOSTS WITH HIGH FAILED LOGIN COUNTS
PROMPT ----------------------------------------------------------------

SELECT
    userhost,
    COUNT(*) AS failed_attempts,
    COUNT(DISTINCT username) AS affected_users
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY userhost
HAVING COUNT(*) >= 5
ORDER BY failed_attempts DESC;


PROMPT
PROMPT 16. FAILED LOGONS FOR LOCKED / EXPIRED USERS
PROMPT ----------------------------------------------------------------

SELECT
    a.username,
    u.account_status,
    u.profile,
    COUNT(*) AS failed_logons,
    MAX(a.event_timestamp) AS last_failure
FROM unified_audit_trail a
JOIN dba_users u
  ON a.username = u.username
WHERE a.action_name = 'LOGON'
  AND a.return_code <> 0
  AND a.event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
       u.account_status LIKE '%LOCKED%'
       OR u.account_status LIKE '%EXPIRED%'
  )
GROUP BY
    a.username,
    u.account_status,
    u.profile
ORDER BY failed_logons DESC;


PROMPT
PROMPT 17. FAILED LOGONS FOR PRIVILEGED USERS
PROMPT ----------------------------------------------------------------

SELECT
    a.username,
    COUNT(*) AS failed_logons,
    COUNT(DISTINCT a.userhost) AS source_hosts,
    MAX(a.event_timestamp) AS last_failure
FROM unified_audit_trail a
WHERE a.action_name = 'LOGON'
  AND a.return_code <> 0
  AND a.event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND a.username IN (
      SELECT username
      FROM dba_users
      WHERE username IN (
          SELECT grantee
          FROM dba_role_privs
          WHERE granted_role = 'DBA'

          UNION

          SELECT grantee
          FROM dba_sys_privs
          WHERE privilege IN (
              'ALTER SYSTEM',
              'ALTER DATABASE',
              'CREATE USER',
              'DROP USER',
              'GRANT ANY PRIVILEGE',
              'GRANT ANY ROLE',
              'GRANT ANY OBJECT PRIVILEGE'
          )
      )
  )
GROUP BY a.username
ORDER BY failed_logons DESC;


PROMPT
PROMPT 18. FAILED AUDIT EVENTS BY HOUR
PROMPT ----------------------------------------------------------------

SELECT
    TO_CHAR(
        CAST(event_timestamp AS TIMESTAMP),
        'YYYY-MM-DD HH24'
    ) AS failure_hour,
    COUNT(*) AS failure_count
FROM unified_audit_trail
WHERE return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY
    TO_CHAR(
        CAST(event_timestamp AS TIMESTAMP),
        'YYYY-MM-DD HH24'
    )
ORDER BY failure_hour;


PROMPT
PROMPT 19. RECENT HIGH-RISK FAILED OPERATIONS
PROMPT ----------------------------------------------------------------

SELECT
    event_timestamp,
    username,
    userhost,
    action_name,
    object_schema,
    object_name,
    return_code
FROM unified_audit_trail
WHERE return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND action_name IN (
      'CREATE USER',
      'ALTER USER',
      'DROP USER',
      'CREATE ROLE',
      'DROP ROLE',
      'GRANT',
      'REVOKE',
      'ALTER SYSTEM',
      'ALTER DATABASE',
      'CREATE TABLE',
      'DROP TABLE'
  )
ORDER BY event_timestamp DESC;


PROMPT
PROMPT 20. FAILED EVENTS - LAST 7 DAYS
PROMPT ----------------------------------------------------------------

SELECT
    TRUNC(CAST(event_timestamp AS DATE)) AS event_date,
    COUNT(*) AS failure_count
FROM unified_audit_trail
WHERE return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
GROUP BY TRUNC(CAST(event_timestamp AS DATE))
ORDER BY event_date;


PROMPT
PROMPT 21. FAILED LOGONS - LAST 7 DAYS
PROMPT ----------------------------------------------------------------

SELECT
    TRUNC(CAST(event_timestamp AS DATE)) AS event_date,
    COUNT(*) AS failed_logons
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
GROUP BY TRUNC(CAST(event_timestamp AS DATE))
ORDER BY event_date;


PROMPT
PROMPT 22. TOP FAILURE SOURCES - USER / HOST / CODE
PROMPT ----------------------------------------------------------------

SELECT
    username,
    userhost,
    return_code,
    COUNT(*) AS failure_count,
    MAX(event_timestamp) AS last_failure
FROM unified_audit_trail
WHERE return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY
    username,
    userhost,
    return_code
ORDER BY failure_count DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT 23. RECENT FAILED AUDIT EVENTS
PROMPT ----------------------------------------------------------------

SELECT
    event_timestamp,
    username,
    userhost,
    os_username,
    action_name,
    object_schema,
    object_name,
    return_code
FROM unified_audit_trail
WHERE return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY event_timestamp DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT 24. AUDIT FAILURE SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS failed_audit_events_24h,
    COUNT(
        CASE
            WHEN action_name = 'LOGON'
            THEN 1
        END
    ) AS failed_logons_24h,
    COUNT(
        CASE
            WHEN action_name <> 'LOGON'
            THEN 1
        END
    ) AS failed_operations_24h,
    COUNT(DISTINCT username) AS affected_users,
    COUNT(DISTINCT userhost) AS source_hosts,
    COUNT(DISTINCT return_code) AS distinct_return_codes
FROM unified_audit_trail
WHERE return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR;


PROMPT
PROMPT ================================================================
PROMPT AUDIT FAILURE DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Review failed logons in the last 24 hours.
PROMPT 2. Identify users with repeated authentication failures.
PROMPT 3. Identify hosts generating repeated failures.
PROMPT 4. Review failure return codes.
PROMPT 5. Review failed non-LOGON operations.
PROMPT 6. Check failures involving locked or expired accounts.
PROMPT 7. Review failures involving privileged users.
PROMPT 8. Check high-risk administrative operations.
PROMPT 9. Look for unusual user/host combinations.
PROMPT 10. Compare failures against application deployment/activity.
PROMPT 11. Correlate with locked_users.sql.
PROMPT 12. Correlate with failed_logins.sql and user_activity.sql.
PROMPT
PROMPT IMPORTANT:
PROMPT - A non-zero RETURN_CODE indicates an unsuccessful audited action.
PROMPT - Failed logons may be caused by expired passwords, applications,
PROMPT   connection pools, configuration errors, or unauthorized attempts.
PROMPT - Repeated failures do not automatically indicate an attack.
PROMPT - Investigate the user, source host, timestamp and return code
PROMPT   together.
PROMPT - Audit results depend on configured Unified Audit policies.
PROMPT - Audit retention/purging can affect historical visibility.
PROMPT - This script is read-only and does not lock, disable or modify users.
PROMPT
PROMPT ================================================================
PROMPT END OF AUDIT FAILURE MONITOR
PROMPT ================================================================


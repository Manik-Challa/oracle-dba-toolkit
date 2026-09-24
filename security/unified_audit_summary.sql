-- ================================================================
-- Oracle DBA Toolkit
-- Unified Audit Summary
-- File: oracle/monitoring/unified_audit_summary.sql
--
-- Purpose:
--   Provide a concise operational summary of Oracle Unified Auditing.
--
-- Covers:
--   1. Database / instance information
--   2. Unified Auditing status
--   3. Audit trail availability
--   4. Audit activity - last 24 hours
--   5. Audit activity - last 7 days
--   6. Activity by user
--   7. Activity by host
--   8. Activity by action
--   9. Success vs failure
--  10. Failed audit activity
--  11. Failed logons
--  12. Successful logons
--  13. Privileged activity
--  14. High-risk administrative actions
--  15. Object activity
--  16. Audit activity by hour
--  17. Top users generating audit records
--  18. Top client hosts
--  19. Recent audit records
--  20. Audit health summary
--
-- Read-only monitoring script.
-- Does NOT create, alter, enable, disable, or purge audit policies.
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

COLUMN INSTANCE_NAME FORMAT A18
COLUMN HOST_NAME FORMAT A35
COLUMN VERSION FORMAT A20
COLUMN STATUS FORMAT A15
COLUMN OPEN_MODE FORMAT A20
COLUMN DATABASE_ROLE FORMAT A20

COLUMN PARAMETER FORMAT A35
COLUMN VALUE FORMAT A80

COLUMN USERNAME FORMAT A30
COLUMN USERHOST FORMAT A40
COLUMN OS_USERNAME FORMAT A30
COLUMN ACTION_NAME FORMAT A35
COLUMN OBJECT_SCHEMA FORMAT A30
COLUMN OBJECT_NAME FORMAT A40
COLUMN OBJECT_TYPE FORMAT A25
COLUMN RETURN_CODE FORMAT 999999
COLUMN AUTHENTICATION_TYPE FORMAT A25

COLUMN EVENT_TIME FORMAT A25
COLUMN HOUR_START FORMAT A20
COLUMN ERROR_COUNT FORMAT 99999999
COLUMN EVENT_COUNT FORMAT 99999999
COLUMN SUCCESS_COUNT FORMAT 99999999
COLUMN FAILURE_COUNT FORMAT 99999999

COLUMN POLICY_NAME FORMAT A50
COLUMN ENABLED_OPTION FORMAT A20
COLUMN ENTITY_NAME FORMAT A30

COLUMN MESSAGE_TEXT FORMAT A120

PROMPT
PROMPT ================================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ================================================================

SELECT
    i.instance_name,
    i.host_name,
    i.version,
    i.status,
    d.open_mode,
    d.database_role
FROM v$instance i
CROSS JOIN v$database d;


PROMPT
PROMPT ================================================================
PROMPT 2. UNIFIED AUDITING STATUS
PROMPT ================================================================

SELECT
    parameter,
    value
FROM v$option
WHERE parameter = 'Unified Auditing';


PROMPT
PROMPT ================================================================
PROMPT 3. UNIFIED AUDIT TRAIL AVAILABILITY
PROMPT ================================================================

SELECT
    COUNT(*) AS audit_records,
    MIN(event_timestamp) AS oldest_record,
    MAX(event_timestamp) AS newest_record
FROM unified_audit_trail;


PROMPT
PROMPT ================================================================
PROMPT 4. AUDIT ACTIVITY - LAST 24 HOURS
PROMPT ================================================================

SELECT
    COUNT(*) AS audit_records_24h,
    COUNT(DISTINCT username) AS distinct_users,
    COUNT(DISTINCT userhost) AS distinct_hosts,
    COUNT(DISTINCT action_name) AS distinct_actions
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR;


PROMPT
PROMPT ================================================================
PROMPT 5. AUDIT ACTIVITY - LAST 7 DAYS
PROMPT ================================================================

SELECT
    COUNT(*) AS audit_records_7d,
    COUNT(DISTINCT username) AS distinct_users,
    COUNT(DISTINCT userhost) AS distinct_hosts,
    COUNT(DISTINCT action_name) AS distinct_actions
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY;


PROMPT
PROMPT ================================================================
PROMPT 6. AUDIT ACTIVITY BY USER - LAST 24 HOURS
PROMPT ================================================================

SELECT
    username,
    COUNT(*) AS event_count,
    SUM(CASE WHEN return_code = 0 THEN 1 ELSE 0 END) AS success_count,
    SUM(CASE WHEN return_code <> 0 THEN 1 ELSE 0 END) AS failure_count
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY username
ORDER BY event_count DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 7. AUDIT ACTIVITY BY HOST - LAST 24 HOURS
PROMPT ================================================================

SELECT
    userhost,
    COUNT(*) AS event_count,
    COUNT(DISTINCT username) AS distinct_users
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY userhost
ORDER BY event_count DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 8. AUDIT ACTIVITY BY ACTION - LAST 24 HOURS
PROMPT ================================================================

SELECT
    action_name,
    COUNT(*) AS event_count,
    SUM(CASE WHEN return_code = 0 THEN 1 ELSE 0 END) AS success_count,
    SUM(CASE WHEN return_code <> 0 THEN 1 ELSE 0 END) AS failure_count
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY action_name
ORDER BY event_count DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 9. SUCCESS VS FAILURE - LAST 24 HOURS
PROMPT ================================================================

SELECT
    CASE
        WHEN return_code = 0 THEN 'SUCCESS'
        ELSE 'FAILURE'
    END AS result,
    COUNT(*) AS event_count
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY
    CASE
        WHEN return_code = 0 THEN 'SUCCESS'
        ELSE 'FAILURE'
    END
ORDER BY event_count DESC;


PROMPT
PROMPT ================================================================
PROMPT 10. SUCCESS VS FAILURE PERCENTAGE
PROMPT ================================================================

SELECT
    COUNT(*) AS total_events,

    SUM(
        CASE
            WHEN return_code = 0 THEN 1
            ELSE 0
        END
    ) AS successful_events,

    SUM(
        CASE
            WHEN return_code <> 0 THEN 1
            ELSE 0
        END
    ) AS failed_events,

    ROUND(
        100 *
        SUM(
            CASE
                WHEN return_code <> 0 THEN 1
                ELSE 0
            END
        ) / NULLIF(COUNT(*), 0),
        2
    ) AS failure_pct

FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR;


PROMPT
PROMPT ================================================================
PROMPT 11. FAILED AUDIT EVENTS - LAST 24 HOURS
PROMPT ================================================================

SELECT
    username,
    userhost,
    action_name,
    return_code,
    COUNT(*) AS failure_count
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND return_code <> 0
GROUP BY
    username,
    userhost,
    action_name,
    return_code
ORDER BY failure_count DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 12. FAILED LOGONS - LAST 24 HOURS
PROMPT ================================================================

SELECT
    username,
    userhost,
    return_code,
    COUNT(*) AS failed_logons
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY
    username,
    userhost,
    return_code
ORDER BY failed_logons DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 13. FAILED LOGONS BY USER
PROMPT ================================================================

SELECT
    username,
    COUNT(*) AS failed_logons
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY username
ORDER BY failed_logons DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 14. FAILED LOGONS BY HOST
PROMPT ================================================================

SELECT
    userhost,
    COUNT(*) AS failed_logons
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code <> 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY userhost
ORDER BY failed_logons DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 15. SUCCESSFUL LOGONS - LAST 24 HOURS
PROMPT ================================================================

SELECT
    username,
    userhost,
    COUNT(*) AS successful_logons
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code = 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY
    username,
    userhost
ORDER BY successful_logons DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 16. PRIVILEGED USER ACTIVITY
PROMPT ================================================================

SELECT
    username,
    COUNT(*) AS event_count,
    SUM(CASE WHEN return_code = 0 THEN 1 ELSE 0 END) AS success_count,
    SUM(CASE WHEN return_code <> 0 THEN 1 ELSE 0 END) AS failure_count
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
       username IN (
           SELECT grantee
           FROM dba_role_privs
           WHERE granted_role IN (
               'DBA',
               'SYSDBA',
               'SYSOPER',
               'SYSBACKUP',
               'SYSDG',
               'SYSKM'
           )
       )
    OR username IN ('SYS', 'SYSTEM')
  )
GROUP BY username
ORDER BY event_count DESC;


PROMPT
PROMPT ================================================================
PROMPT 17. HIGH-RISK ADMINISTRATIVE ACTIONS
PROMPT ================================================================

SELECT
    username,
    userhost,
    action_name,
    return_code,
    COUNT(*) AS event_count
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND UPPER(action_name) IN (
        'CREATE USER',
        'ALTER USER',
        'DROP USER',
        'CREATE ROLE',
        'ALTER ROLE',
        'DROP ROLE',
        'GRANT',
        'REVOKE',
        'ALTER SYSTEM',
        'ALTER DATABASE',
        'CREATE PROFILE',
        'ALTER PROFILE',
        'DROP PROFILE',
        'CREATE TABLE',
        'ALTER TABLE',
        'DROP TABLE',
        'TRUNCATE TABLE',
        'CREATE DIRECTORY',
        'DROP DIRECTORY',
        'CREATE DATABASE LINK',
        'DROP DATABASE LINK'
      )
GROUP BY
    username,
    userhost,
    action_name,
    return_code
ORDER BY event_count DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 18. OBJECT ACTIVITY - LAST 24 HOURS
PROMPT ================================================================

SELECT
    object_schema,
    object_name,
    object_type,
    COUNT(*) AS event_count
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND object_name IS NOT NULL
GROUP BY
    object_schema,
    object_name,
    object_type
ORDER BY event_count DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 19. OBJECT ACTIVITY BY ACTION
PROMPT ================================================================

SELECT
    object_schema,
    object_name,
    action_name,
    COUNT(*) AS event_count
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND object_name IS NOT NULL
GROUP BY
    object_schema,
    object_name,
    action_name
ORDER BY event_count DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 20. AUDIT ACTIVITY BY HOUR
PROMPT ================================================================

SELECT
    TO_CHAR(
        TRUNC(
            CAST(event_timestamp AS DATE),
            'HH24'
        ),
        'YYYY-MM-DD HH24:00'
    ) AS hour_start,
    COUNT(*) AS event_count,
    SUM(CASE WHEN return_code = 0 THEN 1 ELSE 0 END) AS success_count,
    SUM(CASE WHEN return_code <> 0 THEN 1 ELSE 0 END) AS failure_count
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY
    TRUNC(
        CAST(event_timestamp AS DATE),
        'HH24'
    )
ORDER BY hour_start;


PROMPT
PROMPT ================================================================
PROMPT 21. TOP AUDIT USERS - LAST 7 DAYS
PROMPT ================================================================

SELECT
    username,
    COUNT(*) AS event_count,
    COUNT(DISTINCT action_name) AS distinct_actions,
    COUNT(DISTINCT userhost) AS distinct_hosts
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
GROUP BY username
ORDER BY event_count DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 22. TOP CLIENT HOSTS - LAST 7 DAYS
PROMPT ================================================================

SELECT
    userhost,
    COUNT(*) AS event_count,
    COUNT(DISTINCT username) AS distinct_users,
    COUNT(DISTINCT action_name) AS distinct_actions
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
GROUP BY userhost
ORDER BY event_count DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 23. TOP ACTIONS - LAST 7 DAYS
PROMPT ================================================================

SELECT
    action_name,
    COUNT(*) AS event_count,
    COUNT(DISTINCT username) AS distinct_users,
    SUM(CASE WHEN return_code <> 0 THEN 1 ELSE 0 END) AS failure_count
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
GROUP BY action_name
ORDER BY event_count DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 24. RETURN CODES - LAST 7 DAYS
PROMPT ================================================================

SELECT
    return_code,
    COUNT(*) AS event_count
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
GROUP BY return_code
ORDER BY event_count DESC;


PROMPT
PROMPT ================================================================
PROMPT 25. AUDIT ACTIVITY BY AUTHENTICATION TYPE
PROMPT ================================================================

SELECT
    authentication_type,
    COUNT(*) AS event_count
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY authentication_type
ORDER BY event_count DESC;


PROMPT
PROMPT ================================================================
PROMPT 26. AUDIT ACTIVITY BY OS USER
PROMPT ================================================================

SELECT
    os_username,
    COUNT(*) AS event_count,
    COUNT(DISTINCT username) AS database_users,
    COUNT(DISTINCT userhost) AS client_hosts
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY os_username
ORDER BY event_count DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 27. RECENT AUDIT RECORDS
PROMPT ================================================================

SELECT
    event_timestamp,
    username,
    userhost,
    action_name,
    object_schema,
    object_name,
    return_code
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY event_timestamp DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 28. RECENT FAILED AUDIT RECORDS
PROMPT ================================================================

SELECT
    event_timestamp,
    username,
    userhost,
    action_name,
    object_schema,
    object_name,
    return_code
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND return_code <> 0
ORDER BY event_timestamp DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 29. RECENT HIGH-RISK ACTIVITY
PROMPT ================================================================

SELECT
    event_timestamp,
    username,
    userhost,
    action_name,
    object_schema,
    object_name,
    return_code
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND UPPER(action_name) IN (
        'CREATE USER',
        'ALTER USER',
        'DROP USER',
        'CREATE ROLE',
        'ALTER ROLE',
        'DROP ROLE',
        'GRANT',
        'REVOKE',
        'ALTER SYSTEM',
        'ALTER DATABASE',
        'CREATE PROFILE',
        'ALTER PROFILE',
        'DROP PROFILE',
        'CREATE DIRECTORY',
        'DROP DIRECTORY',
        'CREATE DATABASE LINK',
        'DROP DATABASE LINK'
      )
ORDER BY event_timestamp DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 30. AUDIT HEALTH SUMMARY
PROMPT ================================================================

SELECT
    total_events,
    successful_events,
    failed_events,
    failure_pct,
    CASE
        WHEN total_events = 0
            THEN 'NO AUDIT ACTIVITY FOUND'
        WHEN failed_events = 0
            THEN 'NO FAILED AUDIT EVENTS'
        WHEN failure_pct < 1
            THEN 'LOW FAILURE RATE - REVIEW IF UNEXPECTED'
        WHEN failure_pct < 5
            THEN 'ELEVATED FAILURE RATE - REVIEW'
        ELSE
            'HIGH FAILURE RATE - INVESTIGATE'
    END AS audit_health
FROM (
    SELECT
        COUNT(*) AS total_events,

        SUM(
            CASE
                WHEN return_code = 0 THEN 1
                ELSE 0
            END
        ) AS successful_events,

        SUM(
            CASE
                WHEN return_code <> 0 THEN 1
                ELSE 0
            END
        ) AS failed_events,

        ROUND(
            100 *
            SUM(
                CASE
                    WHEN return_code <> 0 THEN 1
                    ELSE 0
                END
            ) / NULLIF(COUNT(*), 0),
            2
        ) AS failure_pct
    FROM unified_audit_trail
    WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
);


PROMPT
PROMPT ================================================================
PROMPT DBA CHECKLIST
PROMPT ================================================================
PROMPT
PROMPT [ ] Verify Unified Auditing status.
PROMPT [ ] Confirm audit records are being generated.
PROMPT [ ] Review audit activity by user and host.
PROMPT [ ] Review failed logons.
PROMPT [ ] Review failed administrative operations.
PROMPT [ ] Review privileged-user activity.
PROMPT [ ] Review high-risk administrative actions.
PROMPT [ ] Investigate unexpected client hosts.
PROMPT [ ] Investigate unusual activity outside normal windows.
PROMPT [ ] Review audit policy configuration separately.
PROMPT [ ] Confirm audit retention meets organizational requirements.
PROMPT [ ] Correlate important events with alert.log and application logs.
PROMPT
PROMPT ================================================================
PROMPT IMPORTANT NOTES
PROMPT ================================================================
PROMPT
PROMPT * This script is READ-ONLY.
PROMPT * It does not enable or disable Unified Auditing.
PROMPT * It does not create or modify audit policies.
PROMPT * It does not purge audit records.
PROMPT * Empty audit results do not automatically mean auditing is disabled.
PROMPT * Audit visibility depends on enabled Unified Audit policies.
PROMPT * High audit volume is not automatically suspicious.
PROMPT * Failed operations should be investigated in context.
PROMPT * High-risk actions may be legitimate DBA activity.
PROMPT * The health thresholds in this script are toolkit heuristics,
PROMPT   not Oracle-defined security thresholds.
PROMPT
PROMPT ================================================================
PROMPT END OF UNIFIED AUDIT SUMMARY
PROMPT ================================================================


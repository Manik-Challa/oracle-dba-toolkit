-- ================================================================
-- Oracle DBA Toolkit
-- Script : audit_status.sql
-- Purpose: Monitor Oracle Auditing Configuration and Status
-- Usage  : Run as SYS or a user with access to audit-related views
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN name FORMAT A35
COLUMN value FORMAT A60
COLUMN parameter FORMAT A35
COLUMN audit_option FORMAT A45
COLUMN policy_name FORMAT A45
COLUMN enabled_option FORMAT A25
COLUMN entity_name FORMAT A30
COLUMN audit_trail FORMAT A30
COLUMN component FORMAT A30
COLUMN status FORMAT A20

PROMPT
PROMPT ================================================================
PROMPT ORACLE AUDIT STATUS MONITOR
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
PROMPT 2. UNIFIED AUDITING STATUS
PROMPT ----------------------------------------------------------------

SELECT
    parameter,
    value
FROM v$option
WHERE parameter = 'Unified Auditing';


PROMPT
PROMPT 3. UNIFIED AUDIT TRAIL AVAILABILITY
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS total_audit_records,
    MIN(event_timestamp) AS oldest_record,
    MAX(event_timestamp) AS newest_record
FROM unified_audit_trail;


PROMPT
PROMPT 4. RECENT UNIFIED AUDIT ACTIVITY - LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    action_name,
    COUNT(*) AS audit_records
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY action_name
ORDER BY audit_records DESC;


PROMPT
PROMPT 5. RECENT AUDIT ACTIVITY - LAST 7 DAYS
PROMPT ----------------------------------------------------------------

SELECT
    action_name,
    COUNT(*) AS audit_records
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
GROUP BY action_name
ORDER BY audit_records DESC;


PROMPT
PROMPT 6. AUDIT ACTIVITY BY USER - LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    COUNT(*) AS audit_records
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY username
ORDER BY audit_records DESC;


PROMPT
PROMPT 7. AUDIT ACTIVITY BY HOST - LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    userhost,
    COUNT(*) AS audit_records
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY userhost
ORDER BY audit_records DESC;


PROMPT
PROMPT 8. FAILED AUDIT EVENTS - LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    userhost,
    action_name,
    return_code,
    COUNT(*) AS failed_events
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND return_code <> 0
GROUP BY
    username,
    userhost,
    action_name,
    return_code
ORDER BY failed_events DESC;


PROMPT
PROMPT 9. FAILED LOGONS - LAST 24 HOURS
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
PROMPT 10. SUCCESSFUL LOGONS - LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    userhost,
    COUNT(*) AS successful_logons
FROM unified_audit_trail
WHERE action_name = 'LOGON'
  AND return_code = 0
  AND event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY username, userhost
ORDER BY successful_logons DESC;


PROMPT
PROMPT 11. AUDIT POLICIES
PROMPT ----------------------------------------------------------------

SELECT
    policy_name,
    audit_option,
    condition_eval_opt,
    audit_condition,
    enabled_option
FROM audit_unified_policies
ORDER BY policy_name, audit_option;


PROMPT
PROMPT 12. ENABLED UNIFIED AUDIT POLICIES
PROMPT ----------------------------------------------------------------

SELECT
    policy_name,
    enabled_option
FROM audit_unified_enabled_policies
ORDER BY policy_name;


PROMPT
PROMPT 13. AUDIT POLICY COUNT
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS unified_audit_policies
FROM audit_unified_policies;


PROMPT
PROMPT 14. ENABLED AUDIT POLICY COUNT
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS enabled_audit_policies
FROM audit_unified_enabled_policies;


PROMPT
PROMPT 15. TRADITIONAL AUDITING PARAMETERS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$parameter
WHERE name IN (
    'audit_trail',
    'audit_sys_operations',
    'audit_file_dest'
)
ORDER BY name;


PROMPT
PROMPT 16. AUDIT TRAIL CONFIGURATION
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$parameter
WHERE name LIKE 'audit%'
ORDER BY name;


PROMPT
PROMPT 17. AUDIT TRAIL RECORDS BY ACTION
PROMPT ----------------------------------------------------------------

SELECT
    action_name,
    COUNT(*) AS total_records
FROM unified_audit_trail
GROUP BY action_name
ORDER BY total_records DESC;


PROMPT
PROMPT 18. AUDIT RECORDS BY RETURN CODE
PROMPT ----------------------------------------------------------------

SELECT
    return_code,
    COUNT(*) AS audit_records
FROM unified_audit_trail
GROUP BY return_code
ORDER BY audit_records DESC;


PROMPT
PROMPT 19. AUDIT ACTIVITY BY OBJECT
PROMPT ----------------------------------------------------------------

SELECT
    object_schema,
    object_name,
    action_name,
    COUNT(*) AS audit_records
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND object_name IS NOT NULL
GROUP BY
    object_schema,
    object_name,
    action_name
ORDER BY audit_records DESC;


PROMPT
PROMPT 20. PRIVILEGED USER AUDIT ACTIVITY
PROMPT ----------------------------------------------------------------

SELECT
    username,
    action_name,
    COUNT(*) AS audit_records
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND username IN (
      SELECT username
      FROM dba_users
      WHERE username IN (
          SELECT grantee
          FROM dba_role_privs
          WHERE granted_role = 'DBA'
      )
  )
GROUP BY username, action_name
ORDER BY audit_records DESC;


PROMPT
PROMPT 21. AUDIT ACTIVITY BY HOUR - LAST 24 HOURS
PROMPT ----------------------------------------------------------------

SELECT
    TO_CHAR(
        CAST(event_timestamp AS TIMESTAMP),
        'YYYY-MM-DD HH24'
    ) AS audit_hour,
    COUNT(*) AS audit_records
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
GROUP BY
    TO_CHAR(
        CAST(event_timestamp AS TIMESTAMP),
        'YYYY-MM-DD HH24'
    )
ORDER BY audit_hour;


PROMPT
PROMPT 22. RECENT HIGH-RISK AUDIT ACTIONS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    userhost,
    action_name,
    object_schema,
    object_name,
    return_code,
    event_timestamp
FROM unified_audit_trail
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
       action_name IN (
           'CREATE USER',
           'ALTER USER',
           'DROP USER',
           'GRANT',
           'REVOKE',
           'ALTER SYSTEM',
           'ALTER DATABASE',
           'CREATE ROLE',
           'DROP ROLE',
           'CREATE TABLE',
           'DROP TABLE'
       )
       OR return_code <> 0
  )
ORDER BY event_timestamp DESC;


PROMPT
PROMPT 23. RECENT AUDIT RECORDS
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
WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY event_timestamp DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT 24. AUDIT STATUS SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    (SELECT COUNT(*) FROM audit_unified_policies)
        AS total_policies,
    (SELECT COUNT(*) FROM audit_unified_enabled_policies)
        AS enabled_policies,
    (SELECT COUNT(*)
       FROM unified_audit_trail
      WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR)
        AS audit_records_24h,
    (SELECT COUNT(*)
       FROM unified_audit_trail
      WHERE event_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
        AND return_code <> 0)
        AS failed_audit_events_24h
FROM dual;


PROMPT
PROMPT ================================================================
PROMPT AUDIT DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Verify Unified Auditing availability.
PROMPT 2. Review enabled Unified Audit policies.
PROMPT 3. Check recent audit activity.
PROMPT 4. Review failed audit events.
PROMPT 5. Review failed logons.
PROMPT 6. Review audit activity by user and host.
PROMPT 7. Review privileged-user activity.
PROMPT 8. Review high-risk administrative actions.
PROMPT 9. Check audit trail retention and volume.
PROMPT 10. Review traditional audit parameters where applicable.
PROMPT 11. Correlate audit events with failed_logins.sql.
PROMPT 12. Correlate privileged activity with privileged_users.sql.
PROMPT
PROMPT IMPORTANT:
PROMPT - Unified Auditing availability/configuration depends on Oracle release
PROMPT   and deployment mode.
PROMPT - An empty audit trail does not necessarily mean auditing is disabled.
PROMPT - Audit policies determine which activities are recorded.
PROMPT - Traditional auditing parameters may be legacy/compatibility settings.
PROMPT - Audit volume can become very large; review retention and purging.
PROMPT - Do not modify audit policies based only on this report.
PROMPT - Validate audit requirements against organizational security policy.
PROMPT
PROMPT ================================================================
PROMPT END OF AUDIT STATUS MONITOR
PROMPT ================================================================


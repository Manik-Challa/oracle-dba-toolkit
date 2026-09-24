-- ================================================================
-- Oracle DBA Toolkit
-- Script : profile_settings.sql
-- Purpose: Monitor Oracle Profile / Password / Resource Settings
-- Usage  : Run as SYS or a user with access to DBA_PROFILES/DBA_USERS
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN profile FORMAT A30
COLUMN resource_name FORMAT A35
COLUMN resource_type FORMAT A15
COLUMN limit FORMAT A25
COLUMN username FORMAT A30
COLUMN account_status FORMAT A30

PROMPT
PROMPT ================================================================
PROMPT ORACLE PROFILE SETTINGS MONITOR
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
PROMPT 2. ALL DATABASE PROFILES
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    resource_name,
    resource_type,
    limit
FROM dba_profiles
ORDER BY profile, resource_type, resource_name;


PROMPT
PROMPT 3. PASSWORD PROFILE SETTINGS
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    resource_name,
    resource_type,
    limit
FROM dba_profiles
WHERE resource_name IN (
    'FAILED_LOGIN_ATTEMPTS',
    'PASSWORD_LIFE_TIME',
    'PASSWORD_REUSE_TIME',
    'PASSWORD_REUSE_MAX',
    'PASSWORD_VERIFY_FUNCTION',
    'PASSWORD_LOCK_TIME',
    'PASSWORD_GRACE_TIME',
    'INACTIVE_ACCOUNT_TIME'
)
ORDER BY profile, resource_name;


PROMPT
PROMPT 4. PASSWORD POLICY SUMMARY BY PROFILE
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    MAX(
        CASE
            WHEN resource_name = 'FAILED_LOGIN_ATTEMPTS'
            THEN limit
        END
    ) AS failed_login_attempts,
    MAX(
        CASE
            WHEN resource_name = 'PASSWORD_LIFE_TIME'
            THEN limit
        END
    ) AS password_life_time,
    MAX(
        CASE
            WHEN resource_name = 'PASSWORD_REUSE_TIME'
            THEN limit
        END
    ) AS password_reuse_time,
    MAX(
        CASE
            WHEN resource_name = 'PASSWORD_REUSE_MAX'
            THEN limit
        END
    ) AS password_reuse_max,
    MAX(
        CASE
            WHEN resource_name = 'PASSWORD_VERIFY_FUNCTION'
            THEN limit
        END
    ) AS password_verify_function,
    MAX(
        CASE
            WHEN resource_name = 'PASSWORD_LOCK_TIME'
            THEN limit
        END
    ) AS password_lock_time,
    MAX(
        CASE
            WHEN resource_name = 'PASSWORD_GRACE_TIME'
            THEN limit
        END
    ) AS password_grace_time,
    MAX(
        CASE
            WHEN resource_name = 'INACTIVE_ACCOUNT_TIME'
            THEN limit
        END
    ) AS inactive_account_time
FROM dba_profiles
WHERE resource_type = 'PASSWORD'
GROUP BY profile
ORDER BY profile;


PROMPT
PROMPT 5. RESOURCE PROFILE SETTINGS
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    resource_name,
    resource_type,
    limit
FROM dba_profiles
WHERE resource_type = 'KERNEL'
ORDER BY profile, resource_name;


PROMPT
PROMPT 6. PROFILES WITH UNLIMITED RESOURCE LIMITS
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    resource_name,
    resource_type,
    limit
FROM dba_profiles
WHERE UPPER(limit) = 'UNLIMITED'
ORDER BY profile, resource_type, resource_name;


PROMPT
PROMPT 7. PROFILES WITH UNLIMITED PASSWORD LIFETIME
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    limit AS password_life_time
FROM dba_profiles
WHERE resource_name = 'PASSWORD_LIFE_TIME'
  AND UPPER(limit) = 'UNLIMITED'
ORDER BY profile;


PROMPT
PROMPT 8. PROFILES WITH UNLIMITED FAILED LOGIN ATTEMPTS
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    limit AS failed_login_attempts
FROM dba_profiles
WHERE resource_name = 'FAILED_LOGIN_ATTEMPTS'
  AND UPPER(limit) = 'UNLIMITED'
ORDER BY profile;


PROMPT
PROMPT 9. PROFILES WITH NO PASSWORD VERIFICATION FUNCTION
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    limit AS password_verify_function
FROM dba_profiles
WHERE resource_name = 'PASSWORD_VERIFY_FUNCTION'
  AND (
       limit IS NULL
       OR UPPER(limit) IN ('NULL', 'NULL ')
  )
ORDER BY profile;


PROMPT
PROMPT 10. USERS BY PROFILE
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    COUNT(*) AS user_count
FROM dba_users
GROUP BY profile
ORDER BY user_count DESC, profile;


PROMPT
PROMPT 11. USER PROFILE ASSIGNMENTS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    created,
    lock_date,
    expiry_date
FROM dba_users
WHERE username IS NOT NULL
ORDER BY profile, username;


PROMPT
PROMPT 12. USERS USING DEFAULT PROFILE
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    created,
    expiry_date
FROM dba_users
WHERE profile = 'DEFAULT'
ORDER BY username;


PROMPT
PROMPT 13. PROFILE SETTINGS FOR DEFAULT PROFILE
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    resource_name,
    resource_type,
    limit
FROM dba_profiles
WHERE profile = 'DEFAULT'
ORDER BY resource_type, resource_name;


PROMPT
PROMPT 14. USERS WITH PASSWORD SECURITY ISSUES
PROMPT ----------------------------------------------------------------

SELECT
    u.username,
    u.account_status,
    u.profile,
    u.expiry_date,
    p.limit AS password_life_time
FROM dba_users u
JOIN dba_profiles p
  ON u.profile = p.profile
WHERE p.resource_name = 'PASSWORD_LIFE_TIME'
  AND (
       u.account_status LIKE '%EXPIRED%'
       OR u.account_status LIKE '%LOCKED%'
       OR (
           u.expiry_date IS NOT NULL
           AND u.expiry_date < SYSDATE + 30
       )
  )
ORDER BY u.expiry_date NULLS FIRST, u.username;


PROMPT
PROMPT 15. PROFILES WITH SHORT PASSWORD LIFETIME
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    limit AS password_life_time
FROM dba_profiles
WHERE resource_name = 'PASSWORD_LIFE_TIME'
  AND REGEXP_LIKE(limit, '^[0-9]+(\.[0-9]+)?$')
  AND TO_NUMBER(limit) <= 30
ORDER BY TO_NUMBER(limit), profile;


PROMPT
PROMPT 16. PROFILES WITH LONG PASSWORD LIFETIME
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    limit AS password_life_time
FROM dba_profiles
WHERE resource_name = 'PASSWORD_LIFE_TIME'
  AND REGEXP_LIKE(limit, '^[0-9]+(\.[0-9]+)?$')
  AND TO_NUMBER(limit) > 90
ORDER BY TO_NUMBER(limit) DESC, profile;


PROMPT
PROMPT 17. PROFILES WITH WEAK LOGIN LOCK SETTINGS
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    resource_name,
    limit
FROM dba_profiles
WHERE resource_name IN (
    'FAILED_LOGIN_ATTEMPTS',
    'PASSWORD_LOCK_TIME'
)
AND (
       (
           resource_name = 'FAILED_LOGIN_ATTEMPTS'
           AND UPPER(limit) = 'UNLIMITED'
       )
       OR
       (
           resource_name = 'PASSWORD_LOCK_TIME'
           AND UPPER(limit) = 'UNLIMITED'
       )
)
ORDER BY profile, resource_name;


PROMPT
PROMPT 18. PROFILE RESOURCE CONSUMPTION LIMITS
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    resource_name,
    limit
FROM dba_profiles
WHERE resource_name IN (
    'SESSIONS_PER_USER',
    'CPU_PER_SESSION',
    'CPU_PER_CALL',
    'CONNECT_TIME',
    'IDLE_TIME',
    'LOGICAL_READS_PER_SESSION',
    'LOGICAL_READS_PER_CALL',
    'PRIVATE_SGA',
    'COMPOSITE_LIMIT'
)
ORDER BY profile, resource_name;


PROMPT
PROMPT 19. USERS WITH CUSTOM PROFILES
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    created,
    expiry_date
FROM dba_users
WHERE profile <> 'DEFAULT'
ORDER BY profile, username;


PROMPT
PROMPT 20. PROFILES AND USER COUNTS
PROMPT ----------------------------------------------------------------

SELECT
    p.profile,
    COUNT(u.username) AS assigned_users,
    COUNT(
        CASE
            WHEN u.account_status LIKE '%LOCKED%'
            THEN 1
        END
    ) AS locked_users,
    COUNT(
        CASE
            WHEN u.account_status LIKE '%EXPIRED%'
            THEN 1
        END
    ) AS expired_users
FROM (
    SELECT DISTINCT profile
    FROM dba_profiles
) p
LEFT JOIN dba_users u
       ON p.profile = u.profile
GROUP BY p.profile
ORDER BY assigned_users DESC, p.profile;


PROMPT
PROMPT 21. PROFILE SECURITY SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    MAX(
        CASE
            WHEN resource_name = 'PASSWORD_LIFE_TIME'
            THEN limit
        END
    ) AS password_life_time,
    MAX(
        CASE
            WHEN resource_name = 'FAILED_LOGIN_ATTEMPTS'
            THEN limit
        END
    ) AS failed_login_attempts,
    MAX(
        CASE
            WHEN resource_name = 'PASSWORD_LOCK_TIME'
            THEN limit
        END
    ) AS password_lock_time,
    MAX(
        CASE
            WHEN resource_name = 'PASSWORD_VERIFY_FUNCTION'
            THEN limit
        END
    ) AS password_verify_function,
    MAX(
        CASE
            WHEN resource_name = 'INACTIVE_ACCOUNT_TIME'
            THEN limit
        END
    ) AS inactive_account_time
FROM dba_profiles
WHERE resource_type = 'PASSWORD'
GROUP BY profile
ORDER BY profile;


PROMPT
PROMPT 22. PROFILE HEALTH SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(DISTINCT profile) AS total_profiles,
    SUM(
        CASE
            WHEN resource_name = 'PASSWORD_LIFE_TIME'
             AND UPPER(limit) = 'UNLIMITED'
            THEN 1
            ELSE 0
        END
    ) AS profiles_unlimited_password_lifetime,
    SUM(
        CASE
            WHEN resource_name = 'FAILED_LOGIN_ATTEMPTS'
             AND UPPER(limit) = 'UNLIMITED'
            THEN 1
            ELSE 0
        END
    ) AS profiles_unlimited_failed_logins,
    SUM(
        CASE
            WHEN resource_name = 'PASSWORD_VERIFY_FUNCTION'
             AND (limit IS NULL OR UPPER(limit) = 'NULL')
            THEN 1
            ELSE 0
        END
    ) AS profiles_without_verify_function
FROM dba_profiles;


PROMPT
PROMPT ================================================================
PROMPT PROFILE SETTINGS DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Review password settings for every profile.
PROMPT 2. Check PASSWORD_LIFE_TIME.
PROMPT 3. Check PASSWORD_GRACE_TIME.
PROMPT 4. Check FAILED_LOGIN_ATTEMPTS.
PROMPT 5. Check PASSWORD_LOCK_TIME.
PROMPT 6. Review PASSWORD_VERIFY_FUNCTION.
PROMPT 7. Identify profiles with unlimited password lifetime.
PROMPT 8. Review users assigned to DEFAULT profile.
PROMPT 9. Review custom profile assignments.
PROMPT 10. Review resource limits such as sessions and idle time.
PROMPT 11. Correlate profile settings with password_expiry.sql.
PROMPT 12. Validate settings against organizational security policy.
PROMPT
PROMPT IMPORTANT:
PROMPT - UNLIMITED does not automatically mean insecure or incorrect.
PROMPT - Service/application accounts may intentionally use different profiles.
PROMPT - DEFAULT profile settings affect users assigned to DEFAULT.
PROMPT - Resource limits depend on RESOURCE_LIMIT configuration and usage.
PROMPT - Profile settings should be reviewed before production changes.
PROMPT - This script is read-only and does not alter profiles.
PROMPT
PROMPT ================================================================
PROMPT END OF PROFILE SETTINGS MONITOR
PROMPT ================================================================


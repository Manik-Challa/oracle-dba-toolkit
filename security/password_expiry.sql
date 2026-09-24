-- ================================================================
-- Oracle DBA Toolkit
-- Script : password_expiry.sql
-- Purpose: Monitor Oracle User Password Expiry / Account Status
-- Usage  : Run as SYS or a user with access to DBA_USERS / DBA_PROFILES
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN username FORMAT A30
COLUMN account_status FORMAT A30
COLUMN profile FORMAT A25
COLUMN expiry_date FORMAT A22
COLUMN lock_date FORMAT A22
COLUMN created FORMAT A22
COLUMN profile_name FORMAT A25
COLUMN resource_name FORMAT A35
COLUMN limit FORMAT A20

PROMPT
PROMPT ================================================================
PROMPT ORACLE PASSWORD EXPIRY MONITOR
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
PROMPT 2. USER PASSWORD / ACCOUNT STATUS
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
        WHEN account_status LIKE '%EXPIRED%' THEN 1
        WHEN account_status LIKE '%LOCKED%' THEN 2
        ELSE 3
    END,
    expiry_date NULLS LAST,
    username;


PROMPT
PROMPT 3. ALREADY EXPIRED PASSWORDS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    expiry_date,
    lock_date
FROM dba_users
WHERE account_status LIKE '%EXPIRED%'
ORDER BY expiry_date NULLS FIRST, username;


PROMPT
PROMPT 4. PASSWORDS EXPIRING WITHIN 7 DAYS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    expiry_date,
    ROUND(expiry_date - SYSDATE, 2) AS days_until_expiry
FROM dba_users
WHERE expiry_date IS NOT NULL
  AND expiry_date >= SYSDATE
  AND expiry_date < SYSDATE + 7
ORDER BY expiry_date;


PROMPT
PROMPT 5. PASSWORDS EXPIRING WITHIN 30 DAYS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    expiry_date,
    ROUND(expiry_date - SYSDATE, 2) AS days_until_expiry
FROM dba_users
WHERE expiry_date IS NOT NULL
  AND expiry_date >= SYSDATE
  AND expiry_date < SYSDATE + 30
ORDER BY expiry_date;


PROMPT
PROMPT 6. PASSWORDS ALREADY EXPIRED BY DATE
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    expiry_date,
    ROUND(SYSDATE - expiry_date, 2) AS days_expired
FROM dba_users
WHERE expiry_date IS NOT NULL
  AND expiry_date < SYSDATE
ORDER BY expiry_date;


PROMPT
PROMPT 7. USERS IN PASSWORD GRACE PERIOD
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    expiry_date,
    ROUND(expiry_date - SYSDATE, 2) AS days_until_expiry
FROM dba_users
WHERE account_status LIKE '%EXPIRED(GRACE)%'
ORDER BY expiry_date;


PROMPT
PROMPT 8. LOCKED ACCOUNTS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    lock_date,
    expiry_date
FROM dba_users
WHERE account_status LIKE '%LOCKED%'
ORDER BY lock_date DESC NULLS LAST, username;


PROMPT
PROMPT 9. LOCKED AND EXPIRED ACCOUNTS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    lock_date,
    expiry_date
FROM dba_users
WHERE account_status LIKE '%LOCKED%'
  AND account_status LIKE '%EXPIRED%'
ORDER BY username;


PROMPT
PROMPT 10. PASSWORD LIFETIME BY PROFILE
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    resource_name,
    limit
FROM dba_profiles
WHERE resource_name IN (
    'PASSWORD_LIFE_TIME',
    'PASSWORD_GRACE_TIME',
    'PASSWORD_REUSE_TIME',
    'PASSWORD_REUSE_MAX',
    'PASSWORD_LOCK_TIME',
    'FAILED_LOGIN_ATTEMPTS',
    'INACTIVE_ACCOUNT_TIME'
)
ORDER BY profile, resource_name;


PROMPT
PROMPT 11. PROFILES WITH UNLIMITED PASSWORD LIFETIME
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    limit AS password_life_time
FROM dba_profiles
WHERE resource_name = 'PASSWORD_LIFE_TIME'
  AND UPPER(limit) = 'UNLIMITED'
ORDER BY profile;


PROMPT
PROMPT 12. USERS USING UNLIMITED PASSWORD LIFETIME PROFILES
PROMPT ----------------------------------------------------------------

SELECT
    u.username,
    u.account_status,
    u.profile,
    p.limit AS password_life_time,
    u.expiry_date
FROM dba_users u
JOIN dba_profiles p
  ON u.profile = p.profile
WHERE p.resource_name = 'PASSWORD_LIFE_TIME'
  AND UPPER(p.limit) = 'UNLIMITED'
ORDER BY u.username;


PROMPT
PROMPT 13. USERS WITH PASSWORD EXPIRED OR GRACE STATUS
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    expiry_date,
    lock_date
FROM dba_users
WHERE account_status IN (
    'EXPIRED',
    'EXPIRED(GRACE)',
    'EXPIRED & LOCKED',
    'EXPIRED(GRACE) & LOCKED'
)
ORDER BY username;


PROMPT
PROMPT 14. PASSWORD EXPIRY SUMMARY BY PROFILE
PROMPT ----------------------------------------------------------------

SELECT
    profile,
    COUNT(*) AS total_users,
    SUM(
        CASE
            WHEN account_status LIKE '%EXPIRED%'
            THEN 1
            ELSE 0
        END
    ) AS expired_users,
    SUM(
        CASE
            WHEN account_status LIKE '%LOCKED%'
            THEN 1
            ELSE 0
        END
    ) AS locked_users
FROM dba_users
GROUP BY profile
ORDER BY profile;


PROMPT
PROMPT 15. PASSWORD EXPIRY SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS total_users,
    SUM(
        CASE
            WHEN expiry_date < SYSDATE
            THEN 1
            ELSE 0
        END
    ) AS passwords_expired_by_date,
    SUM(
        CASE
            WHEN expiry_date >= SYSDATE
             AND expiry_date < SYSDATE + 7
            THEN 1
            ELSE 0
        END
    ) AS expiring_within_7_days,
    SUM(
        CASE
            WHEN expiry_date >= SYSDATE
             AND expiry_date < SYSDATE + 30
            THEN 1
            ELSE 0
        END
    ) AS expiring_within_30_days,
    SUM(
        CASE
            WHEN account_status LIKE '%EXPIRED%'
            THEN 1
            ELSE 0
        END
    ) AS expired_accounts,
    SUM(
        CASE
            WHEN account_status LIKE '%LOCKED%'
            THEN 1
            ELSE 0
        END
    ) AS locked_accounts
FROM dba_users;


PROMPT
PROMPT 16. NON-ORACLE-MAINTAINED USERS WITH PASSWORD ISSUES
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    expiry_date,
    lock_date
FROM dba_users
WHERE oracle_maintained = 'N'
  AND (
       account_status LIKE '%EXPIRED%'
    OR account_status LIKE '%LOCKED%'
    OR (
        expiry_date IS NOT NULL
        AND expiry_date < SYSDATE + 30
    )
  )
ORDER BY expiry_date NULLS FIRST, username;


PROMPT
PROMPT 17. PRIVILEGED USERS WITH PASSWORD EXPIRY ISSUES
PROMPT ----------------------------------------------------------------

SELECT DISTINCT
    u.username,
    u.account_status,
    u.profile,
    u.expiry_date,
    u.lock_date
FROM dba_users u
LEFT JOIN dba_role_privs r
       ON u.username = r.grantee
LEFT JOIN dba_sys_privs s
       ON u.username = s.grantee
WHERE (
       r.granted_role IN (
           'DBA',
           'SELECT_CATALOG_ROLE',
           'EXECUTE_CATALOG_ROLE'
       )
       OR s.privilege IN (
           'ALTER SYSTEM',
           'ALTER DATABASE',
           'CREATE USER',
           'DROP USER',
           'GRANT ANY PRIVILEGE',
           'GRANT ANY ROLE',
           'GRANT ANY OBJECT PRIVILEGE'
       )
)
AND (
       u.account_status LIKE '%EXPIRED%'
    OR u.account_status LIKE '%LOCKED%'
    OR (
        u.expiry_date IS NOT NULL
        AND u.expiry_date < SYSDATE + 30
    )
)
ORDER BY u.username;


PROMPT
PROMPT 18. USERS WITH PASSWORD EXPIRY AND RECENT LOGON
PROMPT ----------------------------------------------------------------

SELECT
    u.username,
    u.account_status,
    u.profile,
    u.expiry_date,
    u.last_login
FROM dba_users u
WHERE u.expiry_date IS NOT NULL
  AND u.expiry_date < SYSDATE + 30
ORDER BY u.expiry_date;


PROMPT
PROMPT 19. PROFILE PASSWORD SECURITY SETTINGS
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
            WHEN resource_name = 'PASSWORD_GRACE_TIME'
            THEN limit
        END
    ) AS password_grace_time,
    MAX(
        CASE
            WHEN resource_name = 'PASSWORD_LOCK_TIME'
            THEN limit
        END
    ) AS password_lock_time,
    MAX(
        CASE
            WHEN resource_name = 'FAILED_LOGIN_ATTEMPTS'
            THEN limit
        END
    ) AS failed_login_attempts,
    MAX(
        CASE
            WHEN resource_name = 'INACTIVE_ACCOUNT_TIME'
            THEN limit
        END
    ) AS inactive_account_time
FROM dba_profiles
WHERE resource_name IN (
    'PASSWORD_LIFE_TIME',
    'PASSWORD_GRACE_TIME',
    'PASSWORD_LOCK_TIME',
    'FAILED_LOGIN_ATTEMPTS',
    'INACTIVE_ACCOUNT_TIME'
)
GROUP BY profile
ORDER BY profile;


PROMPT
PROMPT 20. PASSWORD EXPIRY HEALTH SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    CASE
        WHEN SUM(
            CASE
                WHEN account_status LIKE '%EXPIRED%'
                THEN 1 ELSE 0
            END
        ) > 0
        THEN 'WARNING - EXPIRED ACCOUNTS FOUND'

        WHEN SUM(
            CASE
                WHEN expiry_date >= SYSDATE
                 AND expiry_date < SYSDATE + 7
                THEN 1 ELSE 0
            END
        ) > 0
        THEN 'WARNING - PASSWORDS EXPIRING WITHIN 7 DAYS'

        ELSE 'HEALTHY - NO IMMEDIATE PASSWORD EXPIRY ISSUE'
    END AS health_status
FROM dba_users;


PROMPT
PROMPT ================================================================
PROMPT PASSWORD EXPIRY DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Review accounts that are already expired.
PROMPT 2. Check users entering the password grace period.
PROMPT 3. Review passwords expiring within 7 days.
PROMPT 4. Review passwords expiring within 30 days.
PROMPT 5. Check locked and expired accounts.
PROMPT 6. Review PASSWORD_LIFE_TIME by profile.
PROMPT 7. Check profiles using UNLIMITED password lifetime.
PROMPT 8. Review privileged users with password issues.
PROMPT 9. Review non-Oracle-maintained application accounts.
PROMPT 10. Validate password policies against organizational standards.
PROMPT
PROMPT IMPORTANT:
PROMPT - Password expiry behavior depends on the assigned profile.
PROMPT - EXPIRED(GRACE) indicates the user is in the password grace period.
PROMPT - UNLIMITED password lifetime may be intentional for service accounts.
PROMPT - Oracle-maintained accounts require special handling.
PROMPT - Do not reset passwords or unlock accounts automatically.
PROMPT - Review application/service accounts before changing passwords.
PROMPT - Password expiry dates alone do not indicate account usage.
PROMPT
PROMPT ================================================================
PROMPT END OF PASSWORD EXPIRY MONITOR
PROMPT ================================================================


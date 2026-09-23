-- ================================================================
-- Oracle DBA Toolkit
-- Script : privileged_users.sql
-- Purpose: Identify Oracle users with elevated / privileged access
-- Usage  : Run as SYS or a user with access to DBA_* views
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN username FORMAT A30
COLUMN account_status FORMAT A25
COLUMN profile FORMAT A25
COLUMN granted_role FORMAT A30
COLUMN privilege FORMAT A45
COLUMN owner FORMAT A25
COLUMN table_name FORMAT A35
COLUMN privilege_type FORMAT A20
COLUMN admin_option FORMAT A12
COLUMN default_role FORMAT A15

PROMPT
PROMPT ================================================================
PROMPT ORACLE PRIVILEGED USER MONITOR
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
PROMPT 2. USERS WITH DBA ROLE
PROMPT ----------------------------------------------------------------

SELECT
    u.username,
    u.account_status,
    u.profile,
    r.granted_role,
    r.admin_option,
    r.default_role
FROM dba_users u
JOIN dba_role_privs r
  ON u.username = r.grantee
WHERE r.granted_role = 'DBA'
ORDER BY u.username;


PROMPT
PROMPT 3. USERS WITH POWERFUL ADMINISTRATIVE ROLES
PROMPT ----------------------------------------------------------------

SELECT
    u.username,
    u.account_status,
    r.granted_role,
    r.admin_option,
    r.default_role
FROM dba_users u
JOIN dba_role_privs r
  ON u.username = r.grantee
WHERE r.granted_role IN (
    'DBA',
    'EXP_FULL_DATABASE',
    'IMP_FULL_DATABASE',
    'DATAPUMP_EXP_FULL_DATABASE',
    'DATAPUMP_IMP_FULL_DATABASE',
    'SELECT_CATALOG_ROLE',
    'EXECUTE_CATALOG_ROLE',
    'DELETE_CATALOG_ROLE',
    'HS_ADMIN_ROLE',
    'OEM_MONITOR',
    'OEM_ADVISOR'
)
ORDER BY r.granted_role, u.username;


PROMPT
PROMPT 4. ALL ROLES GRANTED TO USERS
PROMPT ----------------------------------------------------------------

SELECT
    u.username,
    u.account_status,
    r.granted_role,
    r.admin_option,
    r.default_role
FROM dba_users u
JOIN dba_role_privs r
  ON u.username = r.grantee
ORDER BY u.username, r.granted_role;


PROMPT
PROMPT 5. USERS WITH DIRECT SYSTEM PRIVILEGES
PROMPT ----------------------------------------------------------------

SELECT
    grantee AS username,
    privilege,
    admin_option
FROM dba_sys_privs
WHERE grantee IN (
    SELECT username
    FROM dba_users
)
ORDER BY grantee, privilege;


PROMPT
PROMPT 6. HIGH-RISK SYSTEM PRIVILEGES
PROMPT ----------------------------------------------------------------

SELECT
    grantee AS username,
    privilege,
    admin_option
FROM dba_sys_privs
WHERE privilege IN (
    'ALTER DATABASE',
    'ALTER SYSTEM',
    'AUDIT ANY',
    'BECOME USER',
    'CREATE ANY DIRECTORY',
    'CREATE ANY JOB',
    'CREATE ANY PROCEDURE',
    'CREATE ANY SEQUENCE',
    'CREATE ANY TABLE',
    'CREATE ANY TRIGGER',
    'CREATE ANY VIEW',
    'CREATE DATABASE LINK',
    'CREATE USER',
    'DROP ANY DIRECTORY',
    'DROP ANY PROCEDURE',
    'DROP ANY TABLE',
    'DROP USER',
    'EXECUTE ANY PROCEDURE',
    'EXEMPT ACCESS POLICY',
    'GRANT ANY OBJECT PRIVILEGE',
    'GRANT ANY PRIVILEGE',
    'GRANT ANY ROLE',
    'SELECT ANY DICTIONARY',
    'SELECT ANY TABLE',
    'UPDATE ANY TABLE'
)
ORDER BY grantee, privilege;


PROMPT
PROMPT 7. USERS WITH ANY PRIVILEGE
PROMPT ----------------------------------------------------------------

SELECT
    grantee AS username,
    COUNT(*) AS system_privilege_count
FROM dba_sys_privs
WHERE grantee IN (
    SELECT username
    FROM dba_users
)
GROUP BY grantee
ORDER BY system_privilege_count DESC;


PROMPT
PROMPT 8. USERS WITH ADMIN OPTION
PROMPT ----------------------------------------------------------------

SELECT
    grantee AS username,
    privilege,
    admin_option
FROM dba_sys_privs
WHERE admin_option = 'YES'
ORDER BY grantee, privilege;


PROMPT
PROMPT 9. USERS WITH GRANT ANY PRIVILEGE / ROLE
PROMPT ----------------------------------------------------------------

SELECT
    grantee AS username,
    privilege,
    admin_option
FROM dba_sys_privs
WHERE privilege IN (
    'GRANT ANY PRIVILEGE',
    'GRANT ANY ROLE',
    'GRANT ANY OBJECT PRIVILEGE'
)
ORDER BY grantee, privilege;


PROMPT
PROMPT 10. USERS WITH SELECT ANY DICTIONARY
PROMPT ----------------------------------------------------------------

SELECT
    grantee AS username,
    privilege,
    admin_option
FROM dba_sys_privs
WHERE privilege = 'SELECT ANY DICTIONARY'
ORDER BY grantee;


PROMPT
PROMPT 11. USERS WITH SELECT ANY TABLE
PROMPT ----------------------------------------------------------------

SELECT
    grantee AS username,
    privilege,
    admin_option
FROM dba_sys_privs
WHERE privilege = 'SELECT ANY TABLE'
ORDER BY grantee;


PROMPT
PROMPT 12. USERS WITH EXECUTE ANY PROCEDURE
PROMPT ----------------------------------------------------------------

SELECT
    grantee AS username,
    privilege,
    admin_option
FROM dba_sys_privs
WHERE privilege = 'EXECUTE ANY PROCEDURE'
ORDER BY grantee;


PROMPT
PROMPT 13. PRIVILEGED OBJECT GRANTS
PROMPT ----------------------------------------------------------------

SELECT
    grantee AS username,
    owner,
    table_name,
    privilege,
    grantable
FROM dba_tab_privs
WHERE privilege IN (
    'DELETE',
    'INSERT',
    'SELECT',
    'UPDATE',
    'EXECUTE',
    'REFERENCES'
)
AND owner IN (
    SELECT username
    FROM dba_users
)
ORDER BY grantee, owner, table_name;


PROMPT
PROMPT 14. OBJECT PRIVILEGES WITH GRANTABLE = YES
PROMPT ----------------------------------------------------------------

SELECT
    grantee AS username,
    owner,
    table_name,
    privilege,
    grantable
FROM dba_tab_privs
WHERE grantable = 'YES'
ORDER BY grantee, owner, table_name;


PROMPT
PROMPT 15. USERS WITH DBA-LIKE ACCESS
PROMPT ----------------------------------------------------------------

SELECT DISTINCT
    grantee AS username
FROM dba_sys_privs
WHERE privilege IN (
    'ALTER SYSTEM',
    'ALTER DATABASE',
    'CREATE USER',
    'DROP USER',
    'GRANT ANY PRIVILEGE',
    'GRANT ANY ROLE',
    'GRANT ANY OBJECT PRIVILEGE',
    'SELECT ANY DICTIONARY',
    'SELECT ANY TABLE',
    'EXECUTE ANY PROCEDURE',
    'BECOME USER'
)
ORDER BY username;


PROMPT
PROMPT 16. PRIVILEGED USERS CURRENTLY CONNECTED
PROMPT ----------------------------------------------------------------

SELECT
    s.username,
    s.sid,
    s.serial# AS serial,
    s.status,
    s.logon_time,
    s.machine,
    s.program,
    s.module,
    s.service_name,
    s.sql_id
FROM v$session s
WHERE s.username IN (
    SELECT username
    FROM dba_users
    WHERE username IN (
        SELECT grantee
        FROM dba_sys_privs
        WHERE privilege IN (
            'ALTER SYSTEM',
            'ALTER DATABASE',
            'CREATE USER',
            'DROP USER',
            'GRANT ANY PRIVILEGE',
            'GRANT ANY ROLE',
            'GRANT ANY OBJECT PRIVILEGE',
            'SELECT ANY DICTIONARY',
            'SELECT ANY TABLE',
            'EXECUTE ANY PROCEDURE',
            'BECOME USER'
        )
    )
)
ORDER BY s.username, s.sid;


PROMPT
PROMPT 17. PRIVILEGED USERS WITH ACTIVE SESSIONS
PROMPT ----------------------------------------------------------------

SELECT
    s.username,
    COUNT(*) AS active_sessions
FROM v$session s
WHERE s.username IN (
    SELECT grantee
    FROM dba_sys_privs
    WHERE privilege IN (
        'ALTER SYSTEM',
        'ALTER DATABASE',
        'CREATE USER',
        'DROP USER',
        'GRANT ANY PRIVILEGE',
        'GRANT ANY ROLE',
        'GRANT ANY OBJECT PRIVILEGE',
        'SELECT ANY DICTIONARY',
        'SELECT ANY TABLE',
        'EXECUTE ANY PROCEDURE',
        'BECOME USER'
    )
)
AND s.status = 'ACTIVE'
GROUP BY s.username
ORDER BY active_sessions DESC;


PROMPT
PROMPT 18. PRIVILEGED USERS BY CLIENT MACHINE
PROMPT ----------------------------------------------------------------

SELECT
    s.username,
    s.machine,
    s.program,
    s.module,
    COUNT(*) AS sessions
FROM v$session s
WHERE s.username IN (
    SELECT grantee
    FROM dba_sys_privs
    WHERE privilege IN (
        'ALTER SYSTEM',
        'ALTER DATABASE',
        'CREATE USER',
        'DROP USER',
        'GRANT ANY PRIVILEGE',
        'GRANT ANY ROLE',
        'GRANT ANY OBJECT PRIVILEGE',
        'SELECT ANY DICTIONARY',
        'SELECT ANY TABLE',
        'EXECUTE ANY PROCEDURE',
        'BECOME USER'
    )
)
GROUP BY
    s.username,
    s.machine,
    s.program,
    s.module
ORDER BY sessions DESC;


PROMPT
PROMPT 19. PRIVILEGED USERS WITH PASSWORD / ACCOUNT ISSUES
PROMPT ----------------------------------------------------------------

SELECT
    username,
    account_status,
    profile,
    lock_date,
    expiry_date,
    created
FROM dba_users
WHERE username IN (
    SELECT grantee
    FROM dba_sys_privs
    WHERE privilege IN (
        'ALTER SYSTEM',
        'ALTER DATABASE',
        'CREATE USER',
        'DROP USER',
        'GRANT ANY PRIVILEGE',
        'GRANT ANY ROLE',
        'GRANT ANY OBJECT PRIVILEGE',
        'SELECT ANY DICTIONARY',
        'SELECT ANY TABLE',
        'EXECUTE ANY PROCEDURE',
        'BECOME USER'
    )
)
AND (
       account_status LIKE '%LOCKED%'
    OR account_status LIKE '%EXPIRED%'
    OR account_status LIKE '%EXPIRED(GRACE)%'
)
ORDER BY username;


PROMPT
PROMPT 20. PRIVILEGED USER SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(DISTINCT username) AS users_with_privileges
FROM (
    SELECT grantee AS username
    FROM dba_sys_privs
    WHERE privilege IN (
        'ALTER SYSTEM',
        'ALTER DATABASE',
        'CREATE USER',
        'DROP USER',
        'GRANT ANY PRIVILEGE',
        'GRANT ANY ROLE',
        'GRANT ANY OBJECT PRIVILEGE',
        'SELECT ANY DICTIONARY',
        'SELECT ANY TABLE',
        'EXECUTE ANY PROCEDURE',
        'BECOME USER'
    )

    UNION

    SELECT grantee AS username
    FROM dba_role_privs
    WHERE granted_role IN (
        'DBA',
        'SELECT_CATALOG_ROLE',
        'EXECUTE_CATALOG_ROLE',
        'EXP_FULL_DATABASE',
        'IMP_FULL_DATABASE'
    )
);


PROMPT
PROMPT ================================================================
PROMPT PRIVILEGED USER DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Review all users granted the DBA role.
PROMPT 2. Review powerful administrative roles.
PROMPT 3. Review direct system privileges.
PROMPT 4. Check GRANT ANY PRIVILEGE / ROLE / OBJECT PRIVILEGE.
PROMPT 5. Check SELECT ANY DICTIONARY and SELECT ANY TABLE.
PROMPT 6. Review CREATE/DROP USER privileges.
PROMPT 7. Review EXECUTE ANY PROCEDURE and BECOME USER.
PROMPT 8. Check privileged users currently connected.
PROMPT 9. Check privileged users with active sessions.
PROMPT 10. Review privileged access by machine/program.
PROMPT 11. Review locked or expired privileged accounts.
PROMPT 12. Validate privileged access against your organization's policy.
PROMPT
PROMPT IMPORTANT:
PROMPT - DBA role or powerful privileges may be intentional.
PROMPT - This script reports access; it does not revoke privileges.
PROMPT - Role inheritance can provide privileges indirectly.
PROMPT - SYS, SYSTEM and Oracle-maintained accounts require special handling.
PROMPT - Review privileges before making production changes.
PROMPT - Privilege review should be combined with audit/logon monitoring.
PROMPT
PROMPT ================================================================
PROMPT END OF PRIVILEGED USER MONITOR
PROMPT ================================================================


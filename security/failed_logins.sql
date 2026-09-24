-- ============================================================
-- Oracle DBA Toolkit
-- Script  : failed_logins.sql
-- Purpose : Find failed database login attempts
-- Requires: Unified Auditing / appropriate audit configuration
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100

COLUMN USERNAME FORMAT A30
COLUMN OS_USERNAME FORMAT A25
COLUMN EVENT_TIMESTAMP FORMAT A30
COLUMN RETURN_CODE FORMAT 99999
COLUMN ACTION_NAME FORMAT A15

PROMPT
PROMPT ============================================================
PROMPT              FAILED DATABASE LOGINS
PROMPT ============================================================
PROMPT

SELECT
    dbusername AS username,
    os_username,
    event_timestamp,
    return_code,
    action_name
FROM
    unified_audit_trail
WHERE
    action_name = 'LOGON'
    AND return_code <> 0
ORDER BY
    event_timestamp DESC
FETCH FIRST 50 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT              FAILED LOGIN SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    dbusername AS username,
    COUNT(*) AS failed_attempts
FROM
    unified_audit_trail
WHERE
    action_name = 'LOGON'
    AND return_code <> 0
GROUP BY
    dbusername
ORDER BY
    failed_attempts DESC;

PROMPT
PROMPT ============================================================
PROMPT              END OF REPORT
PROMPT ============================================================
 

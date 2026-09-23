-- ============================================================
-- Oracle Database Errors Monitoring
-- File   : database_errors.sql
-- Purpose: Monitor recent Oracle database errors and failures
-- Author : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN originating_timestamp FORMAT A24
COLUMN message_text          FORMAT A100 WORD_WRAP
COLUMN message_id            FORMAT A15
COLUMN problem_key           FORMAT A35
COLUMN host_id               FORMAT A25
COLUMN component_id          FORMAT A20
COLUMN error_count           FORMAT 999,999,999
COLUMN hour                  FORMAT A16
COLUMN error_code             FORMAT A15

PROMPT
PROMPT ============================================================
PROMPT ORACLE DATABASE ERROR MONITORING
PROMPT ============================================================
PROMPT

-- ============================================================
-- 1. DATABASE INFORMATION
-- ============================================================

PROMPT ============================================================
PROMPT 1. DATABASE INFORMATION
PROMPT ============================================================

SELECT
    name,
    db_unique_name,
    open_mode,
    database_role,
    log_mode,
    force_logging
FROM v$database;

SELECT
    instance_name,
    host_name,
    version,
    status,
    startup_time
FROM v$instance;

-- ============================================================
-- 2. RECENT DATABASE ERRORS - LAST 24 HOURS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. ORACLE ERRORS - LAST 24 HOURS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND REGEXP_LIKE(message_text, 'ORA-[0-9]+')
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 3. ORACLE ERRORS - LAST 7 DAYS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. ORACLE ERRORS - LAST 7 DAYS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND REGEXP_LIKE(message_text, 'ORA-[0-9]+')
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 4. ERROR FREQUENCY BY MESSAGE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. ERROR FREQUENCY BY MESSAGE
PROMPT ============================================================

SELECT
    message_id,
    problem_key,
    COUNT(*) AS error_count
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND REGEXP_LIKE(message_text, 'ORA-[0-9]+')
GROUP BY
    message_id,
    problem_key
ORDER BY error_count DESC;

-- ============================================================
-- 5. ERROR FREQUENCY BY HOUR
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. ERROR FREQUENCY BY HOUR
PROMPT ============================================================

SELECT
    TO_CHAR(
        CAST(originating_timestamp AS TIMESTAMP),
        'YYYY-MM-DD HH24'
    ) AS hour,
    COUNT(*) AS error_count
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND REGEXP_LIKE(message_text, 'ORA-[0-9]+')
GROUP BY
    TO_CHAR(
        CAST(originating_timestamp AS TIMESTAMP),
        'YYYY-MM-DD HH24'
    )
ORDER BY hour DESC;

-- ============================================================
-- 6. CRITICAL ORACLE ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. CRITICAL ORACLE ERRORS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND (
        message_text LIKE '%ORA-00600%'
     OR message_text LIKE '%ORA-07445%'
     OR message_text LIKE '%ORA-04031%'
     OR message_text LIKE '%ORA-00060%'
     OR message_text LIKE '%ORA-01555%'
     OR message_text LIKE '%ORA-0165%'
     OR message_text LIKE '%ORA-1980%'
     OR message_text LIKE '%ORA-03113%'
     OR message_text LIKE '%ORA-03135%'
  )
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 7. INTERNAL ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. INTERNAL / CRITICAL ERRORS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND (
        message_text LIKE '%ORA-00600%'
     OR message_text LIKE '%ORA-07445%'
     OR message_text LIKE '%ORA-04031%'
  )
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 8. DEADLOCK ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. DEADLOCK ERRORS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND (
        message_text LIKE '%ORA-00060%'
     OR UPPER(message_text) LIKE '%DEADLOCK%'
  )
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 9. SPACE-RELATED ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. SPACE-RELATED ERRORS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND (
        message_text LIKE '%ORA-0165%'
     OR message_text LIKE '%ORA-01652%'
     OR message_text LIKE '%ORA-01653%'
     OR message_text LIKE '%ORA-01654%'
     OR message_text LIKE '%ORA-01658%'
     OR message_text LIKE '%ORA-19809%'
     OR message_text LIKE '%ORA-19815%'
  )
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 10. NETWORK / CONNECTION ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. NETWORK / CONNECTION ERRORS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND (
        message_text LIKE '%ORA-03113%'
     OR message_text LIKE '%ORA-03135%'
     OR message_text LIKE '%TNS-%'
     OR UPPER(message_text) LIKE '%LISTENER%'
     OR UPPER(message_text) LIKE '%CONNECTION%'
  )
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 11. DATA GUARD RELATED ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. DATA GUARD RELATED ERRORS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND (
        UPPER(message_text) LIKE '%DATAGUARD%'
     OR UPPER(message_text) LIKE '%STANDBY%'
     OR UPPER(message_text) LIKE '%ARCHIVE GAP%'
     OR UPPER(message_text) LIKE '%REDO TRANSPORT%'
     OR UPPER(message_text) LIKE '%MRP%'
     OR UPPER(message_text) LIKE '%RFS%'
  )
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 12. ASM / STORAGE RELATED ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. ASM / STORAGE RELATED ERRORS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND (
        UPPER(message_text) LIKE '%ASM%'
     OR UPPER(message_text) LIKE '%DISK%'
     OR UPPER(message_text) LIKE '%I/O%'
     OR UPPER(message_text) LIKE '%STORAGE%'
  )
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 13. STARTUP / SHUTDOWN EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. DATABASE STARTUP / SHUTDOWN EVENTS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND (
        UPPER(message_text) LIKE '%STARTUP%'
     OR UPPER(message_text) LIKE '%SHUTDOWN%'
     OR UPPER(message_text) LIKE '%INSTANCE STARTED%'
     OR UPPER(message_text) LIKE '%INSTANCE TERMINATED%'
  )
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 14. MOST FREQUENT ORACLE ERROR CODES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. MOST FREQUENT ORACLE ERROR CODES
PROMPT ============================================================

SELECT
    REGEXP_SUBSTR(message_text, 'ORA-[0-9]+') AS error_code,
    COUNT(*) AS error_count
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND REGEXP_LIKE(message_text, 'ORA-[0-9]+')
GROUP BY
    REGEXP_SUBSTR(message_text, 'ORA-[0-9]+')
ORDER BY error_count DESC;

-- ============================================================
-- 15. RECENT HIGH-SEVERITY ALERT MESSAGES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. HIGH-SEVERITY ALERT MESSAGES
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_level,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND message_level <= 3
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 16. DATABASE ERROR SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. DATABASE ERROR SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS errors_last_24h
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND REGEXP_LIKE(message_text, 'ORA-[0-9]+');

SELECT
    COUNT(*) AS errors_last_7d
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND REGEXP_LIKE(message_text, 'ORA-[0-9]+');

-- ============================================================
-- 17. QUICK ERROR HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. QUICK ERROR HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN COUNT(*) = 0
            THEN 'HEALTHY - No ORA errors in last 24 hours'
        WHEN COUNT(*) <= 10
            THEN 'WARNING - ORA errors detected'
        ELSE
            'CRITICAL - High number of ORA errors detected'
    END AS database_error_status,
    COUNT(*) AS errors_last_24h
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND REGEXP_LIKE(message_text, 'ORA-[0-9]+');

PROMPT
PROMPT ============================================================
PROMPT INVESTIGATION NOTES
PROMPT ============================================================
PROMPT ORA-00600 / ORA-07445  -> Check ADR, trace files and Oracle Support.
PROMPT ORA-04031              -> Investigate SGA/shared pool memory pressure.
PROMPT ORA-00060              -> Investigate deadlocks and blocking sessions.
PROMPT ORA-01555              -> Investigate UNDO and long-running queries.
PROMPT ORA-0165x              -> Investigate tablespace/TEMP space.
PROMPT ORA-1980x              -> Investigate FRA/recovery destination usage.
PROMPT ORA-03113/03135        -> Investigate process, network and instance events.
PROMPT
PROMPT Always correlate alert-log errors with current database state.
PROMPT Do not assume every historical error represents a current incident.
PROMPT ============================================================


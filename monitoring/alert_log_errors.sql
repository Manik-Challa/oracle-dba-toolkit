-- ============================================================
-- Oracle DBA Toolkit
-- Alert Log Error Monitoring
--
-- Purpose:
--   Monitor recent Oracle alert log errors, warnings, and
--   important database events using V$DIAG_ALERT_EXT.
--
-- Key checks:
--   - Recent alert log errors
--   - ORA- errors
--   - Critical / severe messages
--   - Errors by message ID
--   - Errors by hour
--   - Recent startup/shutdown events
--   - Recent Data Guard-related messages
--   - Recent storage / ASM-related messages
--
-- Notes:
--   V$DIAG_ALERT_EXT exposes ADR alert information through SQL.
--   Run with appropriate privileges.
--
--   Alert log messages are historical records. A message appearing
--   here does not automatically mean the database is currently
--   unhealthy. Correlate with current database state and timestamps.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN originating_timestamp FORMAT A22
COLUMN message_type          FORMAT 999
COLUMN message_level        FORMAT 999
COLUMN problem_key           FORMAT A35
COLUMN message_id            FORMAT A20
COLUMN module_id             FORMAT A25
COLUMN process_id            FORMAT A15
COLUMN instance_id           FORMAT A15
COLUMN host_id               FORMAT A30
COLUMN message_text          FORMAT A100 WORD_WRAPPED

PROMPT
PROMPT ============================================================
PROMPT 1. RECENT ALERT LOG MESSAGES
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        originating_timestamp,
        message_type,
        message_level,
        message_id,
        problem_key,
        message_text
    FROM v$diag_alert_ext
    ORDER BY originating_timestamp DESC
)
WHERE ROWNUM <= 50;


PROMPT
PROMPT ============================================================
PROMPT 2. RECENT ALERT LOG ERRORS
PROMPT    Last 24 hours
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_type,
    message_level,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND (
        message_text LIKE '%ORA-%'
        OR message_level <= 2
      )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================
PROMPT 3. ORA- ERRORS - LAST 24 HOURS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        originating_timestamp,
        message_id,
        problem_key,
        message_text
    FROM v$diag_alert_ext
    WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
      AND message_text LIKE '%ORA-%'
    ORDER BY originating_timestamp DESC
)
WHERE ROWNUM <= 50;


PROMPT
PROMPT ============================================================
PROMPT 4. CRITICAL / SEVERE ALERT MESSAGES
PROMPT    Last 24 hours
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_type,
    message_level,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND message_level <= 2
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================
PROMPT 5. ALERT ERRORS BY MESSAGE ID
PROMPT    Last 24 hours
PROMPT ============================================================

SELECT
    NVL(message_id, '<NO MESSAGE ID>') AS message_id,
    COUNT(*) AS error_count
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND (
        message_text LIKE '%ORA-%'
        OR message_level <= 2
      )
GROUP BY message_id
ORDER BY error_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 6. ALERT ERRORS BY PROBLEM KEY
PROMPT    Last 24 hours
PROMPT ============================================================

SELECT
    NVL(problem_key, '<NO PROBLEM KEY>') AS problem_key,
    COUNT(*) AS message_count
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND (
        message_text LIKE '%ORA-%'
        OR message_level <= 2
      )
GROUP BY problem_key
ORDER BY message_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. ALERT ERROR FREQUENCY BY HOUR
PROMPT    Last 24 hours
PROMPT ============================================================

SELECT
    TO_CHAR(
        CAST(originating_timestamp AS TIMESTAMP),
        'YYYY-MM-DD HH24'
    ) AS alert_hour,
    COUNT(*) AS error_count
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND (
        message_text LIKE '%ORA-%'
        OR message_level <= 2
      )
GROUP BY
    TO_CHAR(
        CAST(originating_timestamp AS TIMESTAMP),
        'YYYY-MM-DD HH24'
    )
ORDER BY alert_hour DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. ALERT ERRORS - LAST 7 DAYS
PROMPT ============================================================

SELECT *
FROM (
    SELECT
        originating_timestamp,
        message_id,
        problem_key,
        message_text
    FROM v$diag_alert_ext
    WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
      AND message_text LIKE '%ORA-%'
    ORDER BY originating_timestamp DESC
)
WHERE ROWNUM <= 100;


PROMPT
PROMPT ============================================================
PROMPT 9. STARTUP / SHUTDOWN RELATED EVENTS
PROMPT    Last 7 days
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
        OR UPPER(message_text) LIKE '%DATABASE OPEN%'
        OR UPPER(message_text) LIKE '%DATABASE MOUNT%'
      )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. DATA GUARD RELATED ALERT MESSAGES
PROMPT     Last 24 hours
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND (
        UPPER(message_text) LIKE '%DATAGUARD%'
        OR UPPER(message_text) LIKE '%REDO TRANSPORT%'
        OR UPPER(message_text) LIKE '%STANDBY%'
        OR UPPER(message_text) LIKE '%ARCHIVE GAP%'
        OR UPPER(message_text) LIKE '%MRP%'
        OR UPPER(message_text) LIKE '%RFS%'
      )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================
PROMPT 11. ASM / STORAGE RELATED ALERT MESSAGES
PROMPT     Last 24 hours
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND (
        UPPER(message_text) LIKE '%ASM%'
        OR UPPER(message_text) LIKE '%DISK%'
        OR UPPER(message_text) LIKE '%I/O%'
        OR UPPER(message_text) LIKE '%IO ERROR%'
        OR UPPER(message_text) LIKE '%I/O ERROR%'
      )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================
PROMPT 12. TNS / NETWORK RELATED ALERT MESSAGES
PROMPT     Last 24 hours
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND (
        UPPER(message_text) LIKE '%TNS-%'
        OR UPPER(message_text) LIKE '%CONNECTION%'
        OR UPPER(message_text) LIKE '%NETWORK%'
        OR UPPER(message_text) LIKE '%LISTENER%'
      )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================
PROMPT 13. INSTANCE / PROCESS RELATED ERRORS
PROMPT     Last 24 hours
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY
  AND (
        UPPER(message_text) LIKE '%PROCESS%'
        OR UPPER(message_text) LIKE '%BACKGROUND PROCESS%'
        OR UPPER(message_text) LIKE '%ORA-00020%'
        OR UPPER(message_text) LIKE '%ORA-00018%'
        OR UPPER(message_text) LIKE '%ORA-00600%'
        OR UPPER(message_text) LIKE '%ORA-07445%'
      )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. COMMON CRITICAL ORACLE ERRORS
PROMPT     Last 7 days
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
        OR message_text LIKE '%ORA-01652%'
        OR message_text LIKE '%ORA-01653%'
        OR message_text LIKE '%ORA-01654%'
        OR message_text LIKE '%ORA-19809%'
        OR message_text LIKE '%ORA-19815%'
        OR message_text LIKE '%ORA-03113%'
        OR message_text LIKE '%ORA-03135%'
      )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. ALERT MESSAGE SUMMARY
PROMPT     Last 24 hours
PROMPT ============================================================

SELECT
    COUNT(*) AS total_messages,
    SUM(
        CASE
            WHEN message_text LIKE '%ORA-%' THEN 1
            ELSE 0
        END
    ) AS ora_errors,
    SUM(
        CASE
            WHEN message_level <= 2 THEN 1
            ELSE 0
        END
    ) AS critical_messages
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY;


PROMPT
PROMPT ============================================================
PROMPT 16. ALERT HEALTH CHECK
PROMPT     Last 24 hours
PROMPT ============================================================

SELECT
    CASE
        WHEN COUNT(
            CASE
                WHEN message_text LIKE '%ORA-%'
                  OR message_level <= 2
                THEN 1
            END
        ) = 0
        THEN 'OK - No matching alert errors'
        ELSE 'CHECK - Alert errors/messages found'
    END AS alert_health_status,
    COUNT(
        CASE
            WHEN message_text LIKE '%ORA-%'
            THEN 1
        END
    ) AS ora_error_count,
    COUNT(
        CASE
            WHEN message_level <= 2
            THEN 1
        END
    ) AS critical_message_count
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '1' DAY;


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION NOTES
PROMPT ============================================================
PROMPT
PROMPT 1. Start with the timestamp and message text before taking
PROMPT    corrective action.
PROMPT
PROMPT 2. Repeated ORA- errors should be grouped by MESSAGE_ID or
PROMPT    PROBLEM_KEY to identify recurring issues.
PROMPT
PROMPT 3. ORA-00600 and ORA-07445 require detailed investigation
PROMPT    using the associated trace files and ADR information.
PROMPT
PROMPT 4. ORA-04031 may indicate shared pool / memory pressure.
PROMPT
PROMPT 5. ORA-00060 indicates a deadlock and should be correlated
PROMPT    with application transactions and trace information.
PROMPT
PROMPT 6. ORA-01555 can be related to undo/long-running query
PROMPT    conditions and requires transaction/query investigation.
PROMPT
PROMPT 7. ORA-0165x errors should be correlated with tablespace,
PROMPT    datafile, and TEMP usage.
PROMPT
PROMPT 8. ORA-198xx errors should be correlated with FRA usage
PROMPT    and archive log management.
PROMPT
PROMPT 9. ORA-03113 / ORA-03135 should be correlated with
PROMPT    network, process, database, and alert-log events.
PROMPT
PROMPT 10. Alert messages are historical evidence. Always verify
PROMPT     the current database state before declaring an active
PROMPT     incident.
PROMPT
PROMPT ============================================================
PROMPT END OF ALERT LOG ERROR MONITORING
PROMPT ============================================================


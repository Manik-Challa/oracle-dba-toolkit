-- ================================================================
-- Oracle DBA Toolkit
-- Script : flash_log.sql
-- Purpose: Monitor Exadata Flash Log / Smart Flash Log Activity
-- Usage  : Run on an Exadata database
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN name FORMAT A65
COLUMN value FORMAT 999,999,999,999,999
COLUMN event FORMAT A60
COLUMN sql_id FORMAT A15
COLUMN parsing_schema_name FORMAT A25
COLUMN module FORMAT A30
COLUMN cell_name FORMAT A35
COLUMN metric_name FORMAT A55
COLUMN metric_value FORMAT A30

PROMPT
PROMPT ================================================================
PROMPT EXADATA FLASH LOG / SMART FLASH LOG MONITOR
PROMPT ================================================================

PROMPT
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ----------------------------------------------------------------

SELECT
    d.name AS database_name,
    i.instance_name,
    i.host_name,
    i.version,
    d.open_mode,
    d.database_role
FROM v$database d
CROSS JOIN v$instance i;

PROMPT
PROMPT 2. EXADATA CELL VISIBILITY
PROMPT ----------------------------------------------------------------

SELECT
    cell_name,
    status
FROM v$cell
ORDER BY cell_name;

PROMPT
PROMPT 3. FLASH LOG RELATED SYSTEM STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%flash log%'
   OR LOWER(name) LIKE '%flashlog%'
ORDER BY name;

PROMPT
PROMPT 4. CELL / FLASH LOG STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE (
        LOWER(name) LIKE '%cell%'
        AND LOWER(name) LIKE '%log%'
      )
   OR LOWER(name) LIKE '%flash log%'
ORDER BY name;

PROMPT
PROMPT 5. REDO GENERATION STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    ROUND(value / 1024 / 1024 / 1024, 2) AS value_gb
FROM v$sysstat
WHERE name IN (
    'redo size',
    'redo entries',
    'redo writes',
    'redo blocks written'
)
ORDER BY name;

PROMPT
PROMPT 6. REDO WRITE STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%redo%'
ORDER BY name;

PROMPT
PROMPT 7. REDO LOG STATUS
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    group#,
    sequence#,
    bytes / 1024 / 1024 AS size_mb,
    members,
    archived,
    status
FROM v$log
ORDER BY thread#, group#;

PROMPT
PROMPT 8. CURRENT REDO LOG
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    group#,
    sequence#,
    status,
    first_time,
    first_change#,
    next_change#
FROM v$log
WHERE status = 'CURRENT'
ORDER BY thread#;

PROMPT
PROMPT 9. RECENT LOG SWITCH ACTIVITY
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    COUNT(*) AS log_switches,
    MIN(first_time) AS first_switch,
    MAX(first_time) AS last_switch
FROM v$log_history
WHERE first_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;

PROMPT
PROMPT 10. HOURLY REDO / LOG SWITCH ACTIVITY
PROMPT ----------------------------------------------------------------

SELECT
    thread#,
    TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS switch_hour,
    COUNT(*) AS log_switches
FROM v$log_history
WHERE first_time >= SYSDATE - 1
GROUP BY
    thread#,
    TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY switch_hour DESC, thread#;

PROMPT
PROMPT 11. REDO WRITE WAIT EVENTS
PROMPT ----------------------------------------------------------------

SELECT
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN (time_waited / 100) / total_waits
        END,
        6
    ) AS avg_wait_sec
FROM v$system_event
WHERE LOWER(event) LIKE '%redo%'
   OR LOWER(event) LIKE '%log file%'
   OR LOWER(event) LIKE '%flash%'
ORDER BY time_waited DESC;

PROMPT
PROMPT 12. CURRENT REDO / FLASH LOG WAITERS
PROMPT ----------------------------------------------------------------

SELECT
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    seconds_in_wait,
    state,
    machine,
    program
FROM v$session
WHERE status = 'ACTIVE'
  AND (
       LOWER(event) LIKE '%redo%'
       OR LOWER(event) LIKE '%log file%'
       OR LOWER(event) LIKE '%flash%'
      )
ORDER BY seconds_in_wait DESC;

PROMPT
PROMPT 13. REDO LOG FILE I/O
PROMPT ----------------------------------------------------------------

SELECT
    lf.group#,
    lf.member,
    l.thread#,
    l.sequence#,
    l.status
FROM v$logfile lf
JOIN v$log l
  ON lf.group# = l.group#
ORDER BY lf.group#, lf.member;

PROMPT
PROMPT 14. REDO LOG MEMBERS BY GROUP
PROMPT ----------------------------------------------------------------

SELECT
    group#,
    COUNT(*) AS members,
    LISTAGG(member, ', ')
        WITHIN GROUP (ORDER BY member) AS redo_members
FROM v$logfile
GROUP BY group#
ORDER BY group#;

PROMPT
PROMPT 15. REDO WRITE PERFORMANCE
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE name IN (
    'redo writes',
    'redo blocks written',
    'redo write time',
    'redo synch writes',
    'redo synch time'
)
ORDER BY name;

PROMPT
PROMPT 16. REDO SYNCHRONIZATION STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%redo synch%'
ORDER BY name;

PROMPT
PROMPT 17. REDO SYNCHRONIZATION WAIT EVENTS
PROMPT ----------------------------------------------------------------

SELECT
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN (time_waited / 100) / total_waits
        END,
        6
    ) AS avg_wait_sec
FROM v$system_event
WHERE LOWER(event) LIKE '%redo synch%'
   OR LOWER(event) LIKE '%log file sync%'
   OR LOWER(event) LIKE '%log file parallel%'
ORDER BY time_waited DESC;

PROMPT
PROMPT 18. RAC REDO STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    inst_id,
    name,
    value
FROM gv$sysstat
WHERE LOWER(name) LIKE '%redo%'
   OR LOWER(name) LIKE '%flash log%'
ORDER BY inst_id, name;

PROMPT
PROMPT 19. CELL FLASH / LOG METRICS
PROMPT ----------------------------------------------------------------

SELECT
    cell_name,
    metric_name,
    metric_value
FROM v$cell_metric
WHERE LOWER(metric_name) LIKE '%flash%'
   OR LOWER(metric_name) LIKE '%log%'
ORDER BY cell_name, metric_name;

PROMPT
PROMPT 20. RECENT FLASH / REDO / STORAGE ALERTS
PROMPT ----------------------------------------------------------------

SELECT
    originating_timestamp,
    message_type,
    message_level,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
       LOWER(message_text) LIKE '%flash log%'
       OR LOWER(message_text) LIKE '%flashlog%'
       OR LOWER(message_text) LIKE '%redo%'
       OR LOWER(message_text) LIKE '%log file%'
       OR LOWER(message_text) LIKE '%storage cell%'
      )
ORDER BY originating_timestamp DESC;

PROMPT
PROMPT ================================================================
PROMPT FLASH LOG DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Confirm Exadata cells are visible through V$CELL.
PROMPT 2. Review Flash Log / cell log statistics where exposed.
PROMPT 3. Check redo generation and redo write activity.
PROMPT 4. Review "log file sync" waits.
PROMPT 5. Review "log file parallel write" waits.
PROMPT 6. Check redo log switch frequency.
PROMPT 7. Check redo log groups and members.
PROMPT 8. Review current sessions waiting on redo/log events.
PROMPT 9. Check RAC redo activity by instance.
PROMPT 10. Correlate DB statistics with CellCLI metrics.
PROMPT 11. Review recent storage/cell alerts.
PROMPT
PROMPT IMPORTANT:
PROMPT - Smart Flash Log is an Exadata storage feature for redo log writes.
PROMPT - Database-side counters vary by Oracle/Exadata release.
PROMPT - Flash Log statistics should be correlated with redo wait events.
PROMPT - High log file sync can have causes beyond storage latency.
PROMPT - Redo statistics are generally cumulative counters.
PROMPT - CellCLI is required for detailed storage-cell Flash Log health.
PROMPT - Verify V$CELL_METRIC metric names on the target platform.
PROMPT
PROMPT ================================================================
PROMPT END OF FLASH LOG MONITOR
PROMPT ================================================================


-- ================================================================
-- Oracle DBA Toolkit
-- Script : flash_cache.sql
-- Purpose: Monitor Exadata Flash Cache / Smart Flash Cache
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
PROMPT EXADATA FLASH CACHE MONITOR
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
PROMPT 3. FLASH CACHE RELATED SYSTEM STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%flash cache%'
   OR LOWER(name) LIKE '%flash log%'
   OR LOWER(name) LIKE '%flash%'
ORDER BY name;

PROMPT
PROMPT 4. FLASH CACHE STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    ROUND(value / 1024 / 1024 / 1024, 2) AS value_gb
FROM v$sysstat
WHERE LOWER(name) LIKE '%flash cache%'
ORDER BY name;

PROMPT
PROMPT 5. FLASH CACHE READ STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%flash%'
  AND (
       LOWER(name) LIKE '%read%'
       OR LOWER(name) LIKE '%hit%'
      )
ORDER BY name;

PROMPT
PROMPT 6. FLASH CACHE WRITE STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%flash%'
  AND (
       LOWER(name) LIKE '%write%'
       OR LOWER(name) LIKE '%flush%'
      )
ORDER BY name;

PROMPT
PROMPT 7. FLASH CACHE RELATED WAIT EVENTS
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
        4
    ) AS avg_wait_sec
FROM v$system_event
WHERE LOWER(event) LIKE '%flash%'
   OR LOWER(event) LIKE '%cell%'
ORDER BY time_waited DESC;

PROMPT
PROMPT 8. CURRENT FLASH / CELL WAITERS
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
       LOWER(event) LIKE '%flash%'
       OR LOWER(event) LIKE '%cell%'
      )
ORDER BY seconds_in_wait DESC;

PROMPT
PROMPT 9. DATABASE PHYSICAL I/O
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE name IN (
    'physical reads',
    'physical reads direct',
    'physical reads direct (lob)',
    'physical writes',
    'physical writes direct'
)
ORDER BY name;

PROMPT
PROMPT 10. DATABASE I/O BY FILE
PROMPT ----------------------------------------------------------------

SELECT
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    fs.phyrds AS physical_reads,
    fs.phywrts AS physical_writes,
    fs.readtim AS read_time,
    fs.writetim AS write_time
FROM dba_data_files df
JOIN v$filestat fs
  ON df.file_id = fs.file#
ORDER BY fs.phyrds DESC;

PROMPT
PROMPT 11. TOP SQL BY PHYSICAL READS
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        sql_id,
        child_number,
        plan_hash_value,
        parsing_schema_name,
        executions,
        disk_reads,
        physical_read_bytes,
        ROUND(
            CASE
                WHEN executions > 0
                THEN disk_reads / executions
            END,
            2
        ) AS disk_reads_per_exec,
        ROUND(
            CASE
                WHEN executions > 0
                THEN physical_read_bytes / executions / 1024 / 1024
            END,
            2
        ) AS mb_read_per_exec,
        module
    FROM v$sql
    WHERE executions > 0
      AND physical_read_bytes > 0
    ORDER BY physical_read_bytes DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 12. TOP SQL BY DIRECT PHYSICAL READS
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        sql_id,
        child_number,
        plan_hash_value,
        parsing_schema_name,
        executions,
        disk_reads,
        physical_read_bytes,
        ROUND(
            physical_read_bytes / 1024 / 1024 / 1024,
            2
        ) AS physical_read_gb,
        module
    FROM v$sql
    WHERE physical_read_bytes > 0
    ORDER BY physical_read_bytes DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 13. CELL FLASH-RELATED STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%cell%'
  AND (
       LOWER(name) LIKE '%flash%'
       OR LOWER(name) LIKE '%cache%'
      )
ORDER BY name;

PROMPT
PROMPT 14. CELL METRICS RELATED TO FLASH / CACHE
PROMPT ----------------------------------------------------------------

SELECT
    cell_name,
    metric_name,
    metric_value
FROM v$cell_metric
WHERE LOWER(metric_name) LIKE '%flash%'
   OR LOWER(metric_name) LIKE '%cache%'
ORDER BY cell_name, metric_name;

PROMPT
PROMPT 15. RAC FLASH / CELL STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    inst_id,
    name,
    value
FROM gv$sysstat
WHERE LOWER(name) LIKE '%flash%'
   OR (
       LOWER(name) LIKE '%cell%'
       AND LOWER(name) LIKE '%cache%'
      )
ORDER BY inst_id, name;

PROMPT
PROMPT 16. RECENT FLASH / STORAGE ALERTS
PROMPT ----------------------------------------------------------------

SELECT
    originating_timestamp,
    message_type,
    message_level,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
       LOWER(message_text) LIKE '%flash cache%'
       OR LOWER(message_text) LIKE '%flash%'
       OR LOWER(message_text) LIKE '%storage cell%'
      )
ORDER BY originating_timestamp DESC;

PROMPT
PROMPT 17. QUICK FLASH CACHE HEALTH SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    COUNT(*) AS flash_statistics
FROM v$sysstat
WHERE LOWER(name) LIKE '%flash cache%';

PROMPT
PROMPT ================================================================
PROMPT FLASH CACHE DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Confirm Exadata cells are visible through V$CELL.
PROMPT 2. Review Flash Cache related V$SYSSTAT counters.
PROMPT 3. Review Flash Cache read/write statistics.
PROMPT 4. Check cell and flash-related wait events.
PROMPT 5. Identify SQL generating high physical I/O.
PROMPT 6. Review physical I/O by datafile.
PROMPT 7. Check V$CELL_METRIC where supported.
PROMPT 8. Review recent storage/Flash Cache alerts.
PROMPT 9. Correlate database metrics with CellCLI.
PROMPT
PROMPT IMPORTANT:
PROMPT - Flash Cache behavior is controlled at the Exadata storage-cell layer.
PROMPT - Database-side statistics are generally cumulative.
PROMPT - Physical reads alone do not prove a Flash Cache problem.
PROMPT - CellCLI provides the detailed storage-cell Flash Cache view.
PROMPT - Metric names can vary by Exadata/database release.
PROMPT - Verify V$CELL_METRIC columns on the target platform.
PROMPT
PROMPT ================================================================
PROMPT END OF FLASH CACHE MONITOR
PROMPT ================================================================


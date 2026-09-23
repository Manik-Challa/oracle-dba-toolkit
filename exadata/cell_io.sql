-- ================================================================
-- Oracle DBA Toolkit
-- Script : cell_io.sql
-- Purpose: Monitor Exadata Cell I/O, Throughput and Latency
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
COLUMN file_name FORMAT A70
COLUMN object_name FORMAT A40

PROMPT
PROMPT ================================================================
PROMPT EXADATA CELL I/O MONITOR
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
PROMPT 3. CELL I/O RELATED SYSTEM STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%cell%'
ORDER BY name;

PROMPT
PROMPT 4. CELL PHYSICAL I/O STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    ROUND(value / 1024 / 1024 / 1024, 2) AS value_gb
FROM v$sysstat
WHERE LOWER(name) LIKE '%cell physical%'
ORDER BY name;

PROMPT
PROMPT 5. CELL INTERCONNECT I/O
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    ROUND(value / 1024 / 1024 / 1024, 2) AS value_gb
FROM v$sysstat
WHERE LOWER(name) LIKE '%interconnect%'
   OR LOWER(name) LIKE '%cell physical io%'
ORDER BY name;

PROMPT
PROMPT 6. DATABASE PHYSICAL I/O
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    ROUND(value / 1024 / 1024 / 1024, 2) AS value_gb
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
PROMPT 7. FILE-LEVEL I/O
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        df.file_id,
        df.tablespace_name,
        df.file_name,
        ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS size_gb,
        fs.phyrds AS physical_reads,
        fs.phywrts AS physical_writes,
        fs.readtim AS read_time,
        fs.writetim AS write_time,
        ROUND(
            CASE
                WHEN fs.phyrds > 0
                THEN fs.readtim / fs.phyrds
            END,
            4
        ) AS avg_read_time_cs,
        ROUND(
            CASE
                WHEN fs.phywrts > 0
                THEN fs.writetim / fs.phywrts
            END,
            4
        ) AS avg_write_time_cs
    FROM dba_data_files df
    JOIN v$filestat fs
      ON df.file_id = fs.file#
    ORDER BY fs.phyrds DESC
)
WHERE ROWNUM <= 30;

PROMPT
PROMPT 8. TOP DATAFILES BY PHYSICAL READS
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        df.file_id,
        df.tablespace_name,
        df.file_name,
        fs.phyrds AS physical_reads,
        ROUND(
            fs.phyrds /
            NULLIF((SYSDATE - i.startup_time) * 86400, 0),
            2
        ) AS approx_reads_per_sec,
        ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS size_gb
    FROM dba_data_files df
    JOIN v$filestat fs
      ON df.file_id = fs.file#
    CROSS JOIN v$instance i
    ORDER BY fs.phyrds DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 9. CELL-RELATED WAIT EVENTS
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
WHERE LOWER(event) LIKE '%cell%'
   OR LOWER(event) LIKE '%smart scan%'
   OR LOWER(event) LIKE '%offload%'
ORDER BY time_waited DESC;

PROMPT
PROMPT 10. CELL I/O CURRENT WAITERS
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
       LOWER(event) LIKE '%cell%'
       OR LOWER(event) LIKE '%smart scan%'
       OR LOWER(event) LIKE '%offload%'
      )
ORDER BY seconds_in_wait DESC;

PROMPT
PROMPT 11. CURRENT USER I/O WAITERS
PROMPT ----------------------------------------------------------------

SELECT
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    seconds_in_wait,
    state,
    machine,
    program
FROM v$session
WHERE status = 'ACTIVE'
  AND wait_class = 'User I/O'
ORDER BY seconds_in_wait DESC;

PROMPT
PROMPT 12. TOP SQL BY PHYSICAL READS
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
        ) AS mb_per_exec,
        module
    FROM v$sql
    WHERE executions > 0
      AND physical_read_bytes > 0
    ORDER BY physical_read_bytes DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 13. TOP SQL BY PHYSICAL WRITE BYTES
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        sql_id,
        child_number,
        plan_hash_value,
        parsing_schema_name,
        executions,
        physical_write_bytes,
        ROUND(
            physical_write_bytes / 1024 / 1024 / 1024,
            2
        ) AS physical_write_gb,
        ROUND(
            CASE
                WHEN executions > 0
                THEN physical_write_bytes / executions / 1024 / 1024
            END,
            2
        ) AS mb_written_per_exec,
        module
    FROM v$sql
    WHERE physical_write_bytes > 0
    ORDER BY physical_write_bytes DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 14. TOP SQL BY BUFFER GETS
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        sql_id,
        child_number,
        plan_hash_value,
        parsing_schema_name,
        executions,
        buffer_gets,
        disk_reads,
        ROUND(
            CASE
                WHEN executions > 0
                THEN buffer_gets / executions
            END,
            2
        ) AS buffer_gets_per_exec,
        ROUND(
            CASE
                WHEN executions > 0
                THEN disk_reads / executions
            END,
            2
        ) AS disk_reads_per_exec,
        module
    FROM v$sql
    WHERE executions > 0
    ORDER BY buffer_gets DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 15. CELL METRICS
PROMPT ----------------------------------------------------------------

SELECT
    cell_name,
    metric_name,
    metric_value
FROM v$cell_metric
ORDER BY cell_name, metric_name;

PROMPT
PROMPT 16. CELL I/O RELATED METRICS
PROMPT ----------------------------------------------------------------

SELECT
    cell_name,
    metric_name,
    metric_value
FROM v$cell_metric
WHERE LOWER(metric_name) LIKE '%io%'
   OR LOWER(metric_name) LIKE '%latency%'
   OR LOWER(metric_name) LIKE '%throughput%'
   OR LOWER(metric_name) LIKE '%iops%'
ORDER BY cell_name, metric_name;

PROMPT
PROMPT 17. RAC CELL I/O STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    inst_id,
    name,
    value
FROM gv$sysstat
WHERE LOWER(name) LIKE '%cell%'
ORDER BY inst_id, name;

PROMPT
PROMPT 18. STORAGE I/O SYSTEM EVENTS
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
WHERE wait_class = 'User I/O'
ORDER BY time_waited DESC;

PROMPT
PROMPT 19. RECENT STORAGE / CELL ALERTS
PROMPT ----------------------------------------------------------------

SELECT
    originating_timestamp,
    message_type,
    message_level,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
       LOWER(message_text) LIKE '%cell%'
       OR LOWER(message_text) LIKE '%storage%'
       OR LOWER(message_text) LIKE '%disk%'
       OR LOWER(message_text) LIKE '%i/o%'
       OR LOWER(message_text) LIKE '%io%'
      )
ORDER BY originating_timestamp DESC;

PROMPT
PROMPT 20. QUICK CELL I/O SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE name IN (
    'physical reads',
    'physical writes',
    'cell physical IO interconnect bytes',
    'cell physical IO bytes eligible for predicate offload',
    'cell physical IO interconnect bytes returned by smart scan',
    'cell physical IO bytes saved by storage index',
    'cell physical IO bytes saved by predicate filtering'
)
ORDER BY name;

PROMPT
PROMPT ================================================================
PROMPT EXADATA CELL I/O DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Confirm expected cells are visible through V$CELL.
PROMPT 2. Review cell physical I/O statistics.
PROMPT 3. Review cell interconnect bytes.
PROMPT 4. Check physical reads and physical writes.
PROMPT 5. Identify high-I/O datafiles.
PROMPT 6. Identify SQL generating high physical I/O.
PROMPT 7. Review current cell and User I/O waits.
PROMPT 8. Review cell I/O metrics where supported.
PROMPT 9. Check RAC instances for uneven I/O activity.
PROMPT 10. Review recent storage/cell alerts.
PROMPT 11. Correlate database metrics with CellCLI.
PROMPT
PROMPT IMPORTANT:
PROMPT - Most V$SYSSTAT and V$FILESTAT values are cumulative.
PROMPT - Approximate rates depend on database uptime and counter resets.
PROMPT - High I/O does not automatically indicate a storage problem.
PROMPT - Cell-related waits must be interpreted with workload and SQL plans.
PROMPT - CellCLI provides the detailed storage-cell hardware perspective.
PROMPT - Verify V$CELL_METRIC availability and metric names on the target
PROMPT   Oracle/Exadata release before relying on specific metrics.
PROMPT
PROMPT ================================================================
PROMPT END OF CELL I/O MONITOR
PROMPT ================================================================


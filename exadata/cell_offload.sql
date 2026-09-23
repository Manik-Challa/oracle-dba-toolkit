-- ================================================================
-- Oracle DBA Toolkit
-- Script : cell_offload.sql
-- Purpose: Monitor Exadata Cell Offload / Smart I/O Activity
-- Usage  : Run from an Exadata database instance
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN name FORMAT A65
COLUMN value FORMAT 999,999,999,999,999
COLUMN event FORMAT A55
COLUMN sql_id FORMAT A15
COLUMN parsing_schema_name FORMAT A25
COLUMN module FORMAT A30
COLUMN cell_name FORMAT A35

PROMPT
PROMPT ================================================================
PROMPT EXADATA CELL OFFLOAD MONITOR
PROMPT ================================================================

PROMPT
PROMPT 1. DATABASE / INSTANCE
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
PROMPT 3. CELL OFFLOAD RELATED STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%offload%'
   OR LOWER(name) LIKE '%cell physical io%'
ORDER BY name;

PROMPT
PROMPT 4. OFFLOAD ELIGIBLE BYTES
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    ROUND(value / 1024 / 1024 / 1024, 2) AS value_gb
FROM v$sysstat
WHERE LOWER(name) LIKE '%eligible%'
ORDER BY name;

PROMPT
PROMPT 5. SMART SCAN BYTES RETURNED TO DATABASE
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    ROUND(value / 1024 / 1024 / 1024, 2) AS value_gb
FROM v$sysstat
WHERE LOWER(name) LIKE '%returned by smart scan%'
   OR LOWER(name) LIKE '%interconnect bytes%'
ORDER BY name;

PROMPT
PROMPT 6. PREDICATE FILTERING
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    ROUND(value / 1024 / 1024 / 1024, 2) AS value_gb
FROM v$sysstat
WHERE LOWER(name) LIKE '%predicate%'
ORDER BY name;

PROMPT
PROMPT 7. STORAGE INDEX SAVINGS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    ROUND(value / 1024 / 1024 / 1024, 2) AS value_gb
FROM v$sysstat
WHERE LOWER(name) LIKE '%storage index%'
ORDER BY name;

PROMPT
PROMPT 8. COLUMNAR CACHE SAVINGS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value,
    ROUND(value / 1024 / 1024 / 1024, 2) AS value_gb
FROM v$sysstat
WHERE LOWER(name) LIKE '%columnar cache%'
ORDER BY name;

PROMPT
PROMPT 9. CELL OFFLOAD RATIO
PROMPT ----------------------------------------------------------------

WITH stats AS (
    SELECT
        MAX(
            CASE
                WHEN name =
                    'cell physical IO bytes eligible for predicate offload'
                THEN value
            END
        ) AS eligible_bytes,

        MAX(
            CASE
                WHEN name =
                    'cell physical IO interconnect bytes returned by smart scan'
                THEN value
            END
        ) AS returned_bytes
    FROM v$sysstat
)
SELECT
    eligible_bytes,
    returned_bytes,

    ROUND(
        eligible_bytes / 1024 / 1024 / 1024,
        2
    ) AS eligible_gb,

    ROUND(
        returned_bytes / 1024 / 1024 / 1024,
        2
    ) AS returned_gb,

    ROUND(
        CASE
            WHEN eligible_bytes > 0
            THEN
                (1 - returned_bytes / eligible_bytes) * 100
        END,
        2
    ) AS estimated_bytes_reduction_pct
FROM stats;

PROMPT
PROMPT 10. CELL RELATED SYSTEM WAIT EVENTS
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
WHERE LOWER(event) LIKE '%cell%'
   OR LOWER(event) LIKE '%smart scan%'
   OR LOWER(event) LIKE '%offload%'
ORDER BY time_waited DESC;

PROMPT
PROMPT 11. CURRENT CELL / OFFLOAD WAITERS
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
        ) AS mb_read_per_exec,
        module
    FROM v$sql
    WHERE executions > 0
      AND disk_reads > 0
    ORDER BY physical_read_bytes DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 13. TOP SQL BY PHYSICAL READ BYTES
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        sql_id,
        child_number,
        plan_hash_value,
        parsing_schema_name,
        executions,
        physical_read_bytes,
        ROUND(
            physical_read_bytes / 1024 / 1024 / 1024,
            2
        ) AS physical_read_gb,
        ROUND(
            CASE
                WHEN executions > 0
                THEN physical_read_bytes / executions / 1024 / 1024
            END,
            2
        ) AS mb_per_execution,
        module
    FROM v$sql
    WHERE physical_read_bytes > 0
    ORDER BY physical_read_bytes DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 14. TOP SQL WITH HIGH I/O AND LOW ROW RETURN
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        sql_id,
        child_number,
        plan_hash_value,
        executions,
        disk_reads,
        rows_processed,
        ROUND(
            CASE
                WHEN disk_reads > 0
                THEN rows_processed / disk_reads
            END,
            2
        ) AS rows_per_disk_read,
        parsing_schema_name,
        module
    FROM v$sql
    WHERE disk_reads > 0
      AND executions > 0
    ORDER BY disk_reads DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 15. CELL-RELATED V$SYSSTAT SUMMARY
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%cell%'
ORDER BY name;

PROMPT
PROMPT 16. RAC CELL OFFLOAD STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    inst_id,
    name,
    value
FROM gv$sysstat
WHERE LOWER(name) LIKE '%cell%'
   OR LOWER(name) LIKE '%offload%'
ORDER BY inst_id, name;

PROMPT
PROMPT 17. DATABASE I/O BASELINE
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
    'physical writes direct',
    'consistent gets',
    'db block gets'
)
ORDER BY name;

PROMPT
PROMPT 18. CELL METRICS
PROMPT ----------------------------------------------------------------

SELECT
    cell_name,
    metric_name,
    metric_value
FROM v$cell_metric
ORDER BY cell_name, metric_name;

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
       OR LOWER(message_text) LIKE '%offload%'
       OR LOWER(message_text) LIKE '%storage%'
       OR LOWER(message_text) LIKE '%smart scan%'
      )
ORDER BY originating_timestamp DESC;

PROMPT
PROMPT ================================================================
PROMPT CELL OFFLOAD DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT 1. Confirm expected Exadata cells are visible in V$CELL.
PROMPT 2. Review cell/offload statistics from V$SYSSTAT.
PROMPT 3. Check bytes eligible for predicate offload.
PROMPT 4. Check bytes returned by Smart Scan.
PROMPT 5. Review predicate filtering and storage-index savings.
PROMPT 6. Review columnar-cache statistics where applicable.
PROMPT 7. Identify SQL generating high physical I/O.
PROMPT 8. Check active sessions waiting on cell-related events.
PROMPT 9. Review recent storage/cell messages in the alert log.
PROMPT 10. Correlate database statistics with CellCLI metrics.
PROMPT
PROMPT IMPORTANT:
PROMPT - V$SYSSTAT values are generally cumulative counters.
PROMPT - High physical reads do not automatically mean offload failure.
PROMPT - Smart Scan eligibility depends on SQL and execution plan.
PROMPT - CellCLI is required for detailed storage-cell hardware health.
PROMPT - Verify V$CELL_METRIC columns against the target Exadata release.
PROMPT
PROMPT ================================================================
PROMPT END OF CELL OFFLOAD MONITOR
PROMPT ================================================================


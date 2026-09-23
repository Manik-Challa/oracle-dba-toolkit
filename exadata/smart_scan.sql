-- ================================================================
-- Oracle DBA Toolkit
-- Script : smart_scan.sql
-- Purpose: Monitor Exadata Smart Scan / Offload Activity
-- Usage  : Run as SYS or a user with access to required V$ views
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN name FORMAT A55
COLUMN value FORMAT 999,999,999,999,999
COLUMN sql_id FORMAT A15
COLUMN child_number FORMAT 99999
COLUMN parsing_schema_name FORMAT A25
COLUMN module FORMAT A30
COLUMN plan_hash_value FORMAT 9999999999
COLUMN executions FORMAT 999,999,999
COLUMN disk_reads FORMAT 999,999,999,999
COLUMN io_saved FORMAT 999,999,999,999
COLUMN offload_eligible FORMAT 999,999,999,999
COLUMN offload_returned FORMAT 999,999,999,999

PROMPT
PROMPT ================================================================
PROMPT EXADATA SMART SCAN / OFFLOAD MONITOR
PROMPT ================================================================

PROMPT
PROMPT 1. DATABASE / EXADATA ENVIRONMENT
PROMPT ----------------------------------------------------------------

SELECT
    d.name AS database_name,
    i.instance_name,
    i.host_name,
    d.platform_name,
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
PROMPT 3. SMART SCAN / OFFLOAD SYSTEM STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%cell%'
   OR LOWER(name) LIKE '%offload%'
   OR LOWER(name) LIKE '%smart scan%'
ORDER BY name;

PROMPT
PROMPT 4. KEY SMART SCAN STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE name IN (
    'cell physical IO interconnect bytes',
    'cell physical IO bytes eligible for predicate offload',
    'cell physical IO bytes saved by storage index',
    'cell physical IO interconnect bytes returned by smart scan',
    'cell physical IO bytes saved by columnar cache',
    'cell physical IO bytes saved by predicate filtering',
    'cell physical IO bytes eligible for smart IO'
)
ORDER BY name;

PROMPT
PROMPT 5. SMART SCAN RELATED SYSTEM EVENTS
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
PROMPT 6. CURRENT SMART SCAN / CELL WAITS
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
PROMPT 7. TOP SQL BY PHYSICAL READS
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
        buffer_gets,
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
                THEN cpu_time / executions / 1000
            END,
            2
        ) AS cpu_ms_per_exec,
        module
    FROM v$sql
    WHERE executions > 0
      AND disk_reads > 0
    ORDER BY disk_reads DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 8. SQL WITH HIGH PHYSICAL I/O
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
        rows_processed,
        ROUND(
            CASE
                WHEN executions > 0
                THEN disk_reads / executions
            END,
            2
        ) AS disk_reads_per_exec,
        ROUND(
            CASE
                WHEN disk_reads > 0
                THEN rows_processed / disk_reads
            END,
            2
        ) AS rows_per_disk_read,
        module
    FROM v$sql
    WHERE disk_reads > 0
    ORDER BY disk_reads DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 9. SQL WITH HIGH BUFFER GETS VS PHYSICAL READS
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        sql_id,
        child_number,
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
        parsing_schema_name,
        module
    FROM v$sql
    WHERE executions > 0
    ORDER BY disk_reads DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 10. SQL PLAN / EXECUTION INFORMATION
PROMPT ----------------------------------------------------------------

SELECT *
FROM (
    SELECT
        sql_id,
        child_number,
        plan_hash_value,
        executions,
        disk_reads,
        physical_read_bytes,
        rows_processed,
        ROUND(
            CASE
                WHEN executions > 0
                THEN physical_read_bytes / executions / 1024 / 1024
            END,
            2
        ) AS mb_read_per_exec,
        parsing_schema_name,
        module
    FROM v$sql
    WHERE executions > 0
      AND physical_read_bytes > 0
    ORDER BY physical_read_bytes DESC
)
WHERE ROWNUM <= 20;

PROMPT
PROMPT 11. DATABASE I/O STATISTICS
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
PROMPT 12. SMART SCAN / OFFLOAD RATIO
PROMPT ----------------------------------------------------------------

SELECT
    eligible,
    returned,
    ROUND(
        CASE
            WHEN eligible > 0
            THEN (1 - (returned / eligible)) * 100
        END,
        2
    ) AS estimated_offload_reduction_pct
FROM (
    SELECT
        MAX(
            CASE
                WHEN name =
                    'cell physical IO bytes eligible for predicate offload'
                THEN value
            END
        ) AS eligible,
        MAX(
            CASE
                WHEN name =
                    'cell physical IO interconnect bytes returned by smart scan'
                THEN value
            END
        ) AS returned
    FROM v$sysstat
);

PROMPT
PROMPT 13. EXADATA STORAGE INDEX STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%storage index%'
ORDER BY name;

PROMPT
PROMPT 14. COLUMNAR CACHE STATISTICS
PROMPT ----------------------------------------------------------------

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%columnar cache%'
ORDER BY name;

PROMPT
PROMPT 15. CELL OFFLOAD STATISTICS BY INSTANCE
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
PROMPT 16. ACTIVE SQL CURRENTLY DOING PHYSICAL I/O
PROMPT ----------------------------------------------------------------

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.machine,
    s.program
FROM v$session s
JOIN v$sql q
  ON s.sql_id = q.sql_id
 AND s.sql_child_number = q.child_number
WHERE s.status = 'ACTIVE'
  AND q.disk_reads > 0
ORDER BY q.disk_reads DESC;

PROMPT
PROMPT ================================================================
PROMPT SMART SCAN DBA CHECKLIST
PROMPT ================================================================

PROMPT
PROMPT Check the following when Smart Scan performance is poor:
PROMPT
PROMPT 1. Confirm the database is running on Exadata.
PROMPT 2. Confirm V$CELL shows the expected storage cells.
PROMPT 3. Review cell physical IO / offload statistics.
PROMPT 4. Check SQL physical reads and physical_read_bytes.
PROMPT 5. Review current cell-related wait events.
PROMPT 6. Check whether SQL is eligible for storage offload.
PROMPT 7. Review execution plans for full table scans.
PROMPT 8. Check storage index / columnar cache statistics.
PROMPT 9. Correlate DB-side statistics with CellCLI metrics.
PROMPT 10. Investigate storage cells, disks and network if needed.

PROMPT
PROMPT IMPORTANT:
PROMPT Smart Scan eligibility depends on SQL, access path, data type,
PROMPT storage features, predicates, and execution environment.
PROMPT High physical reads alone do not prove Smart Scan failure.
PROMPT V$ statistics are generally cumulative since startup/reset.
PROMPT CellCLI provides the authoritative storage-cell hardware view.
PROMPT
PROMPT ================================================================
PROMPT END OF SMART SCAN MONITOR
PROMPT ================================================================


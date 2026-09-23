-- ============================================================
-- Exadata Cell Health - Database Side Monitoring
-- File   : cell_health.sql
-- Purpose: Monitor Exadata cell/storage health from the DB
-- Author : Manik Challa
--
-- Note:
--   This script uses database-side views and statistics.
--   Detailed physical disk/cell hardware status should be
--   verified with CellCLI on the storage server.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN cell_name          FORMAT A40
COLUMN cell_hash           FORMAT 999999999999
COLUMN status              FORMAT A15
COLUMN name                FORMAT A35
COLUMN path                FORMAT A70
COLUMN diskgroup           FORMAT A30
COLUMN disk_state          FORMAT A15
COLUMN mode_status         FORMAT A15
COLUMN header_status       FORMAT A18
COLUMN metric_name         FORMAT A45
COLUMN value               FORMAT 999,999,999,999.99
COLUMN wait_class          FORMAT A20
COLUMN event               FORMAT A55 WORD_WRAP
COLUMN sql_id              FORMAT A15
COLUMN host_name           FORMAT A45
COLUMN instance_name       FORMAT A20

PROMPT
PROMPT ============================================================
PROMPT EXADATA CELL HEALTH - DATABASE SIDE
PROMPT ============================================================
PROMPT

-- ============================================================
-- 1. DATABASE / INSTANCE INFORMATION
-- ============================================================

PROMPT ============================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    name,
    db_unique_name,
    open_mode,
    database_role,
    log_mode
FROM v$database;

SELECT
    instance_name,
    host_name,
    version,
    status,
    startup_time
FROM v$instance;

-- ============================================================
-- 2. ASM DISKGROUP HEALTH
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. ASM DISKGROUP HEALTH
PROMPT ============================================================

SELECT
    name,
    state,
    type,
    total_mb,
    free_mb,
    usable_file_mb,
    offline_disks,
    required_mirror_free_mb
FROM v$asm_diskgroup
ORDER BY name;

-- ============================================================
-- 3. ASM DISK STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. ASM DISK STATUS
PROMPT ============================================================

SELECT
    group_number,
    disk_number,
    name,
    path,
    header_status,
    mode_status,
    state,
    total_mb,
    free_mb
FROM v$asm_disk
ORDER BY group_number, disk_number;

-- ============================================================
-- 4. ASM DISKS NOT ONLINE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. ASM DISKS REQUIRING ATTENTION
PROMPT ============================================================

SELECT
    group_number,
    disk_number,
    name,
    path,
    header_status,
    mode_status,
    state,
    total_mb,
    free_mb
FROM v$asm_disk
WHERE state <> 'NORMAL'
   OR mode_status <> 'ONLINE'
ORDER BY group_number, disk_number;

-- ============================================================
-- 5. ASM DISK HEADER STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. ASM DISK HEADER STATUS
PROMPT ============================================================

SELECT
    header_status,
    COUNT(*) AS disk_count
FROM v$asm_disk
GROUP BY header_status
ORDER BY disk_count DESC;

-- ============================================================
-- 6. ASM DISK STATE SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. ASM DISK STATE SUMMARY
PROMPT ============================================================

SELECT
    state,
    mode_status,
    COUNT(*) AS disk_count
FROM v$asm_disk
GROUP BY
    state,
    mode_status
ORDER BY
    state,
    mode_status;

-- ============================================================
-- 7. ASM REBALANCE OPERATIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. ASM REBALANCE OPERATIONS
PROMPT ============================================================

SELECT
    group_number,
    operation,
    state,
    power,
    actual,
    sofar,
    est_work,
    est_rate,
    est_minutes
FROM v$asm_operation
ORDER BY group_number;

-- ============================================================
-- 8. ASM CLIENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. ASM CLIENTS
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    db_name,
    status,
    software_version
FROM gv$asm_client
ORDER BY inst_id, db_name;

-- ============================================================
-- 9. EXADATA CELL INFORMATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. EXADATA CELL INFORMATION
PROMPT ============================================================

SELECT
    cell_name,
    cell_hash,
    status
FROM v$cell
ORDER BY cell_name;

-- ============================================================
-- 10. EXADATA CELLS BY INSTANCE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. EXADATA CELL VISIBILITY
PROMPT ============================================================

SELECT
    inst_id,
    cell_name,
    cell_hash,
    status
FROM gv$cell
ORDER BY inst_id, cell_name;

-- ============================================================
-- 11. CELL STATUS SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. CELL STATUS SUMMARY
PROMPT ============================================================

SELECT
    status,
    COUNT(*) AS cell_count
FROM v$cell
GROUP BY status
ORDER BY status;

-- ============================================================
-- 12. CELL STORAGE I/O STATISTICS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. CELL STORAGE I/O STATISTICS
PROMPT ============================================================

SELECT
    cell_name,
    metric_name,
    metric_value
FROM v$cell_metric
ORDER BY cell_name, metric_name;

-- ============================================================
-- 13. CELL METRICS - LAST MEASUREMENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. CELL METRIC SUMMARY
PROMPT ============================================================

SELECT
    cell_name,
    metric_name,
    metric_value
FROM v$cell_metric
WHERE UPPER(metric_name) LIKE '%IO%'
   OR UPPER(metric_name) LIKE '%DISK%'
   OR UPPER(metric_name) LIKE '%FLASH%'
   OR UPPER(metric_name) LIKE '%CPU%'
ORDER BY
    cell_name,
    metric_name;

-- ============================================================
-- 14. CELL I/O RELATED WAIT EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. CELL / STORAGE I/O WAIT EVENTS
PROMPT ============================================================

SELECT
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN time_waited / total_waits / 100
            ELSE 0
        END,
        4
    ) AS avg_wait_sec
FROM v$system_event
WHERE wait_class <> 'Idle'
  AND (
       LOWER(event) LIKE '%cell%'
    OR LOWER(event) LIKE '%storage%'
    OR LOWER(event) LIKE '%disk%'
    OR LOWER(event) LIKE '%db file%'
    OR LOWER(event) LIKE '%direct path%'
  )
ORDER BY time_waited DESC;

-- ============================================================
-- 15. CURRENT STORAGE WAITERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. CURRENT STORAGE WAITERS
PROMPT ============================================================

SELECT
    sid,
    serial# AS serial,
    username,
    status,
    sql_id,
    event,
    wait_class,
    seconds_in_wait,
    machine,
    program
FROM v$session
WHERE status = 'ACTIVE'
  AND wait_class <> 'Idle'
  AND (
       LOWER(event) LIKE '%cell%'
    OR LOWER(event) LIKE '%db file%'
    OR LOWER(event) LIKE '%direct path%'
    OR LOWER(event) LIKE '%disk%'
  )
ORDER BY seconds_in_wait DESC;

-- ============================================================
-- 16. TOP SQL BY PHYSICAL READS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. TOP SQL BY PHYSICAL READS
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name,
    executions,
    disk_reads,
    buffer_gets,
    ROUND(
        CASE
            WHEN executions > 0
            THEN disk_reads / executions
            ELSE 0
        END,
        2
    ) AS disk_reads_per_exec,
    ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
    ROUND(cpu_time / 1000000, 2) AS cpu_sec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
ORDER BY disk_reads DESC
FETCH FIRST 30 ROWS ONLY;

-- ============================================================
-- 17. TOP SQL BY PHYSICAL READS PER EXECUTION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. TOP SQL BY PHYSICAL READS / EXECUTION
PROMPT ============================================================

SELECT
    sql_id,
    parsing_schema_name,
    executions,
    disk_reads,
    ROUND(disk_reads / executions, 2) AS disk_reads_per_exec,
    ROUND(buffer_gets / executions, 2) AS buffer_gets_per_exec,
    SUBSTR(sql_text, 1, 100) AS sql_text
FROM v$sql
WHERE executions > 0
  AND disk_reads > 0
ORDER BY disk_reads_per_exec DESC
FETCH FIRST 30 ROWS ONLY;

-- ============================================================
-- 18. DATABASE I/O STATISTICS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. DATABASE I/O STATISTICS
PROMPT ============================================================

SELECT
    name,
    value
FROM v$sysstat
WHERE name IN
(
    'physical reads',
    'physical writes',
    'physical reads direct',
    'physical writes direct',
    'cell physical IO interconnect bytes',
    'cell physical IO bytes saved by storage index',
    'cell physical IO bytes saved by smart scan',
    'cell physical IO interconnect bytes returned by smart scan'
)
ORDER BY name;

-- ============================================================
-- 19. EXADATA SMART SCAN / OFFLOAD STATISTICS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 19. EXADATA SMART SCAN / OFFLOAD STATISTICS
PROMPT ============================================================

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%cell physical%'
ORDER BY name;

-- ============================================================
-- 20. CELL SMART SCAN WAIT EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 20. SMART SCAN / CELL WAIT EVENTS
PROMPT ============================================================

SELECT
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN time_waited / total_waits / 100
            ELSE 0
        END,
        4
    ) AS avg_wait_sec
FROM v$system_event
WHERE wait_class <> 'Idle'
  AND (
       LOWER(event) LIKE '%cell%'
    OR LOWER(event) LIKE '%smart scan%'
  )
ORDER BY time_waited DESC;

-- ============================================================
-- 21. RECENT ASM / STORAGE ALERTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 21. RECENT ASM / STORAGE ALERTS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND (
       UPPER(message_text) LIKE '%ASM%'
    OR UPPER(message_text) LIKE '%CELL%'
    OR UPPER(message_text) LIKE '%DISK%'
    OR UPPER(message_text) LIKE '%I/O%'
    OR UPPER(message_text) LIKE '%STORAGE%'
  )
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 22. CRITICAL STORAGE ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 22. CRITICAL STORAGE ERRORS
PROMPT ============================================================

SELECT
    originating_timestamp,
    message_id,
    problem_key,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND (
       message_text LIKE '%ORA-150%'
    OR message_text LIKE '%ORA-175%'
    OR message_text LIKE '%ORA-270%'
    OR message_text LIKE '%ORA-195%'
    OR message_text LIKE '%ORA-011%'
  )
ORDER BY originating_timestamp DESC;

-- ============================================================
-- 23. CELL HEALTH SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 23. CELL HEALTH SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS total_cells,
    SUM(
        CASE
            WHEN UPPER(status) = 'ONLINE'
            THEN 1
            ELSE 0
        END
    ) AS online_cells
FROM v$cell;

-- ============================================================
-- 24. ASM HEALTH SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 24. ASM HEALTH SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS total_asm_disks,
    SUM(
        CASE
            WHEN state = 'NORMAL'
             AND mode_status = 'ONLINE'
            THEN 1
            ELSE 0
        END
    ) AS healthy_asm_disks,
    SUM(
        CASE
            WHEN state <> 'NORMAL'
              OR mode_status <> 'ONLINE'
            THEN 1
            ELSE 0
        END
    ) AS disks_requiring_attention
FROM v$asm_disk;

-- ============================================================
-- 25. QUICK EXADATA HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 25. QUICK EXADATA HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN EXISTS
             (
                 SELECT 1
                 FROM v$asm_disk
                 WHERE state <> 'NORMAL'
                    OR mode_status <> 'ONLINE'
             )
        THEN 'ATTENTION - ASM disks require investigation'

        WHEN EXISTS
             (
                 SELECT 1
                 FROM v$asm_diskgroup
                 WHERE state <> 'MOUNTED'
                    OR offline_disks > 0
             )
        THEN 'ATTENTION - ASM diskgroup requires investigation'

        WHEN EXISTS
             (
                 SELECT 1
                 FROM v$cell
                 WHERE UPPER(status) NOT IN ('ONLINE', 'NORMAL')
             )
        THEN 'ATTENTION - Exadata cell status requires investigation'

        ELSE 'HEALTHY - Database-side Exadata checks look normal'
    END AS exadata_health_status
FROM dual;

PROMPT
PROMPT ============================================================
PROMPT INVESTIGATION NOTES
PROMPT ============================================================
PROMPT
PROMPT 1. This script provides database-side Exadata visibility.
PROMPT 2. Use CellCLI for authoritative physical disk/cell hardware status.
PROMPT 3. Correlate ASM disk status with Grid Disk, Cell Disk and Physical Disk.
PROMPT 4. Check iSCSI and multipath from the database/compute OS where applicable.
PROMPT 5. Cumulative V$SYSSTAT and V$SQL values are not instantaneous rates.
PROMPT 6. Use before/after snapshots when calculating I/O rates.
PROMPT 7. Storage wait events should be correlated with workload and SQL activity.
PROMPT 8. Do not perform disk replacement or CellCLI changes from this script.
PROMPT
PROMPT ============================================================
PROMPT END OF EXADATA CELL HEALTH MONITORING
PROMPT ============================================================


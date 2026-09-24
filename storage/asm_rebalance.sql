-- ============================================================
-- Oracle DBA Toolkit
-- File   : asm_rebalance.sql
-- Purpose: Monitor ASM rebalance operations
-- Scope  : Active rebalance, progress, power, estimated time,
--          diskgroup state and rebalance-related waits
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

-- ============================================================
-- COLUMN FORMATS
-- ============================================================

-- Database / Instance
COLUMN INSTANCE_NAME          FORMAT A20
COLUMN HOST_NAME              FORMAT A40
COLUMN STATUS                 FORMAT A15
COLUMN VERSION                FORMAT A20
COLUMN STARTUP_TIME           FORMAT A20
COLUMN DB_UNIQUE_NAME         FORMAT A20
COLUMN OPEN_MODE              FORMAT A20
COLUMN DATABASE_ROLE          FORMAT A20

-- ASM Diskgroup
COLUMN DISKGROUP_NAME         FORMAT A20
COLUMN NAME                   FORMAT A20
COLUMN TYPE                   FORMAT A12
COLUMN STATE                  FORMAT A15
COLUMN TOTAL_GB               FORMAT 999,999,999.99
COLUMN FREE_GB                FORMAT 999,999,999.99
COLUMN USABLE_GB              FORMAT 999,999,999.99
COLUMN REQUIRED_MIRROR_GB     FORMAT 999,999,999.99
COLUMN USED_PCT               FORMAT 990.99
COLUMN OFFLINE_DISKS          FORMAT 9999

-- ASM Rebalance
COLUMN GROUP_NUMBER           FORMAT 9999
COLUMN OPERATION              FORMAT A15
COLUMN POWER                  FORMAT 9999
COLUMN ACTUAL                 FORMAT 9999
COLUMN SOFAR                  FORMAT 999,999,999
COLUMN EST_WORK               FORMAT 999,999,999
COLUMN EST_RATE               FORMAT 999,999,999
COLUMN EST_MINUTES            FORMAT 999,999.99
COLUMN EST_HOURS              FORMAT 999,999.99
COLUMN WORK_REMAINING         FORMAT 999,999,999
COLUMN PROGRESS_PCT           FORMAT 990.99
COLUMN REBALANCE_STATUS       FORMAT A25

-- Waits
COLUMN EVENT                  FORMAT A50
COLUMN WAIT_CLASS             FORMAT A20
COLUMN TOTAL_WAITS            FORMAT 999,999,999
COLUMN TIME_WAITED_SEC        FORMAT 999,999,999.99
COLUMN SID                    FORMAT 999999
COLUMN SERIAL                 FORMAT 999999
COLUMN USERNAME               FORMAT A25
COLUMN SQL_ID                 FORMAT A15

PROMPT
PROMPT ============================================================
PROMPT ASM REBALANCE MONITORING
PROMPT ============================================================

-- ============================================================
-- 1. DATABASE / INSTANCE INFORMATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    i.instance_name,
    i.host_name,
    i.status,
    i.version,
    TO_CHAR(i.startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time,
    d.db_unique_name,
    d.open_mode,
    d.database_role
FROM v$instance i
CROSS JOIN v$database d;

-- ============================================================
-- 2. CURRENT ASM DISKGROUP STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. CURRENT ASM DISKGROUP STATUS
PROMPT ============================================================

SELECT
    name,
    type,
    state,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(usable_file_mb / 1024, 2) AS usable_gb,
    ROUND(required_mirror_free_mb / 1024, 2)
        AS required_mirror_gb,
    CASE
        WHEN total_mb > 0
        THEN ROUND(
                 100 * (1 - free_mb / total_mb),
                 2
             )
    END AS used_pct,
    offline_disks
FROM v$asm_diskgroup
ORDER BY name;

-- ============================================================
-- 3. ACTIVE ASM REBALANCE OPERATIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. ACTIVE ASM REBALANCE OPERATIONS
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
    CASE
        WHEN est_work > 0
        THEN ROUND(
                 100 * sofar / est_work,
                 2
             )
    END AS progress_pct,
    CASE
        WHEN est_rate > 0
        THEN ROUND(
                 (est_work - sofar) / est_rate,
                 2
             )
    END AS est_minutes,
    CASE
        WHEN est_rate > 0
        THEN ROUND(
                 (est_work - sofar) / est_rate / 60,
                 2
             )
    END AS est_hours
FROM v$asm_operation
ORDER BY group_number, operation;

-- ============================================================
-- 4. REBALANCE OPERATIONS WITH DISKGROUP NAME
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. REBALANCE BY DISKGROUP
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    o.operation,
    o.state,
    o.power,
    o.actual,
    o.sofar,
    o.est_work,
    o.est_rate,
    CASE
        WHEN o.est_work > 0
        THEN ROUND(
                 100 * o.sofar / o.est_work,
                 2
             )
    END AS progress_pct,
    CASE
        WHEN o.est_rate > 0
        THEN ROUND(
                 (o.est_work - o.sofar) / o.est_rate,
                 2
             )
    END AS est_minutes
FROM v$asm_operation o
JOIN v$asm_diskgroup dg
    ON dg.group_number = o.group_number
ORDER BY
    dg.name,
    o.operation;

-- ============================================================
-- 5. REBALANCE PROGRESS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. REBALANCE PROGRESS
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    o.operation,
    o.state,
    o.sofar AS work_completed,
    o.est_work AS total_work,
    o.est_work - o.sofar AS work_remaining,
    CASE
        WHEN o.est_work > 0
        THEN ROUND(
                 100 * o.sofar / o.est_work,
                 2
             )
    END AS progress_pct
FROM v$asm_operation o
JOIN v$asm_diskgroup dg
    ON dg.group_number = o.group_number
ORDER BY
    progress_pct DESC NULLS LAST;

-- ============================================================
-- 6. REBALANCE POWER
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. REBALANCE POWER
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    o.operation,
    o.state,
    o.power,
    o.actual,
    o.sofar,
    o.est_work
FROM v$asm_operation o
JOIN v$asm_diskgroup dg
    ON dg.group_number = o.group_number
ORDER BY
    o.power DESC,
    dg.name;

-- ============================================================
-- 7. REBALANCE OPERATIONS WAITING
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. ASM OPERATIONS WAITING
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    o.operation,
    o.state,
    o.power,
    o.actual,
    o.sofar,
    o.est_work,
    o.est_rate
FROM v$asm_operation o
JOIN v$asm_diskgroup dg
    ON dg.group_number = o.group_number
WHERE o.state = 'WAIT'
ORDER BY
    dg.name,
    o.operation;

-- ============================================================
-- 8. ASM REBALANCE-RELATED WAIT EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. ASM REBALANCE-RELATED WAIT EVENTS
PROMPT ============================================================

SELECT
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec
FROM v$system_event
WHERE LOWER(event) LIKE '%rebalance%'
   OR LOWER(event) LIKE '%asm%'
ORDER BY
    time_waited DESC;

-- ============================================================
-- 9. CURRENT ASM / REBALANCE WAITERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. CURRENT ASM / REBALANCE WAITERS
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait
FROM v$session s
WHERE s.state = 'WAITING'
  AND (
        LOWER(s.event) LIKE '%rebalance%'
        OR LOWER(s.event) LIKE '%asm%'
        OR LOWER(s.event) LIKE '%disk%'
      )
ORDER BY
    s.seconds_in_wait DESC;

-- ============================================================
-- 10. ASM DISKS CURRENTLY NOT NORMAL
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. ASM DISKS NOT IN NORMAL STATE
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.disk_number,
    d.name AS disk_name,
    d.path,
    d.failgroup,
    d.mount_status,
    d.mode_status,
    d.state,
    d.header_status
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
WHERE d.state <> 'NORMAL'
   OR d.mode_status <> 'ONLINE'
ORDER BY
    dg.name,
    d.disk_number;

-- ============================================================
-- 11. DISKS WITH REPAIR TIMER
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. ASM DISKS WITH REPAIR TIMER
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.disk_number,
    d.name AS disk_name,
    d.path,
    d.failgroup,
    d.state,
    d.mode_status,
    d.repair_timer
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
WHERE NVL(d.repair_timer, 0) > 0
ORDER BY
    d.repair_timer DESC;

-- ============================================================
-- 12. DISK I/O ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. ASM DISK I/O ERRORS
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.disk_number,
    d.name AS disk_name,
    d.path,
    d.failgroup,
    d.read_errs AS read_errors,
    d.write_errs AS write_errors,
    d.state,
    d.mode_status
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
WHERE NVL(d.read_errs, 0) > 0
   OR NVL(d.write_errs, 0) > 0
ORDER BY
    NVL(d.read_errs, 0) + NVL(d.write_errs, 0) DESC;

-- ============================================================
-- 13. ASM DISK COUNT BY DISKGROUP
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. ASM DISK COUNT BY DISKGROUP
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    COUNT(d.disk_number) AS disk_count,
    SUM(
        CASE
            WHEN d.state = 'NORMAL' THEN 1
            ELSE 0
        END
    ) AS normal_disks,
    SUM(
        CASE
            WHEN d.state <> 'NORMAL' THEN 1
            ELSE 0
        END
    ) AS abnormal_disks
FROM v$asm_disk d
JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
GROUP BY dg.name
ORDER BY dg.name;

-- ============================================================
-- 14. ASM OPERATION SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. ASM OPERATION SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS active_operations,
    SUM(
        CASE
            WHEN state = 'WAIT' THEN 1
            ELSE 0
        END
    ) AS waiting_operations,
    SUM(
        CASE
            WHEN state <> 'WAIT' THEN 1
            ELSE 0
        END
    ) AS running_operations
FROM v$asm_operation;

-- ============================================================
-- 15. REBALANCE HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. REBALANCE HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM v$asm_disk
            WHERE NVL(read_errs, 0) > 0
               OR NVL(write_errs, 0) > 0
        )
        THEN 'WARNING - ASM DISK I/O ERRORS DETECTED'

        WHEN EXISTS (
            SELECT 1
            FROM v$asm_disk
            WHERE state <> 'NORMAL'
               OR mode_status <> 'ONLINE'
        )
        THEN 'WARNING - ASM DISK STATE REQUIRES REVIEW'

        WHEN EXISTS (
            SELECT 1
            FROM v$asm_operation
            WHERE state = 'WAIT'
        )
        THEN 'INFO - ASM REBALANCE OPERATION WAITING'

        WHEN EXISTS (
            SELECT 1
            FROM v$asm_operation
        )
        THEN 'INFO - ASM REBALANCE IN PROGRESS'

        ELSE 'HEALTHY - NO ACTIVE ASM REBALANCE'
    END AS rebalance_status
FROM dual;

-- ============================================================
-- 16. QUICK ASM REBALANCE CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. QUICK ASM REBALANCE CHECK
PROMPT ============================================================

SELECT
    (SELECT COUNT(*)
       FROM v$asm_operation) AS active_operations,

    (SELECT COUNT(*)
       FROM v$asm_operation
      WHERE state = 'WAIT') AS waiting_operations,

    (SELECT COUNT(*)
       FROM v$asm_disk
      WHERE state <> 'NORMAL') AS abnormal_disks,

    (SELECT COUNT(*)
       FROM v$asm_disk
      WHERE NVL(read_errs, 0) > 0
         OR NVL(write_errs, 0) > 0) AS disks_with_io_errors
FROM dual;

-- ============================================================
-- 17. DBA QUICK CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. DBA QUICK CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT [ ] Check V$ASM_OPERATION for active operations
PROMPT [ ] Review SOFAR versus EST_WORK
PROMPT [ ] Check estimated completion time
PROMPT [ ] Review rebalance POWER
PROMPT [ ] Check operations in WAIT state
PROMPT [ ] Check diskgroup usable_file_mb
PROMPT [ ] Check OFFLINE_DISKS
PROMPT [ ] Review ASM disks not in NORMAL state
PROMPT [ ] Check ASM disk read/write errors
PROMPT [ ] Check disks with REPAIR_TIMER
PROMPT [ ] Correlate with ASM alert.log
PROMPT [ ] For Exadata, correlate with CellCLI and storage alerts
PROMPT [ ] Check OS multipath/iSCSI when disks are abnormal
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT NOTES
PROMPT ============================================================
PROMPT
PROMPT This script is READ-ONLY.
PROMPT
PROMPT V$ASM_OPERATION shows the current ASM operations. It does
PROMPT not provide a persistent historical rebalance timeline.
PROMPT
PROMPT SOFAR / EST_WORK progress is an estimate and can change
PROMPT as the rebalance progresses.
PROMPT
PROMPT Higher ASM rebalance POWER can increase resource usage.
PROMPT Do not change ASM rebalance power blindly in production.
PROMPT
PROMPT A rebalance may be expected after disk add/drop, disk
PROMPT failure/replacement, diskgroup resize or other ASM changes.
PROMPT
PROMPT A waiting operation does not automatically indicate failure.
PROMPT Investigate the diskgroup, disks, ASM alerts and workload.
PROMPT
PROMPT For Exadata, correlate ASM information with CellCLI,
PROMPT storage-cell alerts, OS multipath/iSCSI and database waits.
PROMPT
PROMPT ============================================================
PROMPT END OF ASM REBALANCE MONITORING
PROMPT ============================================================


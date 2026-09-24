-- ============================================================
-- Oracle DBA Toolkit
-- File   : asm_operation.sql
-- Purpose: Monitor current ASM operations
-- Scope  : ASM operations, progress, power, estimated time,
--          waiting operations, diskgroup and disk health
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

-- ASM Operations
COLUMN GROUP_NUMBER           FORMAT 9999
COLUMN DISKGROUP_NAME         FORMAT A20
COLUMN OPERATION              FORMAT A20
COLUMN STATE                  FORMAT A15
COLUMN POWER                  FORMAT 9999
COLUMN ACTUAL                 FORMAT 9999
COLUMN SOFAR                  FORMAT 999,999,999
COLUMN EST_WORK               FORMAT 999,999,999
COLUMN EST_RATE               FORMAT 999,999,999
COLUMN WORK_REMAINING         FORMAT 999,999,999
COLUMN PROGRESS_PCT           FORMAT 990.99
COLUMN EST_MINUTES            FORMAT 999,999.99
COLUMN EST_HOURS              FORMAT 999,999.99

-- Diskgroup
COLUMN TYPE                   FORMAT A12
COLUMN TOTAL_GB               FORMAT 999,999,999.99
COLUMN FREE_GB                FORMAT 999,999,999.99
COLUMN USABLE_GB              FORMAT 999,999,999.99
COLUMN REQUIRED_MIRROR_GB     FORMAT 999,999,999.99
COLUMN USED_PCT               FORMAT 990.99
COLUMN OFFLINE_DISKS          FORMAT 9999

-- ASM Disk
COLUMN DISK_NUMBER            FORMAT 99999
COLUMN DISK_NAME              FORMAT A30
COLUMN PATH                   FORMAT A70
COLUMN FAILGROUP              FORMAT A25
COLUMN MOUNT_STATUS           FORMAT A15
COLUMN MODE_STATUS            FORMAT A15
COLUMN HEADER_STATUS          FORMAT A20
COLUMN DISK_STATE             FORMAT A15
COLUMN READ_ERRORS            FORMAT 999,999,999
COLUMN WRITE_ERRORS           FORMAT 999,999,999
COLUMN REPAIR_TIMER           FORMAT 999999999

-- Waits
COLUMN EVENT                  FORMAT A50
COLUMN WAIT_CLASS             FORMAT A20
COLUMN TOTAL_WAITS            FORMAT 999,999,999
COLUMN TIME_WAITED_SEC        FORMAT 999,999,999.99
COLUMN SID                    FORMAT 999999
COLUMN SERIAL                 FORMAT 999999
COLUMN USERNAME               FORMAT A25
COLUMN SQL_ID                 FORMAT A15
COLUMN SECONDS_IN_WAIT        FORMAT 999999

-- Health
COLUMN HEALTH_STATUS          FORMAT A50

PROMPT
PROMPT ============================================================
PROMPT ASM OPERATION MONITORING
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
-- 2. CURRENT ASM OPERATIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. CURRENT ASM OPERATIONS
PROMPT ============================================================

SELECT
    o.group_number,
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
    END AS est_minutes,
    CASE
        WHEN o.est_rate > 0
        THEN ROUND(
                 (o.est_work - o.sofar) / o.est_rate / 60,
                 2
             )
    END AS est_hours
FROM v$asm_operation o
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = o.group_number
ORDER BY
    o.group_number,
    o.operation;

-- ============================================================
-- 3. OPERATION PROGRESS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. ASM OPERATION PROGRESS
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    o.operation,
    o.state,
    o.sofar,
    o.est_work,
    o.est_work - o.sofar AS work_remaining,
    CASE
        WHEN o.est_work > 0
        THEN ROUND(
                 100 * o.sofar / o.est_work,
                 2
             )
    END AS progress_pct,
    o.est_rate
FROM v$asm_operation o
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = o.group_number
ORDER BY
    progress_pct DESC NULLS LAST;

-- ============================================================
-- 4. OPERATIONS BY STATE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. ASM OPERATIONS BY STATE
PROMPT ============================================================

SELECT
    state,
    COUNT(*) AS operation_count
FROM v$asm_operation
GROUP BY state
ORDER BY operation_count DESC;

-- ============================================================
-- 5. OPERATIONS BY TYPE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. ASM OPERATIONS BY TYPE
PROMPT ============================================================

SELECT
    operation,
    COUNT(*) AS operation_count
FROM v$asm_operation
GROUP BY operation
ORDER BY operation_count DESC;

-- ============================================================
-- 6. RUNNING ASM OPERATIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. RUNNING ASM OPERATIONS
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
    END AS progress_pct
FROM v$asm_operation o
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = o.group_number
WHERE o.state NOT IN ('WAIT', 'DONE')
ORDER BY
    dg.name,
    o.operation;

-- ============================================================
-- 7. WAITING ASM OPERATIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. WAITING ASM OPERATIONS
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
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = o.group_number
WHERE o.state = 'WAIT'
ORDER BY
    dg.name,
    o.operation;

-- ============================================================
-- 8. OPERATIONS WITH ESTIMATED COMPLETION TIME
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. ASM OPERATION ETA
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    o.operation,
    o.state,
    o.sofar,
    o.est_work,
    o.est_rate,
    CASE
        WHEN o.est_rate > 0
        THEN ROUND(
                 (o.est_work - o.sofar) / o.est_rate,
                 2
             )
    END AS est_minutes,
    CASE
        WHEN o.est_rate > 0
        THEN ROUND(
                 (o.est_work - o.sofar) /
                 o.est_rate / 60,
                 2
             )
    END AS est_hours
FROM v$asm_operation o
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = o.group_number
WHERE o.est_rate > 0
ORDER BY
    est_minutes DESC;

-- ============================================================
-- 9. ASM DISKGROUP STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. ASM DISKGROUP STATUS
PROMPT ============================================================

SELECT
    name,
    type,
    state,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(usable_file_mb / 1024, 2) AS usable_gb,
    ROUND(
        required_mirror_free_mb / 1024,
        2
    ) AS required_mirror_gb,
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
-- 10. ASM DISKS NOT IN NORMAL STATE
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
    d.state AS disk_state,
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
-- 11. ASM DISK I/O ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. ASM DISK I/O ERRORS
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.disk_number,
    d.name AS disk_name,
    d.path,
    d.failgroup,
    d.read_errs AS read_errors,
    d.write_errs AS write_errors,
    d.state AS disk_state,
    d.mode_status
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
WHERE NVL(d.read_errs, 0) > 0
   OR NVL(d.write_errs, 0) > 0
ORDER BY
    NVL(d.read_errs, 0) +
    NVL(d.write_errs, 0) DESC;

-- ============================================================
-- 12. ASM DISKS WITH REPAIR TIMER
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. ASM DISKS WITH REPAIR TIMER
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.disk_number,
    d.name AS disk_name,
    d.path,
    d.failgroup,
    d.state AS disk_state,
    d.mode_status,
    d.repair_timer
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
WHERE NVL(d.repair_timer, 0) > 0
ORDER BY
    d.repair_timer DESC;

-- ============================================================
-- 13. ASM OPERATION WAIT EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. ASM-RELATED WAIT EVENTS
PROMPT ============================================================

SELECT
    event,
    wait_class,
    total_waits,
    ROUND(
        time_waited / 100,
        2
    ) AS time_waited_sec
FROM v$system_event
WHERE LOWER(event) LIKE '%asm%'
   OR LOWER(event) LIKE '%rebalance%'
   OR LOWER(event) LIKE '%resync%'
ORDER BY
    time_waited DESC;

-- ============================================================
-- 14. CURRENT ASM WAITERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. CURRENT ASM WAITERS
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
        LOWER(s.event) LIKE '%asm%'
        OR LOWER(s.event) LIKE '%rebalance%'
        OR LOWER(s.event) LIKE '%resync%'
      )
ORDER BY
    s.seconds_in_wait DESC;

-- ============================================================
-- 15. ASM OPERATION SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. ASM OPERATION SUMMARY
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
            WHEN state NOT IN ('WAIT', 'DONE')
            THEN 1
            ELSE 0
        END
    ) AS running_operations
FROM v$asm_operation;

-- ============================================================
-- 16. QUICK ASM OPERATION HEALTH
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. QUICK ASM OPERATION HEALTH
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
        THEN 'INFO - ASM OPERATION WAITING'

        WHEN EXISTS (
            SELECT 1
            FROM v$asm_operation
        )
        THEN 'INFO - ASM OPERATION IN PROGRESS'

        ELSE 'HEALTHY - NO ACTIVE ASM OPERATIONS'
    END AS health_status
FROM dual;

-- ============================================================
-- 17. QUICK ASM OPERATION CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. QUICK ASM OPERATION CHECK
PROMPT ============================================================

SELECT
    (SELECT COUNT(*)
       FROM v$asm_operation) AS active_operations,

    (SELECT COUNT(*)
       FROM v$asm_operation
      WHERE state = 'WAIT') AS waiting_operations,

    (SELECT COUNT(*)
       FROM v$asm_operation
      WHERE state NOT IN ('WAIT', 'DONE')) AS running_operations,

    (SELECT COUNT(*)
       FROM v$asm_disk
      WHERE state <> 'NORMAL') AS abnormal_disks,

    (SELECT COUNT(*)
       FROM v$asm_disk
      WHERE NVL(read_errs, 0) > 0
         OR NVL(write_errs, 0) > 0) AS disks_with_io_errors
FROM dual;

-- ============================================================
-- 18. DBA QUICK CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. DBA QUICK CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT [ ] Check V$ASM_OPERATION
PROMPT [ ] Identify operation type
PROMPT [ ] Check operation STATE
PROMPT [ ] Review SOFAR versus EST_WORK
PROMPT [ ] Review PROGRESS_PCT
PROMPT [ ] Check EST_RATE and estimated completion
PROMPT [ ] Review ASM operation POWER
PROMPT [ ] Investigate operations in WAIT state
PROMPT [ ] Check ASM diskgroup usable space
PROMPT [ ] Check OFFLINE_DISKS
PROMPT [ ] Review ASM disks not in NORMAL state
PROMPT [ ] Check ASM disk I/O errors
PROMPT [ ] Check REPAIR_TIMER
PROMPT [ ] Review ASM-related waits
PROMPT [ ] Correlate with ASM alert.log
PROMPT [ ] For Exadata, check CellCLI/storage-cell alerts
PROMPT [ ] Check OS multipath/iSCSI if disks are abnormal
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT NOTES
PROMPT ============================================================
PROMPT
PROMPT This script is READ-ONLY.
PROMPT
PROMPT V$ASM_OPERATION shows current ASM operations. It is not
PROMPT a persistent historical operation repository.
PROMPT
PROMPT SOFAR and EST_WORK are progress estimates and may change
PROMPT as the operation progresses.
PROMPT
PROMPT A WAIT state does not automatically indicate failure.
PROMPT Investigate the associated diskgroup, disks, ASM alerts
PROMPT and storage path.
PROMPT
PROMPT ASM operations can be expected after disk additions,
PROMPT disk drops, disk failures/replacements, diskgroup changes
PROMPT and other ASM maintenance activities.
PROMPT
PROMPT Do not cancel, alter or change ASM operations based only
PROMPT on this report.
PROMPT
PROMPT For Exadata environments, correlate database-side ASM
PROMPT information with CellCLI, storage-cell alerts,
PROMPT multipath/iSCSI and OS diagnostics.
PROMPT
PROMPT ============================================================
PROMPT END OF ASM OPERATION MONITORING
PROMPT ============================================================


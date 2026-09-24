-- ============================================================
-- Oracle DBA Toolkit
-- File   : asm_failed_disks.sql
-- Purpose: Identify failed / abnormal ASM disks
-- Scope  : Disk errors, disk state, header status, repair,
--          failgroups and related ASM operations
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

-- ============================================================
-- COLUMN FORMATS
-- ============================================================

COLUMN NAME                  FORMAT A20
COLUMN DB_UNIQUE_NAME        FORMAT A20
COLUMN INSTANCE_NAME         FORMAT A20
COLUMN HOST_NAME             FORMAT A40
COLUMN STATUS                FORMAT A15
COLUMN VERSION               FORMAT A20
COLUMN STARTUP_TIME          FORMAT A20

COLUMN DISKGROUP_NAME        FORMAT A20
COLUMN DISK_NAME             FORMAT A30
COLUMN PATH                  FORMAT A70
COLUMN FAILGROUP             FORMAT A25
COLUMN MOUNT_STATUS          FORMAT A15
COLUMN MODE_STATUS           FORMAT A15
COLUMN STATE                 FORMAT A15
COLUMN HEADER_STATUS         FORMAT A20

COLUMN TOTAL_MB              FORMAT 999,999,999,999
COLUMN FREE_MB               FORMAT 999,999,999,999
COLUMN READ_ERRORS           FORMAT 999,999,999
COLUMN WRITE_ERRORS          FORMAT 999,999,999
COLUMN REPAIR_TIMER          FORMAT 999,999,999
COLUMN DISK_NUMBER           FORMAT 99999
COLUMN GROUP_NUMBER          FORMAT 99999

COLUMN OPERATION             FORMAT A15
COLUMN POWER                 FORMAT 9999
COLUMN ACTUAL                FORMAT 9999
COLUMN SOFAR                 FORMAT 999,999,999
COLUMN EST_WORK              FORMAT 999,999,999
COLUMN EST_RATE              FORMAT 999,999,999
COLUMN EST_MINUTES           FORMAT 999,999.99

COLUMN HEALTH_STATUS         FORMAT A50

PROMPT
PROMPT ============================================================
PROMPT ASM FAILED / ABNORMAL DISK MONITORING
PROMPT ============================================================

-- ============================================================
-- 1. DATABASE / INSTANCE INFORMATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    d.name,
    d.db_unique_name,
    d.open_mode,
    d.database_role,
    i.instance_name,
    i.host_name,
    i.status,
    i.version,
    TO_CHAR(i.startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
FROM v$database d
CROSS JOIN v$instance i;

-- ============================================================
-- 2. ASM DISKS WITH READ / WRITE ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. ASM DISKS WITH READ / WRITE ERRORS
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
    d.header_status,
    d.read_errs AS read_errors,
    d.write_errs AS write_errors
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
WHERE NVL(d.read_errs, 0) > 0
   OR NVL(d.write_errs, 0) > 0
ORDER BY
    NVL(d.read_errs, 0) + NVL(d.write_errs, 0) DESC;

-- ============================================================
-- 3. ASM DISKS NOT IN NORMAL STATE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. ASM DISKS NOT IN NORMAL STATE
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.disk_number,
    d.name AS disk_name,
    d.path,
    d.failgroup,
    d.state,
    d.mode_status,
    d.mount_status,
    d.header_status,
    d.total_mb,
    d.free_mb
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
WHERE NVL(d.state, 'UNKNOWN') <> 'NORMAL'
ORDER BY
    dg.name,
    d.state,
    d.disk_number;

-- ============================================================
-- 4. ASM DISKS NOT ONLINE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. ASM DISKS NOT ONLINE
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
WHERE NVL(d.mode_status, 'UNKNOWN') <> 'ONLINE'
ORDER BY
    dg.name,
    d.disk_number;

-- ============================================================
-- 5. ASM DISKS WITH ABNORMAL HEADER STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. ASM DISKS WITH ABNORMAL HEADER STATUS
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.disk_number,
    d.name AS disk_name,
    d.path,
    d.failgroup,
    d.header_status,
    d.mount_status,
    d.mode_status,
    d.state
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
WHERE d.header_status IS NOT NULL
  AND d.header_status NOT IN ('MEMBER', 'CANDIDATE', 'FORMER')
ORDER BY
    dg.name,
    d.header_status,
    d.disk_number;

-- ============================================================
-- 6. ASM DISKS WITH REPAIR TIMER
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. ASM DISKS WITH ACTIVE REPAIR TIMER
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
-- 7. FAILED / ABNORMAL DISK SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. FAILED / ABNORMAL DISK SUMMARY
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    COUNT(*) AS total_disks,
    SUM(
        CASE
            WHEN NVL(d.read_errs, 0) > 0
              OR NVL(d.write_errs, 0) > 0
            THEN 1
            ELSE 0
        END
    ) AS disks_with_io_errors,
    SUM(
        CASE
            WHEN NVL(d.state, 'UNKNOWN') <> 'NORMAL'
            THEN 1
            ELSE 0
        END
    ) AS abnormal_state_disks,
    SUM(
        CASE
            WHEN NVL(d.mode_status, 'UNKNOWN') <> 'ONLINE'
            THEN 1
            ELSE 0
        END
    ) AS non_online_disks
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
GROUP BY dg.name
ORDER BY dg.name;

-- ============================================================
-- 8. ASM DISK STATE SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. ASM DISK STATE SUMMARY
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.state,
    COUNT(*) AS disk_count
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
GROUP BY
    dg.name,
    d.state
ORDER BY
    dg.name,
    d.state;

-- ============================================================
-- 9. ASM DISK HEADER SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. ASM DISK HEADER STATUS SUMMARY
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.header_status,
    COUNT(*) AS disk_count
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
GROUP BY
    dg.name,
    d.header_status
ORDER BY
    dg.name,
    d.header_status;

-- ============================================================
-- 10. FAILGROUP DISTRIBUTION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. FAILGROUP DISTRIBUTION
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.failgroup,
    COUNT(*) AS disk_count,
    ROUND(SUM(d.total_mb) / 1024, 2) AS total_gb,
    ROUND(SUM(d.free_mb) / 1024, 2) AS free_gb
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
GROUP BY
    dg.name,
    d.failgroup
ORDER BY
    dg.name,
    d.failgroup;

-- ============================================================
-- 11. CURRENT ASM OPERATIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. CURRENT ASM OPERATIONS
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
        WHEN est_rate > 0
        THEN ROUND((est_work - sofar) / est_rate, 2)
        ELSE NULL
    END AS est_minutes
FROM v$asm_operation
ORDER BY
    group_number,
    operation;

-- ============================================================
-- 12. ASM OPERATIONS RELATED TO FAILED DISKS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. ASM OPERATIONS / REBALANCE STATUS
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
        WHEN o.est_rate > 0
        THEN ROUND((o.est_work - o.sofar) / o.est_rate, 2)
        ELSE NULL
    END AS est_minutes
FROM v$asm_operation o
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = o.group_number
ORDER BY
    dg.name,
    o.operation;

-- ============================================================
-- 13. ASM DISK I/O ERROR TOTAL
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. ASM DISK I/O ERROR TOTAL
PROMPT ============================================================

SELECT
    SUM(NVL(read_errs, 0))  AS total_read_errors,
    SUM(NVL(write_errs, 0)) AS total_write_errors,
    SUM(
        CASE
            WHEN NVL(read_errs, 0) > 0
              OR NVL(write_errs, 0) > 0
            THEN 1
            ELSE 0
        END
    ) AS disks_with_errors
FROM v$asm_disk;

-- ============================================================
-- 14. ASM DISK HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. ASM DISK HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN SUM(
            CASE
                WHEN NVL(d.read_errs, 0) > 0
                  OR NVL(d.write_errs, 0) > 0
                THEN 1
                ELSE 0
            END
        ) > 0
        THEN 'WARNING - ASM DISK I/O ERRORS DETECTED'

        WHEN SUM(
            CASE
                WHEN NVL(d.state, 'UNKNOWN') <> 'NORMAL'
                THEN 1
                ELSE 0
            END
        ) > 0
        THEN 'WARNING - ASM DISKS IN ABNORMAL STATE'

        WHEN SUM(
            CASE
                WHEN NVL(d.mode_status, 'UNKNOWN') <> 'ONLINE'
                THEN 1
                ELSE 0
            END
        ) > 0
        THEN 'WARNING - ASM DISKS NOT ONLINE'

        ELSE 'HEALTHY - NO OBVIOUS ASM DISK ERRORS'
    END AS health_status
FROM v$asm_disk d;

-- ============================================================
-- 15. QUICK FAILED-DISK CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. QUICK FAILED-DISK CHECK
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.disk_number,
    d.name AS disk_name,
    d.path,
    d.state,
    d.mode_status,
    d.header_status,
    d.read_errs AS read_errors,
    d.write_errs AS write_errors,
    d.repair_timer
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
WHERE NVL(d.read_errs, 0) > 0
   OR NVL(d.write_errs, 0) > 0
   OR NVL(d.state, 'UNKNOWN') <> 'NORMAL'
   OR NVL(d.mode_status, 'UNKNOWN') <> 'ONLINE'
   OR NVL(d.repair_timer, 0) > 0
ORDER BY
    dg.name,
    d.disk_number;

-- ============================================================
-- 16. DBA CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT DBA CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT 1. Check ASM disks with READ/WRITE errors.
PROMPT 2. Review disks not in NORMAL state.
PROMPT 3. Review disks not ONLINE.
PROMPT 4. Check HEADER_STATUS for unexpected values.
PROMPT 5. Review active REPAIR_TIMER values.
PROMPT 6. Check V$ASM_OPERATION for rebalance/resync activity.
PROMPT 7. Validate failgroup redundancy and diskgroup state.
PROMPT 8. Correlate ASM symptoms with OS multipath/iSCSI/device health.
PROMPT 9. On Exadata, correlate with CellCLI physical disk/cell disk/grid disk status.
PROMPT 10. Do not drop, offline, or replace a disk based only on this report.
PROMPT
PROMPT ============================================================
PROMPT END OF ASM FAILED DISK MONITORING
PROMPT ============================================================


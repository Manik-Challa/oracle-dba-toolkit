-- ============================================================
-- Oracle DBA Toolkit
-- File   : asm_diskgroup_usage.sql
-- Purpose: Monitor ASM diskgroup capacity and health
-- Scope  : Usage, free space, usable space, redundancy,
--          rebalance, disks and capacity risk
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN name                 FORMAT A20
COLUMN type                 FORMAT A12
COLUMN state                FORMAT A12
COLUMN sector_size          FORMAT 9999
COLUMN block_size           FORMAT 999999
COLUMN allocation_unit_size FORMAT 999,999,999
COLUMN total_gb             FORMAT 999,999,999.99
COLUMN free_gb              FORMAT 999,999,999.99
COLUMN usable_gb            FORMAT 999,999,999.99
COLUMN required_mirror_gb   FORMAT 999,999,999.99
COLUMN used_gb              FORMAT 999,999,999.99
COLUMN used_pct             FORMAT 990.99
COLUMN free_pct             FORMAT 990.99
COLUMN usable_pct           FORMAT 990.99
COLUMN disks                FORMAT 9999
COLUMN offline_disks        FORMAT 9999
COLUMN rebalance_power      FORMAT 9999
COLUMN rebalance_state      FORMAT A15
COLUMN compatibility        FORMAT A15
COLUMN database_compatibility FORMAT A15

COLUMN path                 FORMAT A70
COLUMN disk_name            FORMAT A30
COLUMN failgroup            FORMAT A25
COLUMN mount_status         FORMAT A15
COLUMN mode_status          FORMAT A15
COLUMN header_status        FORMAT A15
COLUMN repair_timer         FORMAT 999999
COLUMN read_errors          FORMAT 999,999,999
COLUMN write_errors         FORMAT 999,999,999

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    name,
    db_unique_name,
    open_mode,
    database_role
FROM v$database;

SELECT
    instance_name,
    host_name,
    status,
    version,
    startup_time
FROM v$instance;

PROMPT
PROMPT ============================================================
PROMPT 2. ASM DISKGROUP SUMMARY
PROMPT ============================================================

SELECT
    name,
    type,
    state,
    total_mb / 1024 AS total_gb,
    free_mb / 1024 AS free_gb,
    usable_file_mb / 1024 AS usable_gb,
    required_mirror_free_mb / 1024
        AS required_mirror_gb,
    ROUND(
        (total_mb - free_mb)
        / NULLIF(total_mb, 0) * 100,
        2
    ) AS used_pct,
    ROUND(
        free_mb
        / NULLIF(total_mb, 0) * 100,
        2
    ) AS free_pct,
    ROUND(
        usable_file_mb
        / NULLIF(total_mb, 0) * 100,
        2
    ) AS usable_pct
FROM v$asm_diskgroup
ORDER BY used_pct DESC;

PROMPT
PROMPT ============================================================
PROMPT 3. ASM DISKGROUP CAPACITY
PROMPT ============================================================

SELECT
    name,
    type,
    state,
    total_mb / 1024 AS total_gb,
    free_mb / 1024 AS free_gb,
    usable_file_mb / 1024 AS usable_gb,
    required_mirror_free_mb / 1024
        AS required_mirror_gb,
    ROUND(
        (total_mb - free_mb)
        / NULLIF(total_mb, 0) * 100,
        2
    ) AS used_pct,
    ROUND(
        free_mb
        / NULLIF(total_mb, 0) * 100,
        2
    ) AS free_pct
FROM v$asm_diskgroup
ORDER BY total_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT 4. DISKGROUPS ABOVE 80 PERCENT USED
PROMPT ============================================================

SELECT
    name,
    type,
    state,
    total_mb / 1024 AS total_gb,
    free_mb / 1024 AS free_gb,
    usable_file_mb / 1024 AS usable_gb,
    ROUND(
        (total_mb - free_mb)
        / NULLIF(total_mb, 0) * 100,
        2
    ) AS used_pct
FROM v$asm_diskgroup
WHERE (
        total_mb - free_mb
      ) / NULLIF(total_mb, 0) * 100 >= 80
ORDER BY used_pct DESC;

PROMPT
PROMPT ============================================================
PROMPT 5. DISKGROUPS ABOVE 90 PERCENT USED
PROMPT ============================================================

SELECT
    name,
    type,
    state,
    total_mb / 1024 AS total_gb,
    free_mb / 1024 AS free_gb,
    usable_file_mb / 1024 AS usable_gb,
    required_mirror_free_mb / 1024
        AS required_mirror_gb,
    ROUND(
        (total_mb - free_mb)
        / NULLIF(total_mb, 0) * 100,
        2
    ) AS used_pct
FROM v$asm_diskgroup
WHERE (
        total_mb - free_mb
      ) / NULLIF(total_mb, 0) * 100 >= 90
ORDER BY used_pct DESC;

PROMPT
PROMPT ============================================================
PROMPT 6. DISKGROUPS WITH LOW USABLE FILE SPACE
PROMPT ============================================================

SELECT
    name,
    type,
    state,
    total_mb / 1024 AS total_gb,
    free_mb / 1024 AS free_gb,
    usable_file_mb / 1024 AS usable_gb,
    required_mirror_free_mb / 1024
        AS required_mirror_gb,
    ROUND(
        usable_file_mb
        / NULLIF(total_mb, 0) * 100,
        2
    ) AS usable_pct
FROM v$asm_diskgroup
WHERE usable_file_mb <
      total_mb * 0.20
ORDER BY usable_pct;

PROMPT
PROMPT ============================================================
PROMPT 7. ASM DISKGROUP STATE
PROMPT ============================================================

SELECT
    name,
    state,
    type,
    total_mb / 1024 AS total_gb,
    free_mb / 1024 AS free_gb,
    usable_file_mb / 1024 AS usable_gb
FROM v$asm_diskgroup
ORDER BY name;

PROMPT
PROMPT ============================================================
PROMPT 8. ASM DISK COUNT BY DISKGROUP
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    dg.type,
    COUNT(d.name) AS disk_count,
    SUM(
        CASE
            WHEN d.mount_status = 'CLOSED'
            THEN 1
            ELSE 0
        END
    ) AS closed_disks,
    SUM(
        CASE
            WHEN d.mode_status <> 'ONLINE'
            THEN 1
            ELSE 0
        END
    ) AS non_online_disks
FROM v$asm_diskgroup dg
LEFT JOIN v$asm_disk d
    ON d.group_number = dg.group_number
GROUP BY
    dg.name,
    dg.type
ORDER BY dg.name;

PROMPT
PROMPT ============================================================
PROMPT 9. ASM DISKS NOT ONLINE
PROMPT ============================================================

SELECT
    group_number,
    disk_number,
    name AS disk_name,
    path,
    mount_status,
    mode_status,
    state,
    header_status,
    failgroup,
    repair_timer
FROM v$asm_disk
WHERE mode_status <> 'ONLINE'
   OR mount_status <> 'CACHED'
   OR state <> 'NORMAL'
ORDER BY
    group_number,
    disk_number;

PROMPT
PROMPT ============================================================
PROMPT 10. ASM DISK STATE SUMMARY
PROMPT ============================================================

SELECT
    group_number,
    state,
    mode_status,
    mount_status,
    COUNT(*) AS disk_count
FROM v$asm_disk
GROUP BY
    group_number,
    state,
    mode_status,
    mount_status
ORDER BY
    group_number,
    state,
    mode_status;

PROMPT
PROMPT ============================================================
PROMPT 11. ASM DISKS BY FAILGROUP
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.failgroup,
    COUNT(*) AS disk_count,
    ROUND(
        SUM(d.total_mb) / 1024,
        2
    ) AS total_gb,
    ROUND(
        SUM(d.free_mb) / 1024,
        2
    ) AS free_gb
FROM v$asm_disk d
JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
GROUP BY
    dg.name,
    d.failgroup
ORDER BY
    dg.name,
    d.failgroup;

PROMPT
PROMPT ============================================================
PROMPT 12. ASM DISK CAPACITY
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.disk_number,
    d.name AS disk_name,
    d.failgroup,
    d.path,
    d.total_mb / 1024 AS total_gb,
    d.free_mb / 1024 AS free_gb,
    d.mount_status,
    d.mode_status,
    d.state,
    d.header_status
FROM v$asm_disk d
JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
ORDER BY
    dg.name,
    d.disk_number;

PROMPT
PROMPT ============================================================
PROMPT 13. ASM DISKS WITH READ ERRORS
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.disk_number,
    d.name AS disk_name,
    d.path,
    d.read_errs AS read_errors,
    d.write_errs AS write_errors,
    d.state,
    d.mode_status,
    d.header_status
FROM v$asm_disk d
JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
WHERE NVL(d.read_errs, 0) > 0
   OR NVL(d.write_errs, 0) > 0
ORDER BY
    d.read_errs + d.write_errs DESC;

PROMPT
PROMPT ============================================================
PROMPT 14. ASM DISKS WITH REPAIR TIMER
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
JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
WHERE NVL(d.repair_timer, 0) > 0
ORDER BY d.repair_timer DESC;

PROMPT
PROMPT ============================================================
PROMPT 15. ASM REBALANCE OPERATIONS
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
ORDER BY group_number, operation;

PROMPT
PROMPT ============================================================
PROMPT 16. DISKGROUPS WITH ACTIVE REBALANCE
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
    o.est_minutes
FROM v$asm_operation o
JOIN v$asm_diskgroup dg
    ON dg.group_number = o.group_number
ORDER BY
    dg.name,
    o.operation;

PROMPT
PROMPT ============================================================
PROMPT 17. ASM COMPATIBILITY
PROMPT ============================================================

SELECT
    name,
    type,
    compatibility,
    database_compatibility
FROM v$asm_diskgroup
ORDER BY name;

PROMPT
PROMPT ============================================================
PROMPT 18. ASM DISK HEADER STATUS
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    d.header_status,
    COUNT(*) AS disk_count
FROM v$asm_disk d
JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
GROUP BY
    dg.name,
    d.header_status
ORDER BY
    dg.name,
    d.header_status;

PROMPT
PROMPT ============================================================
PROMPT 19. ASM DISKGROUP HEALTH SUMMARY
PROMPT ============================================================

SELECT
    name,
    type,
    state,
    ROUND(
        (total_mb - free_mb)
        / NULLIF(total_mb, 0) * 100,
        2
    ) AS used_pct,
    ROUND(
        usable_file_mb
        / NULLIF(total_mb, 0) * 100,
        2
    ) AS usable_pct,
    CASE
        WHEN state <> 'CONNECTED'
            THEN 'CRITICAL - DISKGROUP NOT CONNECTED'

        WHEN usable_file_mb <= 0
            THEN 'CRITICAL - NO USABLE FILE SPACE'

        WHEN (
            total_mb - free_mb
        ) / NULLIF(total_mb, 0) * 100 >= 95
            THEN 'CRITICAL - USAGE >= 95%'

        WHEN (
            total_mb - free_mb
        ) / NULLIF(total_mb, 0) * 100 >= 90
            THEN 'WARNING - USAGE >= 90%'

        WHEN usable_file_mb <
             total_mb * 0.20
            THEN 'WARNING - LOW USABLE SPACE'

        ELSE 'HEALTHY'
    END AS health_status
FROM v$asm_diskgroup
ORDER BY used_pct DESC;

PROMPT
PROMPT ============================================================
PROMPT 20. QUICK ASM CAPACITY CHECK
PROMPT ============================================================

SELECT
    COUNT(*) AS diskgroup_count,
    SUM(total_mb) / 1024 AS total_gb,
    SUM(free_mb) / 1024 AS free_gb,
    SUM(usable_file_mb) / 1024 AS usable_gb,
    ROUND(
        (
            SUM(total_mb) -
            SUM(free_mb)
        )
        / NULLIF(SUM(total_mb), 0)
        * 100,
        2
    ) AS overall_used_pct
FROM v$asm_diskgroup;

PROMPT
PROMPT ============================================================
PROMPT DBA QUICK CHECK
PROMPT ============================================================
PROMPT
PROMPT 1. Check DISKGROUP STATE.
PROMPT 2. Review USED_PCT and FREE_GB.
PROMPT 3. Review USABLE_FILE_MB.
PROMPT 4. Check REQUIRED_MIRROR_FREE_MB.
PROMPT 5. Look for disks not ONLINE/NORMAL.
PROMPT 6. Check disk read/write errors.
PROMPT 7. Check disks with active REPAIR_TIMER.
PROMPT 8. Check V$ASM_OPERATION for active rebalance.
PROMPT 9. Review failgroup distribution.
PROMPT 10. Correlate ASM capacity with database growth.
PROMPT 11. On Exadata, correlate ASM findings with CellCLI.
PROMPT 12. Do not drop or replace ASM disks based solely on this report.
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT NOTES
PROMPT ============================================================
PROMPT
PROMPT - FREE_MB and USABLE_FILE_MB are different measurements.
PROMPT - USABLE_FILE_MB accounts for ASM redundancy requirements.
PROMPT - REQUIRED_MIRROR_FREE_MB is important when evaluating
PROMPT   redundancy and failure tolerance.
PROMPT - High diskgroup usage does not automatically mean an incident.
PROMPT - ASM disk state must be correlated with the storage layer.
PROMPT - Active rebalance can temporarily affect I/O workload.
PROMPT - Disk errors require investigation before corrective action.
PROMPT - On Exadata, use CellCLI for physical storage-cell health.
PROMPT - This script is READ-ONLY.
PROMPT - Thresholds used here are DBA toolkit heuristics,
PROMPT   not Oracle-defined incident thresholds.
PROMPT - RAC/ASM environments should be checked from the ASM
PROMPT   instance and correlated across instances where required.
PROMPT
PROMPT ============================================================
PROMPT END OF ASM DISKGROUP USAGE CHECK
PROMPT ============================================================


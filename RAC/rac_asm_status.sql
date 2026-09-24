-- ============================================================================
-- RAC ASM STATUS MONITORING
-- File    : rac_asm_status.sql
-- Purpose : Monitor ASM health across RAC instances
-- Author  : Manik Challa
-- Usage   : Run as SYSASM or a user with appropriate ASM dictionary privileges
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN inst_id              FORMAT 999
COLUMN instance_number      FORMAT 999
COLUMN instance_name        FORMAT A20
COLUMN host_name            FORMAT A30
COLUMN status               FORMAT A15
COLUMN state                FORMAT A15
COLUMN cluster_name         FORMAT A25
COLUMN db_name              FORMAT A15
COLUMN db_unique_name       FORMAT A25

COLUMN name                 FORMAT A25
COLUMN type                 FORMAT A12
COLUMN total_gb             FORMAT 999999.99
COLUMN free_gb              FORMAT 999999.99
COLUMN usable_gb            FORMAT 999999.99
COLUMN required_mirror_gb   FORMAT 999999.99
COLUMN pct_used             FORMAT 999.99
COLUMN pct_free             FORMAT 999.99
COLUMN redundancy            FORMAT A12
COLUMN compatibility        FORMAT A15
COLUMN database_compatibility FORMAT A20

COLUMN disk_number          FORMAT 9999
COLUMN disk_name            FORMAT A30
COLUMN failgroup            FORMAT A30
COLUMN mount_status         FORMAT A15
COLUMN header_status        FORMAT A15
COLUMN mode_status          FORMAT A15
COLUMN path                 FORMAT A80
COLUMN state                 FORMAT A15
COLUMN read_only             FORMAT A10

COLUMN operation            FORMAT A15
COLUMN power                FORMAT 999
COLUMN actual               FORMAT 999
COLUMN sofar                FORMAT 999999999
COLUMN est_work             FORMAT 999999999
COLUMN est_rate             FORMAT 999999999
COLUMN est_minutes          FORMAT 999999
COLUMN error_code           FORMAT A20

COLUMN software_version     FORMAT A20
COLUMN compatible_version   FORMAT A20

PROMPT
PROMPT ============================================================================
PROMPT RAC ASM STATUS MONITORING
PROMPT ============================================================================


PROMPT
PROMPT ============================================================================
PROMPT 1. ASM INSTANCE STATUS
PROMPT ============================================================================

SELECT
    inst_id,
    instance_number,
    instance_name,
    host_name,
    status,
    state,
    cluster_name,
    version AS software_version
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 2. ASM INSTANCE ROLE / DATABASE INFORMATION
PROMPT ============================================================================

SELECT
    inst_id,
    instance_number,
    instance_name,
    host_name,
    status,
    parallel
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 3. ASM DISKGROUP SUMMARY
PROMPT ============================================================================

SELECT
    inst_id,
    name,
    type,
    state,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(usable_file_mb / 1024, 2) AS usable_gb,
    ROUND(
        CASE
            WHEN total_mb > 0
            THEN (total_mb - free_mb) * 100 / total_mb
        END,
        2
    ) AS pct_used,
    ROUND(
        CASE
            WHEN total_mb > 0
            THEN free_mb * 100 / total_mb
        END,
        2
    ) AS pct_free,
    required_mirror_free_mb
FROM gv$asm_diskgroup
ORDER BY inst_id, name;


PROMPT
PROMPT ============================================================================
PROMPT 4. ASM DISKGROUP HEALTH
PROMPT ============================================================================

SELECT
    inst_id,
    name,
    state,
    type,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(usable_file_mb / 1024, 2) AS usable_gb,
    ROUND(
        CASE
            WHEN total_mb > 0
            THEN (total_mb - free_mb) * 100 / total_mb
        END,
        2
    ) AS pct_used,
    CASE
        WHEN state <> 'CONNECTED'
            THEN 'CHECK'
        WHEN total_mb = 0
            THEN 'CHECK'
        WHEN free_mb * 100 / NULLIF(total_mb, 0) < 10
            THEN 'CRITICAL'
        WHEN free_mb * 100 / NULLIF(total_mb, 0) < 20
            THEN 'WARNING'
        ELSE 'OK'
    END AS health
FROM gv$asm_diskgroup
ORDER BY
    CASE
        WHEN state <> 'CONNECTED' THEN 1
        WHEN free_mb * 100 / NULLIF(total_mb, 0) < 10 THEN 2
        WHEN free_mb * 100 / NULLIF(total_mb, 0) < 20 THEN 3
        ELSE 4
    END,
    name;


PROMPT
PROMPT ============================================================================
PROMPT 5. ASM DISKGROUP STATE BY RAC INSTANCE
PROMPT ============================================================================

SELECT
    inst_id,
    name,
    state,
    type,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(usable_file_mb / 1024, 2) AS usable_gb
FROM gv$asm_diskgroup
ORDER BY name, inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 6. ASM DISKGROUP ATTRIBUTE / COMPATIBILITY
PROMPT ============================================================================

SELECT
    inst_id,
    name,
    compatibility,
    database_compatibility
FROM gv$asm_diskgroup
ORDER BY name, inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 7. ASM DISK SUMMARY
PROMPT ============================================================================

SELECT
    inst_id,
    COUNT(*) AS total_disks,
    COUNT(CASE WHEN mount_status = 'CACHED' THEN 1 END) AS cached_disks,
    COUNT(CASE WHEN mount_status = 'OPENED' THEN 1 END) AS opened_disks,
    COUNT(CASE WHEN header_status = 'MEMBER' THEN 1 END) AS member_disks,
    COUNT(CASE WHEN mode_status = 'ONLINE' THEN 1 END) AS online_disks
FROM gv$asm_disk
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 8. ASM DISK DETAILS
PROMPT ============================================================================

SELECT
    inst_id,
    group_number,
    disk_number,
    name AS disk_name,
    failgroup,
    mount_status,
    header_status,
    mode_status,
    state,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    path
FROM gv$asm_disk
ORDER BY
    inst_id,
    group_number,
    disk_number;


PROMPT
PROMPT ============================================================================
PROMPT 9. ASM DISKS NOT ONLINE
PROMPT ============================================================================

SELECT
    inst_id,
    group_number,
    disk_number,
    name AS disk_name,
    failgroup,
    mount_status,
    header_status,
    mode_status,
    state,
    path
FROM gv$asm_disk
WHERE mode_status <> 'ONLINE'
   OR state <> 'NORMAL'
ORDER BY
    inst_id,
    group_number,
    disk_number;


PROMPT
PROMPT ============================================================================
PROMPT 10. ASM DISKS WITH ABNORMAL HEADER STATUS
PROMPT ============================================================================

SELECT
    inst_id,
    group_number,
    disk_number,
    name AS disk_name,
    failgroup,
    mount_status,
    header_status,
    mode_status,
    state,
    path
FROM gv$asm_disk
WHERE header_status NOT IN ('MEMBER', 'FORMER')
ORDER BY
    inst_id,
    group_number,
    disk_number;


PROMPT
PROMPT ============================================================================
PROMPT 11. ASM DISKS WITH ABNORMAL STATE
PROMPT ============================================================================

SELECT
    inst_id,
    group_number,
    disk_number,
    name AS disk_name,
    failgroup,
    state,
    mode_status,
    mount_status,
    path
FROM gv$asm_disk
WHERE state <> 'NORMAL'
ORDER BY
    inst_id,
    group_number,
    disk_number;


PROMPT
PROMPT ============================================================================
PROMPT 12. ASM DISK STATUS SUMMARY
PROMPT ============================================================================

SELECT
    inst_id,
    state,
    mode_status,
    mount_status,
    COUNT(*) AS disk_count
FROM gv$asm_disk
GROUP BY
    inst_id,
    state,
    mode_status,
    mount_status
ORDER BY
    inst_id,
    state,
    mode_status,
    mount_status;


PROMPT
PROMPT ============================================================================
PROMPT 13. ASM FAILGROUP DISTRIBUTION
PROMPT ============================================================================

SELECT
    inst_id,
    group_number,
    failgroup,
    COUNT(*) AS disk_count,
    ROUND(SUM(total_mb) / 1024, 2) AS total_gb,
    ROUND(SUM(free_mb) / 1024, 2) AS free_gb
FROM gv$asm_disk
GROUP BY
    inst_id,
    group_number,
    failgroup
ORDER BY
    group_number,
    failgroup;


PROMPT
PROMPT ============================================================================
PROMPT 14. ASM DISKGROUP MIRRORING / USABLE SPACE
PROMPT ============================================================================

SELECT
    inst_id,
    name,
    type,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(required_mirror_free_mb / 1024, 2)
        AS required_mirror_free_gb,
    ROUND(usable_file_mb / 1024, 2)
        AS usable_file_gb
FROM gv$asm_diskgroup
ORDER BY name, inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 15. ASM REBALANCE OPERATIONS
PROMPT ============================================================================

SELECT
    inst_id,
    group_number,
    operation,
    state,
    power,
    actual,
    sofar,
    est_work,
    est_rate,
    est_minutes
FROM gv$asm_operation
ORDER BY
    inst_id,
    group_number,
    operation;


PROMPT
PROMPT ============================================================================
PROMPT 16. ASM OPERATIONS IN PROGRESS
PROMPT ============================================================================

SELECT
    inst_id,
    group_number,
    operation,
    state,
    power,
    actual,
    sofar,
    est_work,
    est_rate,
    est_minutes
FROM gv$asm_operation
WHERE state <> 'WAIT'
ORDER BY
    inst_id,
    group_number;


PROMPT
PROMPT ============================================================================
PROMPT 17. ASM OPERATION SUMMARY
PROMPT ============================================================================

SELECT
    inst_id,
    operation,
    state,
    COUNT(*) AS operation_count
FROM gv$asm_operation
GROUP BY
    inst_id,
    operation,
    state
ORDER BY
    inst_id,
    operation,
    state;


PROMPT
PROMPT ============================================================================
PROMPT 18. ASM CLIENTS
PROMPT ============================================================================

SELECT
    inst_id,
    group_number,
    instance_name,
    db_name,
    status,
    software_version,
    compatible_version
FROM gv$asm_client
ORDER BY
    inst_id,
    db_name,
    instance_name;


PROMPT
PROMPT ============================================================================
PROMPT 19. ASM CLIENT COUNT BY INSTANCE
PROMPT ============================================================================

SELECT
    inst_id,
    COUNT(*) AS client_count
FROM gv$asm_client
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 20. DATABASES USING ASM
PROMPT ============================================================================

SELECT DISTINCT
    inst_id,
    db_name,
    instance_name,
    status
FROM gv$asm_client
ORDER BY
    db_name,
    instance_name;


PROMPT
PROMPT ============================================================================
PROMPT 21. ASM DISKGROUP USAGE BY CLIENT
PROMPT ============================================================================

SELECT
    c.inst_id,
    c.db_name,
    c.instance_name,
    c.status,
    COUNT(DISTINCT c.group_number) AS diskgroup_count
FROM gv$asm_client c
GROUP BY
    c.inst_id,
    c.db_name,
    c.instance_name,
    c.status
ORDER BY
    c.db_name,
    c.instance_name;


PROMPT
PROMPT ============================================================================
PROMPT 22. ASM DISK COUNT BY DISKGROUP
PROMPT ============================================================================

SELECT
    inst_id,
    group_number,
    COUNT(*) AS disk_count,
    COUNT(DISTINCT failgroup) AS failgroup_count,
    ROUND(SUM(total_mb) / 1024, 2) AS total_gb,
    ROUND(SUM(free_mb) / 1024, 2) AS free_gb
FROM gv$asm_disk
WHERE group_number > 0
GROUP BY
    inst_id,
    group_number
ORDER BY
    inst_id,
    group_number;


PROMPT
PROMPT ============================================================================
PROMPT 23. ASM DISKGROUP CAPACITY SUMMARY
PROMPT ============================================================================

SELECT
    inst_id,
    name,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(
        (total_mb - free_mb) * 100 / NULLIF(total_mb, 0),
        2
    ) AS pct_used,
    ROUND(
        free_mb * 100 / NULLIF(total_mb, 0),
        2
    ) AS pct_free
FROM gv$asm_diskgroup
ORDER BY pct_used DESC;


PROMPT
PROMPT ============================================================================
PROMPT 24. DISKGROUPS WITH LOW FREE SPACE
PROMPT ============================================================================

SELECT
    inst_id,
    name,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(
        free_mb * 100 / NULLIF(total_mb, 0),
        2
    ) AS pct_free,
    CASE
        WHEN free_mb * 100 / NULLIF(total_mb, 0) < 10
            THEN 'CRITICAL'
        WHEN free_mb * 100 / NULLIF(total_mb, 0) < 20
            THEN 'WARNING'
        ELSE 'OK'
    END AS health
FROM gv$asm_diskgroup
WHERE free_mb * 100 / NULLIF(total_mb, 0) < 20
ORDER BY pct_free;


PROMPT
PROMPT ============================================================================
PROMPT 25. ASM INSTANCE / DISKGROUP CONSISTENCY
PROMPT ============================================================================

SELECT
    inst_id,
    name,
    state,
    type,
    total_mb,
    free_mb,
    usable_file_mb
FROM gv$asm_diskgroup
ORDER BY
    name,
    inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 26. ASM HEALTH CHECK
PROMPT ============================================================================

SELECT
    'ASM INSTANCES' AS check_name,
    COUNT(*) AS value,
    CASE
        WHEN COUNT(*) > 0 THEN 'OK'
        ELSE 'CHECK'
    END AS health
FROM gv$instance

UNION ALL

SELECT
    'DISKGROUPS',
    COUNT(*),
    CASE
        WHEN COUNT(*) > 0 THEN 'OK'
        ELSE 'CHECK'
    END
FROM gv$asm_diskgroup

UNION ALL

SELECT
    'DISKGROUPS NOT CONNECTED',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'CHECK'
    END
FROM gv$asm_diskgroup
WHERE state <> 'CONNECTED'

UNION ALL

SELECT
    'DISKS NOT ONLINE',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'CHECK'
    END
FROM gv$asm_disk
WHERE mode_status <> 'ONLINE'
   OR state <> 'NORMAL'

UNION ALL

SELECT
    'ACTIVE ASM OPERATIONS',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'INFO'
    END
FROM gv$asm_operation
WHERE state <> 'WAIT';


PROMPT
PROMPT ============================================================================
PROMPT 27. ASM DBA QUICK CHECK
PROMPT ============================================================================

PROMPT
PROMPT [ ] All expected ASM instances are ONLINE
PROMPT [ ] All expected diskgroups are CONNECTED
PROMPT [ ] Diskgroup usable space is sufficient
PROMPT [ ] No unexpected disks are OFFLINE
PROMPT [ ] No abnormal ASM disk states
PROMPT [ ] Failgroups are distributed as designed
PROMPT [ ] No unexpected ASM rebalance operations
PROMPT [ ] ASM clients are connected
PROMPT [ ] ASM disk paths are present
PROMPT [ ] Storage/network/multipath health is checked when disks are abnormal
PROMPT [ ] Diskgroup capacity is monitored separately from disk health
PROMPT
PROMPT ============================================================================
PROMPT IMPORTANT
PROMPT ============================================================================
PROMPT This script is READ-ONLY.
PROMPT
PROMPT Low free-space thresholds of 20% WARNING and 10% CRITICAL are
PROMPT investigation triggers for this toolkit, not Oracle failure thresholds.
PROMPT
PROMPT ASM disk state should always be correlated with storage, multipath,
PROMPT CellCLI/Exadata and operating-system evidence before taking action.
PROMPT
PROMPT Do NOT offline, drop, force-drop or replace an ASM disk based only
PROMPT on this report.
PROMPT ============================================================================


-- ============================================================
-- Oracle DBA Toolkit
-- File   : asm_client_usage.sql
-- Purpose: Monitor ASM client/database usage
-- Scope  : ASM clients, database instances, diskgroup usage,
--          client connections, ASM activity and dependencies
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
COLUMN INSTANCE_STATUS        FORMAT A15
COLUMN VERSION                FORMAT A20
COLUMN STARTUP_TIME           FORMAT A20
COLUMN DB_NAME                FORMAT A20
COLUMN DB_UNIQUE_NAME         FORMAT A25
COLUMN OPEN_MODE              FORMAT A20
COLUMN DATABASE_ROLE          FORMAT A20

-- ASM Client
COLUMN CLIENT_NAME            FORMAT A30
COLUMN CLIENT_VERSION         FORMAT A20
COLUMN SOFTWARE_VERSION       FORMAT A20
COLUMN STATUS                 FORMAT A15
COLUMN INSTANCE_ID            FORMAT 9999
COLUMN GROUP_NUMBER            FORMAT 9999
COLUMN DISKGROUP_NAME         FORMAT A25
COLUMN CLIENT_COUNT           FORMAT 9999

-- Diskgroup
COLUMN TYPE                   FORMAT A12
COLUMN STATE                  FORMAT A15
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

-- Sessions
COLUMN SID                    FORMAT 999999
COLUMN SERIAL                 FORMAT 999999
COLUMN USERNAME               FORMAT A25
COLUMN PROGRAM                FORMAT A45
COLUMN MACHINE                FORMAT A40
COLUMN SERVICE_NAME           FORMAT A30
COLUMN SQL_ID                 FORMAT A15
COLUMN EVENT                  FORMAT A50
COLUMN WAIT_CLASS             FORMAT A20
COLUMN SECONDS_IN_WAIT        FORMAT 999999

-- Statistics
COLUMN STAT_NAME              FORMAT A60
COLUMN VALUE                  FORMAT 999,999,999,999,999
COLUMN TOTAL_WAITS            FORMAT 999,999,999
COLUMN TIME_WAITED_SEC        FORMAT 999,999,999.99

-- Health
COLUMN HEALTH_STATUS          FORMAT A50

PROMPT
PROMPT ============================================================
PROMPT ASM CLIENT USAGE MONITORING
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
    i.status AS instance_status,
    i.version,
    TO_CHAR(i.startup_time, 'YYYY-MM-DD HH24:MI:SS')
        AS startup_time,
    d.name AS db_name,
    d.db_unique_name,
    d.open_mode,
    d.database_role
FROM v$instance i
CROSS JOIN v$database d;

-- ============================================================
-- 2. ASM CLIENT INFORMATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. ASM CLIENT INFORMATION
PROMPT ============================================================

SELECT
    client_name,
    status,
    software_version
FROM v$asm_client
ORDER BY client_name;

-- ============================================================
-- 3. ASM CLIENT COUNT
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. ASM CLIENT COUNT
PROMPT ============================================================

SELECT
    COUNT(*) AS client_count
FROM v$asm_client;

-- ============================================================
-- 4. ASM CLIENTS BY NAME
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. ASM CLIENTS BY NAME
PROMPT ============================================================

SELECT
    client_name,
    COUNT(*) AS client_count
FROM v$asm_client
GROUP BY client_name
ORDER BY client_count DESC, client_name;

-- ============================================================
-- 5. ASM CLIENT STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. ASM CLIENT STATUS
PROMPT ============================================================

SELECT
    status,
    COUNT(*) AS client_count
FROM v$asm_client
GROUP BY status
ORDER BY client_count DESC;

-- ============================================================
-- 6. ASM DISKGROUP STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. ASM DISKGROUP STATUS
PROMPT ============================================================

SELECT
    name AS diskgroup_name,
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
ORDER BY used_pct DESC NULLS LAST;

-- ============================================================
-- 7. ASM CLIENTS WITH DISKGROUP USAGE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. ASM CLIENTS AND DISKGROUPS
PROMPT ============================================================

SELECT
    c.client_name,
    c.status,
    c.software_version,
    d.name AS diskgroup_name,
    d.state,
    ROUND(d.total_mb / 1024, 2) AS total_gb,
    ROUND(d.free_mb / 1024, 2) AS free_gb,
    ROUND(d.usable_file_mb / 1024, 2) AS usable_gb
FROM v$asm_client c
CROSS JOIN v$asm_diskgroup d
ORDER BY
    c.client_name,
    d.name;

-- ============================================================
-- 8. ASM CLIENTS CONNECTED TO ASM
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. ASM CLIENT CONNECTIONS
PROMPT ============================================================

SELECT
    client_name,
    status,
    software_version
FROM v$asm_client
WHERE status IS NOT NULL
ORDER BY client_name;

-- ============================================================
-- 9. DATABASE SESSIONS USING ASM
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. DATABASE SESSIONS USING ASM-RELATED I/O
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.machine,
    s.program,
    s.service_name
FROM v$session s
WHERE s.state = 'WAITING'
  AND (
        LOWER(s.event) LIKE '%asm%'
        OR LOWER(s.event) LIKE '%disk%'
        OR LOWER(s.event) LIKE '%db file%'
        OR LOWER(s.event) LIKE '%direct path%'
      )
ORDER BY
    s.seconds_in_wait DESC;

-- ============================================================
-- 10. ASM-RELATED SYSTEM WAIT EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. ASM-RELATED SYSTEM WAITS
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
   OR LOWER(event) LIKE '%disk%'
   OR LOWER(event) LIKE '%db file%'
   OR LOWER(event) LIKE '%direct path%'
ORDER BY time_waited DESC;

-- ============================================================
-- 11. ASM DISK SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. ASM DISK SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS disk_count,
    SUM(
        CASE
            WHEN state = 'NORMAL' THEN 1
            ELSE 0
        END
    ) AS normal_disks,
    SUM(
        CASE
            WHEN state <> 'NORMAL' THEN 1
            ELSE 0
        END
    ) AS abnormal_disks,
    SUM(
        CASE
            WHEN mode_status <> 'ONLINE' THEN 1
            ELSE 0
        END
    ) AS non_online_disks
FROM v$asm_disk;

-- ============================================================
-- 12. ASM DISK ERROR SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. ASM DISK ERROR SUMMARY
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    COUNT(*) AS disk_count,
    SUM(NVL(d.read_errs, 0)) AS read_errors,
    SUM(NVL(d.write_errs, 0)) AS write_errors
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
GROUP BY dg.name
ORDER BY
    read_errors + write_errors DESC;

-- ============================================================
-- 13. ASM DISKS NOT NORMAL
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. ASM DISKS NOT IN NORMAL STATE
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
-- 14. ASM OPERATIONS AFFECTING CLIENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. CURRENT ASM OPERATIONS
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
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = o.group_number
ORDER BY
    dg.name,
    o.operation;

-- ============================================================
-- 15. ASM CLIENTS AND ACTIVE OPERATIONS SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. ASM CLIENT / OPERATION SUMMARY
PROMPT ============================================================

SELECT
    (SELECT COUNT(*)
       FROM v$asm_client) AS asm_clients,

    (SELECT COUNT(*)
       FROM v$asm_operation) AS asm_operations,

    (SELECT COUNT(*)
       FROM v$asm_disk
      WHERE state <> 'NORMAL') AS abnormal_disks,

    (SELECT COUNT(*)
       FROM v$asm_disk
      WHERE NVL(read_errs, 0) > 0
         OR NVL(write_errs, 0) > 0) AS disks_with_errors
FROM dual;

-- ============================================================
-- 16. ASM CLIENT HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. ASM CLIENT HEALTH CHECK
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

        WHEN NOT EXISTS (
            SELECT 1
            FROM v$asm_client
        )
        THEN 'INFO - NO ASM CLIENTS VISIBLE'

        ELSE 'HEALTHY - ASM CLIENT ENVIRONMENT LOOKS NORMAL'
    END AS health_status
FROM dual;

-- ============================================================
-- 17. QUICK ASM CLIENT CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. QUICK ASM CLIENT CHECK
PROMPT ============================================================

SELECT
    (SELECT COUNT(*)
       FROM v$asm_client) AS asm_clients,

    (SELECT COUNT(*)
       FROM v$asm_diskgroup) AS diskgroups,

    (SELECT COUNT(*)
       FROM v$asm_disk) AS asm_disks,

    (SELECT COUNT(*)
       FROM v$asm_operation) AS active_operations,

    (SELECT COUNT(*)
       FROM v$asm_disk
      WHERE state <> 'NORMAL') AS abnormal_disks,

    (SELECT COUNT(*)
       FROM v$asm_disk
      WHERE NVL(read_errs, 0) > 0
         OR NVL(write_errs, 0) > 0) AS disks_with_errors
FROM dual;

-- ============================================================
-- 18. DBA QUICK CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. DBA QUICK CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT [ ] Check V$ASM_CLIENT
PROMPT [ ] Identify connected database clients
PROMPT [ ] Review ASM client software versions
PROMPT [ ] Check ASM diskgroup state
PROMPT [ ] Check usable_file_mb
PROMPT [ ] Review ASM disk state
PROMPT [ ] Check disk read/write errors
PROMPT [ ] Check active ASM operations
PROMPT [ ] Review ASM-related wait events
PROMPT [ ] Correlate ASM operations with workload activity
PROMPT [ ] For RAC, check all ASM/database instances
PROMPT [ ] For Exadata, correlate with CellCLI/storage-cell data
PROMPT [ ] Review ASM alert.log for abnormal events
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT NOTES
PROMPT ============================================================
PROMPT
PROMPT This script is READ-ONLY.
PROMPT
PROMPT V$ASM_CLIENT shows clients visible to the ASM instance.
PROMPT It does not represent database storage consumption by
PROMPT individual clients.
PROMPT
PROMPT The diskgroup information is shared across ASM clients;
PROMPT the CROSS JOIN in section 7 is intentionally informational
PROMPT and should not be interpreted as per-client disk usage.
PROMPT
PROMPT ASM client visibility depends on where the script is run.
PROMPT In RAC environments, review all relevant ASM instances.
PROMPT
PROMPT ASM disk errors, abnormal states and operations should be
PROMPT correlated with ASM alert.log and the underlying storage
PROMPT path before corrective action.
PROMPT
PROMPT For Exadata, correlate database-side information with
PROMPT CellCLI, storage-cell alerts and OS/multipath diagnostics.
PROMPT
PROMPT ============================================================
PROMPT END OF ASM CLIENT USAGE MONITORING
PROMPT ============================================================


-- ============================================================
-- Oracle DBA Toolkit
-- File   : asm_diskgroup_attributes.sql
-- Purpose: Monitor ASM diskgroup attributes and configuration
-- Scope  : Redundancy, compatibility, sector size, allocation
--          unit, preferred read, storage and ASM attributes
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
COLUMN DB_UNIQUE_NAME         FORMAT A25
COLUMN OPEN_MODE              FORMAT A20
COLUMN DATABASE_ROLE          FORMAT A20

-- Diskgroup
COLUMN GROUP_NUMBER           FORMAT 9999
COLUMN DISKGROUP_NAME         FORMAT A25
COLUMN NAME                   FORMAT A40
COLUMN TYPE                   FORMAT A15
COLUMN STATE                  FORMAT A15
COLUMN TOTAL_GB               FORMAT 999,999,999.99
COLUMN FREE_GB                FORMAT 999,999,999.99
COLUMN USABLE_GB              FORMAT 999,999,999.99
COLUMN REQUIRED_MIRROR_GB     FORMAT 999,999,999.99
COLUMN USED_PCT               FORMAT 990.99
COLUMN OFFLINE_DISKS          FORMAT 9999

-- Attributes
COLUMN ATTRIBUTE_NAME         FORMAT A45
COLUMN ATTRIBUTE_VALUE        FORMAT A80
COLUMN READ_ONLY              FORMAT A10
COLUMN VALUE                  FORMAT A80

-- Compatibility
COLUMN COMPATIBILITY          FORMAT A25
COLUMN DATABASE_COMPATIBILITY FORMAT A25

-- ASM Configuration
COLUMN ALLOCATION_UNIT_MB     FORMAT 999,999,999.99
COLUMN SECTOR_SIZE            FORMAT 999999
COLUMN LOGICAL_SECTOR_SIZE    FORMAT 999999
COLUMN BLOCK_SIZE             FORMAT 999999
COLUMN REQUIRED_MIRROR_FREE_MB FORMAT 999,999,999
COLUMN USABLE_FILE_MB         FORMAT 999,999,999

-- Health
COLUMN HEALTH_STATUS          FORMAT A60

PROMPT
PROMPT ============================================================
PROMPT ASM DISKGROUP ATTRIBUTES MONITORING
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
    TO_CHAR(i.startup_time, 'YYYY-MM-DD HH24:MI:SS')
        AS startup_time,
    d.db_unique_name,
    d.open_mode,
    d.database_role
FROM v$instance i
CROSS JOIN v$database d;

-- ============================================================
-- 2. ASM DISKGROUP OVERVIEW
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. ASM DISKGROUP OVERVIEW
PROMPT ============================================================

SELECT
    group_number,
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
ORDER BY group_number;

-- ============================================================
-- 3. ALL ASM DISKGROUP ATTRIBUTES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. ALL ASM DISKGROUP ATTRIBUTES
PROMPT ============================================================

SELECT
    a.group_number,
    dg.name AS diskgroup_name,
    a.name AS attribute_name,
    a.value AS attribute_value,
    a.read_only
FROM v$asm_attribute a
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = a.group_number
ORDER BY
    a.group_number,
    a.name;

-- ============================================================
-- 4. IMPORTANT ASM DISKGROUP ATTRIBUTES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. IMPORTANT ASM DISKGROUP ATTRIBUTES
PROMPT ============================================================

SELECT
    a.group_number,
    dg.name AS diskgroup_name,
    a.name AS attribute_name,
    a.value AS attribute_value
FROM v$asm_attribute a
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = a.group_number
WHERE LOWER(a.name) IN (
          'compatible.asm',
          'compatible.rdbms',
          'compatible.advm',
          'sector_size',
          'logical_sector_size',
          'au_size',
          'cell.smart_scan_capable',
          'disk_repair_time',
          'failgroup_repair_time',
          'thin_provisioned',
          'preferred_read',
          'content.type',
          'content.check',
          'content.hard',
          'idp.boundary',
          'idp.type',
          'storage.type',
          'access_control.enabled'
      )
ORDER BY
    a.group_number,
    a.name;

-- ============================================================
-- 5. COMPATIBILITY ATTRIBUTES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. ASM COMPATIBILITY ATTRIBUTES
PROMPT ============================================================

SELECT
    a.group_number,
    dg.name AS diskgroup_name,
    a.name AS attribute_name,
    a.value AS attribute_value
FROM v$asm_attribute a
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = a.group_number
WHERE LOWER(a.name) LIKE 'compatible.%'
ORDER BY
    a.group_number,
    a.name;

-- ============================================================
-- 6. SECTOR SIZE ATTRIBUTES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. SECTOR SIZE ATTRIBUTES
PROMPT ============================================================

SELECT
    a.group_number,
    dg.name AS diskgroup_name,
    a.name AS attribute_name,
    a.value AS attribute_value
FROM v$asm_attribute a
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = a.group_number
WHERE LOWER(a.name) LIKE '%sector%'
ORDER BY
    a.group_number,
    a.name;

-- ============================================================
-- 7. ALLOCATION UNIT ATTRIBUTE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. ALLOCATION UNIT ATTRIBUTE
PROMPT ============================================================

SELECT
    a.group_number,
    dg.name AS diskgroup_name,
    a.name AS attribute_name,
    a.value AS attribute_value
FROM v$asm_attribute a
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = a.group_number
WHERE LOWER(a.name) = 'au_size'
ORDER BY
    a.group_number;

-- ============================================================
-- 8. PREFERRED READ ATTRIBUTE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. PREFERRED READ
PROMPT ============================================================

SELECT
    a.group_number,
    dg.name AS diskgroup_name,
    a.name AS attribute_name,
    a.value AS attribute_value
FROM v$asm_attribute a
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = a.group_number
WHERE LOWER(a.name) LIKE '%preferred_read%'
ORDER BY
    a.group_number,
    a.name;

-- ============================================================
-- 9. REPAIR TIME ATTRIBUTES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. ASM REPAIR TIME ATTRIBUTES
PROMPT ============================================================

SELECT
    a.group_number,
    dg.name AS diskgroup_name,
    a.name AS attribute_name,
    a.value AS attribute_value
FROM v$asm_attribute a
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = a.group_number
WHERE LOWER(a.name) LIKE '%repair_time%'
ORDER BY
    a.group_number,
    a.name;

-- ============================================================
-- 10. STORAGE / PROVISIONING ATTRIBUTES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. STORAGE / PROVISIONING ATTRIBUTES
PROMPT ============================================================

SELECT
    a.group_number,
    dg.name AS diskgroup_name,
    a.name AS attribute_name,
    a.value AS attribute_value
FROM v$asm_attribute a
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = a.group_number
WHERE LOWER(a.name) LIKE '%thin%'
   OR LOWER(a.name) LIKE '%storage%'
   OR LOWER(a.name) LIKE '%provision%'
ORDER BY
    a.group_number,
    a.name;

-- ============================================================
-- 11. ASM CONTENT ATTRIBUTES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. ASM CONTENT ATTRIBUTES
PROMPT ============================================================

SELECT
    a.group_number,
    dg.name AS diskgroup_name,
    a.name AS attribute_name,
    a.value AS attribute_value
FROM v$asm_attribute a
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = a.group_number
WHERE LOWER(a.name) LIKE 'content.%'
ORDER BY
    a.group_number,
    a.name;

-- ============================================================
-- 12. ASM DISKGROUP REPAIR / RESYNC SETTINGS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. REPAIR / RESYNC SETTINGS
PROMPT ============================================================

SELECT
    a.group_number,
    dg.name AS diskgroup_name,
    a.name AS attribute_name,
    a.value AS attribute_value
FROM v$asm_attribute a
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = a.group_number
WHERE LOWER(a.name) LIKE '%repair%'
   OR LOWER(a.name) LIKE '%resync%'
ORDER BY
    a.group_number,
    a.name;

-- ============================================================
-- 13. ASM DISK COUNT AND FAILGROUP SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. ASM DISK / FAILGROUP SUMMARY
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    COUNT(DISTINCT d.disk_number) AS disk_count,
    COUNT(DISTINCT d.failgroup) AS failgroup_count,
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
-- 14. ASM DISK SECTOR / HEADER INFORMATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. ASM DISK INFORMATION
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
    d.state,
    d.total_mb,
    d.free_mb
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
ORDER BY
    dg.name,
    d.disk_number;

-- ============================================================
-- 15. DISKGROUPS WITH COMPATIBILITY ATTRIBUTES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. DISKGROUP COMPATIBILITY SUMMARY
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    MAX(
        CASE
            WHEN LOWER(a.name) = 'compatible.asm'
            THEN a.value
        END
    ) AS compatible_asm,
    MAX(
        CASE
            WHEN LOWER(a.name) = 'compatible.rdbms'
            THEN a.value
        END
    ) AS compatible_rdbms,
    MAX(
        CASE
            WHEN LOWER(a.name) = 'compatible.advm'
            THEN a.value
        END
    ) AS compatible_advm
FROM v$asm_diskgroup dg
LEFT JOIN v$asm_attribute a
    ON a.group_number = dg.group_number
GROUP BY dg.name
ORDER BY dg.name;

-- ============================================================
-- 16. DISKGROUP ATTRIBUTE COUNTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. ATTRIBUTE COUNT BY DISKGROUP
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    COUNT(*) AS attribute_count
FROM v$asm_attribute a
JOIN v$asm_diskgroup dg
    ON dg.group_number = a.group_number
GROUP BY dg.name
ORDER BY
    dg.name;

-- ============================================================
-- 17. READ-ONLY ATTRIBUTES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. READ-ONLY ASM ATTRIBUTES
PROMPT ============================================================

SELECT
    a.group_number,
    dg.name AS diskgroup_name,
    a.name AS attribute_name,
    a.value AS attribute_value,
    a.read_only
FROM v$asm_attribute a
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = a.group_number
WHERE UPPER(a.read_only) = 'Y'
ORDER BY
    dg.name,
    a.name;

-- ============================================================
-- 18. ASM ATTRIBUTE HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. ASM ATTRIBUTE HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN EXISTS (
            SELECT 1
            FROM v$asm_disk
            WHERE state <> 'NORMAL'
               OR mode_status <> 'ONLINE'
        )
        THEN 'WARNING - ASM DISK STATE REQUIRES REVIEW'

        WHEN EXISTS (
            SELECT 1
            FROM v$asm_disk
            WHERE NVL(read_errs, 0) > 0
               OR NVL(write_errs, 0) > 0
        )
        THEN 'WARNING - ASM DISK I/O ERRORS DETECTED'

        WHEN NOT EXISTS (
            SELECT 1
            FROM v$asm_attribute
        )
        THEN 'INFO - NO ASM ATTRIBUTES VISIBLE'

        ELSE 'HEALTHY - ASM ATTRIBUTE VIEW AVAILABLE'
    END AS health_status
FROM dual;

-- ============================================================
-- 19. QUICK ASM ATTRIBUTE CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 19. QUICK ASM ATTRIBUTE CHECK
PROMPT ============================================================

SELECT
    (SELECT COUNT(*)
       FROM v$asm_diskgroup) AS diskgroup_count,

    (SELECT COUNT(*)
       FROM v$asm_attribute) AS attribute_count,

    (SELECT COUNT(*)
       FROM v$asm_disk) AS disk_count,

    (SELECT COUNT(*)
       FROM v$asm_disk
      WHERE state <> 'NORMAL') AS abnormal_disks,

    (SELECT COUNT(*)
       FROM v$asm_disk
      WHERE NVL(read_errs, 0) > 0
         OR NVL(write_errs, 0) > 0) AS disks_with_errors
FROM dual;

-- ============================================================
-- 20. DBA QUICK CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 20. DBA QUICK CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT [ ] Review all V$ASM_ATTRIBUTE values
PROMPT [ ] Check COMPATIBLE.ASM
PROMPT [ ] Check COMPATIBLE.RDBMS
PROMPT [ ] Review AU_SIZE
PROMPT [ ] Review sector size attributes
PROMPT [ ] Check PREFERRED_READ where applicable
PROMPT [ ] Review repair/resync attributes
PROMPT [ ] Check storage/provisioning attributes
PROMPT [ ] Review diskgroup redundancy/type
PROMPT [ ] Check failgroup distribution
PROMPT [ ] Check disk state and mode
PROMPT [ ] Review disk I/O errors
PROMPT [ ] Compare RAC instances where applicable
PROMPT [ ] For Exadata, correlate with storage configuration
PROMPT [ ] Do not change attributes without change control
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT NOTES
PROMPT ============================================================
PROMPT
PROMPT This script is READ-ONLY.
PROMPT
PROMPT V$ASM_ATTRIBUTE exposes ASM diskgroup attributes. The exact
PROMPT attributes available depend on the Oracle ASM release,
PROMPT diskgroup type and enabled features.
PROMPT
PROMPT Not every attribute applies to every diskgroup.
PROMPT
PROMPT Compatibility attributes are important because raising
PROMPT compatibility can enable newer ASM/database features and
PROMPT may have operational implications.
PROMPT
PROMPT Do not modify ASM attributes based only on this report.
PROMPT Use Oracle documentation and approved change procedures.
PROMPT
PROMPT ASM attribute visibility can differ between an ASM instance
PROMPT and a database instance. Run from the appropriate ASM
PROMPT environment when full ASM-level visibility is required.
PROMPT
PROMPT For RAC, review all relevant ASM instances.
PROMPT
PROMPT ============================================================
PROMPT END OF ASM DISKGROUP ATTRIBUTES MONITORING
PROMPT ============================================================
 
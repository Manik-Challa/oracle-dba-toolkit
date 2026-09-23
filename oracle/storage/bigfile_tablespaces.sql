-- ============================================================
-- Oracle DBA Toolkit
-- Script   : bigfile_tablespaces.sql
-- Purpose  : Monitor Oracle BIGFILE tablespaces
-- Author   : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN tablespace_name FORMAT A30
COLUMN status          FORMAT A10
COLUMN contents        FORMAT A15
COLUMN extent_management FORMAT A15
COLUMN allocation_type FORMAT A15
COLUMN file_name       FORMAT A70
COLUMN autoextensible  FORMAT A14

COLUMN current_gb      FORMAT 999,999,990.00
COLUMN max_gb          FORMAT 999,999,990.00
COLUMN used_gb         FORMAT 999,999,990.00
COLUMN free_gb         FORMAT 999,999,990.00
COLUMN headroom_gb     FORMAT 999,999,990.00
COLUMN used_pct        FORMAT 990.00
COLUMN free_pct        FORMAT 990.00
COLUMN max_used_pct    FORMAT 990.00

PROMPT
PROMPT ============================================================
PROMPT BIGFILE TABLESPACE MONITORING
PROMPT ============================================================


-- ============================================================
-- 1. DATABASE / INSTANCE INFORMATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    d.name AS database_name,
    i.instance_name,
    i.host_name,
    d.open_mode,
    d.database_role
FROM v$database d
CROSS JOIN v$instance i;


-- ============================================================
-- 2. BIGFILE TABLESPACE INVENTORY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. BIGFILE TABLESPACE INVENTORY
PROMPT ============================================================

SELECT
    tablespace_name,
    status,
    contents,
    bigfile,
    extent_management,
    allocation_type,
    segment_space_management
FROM dba_tablespaces
WHERE bigfile = 'YES'
ORDER BY tablespace_name;


-- ============================================================
-- 3. BIGFILE TABLESPACE DATAFILE DETAILS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. BIGFILE DATAFILE DETAILS
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(df.maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    df.autoextensible,
    df.status
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
WHERE ts.bigfile = 'YES'
ORDER BY df.tablespace_name;


-- ============================================================
-- 4. BIGFILE CURRENT USAGE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. BIGFILE CURRENT USAGE
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(SUM(df.bytes) / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(
        (SUM(df.bytes) - NVL(fs.free_bytes, 0))
        / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(
        NVL(fs.free_bytes, 0)
        / 1024 / 1024 / 1024,
        2
    ) AS free_gb,
    ROUND(
        (SUM(df.bytes) - NVL(fs.free_bytes, 0))
        / SUM(df.bytes) * 100,
        2
    ) AS used_pct
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
LEFT JOIN (
    SELECT
        tablespace_name,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
    ON df.tablespace_name = fs.tablespace_name
WHERE ts.bigfile = 'YES'
GROUP BY
    df.tablespace_name,
    fs.free_bytes
ORDER BY used_pct DESC;


-- ============================================================
-- 5. BIGFILE MAXIMUM CAPACITY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. BIGFILE MAXIMUM CAPACITY
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(df.maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    df.autoextensible
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
WHERE ts.bigfile = 'YES'
ORDER BY headroom_gb;


-- ============================================================
-- 6. BIGFILE TABLESPACES WITH LIMITED HEADROOM
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. BIGFILE TABLESPACES WITH LIMITED HEADROOM
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(df.maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    df.autoextensible
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
WHERE ts.bigfile = 'YES'
  AND df.autoextensible = 'YES'
  AND (df.maxbytes - df.bytes)
      / 1024 / 1024 / 1024 < 50
ORDER BY headroom_gb;


-- ============================================================
-- 7. BIGFILE TABLESPACES ABOVE 80% USED
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. BIGFILE TABLESPACES ABOVE 80% USED
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(
        (df.bytes - NVL(fs.free_bytes, 0))
        / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(
        (df.bytes - NVL(fs.free_bytes, 0))
        / df.bytes * 100,
        2
    ) AS used_pct,
    ROUND(
        (df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON df.file_id = fs.file_id
WHERE ts.bigfile = 'YES'
  AND (df.bytes - NVL(fs.free_bytes, 0))
      / df.bytes * 100 >= 80
ORDER BY used_pct DESC;


-- ============================================================
-- 8. BIGFILE TABLESPACES ABOVE 90% USED
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. BIGFILE TABLESPACES ABOVE 90% USED
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(
        (df.bytes - NVL(fs.free_bytes, 0))
        / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(
        (df.bytes - NVL(fs.free_bytes, 0))
        / df.bytes * 100,
        2
    ) AS used_pct,
    ROUND(
        (df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON df.file_id = fs.file_id
WHERE ts.bigfile = 'YES'
  AND (df.bytes - NVL(fs.free_bytes, 0))
      / df.bytes * 100 >= 90
ORDER BY used_pct DESC;


-- ============================================================
-- 9. BIGFILE TABLESPACES NEAR MAXIMUM CAPACITY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. BIGFILE TABLESPACES NEAR MAXIMUM CAPACITY
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(df.maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        df.bytes / df.maxbytes * 100,
        2
    ) AS max_used_pct,
    ROUND(
        (df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
WHERE ts.bigfile = 'YES'
  AND df.maxbytes > 0
  AND df.bytes / df.maxbytes * 100 >= 80
ORDER BY max_used_pct DESC;


-- ============================================================
-- 10. BIGFILE AUTOEXTEND STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. BIGFILE AUTOEXTEND STATUS
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_name,
    df.autoextensible,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(df.maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    ROUND(
        df.increment_by * tsb.block_size
        / 1024 / 1024,
        2
    ) AS autoextend_increment_mb
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
JOIN dba_tablespaces tsb
    ON df.tablespace_name = tsb.tablespace_name
WHERE ts.bigfile = 'YES'
ORDER BY df.tablespace_name;


-- ============================================================
-- 11. BIGFILE TABLESPACES WITHOUT AUTOEXTEND
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. BIGFILE TABLESPACES WITHOUT AUTOEXTEND
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(df.maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    df.autoextensible
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
WHERE ts.bigfile = 'YES'
  AND df.autoextensible = 'NO'
ORDER BY df.tablespace_name;


-- ============================================================
-- 12. BIGFILE TABLESPACE FREE EXTENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. BIGFILE FREE EXTENT SUMMARY
PROMPT ============================================================

SELECT
    fs.tablespace_name,
    COUNT(*) AS free_extents,
    ROUND(SUM(fs.bytes) / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(MAX(fs.bytes) / 1024 / 1024, 2) AS largest_free_mb,
    ROUND(AVG(fs.bytes) / 1024 / 1024, 2) AS average_free_mb
FROM dba_free_space fs
JOIN dba_tablespaces ts
    ON fs.tablespace_name = ts.tablespace_name
WHERE ts.bigfile = 'YES'
GROUP BY fs.tablespace_name
ORDER BY free_gb;


-- ============================================================
-- 13. BIGFILE TABLESPACE BLOCK SIZE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. BIGFILE TABLESPACE BLOCK SIZE
PROMPT ============================================================

SELECT
    tablespace_name,
    block_size,
    extent_management,
    allocation_type,
    segment_space_management,
    bigfile
FROM dba_tablespaces
WHERE bigfile = 'YES'
ORDER BY tablespace_name;


-- ============================================================
-- 14. BIGFILE TABLESPACE SEGMENT USAGE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. TOP SEGMENTS IN BIGFILE TABLESPACES
PROMPT ============================================================

SELECT
    s.owner,
    s.segment_name,
    s.segment_type,
    s.tablespace_name,
    ROUND(s.bytes / 1024 / 1024 / 1024, 2) AS segment_gb,
    s.extents,
    s.blocks
FROM dba_segments s
JOIN dba_tablespaces ts
    ON s.tablespace_name = ts.tablespace_name
WHERE ts.bigfile = 'YES'
ORDER BY s.bytes DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================
-- 15. BIGFILE TABLESPACE SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. BIGFILE TABLESPACE SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS bigfile_tablespaces,
    SUM(
        CASE
            WHEN df.autoextensible = 'YES' THEN 1
            ELSE 0
        END
    ) AS autoextend_enabled,
    SUM(
        CASE
            WHEN df.autoextensible = 'NO' THEN 1
            ELSE 0
        END
    ) AS autoextend_disabled
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
WHERE ts.bigfile = 'YES';


-- ============================================================
-- 16. BIGFILE HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. BIGFILE TABLESPACE HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN MAX(
            CASE
                WHEN df.bytes / NULLIF(df.maxbytes, 0) * 100 >= 95
                    THEN 1
                ELSE 0
            END
        ) = 1
        THEN 'CRITICAL - BIGFILE NEAR MAXIMUM CAPACITY'

        WHEN MAX(
            CASE
                WHEN (
                    df.bytes - NVL(fs.free_bytes, 0)
                ) / df.bytes * 100 >= 90
                    THEN 1
                ELSE 0
            END
        ) = 1
        THEN 'WARNING - BIGFILE ABOVE 90% USED'

        ELSE 'HEALTHY - NO IMMEDIATE BIGFILE CAPACITY ALERT'
    END AS health_status
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON df.file_id = fs.file_id
WHERE ts.bigfile = 'YES';


-- ============================================================
-- 17. QUICK BIGFILE CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. QUICK BIGFILE CHECK
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(
        (df.bytes - NVL(fs.free_bytes, 0))
        / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(
        NVL(fs.free_bytes, 0)
        / 1024 / 1024 / 1024,
        2
    ) AS free_gb,
    ROUND(
        (df.bytes - NVL(fs.free_bytes, 0))
        / df.bytes * 100,
        2
    ) AS used_pct,
    ROUND(df.maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    df.autoextensible,
    CASE
        WHEN (
            df.bytes - NVL(fs.free_bytes, 0)
        ) / df.bytes * 100 >= 90
            THEN 'CRITICAL'
        WHEN (
            df.bytes - NVL(fs.free_bytes, 0)
        ) / df.bytes * 100 >= 80
            THEN 'WARNING'
        ELSE 'HEALTHY'
    END AS status
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON df.file_id = fs.file_id
WHERE ts.bigfile = 'YES'
ORDER BY used_pct DESC;


-- ============================================================
-- DBA CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT DBA CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT 1. Identify all BIGFILE tablespaces.
PROMPT 2. Check current size versus MAXBYTES.
PROMPT 3. Review AUTOEXTEND status and increment.
PROMPT 4. Check tablespaces above 80% and 90% used.
PROMPT 5. Check remaining maximum-capacity headroom.
PROMPT 6. Verify underlying ASM/filesystem capacity.
PROMPT 7. Review tablespace growth trends before resizing.
PROMPT 8. Identify the largest segments driving growth.
PROMPT 9. Remember BIGFILE tablespaces use one datafile.
PROMPT 10. Do not assume AUTOEXTEND means unlimited growth.
PROMPT 11. Validate storage capacity before increasing MAXBYTES.
PROMPT
PROMPT ============================================================
PROMPT END OF BIGFILE TABLESPACE CHECK
PROMPT ============================================================


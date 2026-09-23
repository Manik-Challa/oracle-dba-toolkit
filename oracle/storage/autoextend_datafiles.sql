-- ============================================================
-- Oracle DBA Toolkit
-- Script   : autoextend_datafiles.sql
-- Purpose  : Monitor datafile AUTOEXTEND configuration,
--            growth increments and capacity headroom
-- Author   : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN tablespace_name FORMAT A30
COLUMN file_name       FORMAT A75
COLUMN status          FORMAT A10
COLUMN autoextensible  FORMAT A14

COLUMN current_gb      FORMAT 999,999,990.00
COLUMN max_gb          FORMAT 999,999,990.00
COLUMN headroom_gb     FORMAT 999,999,990.00
COLUMN used_gb         FORMAT 999,999,990.00
COLUMN free_gb         FORMAT 999,999,990.00
COLUMN used_pct        FORMAT 990.00
COLUMN max_used_pct    FORMAT 990.00
COLUMN increment_mb    FORMAT 999,999,990.00
COLUMN increment_pct   FORMAT 990.00

PROMPT
PROMPT ============================================================
PROMPT AUTOEXTEND DATAFILE MONITORING
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
-- 2. ALL DATAFILE AUTOEXTEND SETTINGS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. DATAFILE AUTOEXTEND SETTINGS
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    df.autoextensible,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(df.maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    df.increment_by,
    ts.block_size,
    ROUND(
        df.increment_by * ts.block_size
        / 1024 / 1024,
        2
    ) AS increment_mb,
    df.status
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
ORDER BY df.tablespace_name, df.file_id;


-- ============================================================
-- 3. AUTOEXTEND ENABLED DATAFILES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. AUTOEXTEND ENABLED DATAFILES
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(df.maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    ROUND(
        df.increment_by * ts.block_size
        / 1024 / 1024,
        2
    ) AS increment_mb,
    df.autoextensible
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
WHERE df.autoextensible = 'YES'
ORDER BY headroom_gb;


-- ============================================================
-- 4. DATAFILES WITH AUTOEXTEND DISABLED
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. AUTOEXTEND DISABLED DATAFILES
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
WHERE df.autoextensible = 'NO'
ORDER BY df.tablespace_name, df.file_id;


-- ============================================================
-- 5. DATAFILES WITH LIMITED AUTOEXTEND HEADROOM
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. DATAFILES WITH LESS THAN 10 GB HEADROOM
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(df.maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    ROUND(
        df.increment_by * ts.block_size
        / 1024 / 1024,
        2
    ) AS increment_mb
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
WHERE df.autoextensible = 'YES'
  AND (df.maxbytes - df.bytes)
      / 1024 / 1024 / 1024 < 10
ORDER BY headroom_gb;


-- ============================================================
-- 6. DATAFILES ABOVE 80% OF MAXIMUM SIZE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. DATAFILES ABOVE 80% OF MAXIMUM CAPACITY
PROMPT ============================================================

SELECT
    tablespace_name,
    file_id,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        bytes / NULLIF(maxbytes, 0) * 100,
        2
    ) AS max_used_pct,
    ROUND(
        (maxbytes - bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    autoextensible
FROM dba_data_files
WHERE maxbytes > 0
  AND bytes / maxbytes * 100 >= 80
ORDER BY max_used_pct DESC;


-- ============================================================
-- 7. DATAFILES ABOVE 90% OF MAXIMUM SIZE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. DATAFILES ABOVE 90% OF MAXIMUM CAPACITY
PROMPT ============================================================

SELECT
    tablespace_name,
    file_id,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        bytes / NULLIF(maxbytes, 0) * 100,
        2
    ) AS max_used_pct,
    ROUND(
        (maxbytes - bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    autoextensible
FROM dba_data_files
WHERE maxbytes > 0
  AND bytes / maxbytes * 100 >= 90
ORDER BY max_used_pct DESC;


-- ============================================================
-- 8. DATAFILES AT MAXIMUM SIZE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. DATAFILES AT MAXIMUM SIZE
PROMPT ============================================================

SELECT
    tablespace_name,
    file_id,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    autoextensible,
    status
FROM dba_data_files
WHERE autoextensible = 'YES'
  AND bytes >= maxbytes
ORDER BY tablespace_name;


-- ============================================================
-- 9. LARGE AUTOEXTEND INCREMENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. LARGE AUTOEXTEND INCREMENTS
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(
        df.increment_by * ts.block_size
        / 1024 / 1024,
        2
    ) AS increment_mb,
    ROUND(
        (
            df.increment_by * ts.block_size
        ) / df.bytes * 100,
        2
    ) AS increment_pct,
    df.autoextensible
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
WHERE df.autoextensible = 'YES'
ORDER BY increment_mb DESC;


-- ============================================================
-- 10. SMALL AUTOEXTEND INCREMENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. SMALL AUTOEXTEND INCREMENTS
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(
        df.increment_by * ts.block_size
        / 1024 / 1024,
        2
    ) AS increment_mb,
    ROUND(
        (
            df.increment_by * ts.block_size
        ) / df.bytes * 100,
        2
    ) AS increment_pct,
    df.autoextensible
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
WHERE df.autoextensible = 'YES'
  AND (
        df.increment_by * ts.block_size
      ) / NULLIF(df.bytes, 0) * 100 < 1
ORDER BY increment_pct;


-- ============================================================
-- 11. AUTOEXTEND BY TABLESPACE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. AUTOEXTEND SUMMARY BY TABLESPACE
PROMPT ============================================================

SELECT
    df.tablespace_name,
    COUNT(*) AS datafiles,
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
    ) AS autoextend_disabled,
    ROUND(
        SUM(df.bytes) / 1024 / 1024 / 1024,
        2
    ) AS current_gb,
    ROUND(
        SUM(df.maxbytes) / 1024 / 1024 / 1024,
        2
    ) AS max_gb,
    ROUND(
        SUM(df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb
FROM dba_data_files df
GROUP BY df.tablespace_name
ORDER BY headroom_gb;


-- ============================================================
-- 12. TABLESPACES WITH NO AUTOEXTEND
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. TABLESPACES WITH AUTOEXTEND DISABLED
PROMPT ============================================================

SELECT
    tablespace_name,
    COUNT(*) AS datafiles,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS current_gb
FROM dba_data_files
GROUP BY tablespace_name
HAVING COUNT(
    CASE
        WHEN autoextensible = 'YES' THEN 1
    END
) = 0
ORDER BY current_gb DESC;


-- ============================================================
-- 13. AUTOEXTEND WITH VERY SMALL HEADROOM
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. AUTOEXTEND FILES WITH LESS THAN 5 GB HEADROOM
PROMPT ============================================================

SELECT
    tablespace_name,
    file_id,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (maxbytes - bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    autoextensible
FROM dba_data_files
WHERE autoextensible = 'YES'
  AND (maxbytes - bytes)
      / 1024 / 1024 / 1024 < 5
ORDER BY headroom_gb;


-- ============================================================
-- 14. AUTOEXTEND FILES WITH ZERO HEADROOM
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. AUTOEXTEND FILES WITH ZERO HEADROOM
PROMPT ============================================================

SELECT
    tablespace_name,
    file_id,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (maxbytes - bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    autoextensible,
    status
FROM dba_data_files
WHERE autoextensible = 'YES'
  AND bytes >= maxbytes
ORDER BY tablespace_name;


-- ============================================================
-- 15. DATAFILE USAGE VS CURRENT SIZE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. DATAFILE USAGE VS CURRENT SIZE
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
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
        / NULLIF(df.bytes, 0) * 100,
        2
    ) AS used_pct,
    df.autoextensible,
    ROUND(
        (df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb
FROM dba_data_files df
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON df.file_id = fs.file_id
ORDER BY used_pct DESC;


-- ============================================================
-- 16. AUTOEXTEND CAPACITY HEALTH
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. AUTOEXTEND CAPACITY HEALTH
PROMPT ============================================================

SELECT
    CASE
        WHEN COUNT(
            CASE
                WHEN autoextensible = 'YES'
                 AND bytes >= maxbytes
                THEN 1
            END
        ) > 0
        THEN 'CRITICAL - AUTOEXTEND FILE AT MAXIMUM'

        WHEN COUNT(
            CASE
                WHEN autoextensible = 'YES'
                 AND (maxbytes - bytes)
                     / 1024 / 1024 / 1024 < 5
                THEN 1
            END
        ) > 0
        THEN 'WARNING - LOW AUTOEXTEND HEADROOM'

        ELSE 'HEALTHY - AUTOEXTEND HEADROOM AVAILABLE'
    END AS health_status
FROM dba_data_files;


-- ============================================================
-- 17. QUICK AUTOEXTEND CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. QUICK AUTOEXTEND CHECK
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(df.maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (df.maxbytes - df.bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    ROUND(
        df.increment_by * ts.block_size
        / 1024 / 1024,
        2
    ) AS increment_mb,
    df.autoextensible,
    CASE
        WHEN df.autoextensible = 'NO'
            THEN 'CHECK - DISABLED'
        WHEN df.bytes >= df.maxbytes
            THEN 'CRITICAL - AT MAX'
        WHEN (df.maxbytes - df.bytes)
             / 1024 / 1024 / 1024 < 5
            THEN 'WARNING - LOW HEADROOM'
        ELSE 'HEALTHY'
    END AS status
FROM dba_data_files df
JOIN dba_tablespaces ts
    ON df.tablespace_name = ts.tablespace_name
ORDER BY
    CASE
        WHEN df.autoextensible = 'YES'
         AND df.bytes >= df.maxbytes THEN 1
        WHEN df.autoextensible = 'YES'
         AND (df.maxbytes - df.bytes)
             / 1024 / 1024 / 1024 < 5 THEN 2
        WHEN df.autoextensible = 'NO' THEN 3
        ELSE 4
    END,
    headroom_gb;


-- ============================================================
-- DBA CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT DBA CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT 1. Check which datafiles have AUTOEXTEND enabled.
PROMPT 2. Review current size versus MAXBYTES.
PROMPT 3. Check remaining AUTOEXTEND headroom.
PROMPT 4. Review AUTOEXTEND increment size.
PROMPT 5. Identify files already at MAXBYTES.
PROMPT 6. Check datafiles with AUTOEXTEND disabled.
PROMPT 7. Verify ASM/filesystem free capacity.
PROMPT 8. Review tablespace growth trends before changing MAXBYTES.
PROMPT 9. Do not assume AUTOEXTEND means unlimited growth.
PROMPT 10. Confirm storage capacity before increasing MAXBYTES.
PROMPT
PROMPT ============================================================
PROMPT END OF AUTOEXTEND DATAFILE CHECK
PROMPT ============================================================


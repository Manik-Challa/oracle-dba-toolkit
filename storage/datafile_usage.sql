-- ================================================================
-- Oracle DBA Toolkit
-- Datafile Usage Monitoring
-- File: oracle/monitoring/datafile_usage.sql
--
-- Purpose:
--   Monitor Oracle datafile size, free space, autoextend settings,
--   tablespace utilization, and files approaching capacity.
--
-- Covers:
--   1. Database / instance information
--   2. Datafile inventory
--   3. Datafile size and free space
--   4. Datafile usage percentage
--   5. Autoextend configuration
--   6. Maximum file size
--   7. Files above 80%, 90%, 95%
--   8. Datafiles with autoextend disabled
--   9. Datafiles close to MAXBYTES
--  10. Tablespace-level summary
--  11. Largest datafiles
--  12. Smallest remaining free space
--  13. Datafiles by tablespace
--  14. Bigfile tablespaces
--  15. Temporary files
--  16. Read-only datafiles
--  17. Datafile status
--  18. Offline datafiles
--  19. Autoextend growth headroom
--  20. Datafile health summary
--
-- Read-only monitoring script.
-- Does NOT resize, add, drop, or alter datafiles.
-- ================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

COLUMN INSTANCE_NAME FORMAT A18
COLUMN HOST_NAME FORMAT A35
COLUMN VERSION FORMAT A20
COLUMN STATUS FORMAT A15
COLUMN OPEN_MODE FORMAT A20
COLUMN DATABASE_ROLE FORMAT A20

COLUMN TABLESPACE_NAME FORMAT A30
COLUMN FILE_NAME FORMAT A100
COLUMN FILE_ID FORMAT 99999
COLUMN FILE_STATUS FORMAT A12

COLUMN SIZE_GB FORMAT 999,999,990.99
COLUMN USED_GB FORMAT 999,999,990.99
COLUMN FREE_GB FORMAT 999,999,990.99
COLUMN MAX_GB FORMAT 999,999,990.99
COLUMN FREE_PCT FORMAT 990.99
COLUMN USED_PCT FORMAT 990.99
COLUMN MAX_GROWTH_GB FORMAT 999,999,990.99

COLUMN AUTOEXTENSIBLE FORMAT A15
COLUMN ONLINE_STATUS FORMAT A15
COLUMN BIGFILE FORMAT A10
COLUMN EXTENT_MANAGEMENT FORMAT A15

PROMPT
PROMPT ================================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ================================================================

SELECT
    i.instance_name,
    i.host_name,
    i.version,
    i.status,
    d.open_mode,
    d.database_role
FROM v$instance i
CROSS JOIN v$database d;


PROMPT
PROMPT ================================================================
PROMPT 2. DATAFILE INVENTORY
PROMPT ================================================================

SELECT
    file_id,
    tablespace_name,
    file_name,
    status,
    autoextensible,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb
FROM dba_data_files
ORDER BY tablespace_name, file_id;


PROMPT
PROMPT ================================================================
PROMPT 3. DATAFILE USAGE
PROMPT ================================================================

SELECT
    df.file_id,
    df.tablespace_name,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS size_gb,
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
        100 * (df.bytes - NVL(fs.free_bytes, 0))
        / NULLIF(df.bytes, 0),
        2
    ) AS used_pct,
    ROUND(
        100 * NVL(fs.free_bytes, 0)
        / NULLIF(df.bytes, 0),
        2
    ) AS free_pct
FROM dba_data_files df
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON fs.file_id = df.file_id
ORDER BY used_pct DESC;


PROMPT
PROMPT ================================================================
PROMPT 4. DATAFILES ABOVE 80% USED
PROMPT ================================================================

SELECT
    df.file_id,
    df.tablespace_name,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS size_gb,
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
        100 * (df.bytes - NVL(fs.free_bytes, 0))
        / NULLIF(df.bytes, 0),
        2
    ) AS used_pct,
    df.autoextensible
FROM dba_data_files df
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON fs.file_id = df.file_id
WHERE 100 * (df.bytes - NVL(fs.free_bytes, 0))
      / NULLIF(df.bytes, 0) >= 80
ORDER BY used_pct DESC;


PROMPT
PROMPT ================================================================
PROMPT 5. DATAFILES ABOVE 90% USED
PROMPT ================================================================

SELECT
    df.file_id,
    df.tablespace_name,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS size_gb,
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
        100 * (df.bytes - NVL(fs.free_bytes, 0))
        / NULLIF(df.bytes, 0),
        2
    ) AS used_pct,
    df.autoextensible,
    ROUND(
        df.maxbytes / 1024 / 1024 / 1024,
        2
    ) AS max_gb
FROM dba_data_files df
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON fs.file_id = df.file_id
WHERE 100 * (df.bytes - NVL(fs.free_bytes, 0))
      / NULLIF(df.bytes, 0) >= 90
ORDER BY used_pct DESC;


PROMPT
PROMPT ================================================================
PROMPT 6. DATAFILES ABOVE 95% USED
PROMPT ================================================================

SELECT
    df.file_id,
    df.tablespace_name,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS size_gb,
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
        100 * (df.bytes - NVL(fs.free_bytes, 0))
        / NULLIF(df.bytes, 0),
        2
    ) AS used_pct,
    df.autoextensible
FROM dba_data_files df
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON fs.file_id = df.file_id
WHERE 100 * (df.bytes - NVL(fs.free_bytes, 0))
      / NULLIF(df.bytes, 0) >= 95
ORDER BY used_pct DESC;


PROMPT
PROMPT ================================================================
PROMPT 7. DATAFILES WITH AUTOEXTEND DISABLED
PROMPT ================================================================

SELECT
    file_id,
    tablespace_name,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    autoextensible
FROM dba_data_files
WHERE autoextensible = 'NO'
ORDER BY bytes DESC;


PROMPT
PROMPT ================================================================
PROMPT 8. AUTOEXTEND DATAFILES
PROMPT ================================================================

SELECT
    file_id,
    tablespace_name,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (maxbytes - bytes) / 1024 / 1024 / 1024,
        2
    ) AS max_growth_gb,
    ROUND(increment_by * block_size / 1024 / 1024, 2)
        AS next_growth_mb,
    autoextensible
FROM dba_data_files
WHERE autoextensible = 'YES'
ORDER BY max_growth_gb ASC;


PROMPT
PROMPT ================================================================
PROMPT 9. DATAFILES CLOSE TO MAXBYTES
PROMPT ================================================================

SELECT
    file_id,
    tablespace_name,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (maxbytes - bytes) / 1024 / 1024 / 1024,
        2
    ) AS remaining_growth_gb,
    ROUND(
        100 * bytes / NULLIF(maxbytes, 0),
        2
    ) AS pct_of_maxbytes
FROM dba_data_files
WHERE autoextensible = 'YES'
  AND maxbytes > 0
  AND bytes / maxbytes >= 0.90
ORDER BY pct_of_maxbytes DESC;


PROMPT
PROMPT ================================================================
PROMPT 10. DATAFILES WITH VERY LITTLE GROWTH HEADROOM
PROMPT ================================================================

SELECT
    file_id,
    tablespace_name,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (maxbytes - bytes) / 1024 / 1024 / 1024,
        2
    ) AS remaining_growth_gb
FROM dba_data_files
WHERE autoextensible = 'YES'
  AND maxbytes > 0
  AND (maxbytes - bytes) <= 10 * 1024 * 1024 * 1024
ORDER BY remaining_growth_gb ASC;


PROMPT
PROMPT ================================================================
PROMPT 11. TABLESPACE-LEVEL DATAFILE SUMMARY
PROMPT ================================================================

SELECT
    tablespace_name,
    COUNT(*) AS datafile_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS allocated_gb,
    ROUND(
        SUM(maxbytes) / 1024 / 1024 / 1024,
        2
    ) AS max_gb
FROM dba_data_files
GROUP BY tablespace_name
ORDER BY allocated_gb DESC;


PROMPT
PROMPT ================================================================
PROMPT 12. TABLESPACE USAGE SUMMARY
PROMPT ================================================================

SELECT
    df.tablespace_name,
    ROUND(
        SUM(df.bytes) / 1024 / 1024 / 1024,
        2
    ) AS allocated_gb,
    ROUND(
        SUM(NVL(fs.free_bytes, 0))
        / 1024 / 1024 / 1024,
        2
    ) AS free_gb,
    ROUND(
        (
            SUM(df.bytes)
            - SUM(NVL(fs.free_bytes, 0))
        ) / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(
        100 *
        (
            SUM(df.bytes)
            - SUM(NVL(fs.free_bytes, 0))
        )
        / NULLIF(SUM(df.bytes), 0),
        2
    ) AS used_pct
FROM dba_data_files df
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON fs.file_id = df.file_id
GROUP BY df.tablespace_name
ORDER BY used_pct DESC;


PROMPT
PROMPT ================================================================
PROMPT 13. LARGEST DATAFILES
PROMPT ================================================================

SELECT
    file_id,
    tablespace_name,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    autoextensible
FROM dba_data_files
ORDER BY bytes DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 14. DATAFILES WITH LOWEST FREE SPACE
PROMPT ================================================================

SELECT
    df.file_id,
    df.tablespace_name,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(
        NVL(fs.free_bytes, 0)
        / 1024 / 1024 / 1024,
        2
    ) AS free_gb,
    ROUND(
        100 * NVL(fs.free_bytes, 0)
        / NULLIF(df.bytes, 0),
        2
    ) AS free_pct
FROM dba_data_files df
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON fs.file_id = df.file_id
ORDER BY free_gb ASC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 15. BIGFILE TABLESPACES
PROMPT ================================================================

SELECT
    tablespace_name,
    bigfile,
    status,
    contents,
    extent_management
FROM dba_tablespaces
WHERE bigfile = 'YES'
ORDER BY tablespace_name;


PROMPT
PROMPT ================================================================
PROMPT 16. READ-ONLY DATAFILES
PROMPT ================================================================

SELECT
    file_id,
    tablespace_name,
    file_name,
    status,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM dba_data_files
WHERE status <> 'AVAILABLE'
ORDER BY tablespace_name, file_id;


PROMPT
PROMPT ================================================================
PROMPT 17. OFFLINE DATAFILES
PROMPT ================================================================

SELECT
    file_id,
    tablespace_name,
    file_name,
    status,
    online_status,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM v$datafile
WHERE online_status <> 'ONLINE'
ORDER BY tablespace_name, file_id;


PROMPT
PROMPT ================================================================
PROMPT 18. DATAFILE STATUS
PROMPT ================================================================

SELECT
    status,
    COUNT(*) AS datafile_count
FROM v$datafile
GROUP BY status
ORDER BY status;


PROMPT
PROMPT ================================================================
PROMPT 19. DATAFILE COUNT BY TABLESPACE
PROMPT ================================================================

SELECT
    tablespace_name,
    COUNT(*) AS datafile_count,
    SUM(
        CASE
            WHEN autoextensible = 'YES'
            THEN 1
            ELSE 0
        END
    ) AS autoextend_files,
    SUM(
        CASE
            WHEN autoextensible = 'NO'
            THEN 1
            ELSE 0
        END
    ) AS non_autoextend_files
FROM dba_data_files
GROUP BY tablespace_name
ORDER BY datafile_count DESC;


PROMPT
PROMPT ================================================================
PROMPT 20. AUTOEXTEND GROWTH SETTINGS
PROMPT ================================================================

SELECT
    file_id,
    tablespace_name,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        increment_by * block_size / 1024 / 1024,
        2
    ) AS next_growth_mb,
    autoextensible
FROM dba_data_files
WHERE autoextensible = 'YES'
ORDER BY next_growth_mb DESC;


PROMPT
PROMPT ================================================================
PROMPT 21. DATAFILES ABOVE 90% WITH AUTOEXTEND DISABLED
PROMPT ================================================================

SELECT
    df.file_id,
    df.tablespace_name,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    ROUND(
        NVL(fs.free_bytes, 0)
        / 1024 / 1024 / 1024,
        2
    ) AS free_gb,
    ROUND(
        100 * (df.bytes - NVL(fs.free_bytes, 0))
        / NULLIF(df.bytes, 0),
        2
    ) AS used_pct,
    df.autoextensible
FROM dba_data_files df
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON fs.file_id = df.file_id
WHERE df.autoextensible = 'NO'
  AND 100 * (df.bytes - NVL(fs.free_bytes, 0))
      / NULLIF(df.bytes, 0) >= 90
ORDER BY used_pct DESC;


PROMPT
PROMPT ================================================================
PROMPT 22. DATAFILE HEALTH SUMMARY
PROMPT ================================================================

SELECT
    COUNT(*) AS total_datafiles,

    SUM(
        CASE
            WHEN autoextensible = 'YES'
            THEN 1
            ELSE 0
        END
    ) AS autoextend_files,

    SUM(
        CASE
            WHEN autoextensible = 'NO'
            THEN 1
            ELSE 0
        END
    ) AS non_autoextend_files,

    SUM(
        CASE
            WHEN status = 'AVAILABLE'
            THEN 1
            ELSE 0
        END
    ) AS available_files,

    SUM(
        CASE
            WHEN status <> 'AVAILABLE'
            THEN 1
            ELSE 0
        END
    ) AS unavailable_files
FROM dba_data_files;


PROMPT
PROMPT ================================================================
PROMPT 23. DATAFILE CAPACITY HEALTH
PROMPT ================================================================

SELECT
    SUM(
        CASE
            WHEN used_pct >= 95
            THEN 1
            ELSE 0
        END
    ) AS files_above_95_pct,

    SUM(
        CASE
            WHEN used_pct >= 90
             AND used_pct < 95
            THEN 1
            ELSE 0
        END
    ) AS files_90_to_95_pct,

    SUM(
        CASE
            WHEN used_pct >= 80
             AND used_pct < 90
            THEN 1
            ELSE 0
        END
    ) AS files_80_to_90_pct,

    SUM(
        CASE
            WHEN used_pct < 80
            THEN 1
            ELSE 0
        END
    ) AS files_below_80_pct
FROM (
    SELECT
        df.file_id,
        100 *
        (
            df.bytes - NVL(fs.free_bytes, 0)
        ) / NULLIF(df.bytes, 0) AS used_pct
    FROM dba_data_files df
    LEFT JOIN (
        SELECT
            file_id,
            SUM(bytes) AS free_bytes
        FROM dba_free_space
        GROUP BY file_id
    ) fs
        ON fs.file_id = df.file_id
);


PROMPT
PROMPT ================================================================
PROMPT 24. OVERALL DATAFILE HEALTH
PROMPT ================================================================

SELECT
    CASE
        WHEN COUNT(*) = 0
            THEN 'UNKNOWN - NO DATAFILES FOUND'

        WHEN SUM(
                CASE
                    WHEN status <> 'AVAILABLE'
                    THEN 1
                    ELSE 0
                END
             ) > 0
            THEN 'WARNING - DATAFILE STATUS REQUIRES REVIEW'

        WHEN SUM(
                CASE
                    WHEN used_pct >= 95
                    THEN 1
                    ELSE 0
                END
             ) > 0
            THEN 'CRITICAL - DATAFILE ABOVE 95%'

        WHEN SUM(
                CASE
                    WHEN used_pct >= 90
                    THEN 1
                    ELSE 0
                END
             ) > 0
            THEN 'WARNING - DATAFILE ABOVE 90%'

        WHEN SUM(
                CASE
                    WHEN used_pct >= 80
                    THEN 1
                    ELSE 0
                END
             ) > 0
            THEN 'NOTICE - DATAFILE ABOVE 80%'

        ELSE
            'HEALTHY - DATAFILE CAPACITY OK'
    END AS datafile_health
FROM (
    SELECT
        df.file_id,
        df.status,
        100 *
        (
            df.bytes - NVL(fs.free_bytes, 0)
        ) / NULLIF(df.bytes, 0) AS used_pct
    FROM dba_data_files df
    LEFT JOIN (
        SELECT
            file_id,
            SUM(bytes) AS free_bytes
        FROM dba_free_space
        GROUP BY file_id
    ) fs
        ON fs.file_id = df.file_id
);


PROMPT
PROMPT ================================================================
PROMPT DBA CHECKLIST
PROMPT ================================================================
PROMPT
PROMPT [ ] Check datafiles above 80%, 90%, and 95%.
PROMPT [ ] Review files with autoextend disabled.
PROMPT [ ] Check autoextend MAXBYTES headroom.
PROMPT [ ] Review unusually large datafiles.
PROMPT [ ] Check unavailable/offline datafiles.
PROMPT [ ] Review tablespace-level capacity.
PROMPT [ ] Verify filesystem / ASM free space before resizing.
PROMPT [ ] Check growth trends before increasing datafile size.
PROMPT [ ] For ASM, correlate with ASM diskgroup free space.
PROMPT [ ] For filesystem storage, verify OS filesystem capacity.
PROMPT [ ] Consider application growth and retention requirements.
PROMPT [ ] Do not resize datafiles blindly in production.
PROMPT
PROMPT ================================================================
PROMPT IMPORTANT NOTES
PROMPT ================================================================
PROMPT
PROMPT * This script is READ-ONLY.
PROMPT * It does not resize or add datafiles.
PROMPT * It does not change AUTOEXTEND settings.
PROMPT * 90% utilization is a monitoring threshold, not an Oracle
PROMPT   failure threshold.
PROMPT * AUTOEXTEND=YES does not guarantee unlimited growth.
PROMPT * MAXBYTES and underlying storage capacity must be reviewed.
PROMPT * Free space inside a datafile is different from free space
PROMPT   on the underlying filesystem or ASM diskgroup.
PROMPT * DBA_FREE_SPACE reports free extents, not necessarily
PROMPT   contiguous free space.
PROMPT * In ASM environments, correlate datafile capacity with
PROMPT   V$ASM_DISKGROUP.
PROMPT * For large databases, DBA_FREE_SPACE queries can be expensive.
PROMPT * Bigfile tablespaces require special consideration when
PROMPT   evaluating maximum datafile size.
PROMPT
PROMPT ================================================================
PROMPT END OF DATAFILE USAGE MONITORING
PROMPT ================================================================


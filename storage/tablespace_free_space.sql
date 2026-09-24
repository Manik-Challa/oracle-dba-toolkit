-- ============================================================
-- Oracle DBA Toolkit
-- Script   : tablespace_free_space.sql
-- Purpose  : Monitor tablespace free space and free extents
-- Author   : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN tablespace_name FORMAT A30
COLUMN status          FORMAT A10
COLUMN contents        FORMAT A12
COLUMN extent_management FORMAT A12
COLUMN allocation_type FORMAT A12

COLUMN total_gb        FORMAT 999,999,990.00
COLUMN used_gb         FORMAT 999,999,990.00
COLUMN free_gb         FORMAT 999,999,990.00
COLUMN free_pct        FORMAT 990.00
COLUMN largest_free_gb FORMAT 999,999,990.00
COLUMN free_extents    FORMAT 999,999,990
COLUMN max_free_pct    FORMAT 990.00

PROMPT
PROMPT ============================================================
PROMPT TABLESPACE FREE SPACE MONITORING
PROMPT ============================================================

-- ============================================================
-- 1. DATABASE INFORMATION
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
-- 2. CURRENT TABLESPACE FREE SPACE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. CURRENT TABLESPACE FREE SPACE
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(SUM(df.bytes) / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(
        (SUM(df.bytes) - NVL(fs.free_bytes, 0))
        / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(NVL(fs.free_bytes, 0) / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(
        NVL(fs.free_bytes, 0) / SUM(df.bytes) * 100,
        2
    ) AS free_pct
FROM dba_data_files df
LEFT JOIN (
    SELECT
        tablespace_name,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
    ON df.tablespace_name = fs.tablespace_name
GROUP BY
    df.tablespace_name,
    fs.free_bytes
ORDER BY free_pct;


-- ============================================================
-- 3. TABLESPACE FREE SPACE WITH STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. TABLESPACE FREE SPACE WITH STATUS
PROMPT ============================================================

SELECT
    t.tablespace_name,
    t.status,
    t.contents,
    t.extent_management,
    t.allocation_type,
    ROUND(SUM(df.bytes) / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(NVL(fs.free_bytes, 0) / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(
        NVL(fs.free_bytes, 0) / SUM(df.bytes) * 100,
        2
    ) AS free_pct
FROM dba_tablespaces t
JOIN dba_data_files df
    ON t.tablespace_name = df.tablespace_name
LEFT JOIN (
    SELECT
        tablespace_name,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
    ON t.tablespace_name = fs.tablespace_name
GROUP BY
    t.tablespace_name,
    t.status,
    t.contents,
    t.extent_management,
    t.allocation_type,
    fs.free_bytes
ORDER BY free_pct;


-- ============================================================
-- 4. TABLESPACES WITH LESS THAN 20% FREE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. TABLESPACES WITH LESS THAN 20% FREE
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(SUM(df.bytes) / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(NVL(fs.free_bytes, 0) / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(
        NVL(fs.free_bytes, 0) / SUM(df.bytes) * 100,
        2
    ) AS free_pct
FROM dba_data_files df
LEFT JOIN (
    SELECT
        tablespace_name,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
    ON df.tablespace_name = fs.tablespace_name
GROUP BY
    df.tablespace_name,
    fs.free_bytes
HAVING
    NVL(fs.free_bytes, 0) / SUM(df.bytes) * 100 < 20
ORDER BY free_pct;


-- ============================================================
-- 5. TABLESPACES WITH LESS THAN 10% FREE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. TABLESPACES WITH LESS THAN 10% FREE
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(SUM(df.bytes) / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(NVL(fs.free_bytes, 0) / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(
        NVL(fs.free_bytes, 0) / SUM(df.bytes) * 100,
        2
    ) AS free_pct
FROM dba_data_files df
LEFT JOIN (
    SELECT
        tablespace_name,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
    ON df.tablespace_name = fs.tablespace_name
GROUP BY
    df.tablespace_name,
    fs.free_bytes
HAVING
    NVL(fs.free_bytes, 0) / SUM(df.bytes) * 100 < 10
ORDER BY free_pct;


-- ============================================================
-- 6. LARGEST FREE EXTENT PER TABLESPACE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. LARGEST FREE EXTENT PER TABLESPACE
PROMPT ============================================================

SELECT
    tablespace_name,
    ROUND(MAX(bytes) / 1024 / 1024 / 1024, 2) AS largest_free_gb,
    COUNT(*) AS free_extents
FROM dba_free_space
GROUP BY tablespace_name
ORDER BY largest_free_gb DESC;


-- ============================================================
-- 7. FREE EXTENT DETAILS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. FREE EXTENT DETAILS
PROMPT ============================================================

SELECT
    tablespace_name,
    file_id,
    block_id,
    blocks,
    ROUND(bytes / 1024 / 1024, 2) AS free_mb
FROM dba_free_space
ORDER BY
    tablespace_name,
    bytes DESC;


-- ============================================================
-- 8. TOP 20 LARGEST FREE EXTENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. TOP 20 LARGEST FREE EXTENTS
PROMPT ============================================================

SELECT
    *
FROM (
    SELECT
        tablespace_name,
        file_id,
        block_id,
        blocks,
        ROUND(bytes / 1024 / 1024, 2) AS free_mb
    FROM dba_free_space
    ORDER BY bytes DESC
)
WHERE ROWNUM <= 20;


-- ============================================================
-- 9. FREE EXTENT COUNT BY TABLESPACE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. FREE EXTENT COUNT BY TABLESPACE
PROMPT ============================================================

SELECT
    tablespace_name,
    COUNT(*) AS free_extents,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(MAX(bytes) / 1024 / 1024, 2) AS largest_free_mb,
    ROUND(AVG(bytes) / 1024 / 1024, 2) AS average_free_mb
FROM dba_free_space
GROUP BY tablespace_name
ORDER BY free_gb;


-- ============================================================
-- 10. TABLESPACES WITH MANY FREE EXTENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. TABLESPACES WITH MANY FREE EXTENTS
PROMPT ============================================================

SELECT
    tablespace_name,
    COUNT(*) AS free_extents,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(MAX(bytes) / 1024 / 1024, 2) AS largest_free_mb
FROM dba_free_space
GROUP BY tablespace_name
HAVING COUNT(*) > 1000
ORDER BY free_extents DESC;


-- ============================================================
-- 11. DATAFILE FREE SPACE DETAILS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. DATAFILE FREE SPACE DETAILS
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS file_size_gb,
    ROUND(NVL(fs.free_bytes, 0) / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(
        NVL(fs.free_bytes, 0) / df.bytes * 100,
        2
    ) AS free_pct,
    df.autoextensible
FROM dba_data_files df
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON df.file_id = fs.file_id
ORDER BY free_pct;


-- ============================================================
-- 12. DATAFILES WITH LESS THAN 10% FREE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. DATAFILES WITH LESS THAN 10% FREE
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS file_size_gb,
    ROUND(NVL(fs.free_bytes, 0) / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(
        NVL(fs.free_bytes, 0) / df.bytes * 100,
        2
    ) AS free_pct,
    df.autoextensible
FROM dba_data_files df
LEFT JOIN (
    SELECT
        file_id,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY file_id
) fs
    ON df.file_id = fs.file_id
WHERE
    NVL(fs.free_bytes, 0) / df.bytes * 100 < 10
ORDER BY free_pct;


-- ============================================================
-- 13. AUTOEXTEND DATAFILE HEADROOM
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. AUTOEXTEND DATAFILE HEADROOM
PROMPT ============================================================

SELECT
    tablespace_name,
    file_id,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (maxbytes - bytes) / 1024 / 1024 / 1024,
        2
    ) AS autoextend_headroom_gb,
    autoextensible
FROM dba_data_files
WHERE autoextensible = 'YES'
ORDER BY autoextend_headroom_gb;


-- ============================================================
-- 14. TABLESPACES WITH LIMITED AUTOEXTEND HEADROOM
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. TABLESPACES WITH LIMITED AUTOEXTEND HEADROOM
PROMPT ============================================================

SELECT
    tablespace_name,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(SUM(maxbytes) / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        SUM(maxbytes - bytes) / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb
FROM dba_data_files
WHERE autoextensible = 'YES'
GROUP BY tablespace_name
HAVING SUM(maxbytes - bytes) / 1024 / 1024 / 1024 < 10
ORDER BY headroom_gb;


-- ============================================================
-- 15. BIGFILE TABLESPACE INFORMATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. BIGFILE TABLESPACES
PROMPT ============================================================

SELECT
    tablespace_name,
    bigfile,
    status,
    contents,
    extent_management,
    allocation_type
FROM dba_tablespaces
WHERE bigfile = 'YES'
ORDER BY tablespace_name;


-- ============================================================
-- 16. TEMPORARY TABLESPACE FREE SPACE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. TEMPORARY TABLESPACE FREE SPACE
PROMPT ============================================================

SELECT
    tablespace_name,
    ROUND(tablespace_size / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(free_space / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(
        free_space / tablespace_size * 100,
        2
    ) AS free_pct
FROM dba_temp_free_space
ORDER BY free_pct;


-- ============================================================
-- 17. TEMPFILE FREE SPACE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. TEMPFILE FREE SPACE
PROMPT ============================================================

SELECT
    tf.tablespace_name,
    tf.file_id,
    tf.file_name,
    ROUND(tf.bytes / 1024 / 1024 / 1024, 2) AS tempfile_gb,
    ROUND(
        NVL(tfs.free_space, 0) / 1024 / 1024 / 1024,
        2
    ) AS free_gb,
    tf.autoextensible
FROM dba_temp_files tf
LEFT JOIN dba_temp_free_space tfs
    ON tf.tablespace_name = tfs.tablespace_name
ORDER BY tf.tablespace_name, tf.file_id;


-- ============================================================
-- 18. TABLESPACE FREE SPACE SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. TABLESPACE FREE SPACE SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS tablespaces,
    SUM(CASE
            WHEN free_pct < 10 THEN 1
            ELSE 0
        END) AS less_than_10_pct_free,
    SUM(CASE
            WHEN free_pct >= 10
             AND free_pct < 20 THEN 1
            ELSE 0
        END) AS between_10_20_pct_free,
    SUM(CASE
            WHEN free_pct >= 20 THEN 1
            ELSE 0
        END) AS healthy_free_space
FROM (
    SELECT
        df.tablespace_name,
        NVL(fs.free_bytes, 0) / SUM(df.bytes) * 100 AS free_pct
    FROM dba_data_files df
    LEFT JOIN (
        SELECT
            tablespace_name,
            SUM(bytes) AS free_bytes
        FROM dba_free_space
        GROUP BY tablespace_name
    ) fs
        ON df.tablespace_name = fs.tablespace_name
    GROUP BY
        df.tablespace_name,
        fs.free_bytes
);


-- ============================================================
-- 19. TABLESPACE FREE SPACE HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 19. TABLESPACE FREE SPACE HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN SUM(
            CASE
                WHEN free_pct < 10 THEN 1
                ELSE 0
            END
        ) > 0
        THEN 'CRITICAL - TABLESPACE BELOW 10% FREE'

        WHEN SUM(
            CASE
                WHEN free_pct < 20 THEN 1
                ELSE 0
            END
        ) > 0
        THEN 'WARNING - TABLESPACE BELOW 20% FREE'

        ELSE 'HEALTHY - ADEQUATE FREE SPACE'
    END AS health_status
FROM (
    SELECT
        df.tablespace_name,
        NVL(fs.free_bytes, 0) / SUM(df.bytes) * 100 AS free_pct
    FROM dba_data_files df
    LEFT JOIN (
        SELECT
            tablespace_name,
            SUM(bytes) AS free_bytes
        FROM dba_free_space
        GROUP BY tablespace_name
    ) fs
        ON df.tablespace_name = fs.tablespace_name
    GROUP BY
        df.tablespace_name,
        fs.free_bytes
);


-- ============================================================
-- 20. QUICK DBA CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 20. QUICK DBA CHECK
PROMPT ============================================================

SELECT
    df.tablespace_name,
    ROUND(SUM(df.bytes) / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(NVL(fs.free_bytes, 0) / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(
        NVL(fs.free_bytes, 0) / SUM(df.bytes) * 100,
        2
    ) AS free_pct,
    CASE
        WHEN NVL(fs.free_bytes, 0) / SUM(df.bytes) * 100 < 10
            THEN 'CRITICAL'
        WHEN NVL(fs.free_bytes, 0) / SUM(df.bytes) * 100 < 20
            THEN 'WARNING'
        ELSE 'HEALTHY'
    END AS status
FROM dba_data_files df
LEFT JOIN (
    SELECT
        tablespace_name,
        SUM(bytes) AS free_bytes
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
    ON df.tablespace_name = fs.tablespace_name
GROUP BY
    df.tablespace_name,
    fs.free_bytes
ORDER BY free_pct;


-- ============================================================
-- DBA CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT DBA CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT 1. Check tablespaces with less than 20% free.
PROMPT 2. Investigate tablespaces with less than 10% free.
PROMPT 3. Check largest free extent when allocation failures occur.
PROMPT 4. Check AUTOEXTEND and MAXBYTES before adding space.
PROMPT 5. Check underlying ASM/filesystem storage separately.
PROMPT 6. Review tablespace growth trends before increasing capacity.
PROMPT 7. For TEMP, use DBA_TEMP_FREE_SPACE and V$TEMPSEG_USAGE.
PROMPT 8. Do not assume low free percentage means immediate failure.
PROMPT 9. Check object growth and application activity before resizing.
PROMPT
PROMPT ============================================================
PROMPT END OF TABLESPACE FREE SPACE CHECK
PROMPT ============================================================


-- ============================================================================
-- Oracle DBA Toolkit
-- File   : largest_indexes.sql
-- Purpose: Identify and monitor the largest indexes in the database
-- Author : Manik Challa
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN owner              FORMAT A25
COLUMN index_name         FORMAT A45
COLUMN table_owner        FORMAT A25
COLUMN table_name         FORMAT A45
COLUMN tablespace_name    FORMAT A30
COLUMN index_type         FORMAT A20
COLUMN status              FORMAT A15
COLUMN size_gb            FORMAT 999,999,990.99
COLUMN size_mb            FORMAT 999,999,990.99
COLUMN num_rows           FORMAT 999,999,999,999,999
COLUMN distinct_keys      FORMAT 999,999,999,999,999
COLUMN leaf_blocks        FORMAT 999,999,999,999
COLUMN blevel             FORMAT 999
COLUMN clustering_factor  FORMAT 999,999,999,999
COLUMN index_count        FORMAT 999,999
COLUMN pct_of_table       FORMAT 990.99
COLUMN last_analyzed      FORMAT A20

PROMPT
PROMPT ============================================================================
PROMPT ORACLE DBA TOOLKIT - LARGEST INDEXES
PROMPT ============================================================================


-- ============================================================================
-- 1. DATABASE / INSTANCE INFORMATION
-- ============================================================================

PROMPT
PROMPT [1] DATABASE / INSTANCE INFORMATION
PROMPT ============================================================================

SELECT
    d.name AS database_name,
    i.instance_name,
    i.host_name,
    i.status,
    i.version,
    i.startup_time
FROM v$database d
CROSS JOIN v$instance i;


-- ============================================================================
-- 2. TOP 50 LARGEST INDEXES
-- ============================================================================

PROMPT
PROMPT [2] TOP 50 LARGEST INDEXES
PROMPT ============================================================================

SELECT
    owner,
    segment_name AS index_name,
    tablespace_name,
    segment_type,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM dba_segments
WHERE segment_type IN
      ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
ORDER BY bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 3. LARGEST NON-PARTITIONED INDEXES
-- ============================================================================

PROMPT
PROMPT [3] LARGEST NON-PARTITIONED INDEXES
PROMPT ============================================================================

SELECT
    i.owner,
    i.index_name,
    i.table_owner,
    i.table_name,
    i.index_type,
    i.tablespace_name,
    ROUND(
        s.bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    i.status,
    i.blevel,
    i.leaf_blocks,
    i.distinct_keys
FROM dba_indexes i
JOIN dba_segments s
  ON s.owner = i.owner
 AND s.segment_name = i.index_name
 AND s.segment_type = 'INDEX'
ORDER BY s.bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 4. INDEXES LARGER THAN 10 GB
-- ============================================================================

PROMPT
PROMPT [4] INDEXES LARGER THAN 10 GB
PROMPT ============================================================================

SELECT
    owner,
    segment_name AS index_name,
    tablespace_name,
    ROUND(
        bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    CASE
        WHEN bytes >= 100 * 1024 * 1024 * 1024
            THEN 'REVIEW'
        WHEN bytes >= 50 * 1024 * 1024 * 1024
            THEN 'WATCH'
        ELSE 'NORMAL'
    END AS status
FROM dba_segments
WHERE segment_type IN
      ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
  AND bytes >= 10 * 1024 * 1024 * 1024
ORDER BY bytes DESC;


-- ============================================================================
-- 5. INDEX SIZE BY OWNER
-- ============================================================================

PROMPT
PROMPT [5] INDEX SIZE BY OWNER
PROMPT ============================================================================

SELECT
    owner,
    COUNT(*) AS index_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_gb,
    ROUND(
        AVG(bytes) / 1024 / 1024 / 1024,
        2
    ) AS avg_index_gb
FROM dba_segments
WHERE segment_type IN
      ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
GROUP BY owner
ORDER BY SUM(bytes) DESC;


-- ============================================================================
-- 6. INDEX SIZE BY TABLESPACE
-- ============================================================================

PROMPT
PROMPT [6] INDEX SIZE BY TABLESPACE
PROMPT ============================================================================

SELECT
    tablespace_name,
    COUNT(*) AS index_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_gb
FROM dba_segments
WHERE segment_type IN
      ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
GROUP BY tablespace_name
ORDER BY SUM(bytes) DESC;


-- ============================================================================
-- 7. LARGEST INDEXES WITH INDEX STATISTICS
-- ============================================================================

PROMPT
PROMPT [7] LARGEST INDEXES WITH STATISTICS
PROMPT ============================================================================

SELECT
    i.owner,
    i.index_name,
    i.table_name,
    i.index_type,
    i.status,
    ROUND(
        s.bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    i.blevel,
    i.leaf_blocks,
    i.distinct_keys,
    i.clustering_factor,
    TO_CHAR(
        i.last_analyzed,
        'YYYY-MM-DD HH24:MI'
    ) AS last_analyzed
FROM dba_indexes i
JOIN dba_segments s
  ON s.owner = i.owner
 AND s.segment_name = i.index_name
 AND s.segment_type = 'INDEX'
ORDER BY s.bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 8. INDEX SIZE VS TABLE SIZE
-- ============================================================================

PROMPT
PROMPT [8] INDEX SIZE VS TABLE SIZE
PROMPT ============================================================================

WITH table_size AS
(
    SELECT
        owner,
        segment_name AS table_name,
        SUM(bytes) AS table_bytes
    FROM dba_segments
    WHERE segment_type IN
          ('TABLE', 'TABLE PARTITION', 'TABLE SUBPARTITION')
    GROUP BY owner, segment_name
),
index_size AS
(
    SELECT
        i.table_owner AS owner,
        i.table_name,
        SUM(s.bytes) AS index_bytes
    FROM dba_indexes i
    JOIN dba_segments s
      ON s.owner = i.owner
     AND s.segment_name = i.index_name
    WHERE s.segment_type IN
          ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
    GROUP BY
        i.table_owner,
        i.table_name
)
SELECT
    t.owner,
    t.table_name,
    ROUND(
        t.table_bytes / 1024 / 1024 / 1024,
        2
    ) AS table_gb,
    ROUND(
        NVL(i.index_bytes, 0) / 1024 / 1024 / 1024,
        2
    ) AS index_gb,
    ROUND(
        NVL(i.index_bytes, 0)
        / NULLIF(t.table_bytes, 0) * 100,
        2
    ) AS index_to_table_pct
FROM table_size t
LEFT JOIN index_size i
  ON i.owner = t.owner
 AND i.table_name = t.table_name
ORDER BY NVL(i.index_bytes, 0) DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 9. TABLES WHERE INDEX SPACE EXCEEDS TABLE SPACE
-- ============================================================================

PROMPT
PROMPT [9] TABLES WHERE INDEX SPACE EXCEEDS TABLE SPACE
PROMPT ============================================================================

WITH table_size AS
(
    SELECT
        owner,
        segment_name AS table_name,
        SUM(bytes) AS table_bytes
    FROM dba_segments
    WHERE segment_type IN
          ('TABLE', 'TABLE PARTITION', 'TABLE SUBPARTITION')
    GROUP BY owner, segment_name
),
index_size AS
(
    SELECT
        i.table_owner AS owner,
        i.table_name,
        SUM(s.bytes) AS index_bytes
    FROM dba_indexes i
    JOIN dba_segments s
      ON s.owner = i.owner
     AND s.segment_name = i.index_name
    WHERE s.segment_type IN
          ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
    GROUP BY
        i.table_owner,
        i.table_name
)
SELECT
    t.owner,
    t.table_name,
    ROUND(
        t.table_bytes / 1024 / 1024 / 1024,
        2
    ) AS table_gb,
    ROUND(
        i.index_bytes / 1024 / 1024 / 1024,
        2
    ) AS index_gb,
    ROUND(
        i.index_bytes
        / NULLIF(t.table_bytes, 0) * 100,
        2
    ) AS index_to_table_pct
FROM table_size t
JOIN index_size i
  ON i.owner = t.owner
 AND i.table_name = t.table_name
WHERE i.index_bytes > t.table_bytes
ORDER BY i.index_bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 10. LARGEST INDEXES BY TABLE
-- ============================================================================

PROMPT
PROMPT [10] TABLES WITH THE LARGEST INDEX FOOTPRINT
PROMPT ============================================================================

SELECT
    i.table_owner,
    i.table_name,
    COUNT(*) AS index_count,
    ROUND(
        SUM(s.bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_index_gb
FROM dba_indexes i
JOIN dba_segments s
  ON s.owner = i.owner
 AND s.segment_name = i.index_name
WHERE s.segment_type IN
      ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
GROUP BY
    i.table_owner,
    i.table_name
ORDER BY SUM(s.bytes) DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 11. UNUSABLE INDEXES
-- ============================================================================

PROMPT
PROMPT [11] UNUSABLE INDEXES
PROMPT ============================================================================

SELECT
    owner,
    index_name,
    table_owner,
    table_name,
    index_type,
    status,
    tablespace_name
FROM dba_indexes
WHERE status = 'UNUSABLE'
ORDER BY owner, index_name;


-- ============================================================================
-- 12. INVALID / UNUSABLE INDEX PARTITIONS
-- ============================================================================

PROMPT
PROMPT [12] UNUSABLE INDEX PARTITIONS
PROMPT ============================================================================

SELECT
    index_owner,
    index_name,
    partition_name,
    tablespace_name,
    status
FROM dba_ind_partitions
WHERE status <> 'USABLE'
ORDER BY index_owner, index_name, partition_name;


-- ============================================================================
-- 13. LARGEST INDEX PARTITIONS
-- ============================================================================

PROMPT
PROMPT [13] LARGEST INDEX PARTITIONS
PROMPT ============================================================================

SELECT
    owner,
    segment_name AS index_name,
    partition_name,
    tablespace_name,
    ROUND(
        bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM dba_segments
WHERE segment_type = 'INDEX PARTITION'
ORDER BY bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 14. LARGEST INDEX SUBPARTITIONS
-- ============================================================================

PROMPT
PROMPT [14] LARGEST INDEX SUBPARTITIONS
PROMPT ============================================================================

SELECT
    owner,
    segment_name AS index_name,
    partition_name,
    segment_type,
    tablespace_name,
    ROUND(
        bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM dba_segments
WHERE segment_type = 'INDEX SUBPARTITION'
ORDER BY bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 15. INDEXES WITH HIGH BLEVEL
-- ============================================================================

PROMPT
PROMPT [15] INDEXES WITH HIGH BLEVEL
PROMPT ============================================================================

SELECT
    owner,
    index_name,
    table_name,
    index_type,
    blevel,
    leaf_blocks,
    distinct_keys,
    clustering_factor,
    status,
    TO_CHAR(
        last_analyzed,
        'YYYY-MM-DD HH24:MI'
    ) AS last_analyzed
FROM dba_indexes
WHERE blevel >= 4
ORDER BY blevel DESC, leaf_blocks DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 16. INDEXES WITH HIGH CLUSTERING FACTOR
-- ============================================================================

PROMPT
PROMPT [16] INDEXES WITH HIGH CLUSTERING FACTOR
PROMPT ============================================================================

SELECT
    owner,
    index_name,
    table_name,
    blevel,
    leaf_blocks,
    distinct_keys,
    clustering_factor,
    num_rows,
    status
FROM dba_indexes
WHERE clustering_factor IS NOT NULL
ORDER BY clustering_factor DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 17. INDEXES WITH OLD / MISSING STATISTICS
-- ============================================================================

PROMPT
PROMPT [17] INDEXES WITH OLD / MISSING STATISTICS
PROMPT ============================================================================

SELECT
    i.owner,
    i.index_name,
    i.table_name,
    ROUND(
        s.bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    i.status,
    TO_CHAR(
        i.last_analyzed,
        'YYYY-MM-DD HH24:MI'
    ) AS last_analyzed,
    CASE
        WHEN i.last_analyzed IS NULL
            THEN 'MISSING'
        WHEN i.last_analyzed < SYSDATE - 30
            THEN 'OLDER_THAN_30_DAYS'
        WHEN i.last_analyzed < SYSDATE - 7
            THEN 'OLDER_THAN_7_DAYS'
        ELSE 'RECENT'
    END AS stats_status
FROM dba_indexes i
JOIN dba_segments s
  ON s.owner = i.owner
 AND s.segment_name = i.index_name
WHERE s.segment_type = 'INDEX'
ORDER BY s.bytes DESC;


-- ============================================================================
-- 18. INDEXES BY TYPE
-- ============================================================================

PROMPT
PROMPT [18] INDEX SIZE BY INDEX TYPE
PROMPT ============================================================================

SELECT
    i.index_type,
    COUNT(*) AS index_count,
    ROUND(
        SUM(NVL(s.bytes, 0))
        / 1024 / 1024 / 1024,
        2
    ) AS total_gb
FROM dba_indexes i
LEFT JOIN dba_segments s
  ON s.owner = i.owner
 AND s.segment_name = i.index_name
 AND s.segment_type = 'INDEX'
GROUP BY i.index_type
ORDER BY SUM(NVL(s.bytes, 0)) DESC;


-- ============================================================================
-- 19. INDEXES BY OWNER AND TYPE
-- ============================================================================

PROMPT
PROMPT [19] INDEX SIZE BY OWNER AND TYPE
PROMPT ============================================================================

SELECT
    i.owner,
    i.index_type,
    COUNT(*) AS index_count,
    ROUND(
        SUM(NVL(s.bytes, 0))
        / 1024 / 1024 / 1024,
        2
    ) AS total_gb
FROM dba_indexes i
LEFT JOIN dba_segments s
  ON s.owner = i.owner
 AND s.segment_name = i.index_name
 AND s.segment_type = 'INDEX'
GROUP BY
    i.owner,
    i.index_type
ORDER BY SUM(NVL(s.bytes, 0)) DESC;


-- ============================================================================
-- 20. LARGE INDEXES WITH STATUS
-- ============================================================================

PROMPT
PROMPT [20] LARGE INDEX HEALTH VIEW
PROMPT ============================================================================

SELECT
    i.owner,
    i.index_name,
    i.table_name,
    ROUND(
        s.bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    i.status,
    CASE
        WHEN i.status <> 'VALID'
            THEN 'REVIEW'
        WHEN s.bytes >= 100 * 1024 * 1024 * 1024
            THEN 'REVIEW'
        WHEN s.bytes >= 50 * 1024 * 1024 * 1024
            THEN 'WATCH'
        ELSE 'NORMAL'
    END AS health_status
FROM dba_indexes i
JOIN dba_segments s
  ON s.owner = i.owner
 AND s.segment_name = i.index_name
WHERE s.segment_type = 'INDEX'
ORDER BY s.bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 21. TOP INDEXES BY DATABASE SPACE CONSUMPTION
-- ============================================================================

PROMPT
PROMPT [21] TOP INDEXES BY DATABASE SPACE CONSUMPTION
PROMPT ============================================================================

SELECT
    owner,
    segment_name AS index_name,
    tablespace_name,
    ROUND(
        bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    ROUND(
        bytes /
        NULLIF(
            SUM(bytes) OVER (),
            0
        ) * 100,
        2
    ) AS database_space_pct
FROM dba_segments
WHERE segment_type IN
      ('INDEX', 'INDEX PARTITION', 'INDEX SUBPARTITION')
ORDER BY bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 22. QUICK DBA CHECK
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT QUICK LARGEST INDEX CHECK
PROMPT ============================================================================

SELECT
    owner,
    segment_name AS index_name,
    tablespace_name,
    ROUND(
        bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM dba_segments
WHERE segment_type = 'INDEX'
ORDER BY bytes DESC
FETCH FIRST 20 ROWS ONLY;


-- ============================================================================
-- DBA CHECKLIST
-- ============================================================================
--
-- 1. Identify the largest indexes.
-- 2. Check which tables are consuming the most index space.
-- 3. Compare index size against the associated table size.
-- 4. Review unusually large index footprints.
-- 5. Check unusable indexes after partition maintenance or deployments.
-- 6. Review index partition/subpartition sizes.
-- 7. Check statistics freshness for large indexes.
-- 8. Review BLEVEL and clustering factor as diagnostic information.
-- 9. Correlate index growth with segment_growth.sql.
-- 10. Check tablespace and ASM capacity before adding/rebuilding indexes.
--
-- IMPORTANT:
-- * DBA_SEGMENTS.BYTES represents allocated segment space.
-- * DBA_INDEXES statistics depend on when statistics were collected.
-- * A large index is not automatically a performance problem.
-- * High BLEVEL alone does not automatically mean an index must be rebuilt.
-- * High clustering factor is a diagnostic statistic, not an automatic
--   rebuild recommendation.
-- * Partitioned indexes have separate partition/subpartition segments.
-- * Do not rebuild or drop indexes based on size alone.
-- * Size thresholds in this script are DBA Toolkit heuristics.
-- * This script is READ-ONLY.
--
-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
 
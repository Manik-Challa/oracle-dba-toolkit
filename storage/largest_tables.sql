-- ============================================================================
-- Oracle DBA Toolkit
-- File   : largest_tables.sql
-- Purpose: Identify the largest tables in the Oracle database
-- Author : Manik Challa
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN owner             FORMAT A25
COLUMN table_name        FORMAT A40
COLUMN tablespace_name   FORMAT A30
COLUMN segment_type      FORMAT A20
COLUMN size_gb           FORMAT 999,999,990.99
COLUMN size_mb           FORMAT 999,999,990.99
COLUMN num_rows          FORMAT 999,999,999,999,999
COLUMN avg_row_len       FORMAT 999,999,990
COLUMN blocks            FORMAT 999,999,999,999
COLUMN partitions        FORMAT 999,999
COLUMN last_analyzed     FORMAT A20
COLUMN status            FORMAT A12

PROMPT
PROMPT ============================================================================
PROMPT ORACLE DBA TOOLKIT - LARGEST TABLES
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
-- 2. TOP 50 LARGEST TABLES BY SEGMENT SIZE
-- ============================================================================

PROMPT
PROMPT [2] TOP 50 LARGEST TABLES
PROMPT ============================================================================

SELECT
    owner,
    segment_name AS table_name,
    tablespace_name,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM dba_segments
WHERE segment_type = 'TABLE'
ORDER BY bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 3. TABLE SIZE WITH STATISTICS
-- ============================================================================

PROMPT
PROMPT [3] LARGEST TABLES WITH TABLE STATISTICS
PROMPT ============================================================================

SELECT
    t.owner,
    t.table_name,
    t.tablespace_name,
    ROUND(
        NVL(s.bytes, 0) / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    t.num_rows,
    t.avg_row_len,
    t.blocks,
    TO_CHAR(t.last_analyzed, 'YYYY-MM-DD HH24:MI') AS last_analyzed
FROM dba_tables t
LEFT JOIN
(
    SELECT
        owner,
        segment_name,
        SUM(bytes) AS bytes
    FROM dba_segments
    WHERE segment_type = 'TABLE'
    GROUP BY owner, segment_name
) s
    ON s.owner = t.owner
   AND s.segment_name = t.table_name
WHERE t.temporary = 'N'
ORDER BY NVL(s.bytes, 0) DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 4. TABLES LARGER THAN 10 GB
-- ============================================================================

PROMPT
PROMPT [4] TABLES LARGER THAN 10 GB
PROMPT ============================================================================

SELECT
    owner,
    segment_name AS table_name,
    tablespace_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    CASE
        WHEN bytes >= 100 * 1024 * 1024 * 1024 THEN 'REVIEW'
        WHEN bytes >= 50 * 1024 * 1024 * 1024  THEN 'WATCH'
        ELSE 'NORMAL'
    END AS status
FROM dba_segments
WHERE segment_type = 'TABLE'
  AND bytes >= 10 * 1024 * 1024 * 1024
ORDER BY bytes DESC;


-- ============================================================================
-- 5. TABLE SIZE BY OWNER
-- ============================================================================

PROMPT
PROMPT [5] TABLE SIZE BY OWNER
PROMPT ============================================================================

SELECT
    owner,
    COUNT(*) AS table_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_gb,
    ROUND(
        AVG(bytes) / 1024 / 1024 / 1024,
        2
    ) AS avg_table_gb
FROM dba_segments
WHERE segment_type = 'TABLE'
GROUP BY owner
ORDER BY SUM(bytes) DESC;


-- ============================================================================
-- 6. TABLE SIZE BY TABLESPACE
-- ============================================================================

PROMPT
PROMPT [6] TABLE SIZE BY TABLESPACE
PROMPT ============================================================================

SELECT
    tablespace_name,
    COUNT(*) AS table_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_gb
FROM dba_segments
WHERE segment_type = 'TABLE'
GROUP BY tablespace_name
ORDER BY SUM(bytes) DESC;


-- ============================================================================
-- 7. LARGEST TABLES BY DATA BLOCKS
-- ============================================================================

PROMPT
PROMPT [7] LARGEST TABLES BY BLOCKS
PROMPT ============================================================================

SELECT
    owner,
    table_name,
    tablespace_name,
    num_rows,
    blocks,
    ROUND(blocks * 8 / 1024, 2) AS approx_mb,
    TO_CHAR(last_analyzed, 'YYYY-MM-DD HH24:MI') AS last_analyzed
FROM dba_tables
WHERE temporary = 'N'
  AND blocks IS NOT NULL
ORDER BY blocks DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 8. LARGEST TABLES BY ROW COUNT
-- ============================================================================

PROMPT
PROMPT [8] LARGEST TABLES BY ROW COUNT
PROMPT ============================================================================

SELECT
    owner,
    table_name,
    tablespace_name,
    num_rows,
    ROUND(
        NVL(avg_row_len, 0) / 1024,
        2
    ) AS avg_row_kb,
    blocks,
    TO_CHAR(last_analyzed, 'YYYY-MM-DD HH24:MI') AS last_analyzed
FROM dba_tables
WHERE temporary = 'N'
  AND num_rows IS NOT NULL
ORDER BY num_rows DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 9. LARGEST PARTITIONED TABLES
-- ============================================================================

PROMPT
PROMPT [9] LARGEST PARTITIONED TABLES
PROMPT ============================================================================

SELECT
    owner,
    segment_name AS table_name,
    COUNT(*) AS partition_segments,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_gb
FROM dba_segments
WHERE segment_type = 'TABLE PARTITION'
GROUP BY owner, segment_name
ORDER BY SUM(bytes) DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 10. LARGEST TABLE PARTITIONS
-- ============================================================================

PROMPT
PROMPT [10] LARGEST TABLE PARTITIONS
PROMPT ============================================================================

SELECT
    s.owner,
    s.segment_name AS table_name,
    s.partition_name,
    s.tablespace_name,
    ROUND(s.bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM dba_segments s
WHERE s.segment_type = 'TABLE PARTITION'
ORDER BY s.bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 11. LARGEST LOB SEGMENTS
-- ============================================================================

PROMPT
PROMPT [11] LARGEST LOB SEGMENTS ASSOCIATED WITH TABLES
PROMPT ============================================================================

SELECT
    l.owner,
    l.table_name,
    l.column_name,
    l.segment_name,
    l.tablespace_name,
    ROUND(
        NVL(s.bytes, 0) / 1024 / 1024 / 1024,
        2
    ) AS lob_size_gb
FROM dba_lobs l
LEFT JOIN dba_segments s
    ON s.owner = l.owner
   AND s.segment_name = l.segment_name
WHERE s.segment_type LIKE 'LOB%'
ORDER BY s.bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 12. TABLE + INDEX SIZE COMPARISON
-- ============================================================================

PROMPT
PROMPT [12] TABLE SIZE VS INDEX SIZE
PROMPT ============================================================================

WITH table_size AS
(
    SELECT
        owner,
        segment_name AS table_name,
        SUM(bytes) AS table_bytes
    FROM dba_segments
    WHERE segment_type IN ('TABLE', 'TABLE PARTITION', 'TABLE SUBPARTITION')
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
    GROUP BY i.table_owner, i.table_name
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
        (t.table_bytes + NVL(i.index_bytes, 0))
        / 1024 / 1024 / 1024,
        2
    ) AS total_gb,
    ROUND(
        CASE
            WHEN t.table_bytes > 0
            THEN NVL(i.index_bytes, 0) / t.table_bytes * 100
        END,
        2
    ) AS index_to_table_pct
FROM table_size t
LEFT JOIN index_size i
    ON i.owner = t.owner
   AND i.table_name = t.table_name
ORDER BY
    (t.table_bytes + NVL(i.index_bytes, 0)) DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 13. TABLES WITH VERY LARGE INDEX FOOTPRINT
-- ============================================================================

PROMPT
PROMPT [13] TABLES WHERE INDEX SIZE EXCEEDS TABLE SIZE
PROMPT ============================================================================

WITH table_size AS
(
    SELECT
        owner,
        segment_name AS table_name,
        SUM(bytes) AS table_bytes
    FROM dba_segments
    WHERE segment_type IN ('TABLE', 'TABLE PARTITION', 'TABLE SUBPARTITION')
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
    GROUP BY i.table_owner, i.table_name
)
SELECT
    t.owner,
    t.table_name,
    ROUND(t.table_bytes / 1024 / 1024 / 1024, 2) AS table_gb,
    ROUND(i.index_bytes / 1024 / 1024 / 1024, 2) AS index_gb,
    ROUND(
        i.index_bytes / NULLIF(t.table_bytes, 0) * 100,
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
-- 14. TABLES WITH STALE STATISTICS
-- ============================================================================

PROMPT
PROMPT [14] LARGE TABLES WITH OLD / MISSING STATISTICS
PROMPT ============================================================================

SELECT
    t.owner,
    t.table_name,
    t.num_rows,
    ROUND(
        NVL(s.bytes, 0) / 1024 / 1024 / 1024,
        2
    ) AS size_gb,
    TO_CHAR(t.last_analyzed, 'YYYY-MM-DD HH24:MI') AS last_analyzed,
    CASE
        WHEN t.last_analyzed IS NULL
            THEN 'MISSING'
        WHEN t.last_analyzed < SYSDATE - 30
            THEN 'OLDER_THAN_30_DAYS'
        WHEN t.last_analyzed < SYSDATE - 7
            THEN 'OLDER_THAN_7_DAYS'
        ELSE 'RECENT'
    END AS stats_status
FROM dba_tables t
LEFT JOIN
(
    SELECT
        owner,
        segment_name,
        SUM(bytes) AS bytes
    FROM dba_segments
    WHERE segment_type = 'TABLE'
    GROUP BY owner, segment_name
) s
    ON s.owner = t.owner
   AND s.segment_name = t.table_name
WHERE t.temporary = 'N'
  AND NVL(s.bytes, 0) >= 10 * 1024 * 1024 * 1024
ORDER BY NVL(s.bytes, 0) DESC;


-- ============================================================================
-- 15. EMPTY / VERY SMALL TABLES
-- ============================================================================

PROMPT
PROMPT [15] EMPTY OR VERY SMALL TABLES
PROMPT ============================================================================

SELECT
    owner,
    table_name,
    tablespace_name,
    num_rows,
    ROUND(
        NVL(s.bytes, 0) / 1024 / 1024,
        2
    ) AS size_mb,
    TO_CHAR(last_analyzed, 'YYYY-MM-DD HH24:MI') AS last_analyzed
FROM dba_tables t
LEFT JOIN
(
    SELECT
        owner,
        segment_name,
        SUM(bytes) AS bytes
    FROM dba_segments
    WHERE segment_type = 'TABLE'
    GROUP BY owner, segment_name
) s
    ON s.owner = t.owner
   AND s.segment_name = t.table_name
WHERE t.temporary = 'N'
  AND NVL(s.bytes, 0) < 10 * 1024 * 1024
ORDER BY NVL(s.bytes, 0) ASC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 16. TABLES BY SIZE CATEGORY
-- ============================================================================

PROMPT
PROMPT [16] TABLE SIZE DISTRIBUTION
PROMPT ============================================================================

SELECT
    CASE
        WHEN bytes >= 100 * 1024 * 1024 * 1024 THEN '>= 100 GB'
        WHEN bytes >= 50  * 1024 * 1024 * 1024 THEN '50 - 100 GB'
        WHEN bytes >= 10  * 1024 * 1024 * 1024 THEN '10 - 50 GB'
        WHEN bytes >= 1   * 1024 * 1024 * 1024 THEN '1 - 10 GB'
        ELSE '< 1 GB'
    END AS size_category,
    COUNT(*) AS table_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_gb
FROM dba_segments
WHERE segment_type = 'TABLE'
GROUP BY
    CASE
        WHEN bytes >= 100 * 1024 * 1024 * 1024 THEN '>= 100 GB'
        WHEN bytes >= 50  * 1024 * 1024 * 1024 THEN '50 - 100 GB'
        WHEN bytes >= 10  * 1024 * 1024 * 1024 THEN '10 - 50 GB'
        WHEN bytes >= 1   * 1024 * 1024 * 1024 THEN '1 - 10 GB'
        ELSE '< 1 GB'
    END
ORDER BY MIN(bytes) DESC;


-- ============================================================================
-- 17. TOP TABLES CONSUMING DATABASE SEGMENT SPACE
-- ============================================================================

PROMPT
PROMPT [17] TOP TABLES BY DATABASE SPACE CONSUMPTION
PROMPT ============================================================================

SELECT
    owner,
    segment_name AS table_name,
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
WHERE segment_type = 'TABLE'
ORDER BY bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 18. LARGEST TABLES BY SCHEMA - TOP 5 PER OWNER
-- ============================================================================

PROMPT
PROMPT [18] TOP 5 TABLES PER OWNER
PROMPT ============================================================================

SELECT
    owner,
    table_name,
    size_gb
FROM
(
    SELECT
        owner,
        segment_name AS table_name,
        ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
        ROW_NUMBER() OVER
        (
            PARTITION BY owner
            ORDER BY bytes DESC
        ) AS rn
    FROM dba_segments
    WHERE segment_type = 'TABLE'
)
WHERE rn <= 5
ORDER BY owner, size_gb DESC;


-- ============================================================================
-- 19. LARGEST TABLES - QUICK HEALTH VIEW
-- ============================================================================

PROMPT
PROMPT [19] LARGEST TABLE HEALTH VIEW
PROMPT ============================================================================

SELECT
    owner,
    segment_name AS table_name,
    tablespace_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    CASE
        WHEN bytes >= 100 * 1024 * 1024 * 1024
            THEN 'REVIEW'
        WHEN bytes >= 50 * 1024 * 1024 * 1024
            THEN 'WATCH'
        ELSE 'NORMAL'
    END AS status
FROM dba_segments
WHERE segment_type = 'TABLE'
ORDER BY bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 20. QUICK DBA CHECK
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT QUICK LARGEST TABLE CHECK
PROMPT ============================================================================

SELECT
    owner,
    segment_name AS table_name,
    tablespace_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM dba_segments
WHERE segment_type = 'TABLE'
ORDER BY bytes DESC
FETCH FIRST 20 ROWS ONLY;


-- ============================================================================
-- DBA CHECKLIST
-- ============================================================================
--
-- 1. Identify the largest tables.
-- 2. Check whether table growth is expected.
-- 3. Correlate large tables with segment_growth.sql.
-- 4. Check partitioned tables and individual partition sizes.
-- 5. Check associated index and LOB sizes.
-- 6. Review tablespace capacity and AUTOEXTEND headroom.
-- 7. Check statistics freshness on large tables.
-- 8. Investigate sudden growth using AWR/application activity.
-- 9. Review large tables before storage expansion.
-- 10. Do not shrink, move, truncate, or delete data based on size alone.
--
-- IMPORTANT:
-- * DBA_SEGMENTS reports allocated segment space.
-- * DBA_TABLES.NUM_ROWS depends on optimizer statistics and may be stale.
-- * Partitioned tables are represented by partition segments.
-- * LOB segments are separate from the base table segment.
-- * Index space is separate from table space.
-- * A large table is not automatically a performance problem.
-- * Size thresholds in this script are DBA Toolkit heuristics.
-- * This script is READ-ONLY.
--
-- ============================================================================
-- END OF SCRIPT
-- ============================================================================
 
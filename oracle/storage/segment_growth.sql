-- ============================================================================
-- Oracle DBA Toolkit
-- File   : segment_growth.sql
-- Purpose: Monitor segment size and historical growth
-- Author : Manik Challa
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN owner              FORMAT A25
COLUMN segment_name       FORMAT A40
COLUMN segment_type       FORMAT A25
COLUMN tablespace_name    FORMAT A30
COLUMN partition_name    FORMAT A30
COLUMN size_gb            FORMAT 999,999,990.99
COLUMN size_mb            FORMAT 999,999,990.99
COLUMN growth_gb          FORMAT 999,999,990.99
COLUMN growth_mb          FORMAT 999,999,990.99
COLUMN growth_pct         FORMAT 990.99
COLUMN avg_daily_gb       FORMAT 999,990.99
COLUMN first_sample       FORMAT A20
COLUMN last_sample        FORMAT A20
COLUMN days_observed      FORMAT 999,990.99
COLUMN status             FORMAT A12

PROMPT
PROMPT ============================================================================
PROMPT SEGMENT GROWTH MONITORING
PROMPT ============================================================================

-- ============================================================================
-- 1. DATABASE INFORMATION
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
-- 2. CURRENT SEGMENT SIZE
-- ============================================================================

PROMPT
PROMPT [2] CURRENT SEGMENT SIZE
PROMPT ============================================================================

SELECT
    owner,
    segment_name,
    segment_type,
    tablespace_name,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM (
    SELECT
        owner,
        segment_name,
        segment_type,
        tablespace_name,
        bytes
    FROM dba_segments
    ORDER BY bytes DESC
)
WHERE ROWNUM <= 50;


-- ============================================================================
-- 3. LARGEST TABLE SEGMENTS
-- ============================================================================

PROMPT
PROMPT [3] LARGEST TABLE SEGMENTS
PROMPT ============================================================================

SELECT
    owner,
    segment_name,
    tablespace_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM dba_segments
WHERE segment_type LIKE 'TABLE%'
ORDER BY bytes DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================================
-- 4. LARGEST INDEX SEGMENTS
-- ============================================================================

PROMPT
PROMPT [4] LARGEST INDEX SEGMENTS
PROMPT ============================================================================

SELECT
    owner,
    segment_name,
    tablespace_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM dba_segments
WHERE segment_type LIKE 'INDEX%'
ORDER BY bytes DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================================
-- 5. LARGEST LOB SEGMENTS
-- ============================================================================

PROMPT
PROMPT [5] LARGEST LOB SEGMENTS
PROMPT ============================================================================

SELECT
    owner,
    segment_name,
    segment_type,
    tablespace_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM dba_segments
WHERE segment_type LIKE 'LOB%'
ORDER BY bytes DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================================
-- 6. SEGMENT SIZE BY OWNER
-- ============================================================================

PROMPT
PROMPT [6] SEGMENT SIZE BY OWNER
PROMPT ============================================================================

SELECT
    owner,
    COUNT(*) AS segment_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS total_gb
FROM dba_segments
GROUP BY owner
ORDER BY SUM(bytes) DESC;


-- ============================================================================
-- 7. SEGMENT SIZE BY TYPE
-- ============================================================================

PROMPT
PROMPT [7] SEGMENT SIZE BY SEGMENT TYPE
PROMPT ============================================================================

SELECT
    segment_type,
    COUNT(*) AS segment_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS total_gb
FROM dba_segments
GROUP BY segment_type
ORDER BY SUM(bytes) DESC;


-- ============================================================================
-- 8. SEGMENT SIZE BY TABLESPACE
-- ============================================================================

PROMPT
PROMPT [8] SEGMENT SIZE BY TABLESPACE
PROMPT ============================================================================

SELECT
    tablespace_name,
    COUNT(*) AS segment_count,
    ROUND(SUM(bytes) / 1024 / 1024 / 1024, 2) AS total_gb
FROM dba_segments
GROUP BY tablespace_name
ORDER BY SUM(bytes) DESC;


-- ============================================================================
-- 9. AWR SEGMENT GROWTH AVAILABILITY
-- ============================================================================

PROMPT
PROMPT [9] AWR SEGMENT STATISTICS AVAILABILITY
PROMPT ============================================================================

SELECT
    COUNT(*) AS snapshot_rows,
    MIN(begin_interval_time) AS first_snapshot,
    MAX(end_interval_time) AS last_snapshot
FROM dba_hist_snapshot;


-- ============================================================================
-- 10. HISTORICAL SEGMENT GROWTH
--     Requires AWR views / appropriate privileges.
-- ============================================================================

PROMPT
PROMPT [10] HISTORICAL SEGMENT GROWTH
PROMPT ============================================================================

WITH segment_samples AS
(
    SELECT
        ss.owner,
        ss.object_name,
        ss.subobject_name,
        ss.object_type,
        ss.tablespace_name,
        s.begin_interval_time,
        s.snap_id,
        ss.space_used_total
    FROM dba_hist_seg_stat ss
    JOIN dba_hist_snapshot s
      ON s.snap_id = ss.snap_id
     AND s.dbid = ss.dbid
     AND s.instance_number = ss.instance_number
    WHERE s.begin_interval_time >= SYSDATE - 7
      AND ss.space_used_total IS NOT NULL
),
segment_first_last AS
(
    SELECT
        owner,
        object_name,
        subobject_name,
        object_type,
        tablespace_name,
        MIN(begin_interval_time) AS first_sample,
        MAX(begin_interval_time) AS last_sample,
        MIN(space_used_total) KEEP
            (DENSE_RANK FIRST ORDER BY begin_interval_time) AS first_bytes,
        MAX(space_used_total) KEEP
            (DENSE_RANK LAST ORDER BY begin_interval_time) AS last_bytes
    FROM segment_samples
    GROUP BY
        owner,
        object_name,
        subobject_name,
        object_type,
        tablespace_name
)
SELECT
    owner,
    object_name AS segment_name,
    object_type AS segment_type,
    tablespace_name,
    ROUND(first_bytes / 1024 / 1024 / 1024, 2) AS first_gb,
    ROUND(last_bytes / 1024 / 1024 / 1024, 2) AS last_gb,
    ROUND((last_bytes - first_bytes) / 1024 / 1024 / 1024, 2)
        AS growth_gb,
    ROUND(
        CASE
            WHEN first_bytes > 0
            THEN ((last_bytes - first_bytes) / first_bytes) * 100
        END,
        2
    ) AS growth_pct,
    TO_CHAR(first_sample, 'YYYY-MM-DD HH24:MI') AS first_sample,
    TO_CHAR(last_sample, 'YYYY-MM-DD HH24:MI') AS last_sample
FROM segment_first_last
WHERE last_bytes > first_bytes
ORDER BY (last_bytes - first_bytes) DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 11. FASTEST GROWING SEGMENTS
-- ============================================================================

PROMPT
PROMPT [11] FASTEST GROWING SEGMENTS BY DAILY RATE
PROMPT ============================================================================

WITH segment_samples AS
(
    SELECT
        ss.owner,
        ss.object_name,
        ss.subobject_name,
        ss.object_type,
        ss.tablespace_name,
        s.begin_interval_time,
        ss.space_used_total
    FROM dba_hist_seg_stat ss
    JOIN dba_hist_snapshot s
      ON s.snap_id = ss.snap_id
     AND s.dbid = ss.dbid
     AND s.instance_number = ss.instance_number
    WHERE s.begin_interval_time >= SYSDATE - 7
      AND ss.space_used_total IS NOT NULL
),
growth_data AS
(
    SELECT
        owner,
        object_name,
        object_type,
        tablespace_name,
        MIN(begin_interval_time) AS first_sample,
        MAX(begin_interval_time) AS last_sample,
        MIN(space_used_total) KEEP
            (DENSE_RANK FIRST ORDER BY begin_interval_time) AS first_bytes,
        MAX(space_used_total) KEEP
            (DENSE_RANK LAST ORDER BY begin_interval_time) AS last_bytes
    FROM segment_samples
    GROUP BY
        owner,
        object_name,
        object_type,
        tablespace_name
)
SELECT
    owner,
    object_name AS segment_name,
    object_type AS segment_type,
    tablespace_name,
    ROUND(
        (last_bytes - first_bytes) / 1024 / 1024 / 1024,
        2
    ) AS growth_gb,
    ROUND(
        (last_bytes - first_bytes)
        / NULLIF(
            (last_sample - first_sample),
            0
        ),
        2
    ) AS growth_bytes_per_day
FROM growth_data
WHERE last_bytes > first_bytes
ORDER BY (last_bytes - first_bytes)
         / NULLIF((last_sample - first_sample), 0) DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 12. SEGMENTS GROWING MORE THAN 10%
-- ============================================================================

PROMPT
PROMPT [12] SEGMENTS WITH >10% GROWTH
PROMPT ============================================================================

WITH growth_data AS
(
    SELECT
        ss.owner,
        ss.object_name,
        ss.object_type,
        ss.tablespace_name,
        MIN(s.begin_interval_time) AS first_sample,
        MAX(s.begin_interval_time) AS last_sample,
        MIN(ss.space_used_total) KEEP
            (DENSE_RANK FIRST ORDER BY s.begin_interval_time) AS first_bytes,
        MAX(ss.space_used_total) KEEP
            (DENSE_RANK LAST ORDER BY s.begin_interval_time) AS last_bytes
    FROM dba_hist_seg_stat ss
    JOIN dba_hist_snapshot s
      ON s.snap_id = ss.snap_id
     AND s.dbid = ss.dbid
     AND s.instance_number = ss.instance_number
    WHERE s.begin_interval_time >= SYSDATE - 7
      AND ss.space_used_total IS NOT NULL
    GROUP BY
        ss.owner,
        ss.object_name,
        ss.object_type,
        ss.tablespace_name
)
SELECT
    owner,
    object_name AS segment_name,
    object_type AS segment_type,
    tablespace_name,
    ROUND(first_bytes / 1024 / 1024 / 1024, 2) AS first_gb,
    ROUND(last_bytes / 1024 / 1024 / 1024, 2) AS last_gb,
    ROUND(
        (last_bytes - first_bytes) / 1024 / 1024 / 1024,
        2
    ) AS growth_gb,
    ROUND(
        ((last_bytes - first_bytes) / NULLIF(first_bytes, 0)) * 100,
        2
    ) AS growth_pct
FROM growth_data
WHERE last_bytes > first_bytes
  AND first_bytes > 0
  AND ((last_bytes - first_bytes) / first_bytes) * 100 >= 10
ORDER BY growth_pct DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 13. SEGMENTS GROWING MORE THAN 1 GB
-- ============================================================================

PROMPT
PROMPT [13] SEGMENTS WITH >1 GB GROWTH
PROMPT ============================================================================

WITH growth_data AS
(
    SELECT
        ss.owner,
        ss.object_name,
        ss.object_type,
        ss.tablespace_name,
        MIN(s.begin_interval_time) AS first_sample,
        MAX(s.begin_interval_time) AS last_sample,
        MIN(ss.space_used_total) KEEP
            (DENSE_RANK FIRST ORDER BY s.begin_interval_time) AS first_bytes,
        MAX(ss.space_used_total) KEEP
            (DENSE_RANK LAST ORDER BY s.begin_interval_time) AS last_bytes
    FROM dba_hist_seg_stat ss
    JOIN dba_hist_snapshot s
      ON s.snap_id = ss.snap_id
     AND s.dbid = ss.dbid
     AND s.instance_number = ss.instance_number
    WHERE s.begin_interval_time >= SYSDATE - 7
      AND ss.space_used_total IS NOT NULL
    GROUP BY
        ss.owner,
        ss.object_name,
        ss.object_type,
        ss.tablespace_name
)
SELECT
    owner,
    object_name AS segment_name,
    object_type AS segment_type,
    tablespace_name,
    ROUND(
        (last_bytes - first_bytes) / 1024 / 1024 / 1024,
        2
    ) AS growth_gb,
    ROUND(
        (last_bytes - first_bytes)
        / NULLIF(
            (last_sample - first_sample),
            0
        ),
        2
    ) AS growth_bytes_per_day
FROM growth_data
WHERE last_bytes - first_bytes >= 1024 * 1024 * 1024
ORDER BY (last_bytes - first_bytes) DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 14. SEGMENT GROWTH BY OWNER
-- ============================================================================

PROMPT
PROMPT [14] SEGMENT GROWTH BY OWNER - LAST 7 DAYS
PROMPT ============================================================================

WITH growth_data AS
(
    SELECT
        ss.owner,
        ss.object_name,
        MIN(s.begin_interval_time) AS first_sample,
        MAX(s.begin_interval_time) AS last_sample,
        MIN(ss.space_used_total) KEEP
            (DENSE_RANK FIRST ORDER BY s.begin_interval_time) AS first_bytes,
        MAX(ss.space_used_total) KEEP
            (DENSE_RANK LAST ORDER BY s.begin_interval_time) AS last_bytes
    FROM dba_hist_seg_stat ss
    JOIN dba_hist_snapshot s
      ON s.snap_id = ss.snap_id
     AND s.dbid = ss.dbid
     AND s.instance_number = ss.instance_number
    WHERE s.begin_interval_time >= SYSDATE - 7
      AND ss.space_used_total IS NOT NULL
    GROUP BY
        ss.owner,
        ss.object_name
)
SELECT
    owner,
    COUNT(*) AS segments_growing,
    ROUND(
        SUM(GREATEST(last_bytes - first_bytes, 0))
        / 1024 / 1024 / 1024,
        2
    ) AS growth_gb
FROM growth_data
GROUP BY owner
HAVING SUM(GREATEST(last_bytes - first_bytes, 0)) > 0
ORDER BY growth_gb DESC;


-- ============================================================================
-- 15. SEGMENT GROWTH BY TABLESPACE
-- ============================================================================

PROMPT
PROMPT [15] SEGMENT GROWTH BY TABLESPACE - LAST 7 DAYS
PROMPT ============================================================================

WITH growth_data AS
(
    SELECT
        ss.tablespace_name,
        ss.object_name,
        MIN(s.begin_interval_time) AS first_sample,
        MAX(s.begin_interval_time) AS last_sample,
        MIN(ss.space_used_total) KEEP
            (DENSE_RANK FIRST ORDER BY s.begin_interval_time) AS first_bytes,
        MAX(ss.space_used_total) KEEP
            (DENSE_RANK LAST ORDER BY s.begin_interval_time) AS last_bytes
    FROM dba_hist_seg_stat ss
    JOIN dba_hist_snapshot s
      ON s.snap_id = ss.snap_id
     AND s.dbid = ss.dbid
     AND s.instance_number = ss.instance_number
    WHERE s.begin_interval_time >= SYSDATE - 7
      AND ss.space_used_total IS NOT NULL
    GROUP BY
        ss.tablespace_name,
        ss.object_name
)
SELECT
    tablespace_name,
    COUNT(*) AS segments_growing,
    ROUND(
        SUM(GREATEST(last_bytes - first_bytes, 0))
        / 1024 / 1024 / 1024,
        2
    ) AS growth_gb
FROM growth_data
GROUP BY tablespace_name
HAVING SUM(GREATEST(last_bytes - first_bytes, 0)) > 0
ORDER BY growth_gb DESC;


-- ============================================================================
-- 16. CURRENT LARGE SEGMENTS WITH GROWTH POTENTIAL
-- ============================================================================

PROMPT
PROMPT [16] LARGE SEGMENTS - CURRENT SIZE
PROMPT ============================================================================

SELECT
    owner,
    segment_name,
    segment_type,
    tablespace_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    CASE
        WHEN bytes >= 1024 * 1024 * 1024 * 100
            THEN 'REVIEW'
        WHEN bytes >= 1024 * 1024 * 1024 * 50
            THEN 'WATCH'
        ELSE 'NORMAL'
    END AS status
FROM dba_segments
WHERE bytes >= 1024 * 1024 * 1024 * 10
ORDER BY bytes DESC
FETCH FIRST 50 ROWS ONLY;


-- ============================================================================
-- 17. SEGMENT TYPES CONTRIBUTING TO GROWTH
-- ============================================================================

PROMPT
PROMPT [17] GROWTH BY SEGMENT TYPE - LAST 7 DAYS
PROMPT ============================================================================

WITH growth_data AS
(
    SELECT
        ss.object_type,
        ss.object_name,
        MIN(s.begin_interval_time) AS first_sample,
        MAX(s.begin_interval_time) AS last_sample,
        MIN(ss.space_used_total) KEEP
            (DENSE_RANK FIRST ORDER BY s.begin_interval_time) AS first_bytes,
        MAX(ss.space_used_total) KEEP
            (DENSE_RANK LAST ORDER BY s.begin_interval_time) AS last_bytes
    FROM dba_hist_seg_stat ss
    JOIN dba_hist_snapshot s
      ON s.snap_id = ss.snap_id
     AND s.dbid = ss.dbid
     AND s.instance_number = ss.instance_number
    WHERE s.begin_interval_time >= SYSDATE - 7
      AND ss.space_used_total IS NOT NULL
    GROUP BY
        ss.object_type,
        ss.object_name
)
SELECT
    object_type AS segment_type,
    COUNT(*) AS segments_growing,
    ROUND(
        SUM(GREATEST(last_bytes - first_bytes, 0))
        / 1024 / 1024 / 1024,
        2
    ) AS growth_gb
FROM growth_data
GROUP BY object_type
HAVING SUM(GREATEST(last_bytes - first_bytes, 0)) > 0
ORDER BY growth_gb DESC;


-- ============================================================================
-- 18. SEGMENT GROWTH HEALTH CHECK
-- ============================================================================

PROMPT
PROMPT [18] SEGMENT GROWTH HEALTH CHECK
PROMPT ============================================================================

WITH growth_data AS
(
    SELECT
        ss.owner,
        ss.object_name,
        MIN(s.begin_interval_time) AS first_sample,
        MAX(s.begin_interval_time) AS last_sample,
        MIN(ss.space_used_total) KEEP
            (DENSE_RANK FIRST ORDER BY s.begin_interval_time) AS first_bytes,
        MAX(ss.space_used_total) KEEP
            (DENSE_RANK LAST ORDER BY s.begin_interval_time) AS last_bytes
    FROM dba_hist_seg_stat ss
    JOIN dba_hist_snapshot s
      ON s.snap_id = ss.snap_id
     AND s.dbid = ss.dbid
     AND s.instance_number = ss.instance_number
    WHERE s.begin_interval_time >= SYSDATE - 7
      AND ss.space_used_total IS NOT NULL
    GROUP BY
        ss.owner,
        ss.object_name
),
growth_summary AS
(
    SELECT
        COUNT(
            CASE
                WHEN last_bytes - first_bytes >=
                     10 * 1024 * 1024 * 1024
                THEN 1
            END
        ) AS large_growth_segments,
        SUM(
            CASE
                WHEN last_bytes > first_bytes
                THEN last_bytes - first_bytes
                ELSE 0
            END
        ) AS total_growth_bytes
    FROM growth_data
)
SELECT
    large_growth_segments,
    ROUND(
        total_growth_bytes / 1024 / 1024 / 1024,
        2
    ) AS total_growth_gb,
    CASE
        WHEN large_growth_segments > 10
            THEN 'REVIEW'
        WHEN large_growth_segments > 0
            THEN 'WATCH'
        ELSE 'HEALTHY'
    END AS status
FROM growth_summary;


-- ============================================================================
-- 19. QUICK DBA CHECK
-- ============================================================================

PROMPT
PROMPT ============================================================================
PROMPT QUICK SEGMENT GROWTH CHECK
PROMPT ============================================================================

SELECT
    owner,
    segment_name,
    segment_type,
    tablespace_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM dba_segments
ORDER BY bytes DESC
FETCH FIRST 20 ROWS ONLY;


-- ============================================================================
-- DBA CHECKLIST
-- ============================================================================
--
-- 1. Identify the segments growing fastest.
-- 2. Check whether growth is expected application activity.
-- 3. Correlate table growth with row counts and business transactions.
-- 4. Check index growth separately from table growth.
-- 5. Investigate large LOB segments.
-- 6. Check tablespace capacity and AUTOEXTEND headroom.
-- 7. Review partition growth for partitioned objects.
-- 8. Correlate sudden growth with batch jobs or deployments.
-- 9. Review historical AWR data before making capacity decisions.
-- 10. Check ASM/filesystem capacity before extending storage.
--
-- IMPORTANT:
-- * DBA_HIST_SEG_STAT requires appropriate AWR access/privileges.
-- * Historical growth depends on available AWR snapshots.
-- * A large segment is not automatically a problem.
-- * Growth can be normal and workload-driven.
-- * Linear growth estimates should be treated as approximate.
-- * This script is READ-ONLY and does not resize, shrink, move,
--   rebuild, or modify any segment.
--
-- ============================================================================
-- END OF SCRIPT
-- ============================================================================


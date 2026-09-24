-- ================================================================
-- Oracle DBA Toolkit
-- Tablespace Growth Monitoring
-- File: oracle/monitoring/tablespace_growth.sql
--
-- Purpose:
--   Monitor tablespace growth trends and identify rapidly growing
--   tablespaces that may require capacity planning.
--
-- Covers:
--   1. Database / instance information
--   2. Current tablespace allocation
--   3. Current used/free space
--   4. Tablespace growth using DBA_HIST_TBSPC_SPACE_USAGE
--   5. 24-hour growth
--   6. 7-day growth
--   7. Daily growth rate
--   8. Weekly growth rate
--   9. Rapidly growing tablespaces
--  10. Capacity forecast
--  11. Estimated days to 90% capacity
--  12. Estimated days to 95% capacity
--  13. Autoextend headroom
--  14. Tablespaces with limited headroom
--  15. Largest tablespaces
--  16. Growth summary
--
-- Read-only monitoring script.
-- Does NOT resize, add, or modify tablespaces/datafiles.
--
-- Historical sections require AWR views and appropriate licensing.
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

COLUMN TABLESPACE_NAME FORMAT A35
COLUMN CONTENTS FORMAT A15
COLUMN STATUS FORMAT A15
COLUMN BIGFILE FORMAT A10

COLUMN ALLOCATED_GB FORMAT 999,999,990.99
COLUMN USED_GB FORMAT 999,999,990.99
COLUMN FREE_GB FORMAT 999,999,990.99
COLUMN MAX_GB FORMAT 999,999,990.99
COLUMN USED_PCT FORMAT 990.99

COLUMN GROWTH_GB FORMAT 999,999,990.99
COLUMN DAILY_GROWTH_GB FORMAT 999,999,990.99
COLUMN WEEKLY_GROWTH_GB FORMAT 999,999,990.99
COLUMN GROWTH_PCT FORMAT 990.99
COLUMN DAYS_TO_90 FORMAT 999,990.9
COLUMN DAYS_TO_95 FORMAT 999,990.9
COLUMN HEADROOM_GB FORMAT 999,999,990.99

COLUMN SNAP_TIME FORMAT A20
COLUMN AUTOEXTENSIBLE FORMAT A15

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
PROMPT 2. CURRENT TABLESPACE CAPACITY
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
PROMPT 3. CURRENT TABLESPACE INFORMATION
PROMPT ================================================================

SELECT
    tablespace_name,
    status,
    contents,
    extent_management,
    bigfile
FROM dba_tablespaces
ORDER BY tablespace_name;


PROMPT
PROMPT ================================================================
PROMPT 4. TABLESPACE MAXIMUM CAPACITY
PROMPT ================================================================

SELECT
    tablespace_name,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS allocated_gb,
    ROUND(
        SUM(maxbytes) / 1024 / 1024 / 1024,
        2
    ) AS max_gb,
    ROUND(
        SUM(maxbytes - bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb
FROM dba_data_files
GROUP BY tablespace_name
ORDER BY headroom_gb ASC;


PROMPT
PROMPT ================================================================
PROMPT 5. AUTOEXTEND STATUS BY TABLESPACE
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
    ) AS non_autoextend_files,

    ROUND(
        SUM(maxbytes - bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb

FROM dba_data_files
GROUP BY tablespace_name
ORDER BY headroom_gb ASC;


PROMPT
PROMPT ================================================================
PROMPT 6. AWR TABLESPACE SNAPSHOT AVAILABILITY
PROMPT ================================================================

SELECT
    COUNT(*) AS snapshot_rows,
    MIN(snap_id) AS oldest_snap_id,
    MAX(snap_id) AS newest_snap_id,
    MIN(rtime) AS oldest_sample,
    MAX(rtime) AS newest_sample
FROM dba_hist_tbspc_space_usage;


PROMPT
PROMPT ================================================================
PROMPT 7. RECENT TABLESPACE GROWTH SAMPLES
PROMPT ================================================================

SELECT
    tablespace_id,
    snap_id,
    rtime AS snap_time,
    ROUND(
        tablespace_size * block_size
        / 1024 / 1024 / 1024,
        2
    ) AS allocated_gb,
    ROUND(
        tablespace_usedsize * block_size
        / 1024 / 1024 / 1024,
        2
    ) AS used_gb
FROM dba_hist_tbspc_space_usage
ORDER BY rtime DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 8. TABLESPACE GROWTH - LAST 24 HOURS
PROMPT ================================================================

WITH samples AS (
    SELECT
        tablespace_id,
        MIN(rtime) AS first_sample,
        MAX(rtime) AS last_sample,

        MIN(
            tablespace_usedsize * block_size
        ) AS first_used_blocks,

        MAX(
            tablespace_usedsize * block_size
        ) AS last_used_blocks
    FROM dba_hist_tbspc_space_usage
    WHERE rtime >= SYSDATE - 1
    GROUP BY tablespace_id
)
SELECT
    t.tablespace_name,

    ROUND(
        (s.last_used_blocks - s.first_used_blocks)
        / 1024 / 1024 / 1024,
        2
    ) AS growth_gb,

    ROUND(
        (
            (s.last_used_blocks - s.first_used_blocks)
            / NULLIF(
                (s.last_sample - s.first_sample),
                0
            )
        ) * 24
        / 1024 / 1024 / 1024,
        2
    ) AS daily_growth_gb,

    s.first_sample,
    s.last_sample

FROM samples s
JOIN dba_tablespaces t
    ON t.tablespace_id = s.tablespace_id
ORDER BY growth_gb DESC;


PROMPT
PROMPT ================================================================
PROMPT 9. TABLESPACE GROWTH - LAST 7 DAYS
PROMPT ================================================================

WITH samples AS (
    SELECT
        tablespace_id,
        MIN(rtime) AS first_sample,
        MAX(rtime) AS last_sample,

        MIN(
            tablespace_usedsize * block_size
        ) AS first_used_blocks,

        MAX(
            tablespace_usedsize * block_size
        ) AS last_used_blocks
    FROM dba_hist_tbspc_space_usage
    WHERE rtime >= SYSDATE - 7
    GROUP BY tablespace_id
)
SELECT
    t.tablespace_name,

    ROUND(
        (s.last_used_blocks - s.first_used_blocks)
        / 1024 / 1024 / 1024,
        2
    ) AS growth_gb,

    ROUND(
        (
            (s.last_used_blocks - s.first_used_blocks)
            / NULLIF(
                (s.last_sample - s.first_sample),
                0
            )
        ) * 24
        / 1024 / 1024 / 1024,
        2
    ) AS daily_growth_gb,

    ROUND(
        (
            (s.last_used_blocks - s.first_used_blocks)
            / NULLIF(
                (s.last_sample - s.first_sample),
                0
            )
        ) * 168
        / 1024 / 1024 / 1024,
        2
    ) AS weekly_growth_gb

FROM samples s
JOIN dba_tablespaces t
    ON t.tablespace_id = s.tablespace_id
ORDER BY growth_gb DESC;


PROMPT
PROMPT ================================================================
PROMPT 10. RAPIDLY GROWING TABLESPACES - LAST 7 DAYS
PROMPT ================================================================

WITH samples AS (
    SELECT
        tablespace_id,

        MIN(rtime) AS first_sample,
        MAX(rtime) AS last_sample,

        MIN(
            tablespace_usedsize * block_size
        ) AS first_used_blocks,

        MAX(
            tablespace_usedsize * block_size
        ) AS last_used_blocks
    FROM dba_hist_tbspc_space_usage
    WHERE rtime >= SYSDATE - 7
    GROUP BY tablespace_id
)
SELECT
    t.tablespace_name,

    ROUND(
        (s.last_used_blocks - s.first_used_blocks)
        / 1024 / 1024 / 1024,
        2
    ) AS growth_gb,

    ROUND(
        (
            s.last_used_blocks - s.first_used_blocks
        )
        / NULLIF(
            s.first_used_blocks,
            0
        ) * 100,
        2
    ) AS growth_pct

FROM samples s
JOIN dba_tablespaces t
    ON t.tablespace_id = s.tablespace_id
WHERE s.last_used_blocks > s.first_used_blocks
ORDER BY growth_gb DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 11. DAILY GROWTH RATE - LAST 7 DAYS
PROMPT ================================================================

WITH samples AS (
    SELECT
        tablespace_id,
        MIN(rtime) AS first_sample,
        MAX(rtime) AS last_sample,
        MIN(tablespace_usedsize * block_size) AS first_used,
        MAX(tablespace_usedsize * block_size) AS last_used
    FROM dba_hist_tbspc_space_usage
    WHERE rtime >= SYSDATE - 7
    GROUP BY tablespace_id
)
SELECT
    t.tablespace_name,

    ROUND(
        (
            s.last_used - s.first_used
        )
        / NULLIF(
            s.last_sample - s.first_sample,
            0
        )
        * 1
        / 1024 / 1024 / 1024,
        2
    ) AS daily_growth_gb

FROM samples s
JOIN dba_tablespaces t
    ON t.tablespace_id = s.tablespace_id
WHERE s.last_used > s.first_used
ORDER BY daily_growth_gb DESC;


PROMPT
PROMPT ================================================================
PROMPT 12. CURRENT CAPACITY VS 90% TARGET
PROMPT ================================================================

WITH ts AS (
    SELECT
        df.tablespace_name,

        SUM(df.bytes) AS allocated_bytes,

        SUM(df.maxbytes) AS max_bytes,

        SUM(
            df.bytes - NVL(fs.free_bytes, 0)
        ) AS used_bytes

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
)
SELECT
    tablespace_name,

    ROUND(
        used_bytes / 1024 / 1024 / 1024,
        2
    ) AS used_gb,

    ROUND(
        allocated_bytes / 1024 / 1024 / 1024,
        2
    ) AS allocated_gb,

    ROUND(
        max_bytes / 1024 / 1024 / 1024,
        2
    ) AS max_gb,

    ROUND(
        100 * used_bytes
        / NULLIF(max_bytes, 0),
        2
    ) AS used_pct_of_max

FROM ts
ORDER BY used_pct_of_max DESC;


PROMPT
PROMPT ================================================================
PROMPT 13. ESTIMATED DAYS TO 90% OF MAX CAPACITY
PROMPT ================================================================

WITH current_ts AS (
    SELECT
        df.tablespace_name,
        SUM(df.bytes) AS allocated_bytes,
        SUM(df.maxbytes) AS max_bytes,
        SUM(
            df.bytes - NVL(fs.free_bytes, 0)
        ) AS used_bytes
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
),
growth AS (
    SELECT
        tablespace_id,
        MIN(rtime) AS first_sample,
        MAX(rtime) AS last_sample,
        MIN(tablespace_usedsize * block_size) AS first_used,
        MAX(tablespace_usedsize * block_size) AS last_used
    FROM dba_hist_tbspc_space_usage
    WHERE rtime >= SYSDATE - 7
    GROUP BY tablespace_id
)
SELECT
    c.tablespace_name,

    ROUND(
        c.used_bytes / 1024 / 1024 / 1024,
        2
    ) AS used_gb,

    ROUND(
        c.max_bytes / 1024 / 1024 / 1024,
        2
    ) AS max_gb,

    ROUND(
        (
            (
                c.max_bytes * 0.90
            ) - c.used_bytes
        ) / 1024 / 1024 / 1024,
        2
    ) AS growth_required_gb,

    ROUND(
        (
            (
                (
                    c.max_bytes * 0.90
                ) - c.used_bytes
            )
            /
            NULLIF(
                (
                    g.last_used - g.first_used
                )
                /
                NULLIF(
                    g.last_sample - g.first_sample,
                    0
                )
                * 1,
                0
            )
        ),
        1
    ) AS days_to_90

FROM current_ts c
JOIN growth g
    ON g.tablespace_id = (
        SELECT tablespace_id
        FROM dba_tablespaces t
        WHERE t.tablespace_name = c.tablespace_name
    )
WHERE c.max_bytes > c.used_bytes
  AND g.last_used > g.first_used
ORDER BY days_to_90 ASC;


PROMPT
PROMPT ================================================================
PROMPT 14. ESTIMATED DAYS TO 95% OF MAX CAPACITY
PROMPT ================================================================

WITH current_ts AS (
    SELECT
        df.tablespace_name,
        SUM(df.bytes) AS allocated_bytes,
        SUM(df.maxbytes) AS max_bytes,
        SUM(
            df.bytes - NVL(fs.free_bytes, 0)
        ) AS used_bytes
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
),
growth AS (
    SELECT
        tablespace_id,
        MIN(rtime) AS first_sample,
        MAX(rtime) AS last_sample,
        MIN(tablespace_usedsize * block_size) AS first_used,
        MAX(tablespace_usedsize * block_size) AS last_used
    FROM dba_hist_tbspc_space_usage
    WHERE rtime >= SYSDATE - 7
    GROUP BY tablespace_id
)
SELECT
    c.tablespace_name,

    ROUND(
        c.used_bytes / 1024 / 1024 / 1024,
        2
    ) AS used_gb,

    ROUND(
        c.max_bytes / 1024 / 1024 / 1024,
        2
    ) AS max_gb,

    ROUND(
        (
            (
                c.max_bytes * 0.95
            ) - c.used_bytes
        ) / 1024 / 1024 / 1024,
        2
    ) AS growth_required_gb,

    ROUND(
        (
            (
                (
                    c.max_bytes * 0.95
                ) - c.used_bytes
            )
            /
            NULLIF(
                (
                    g.last_used - g.first_used
                )
                /
                NULLIF(
                    g.last_sample - g.first_sample,
                    0
                ),
                0
            )
        ),
        1
    ) AS days_to_95

FROM current_ts c
JOIN growth g
    ON g.tablespace_id = (
        SELECT tablespace_id
        FROM dba_tablespaces t
        WHERE t.tablespace_name = c.tablespace_name
    )
WHERE c.max_bytes > c.used_bytes
  AND g.last_used > g.first_used
ORDER BY days_to_95 ASC;


PROMPT
PROMPT ================================================================
PROMPT 15. TABLESPACES WITH LIMITED AUTOEXTEND HEADROOM
PROMPT ================================================================

SELECT
    tablespace_name,

    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS allocated_gb,

    ROUND(
        SUM(maxbytes) / 1024 / 1024 / 1024,
        2
    ) AS max_gb,

    ROUND(
        SUM(maxbytes - bytes)
        / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb

FROM dba_data_files
GROUP BY tablespace_name
HAVING SUM(maxbytes - bytes)
       <= 10 * 1024 * 1024 * 1024
ORDER BY headroom_gb ASC;


PROMPT
PROMPT ================================================================
PROMPT 16. LARGEST TABLESPACES
PROMPT ================================================================

SELECT
    tablespace_name,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS allocated_gb
FROM dba_data_files
GROUP BY tablespace_name
ORDER BY allocated_gb DESC
FETCH FIRST 30 ROWS ONLY;


PROMPT
PROMPT ================================================================
PROMPT 17. TABLESPACES ABOVE 80% USED
PROMPT ================================================================

WITH ts AS (
    SELECT
        df.tablespace_name,
        SUM(df.bytes) AS total_bytes,
        SUM(
            df.bytes - NVL(fs.free_bytes, 0)
        ) AS used_bytes
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
)
SELECT
    tablespace_name,

    ROUND(
        total_bytes / 1024 / 1024 / 1024,
        2
    ) AS allocated_gb,

    ROUND(
        used_bytes / 1024 / 1024 / 1024,
        2
    ) AS used_gb,

    ROUND(
        100 * used_bytes
        / NULLIF(total_bytes, 0),
        2
    ) AS used_pct

FROM ts
WHERE 100 * used_bytes
      / NULLIF(total_bytes, 0) >= 80
ORDER BY used_pct DESC;


PROMPT
PROMPT ================================================================
PROMPT 18. TABLESPACES ABOVE 90% USED
PROMPT ================================================================

WITH ts AS (
    SELECT
        df.tablespace_name,
        SUM(df.bytes) AS total_bytes,
        SUM(
            df.bytes - NVL(fs.free_bytes, 0)
        ) AS used_bytes
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
)
SELECT
    tablespace_name,

    ROUND(
        total_bytes / 1024 / 1024 / 1024,
        2
    ) AS allocated_gb,

    ROUND(
        used_bytes / 1024 / 1024 / 1024,
        2
    ) AS used_gb,

    ROUND(
        100 * used_bytes
        / NULLIF(total_bytes, 0),
        2
    ) AS used_pct

FROM ts
WHERE 100 * used_bytes
      / NULLIF(total_bytes, 0) >= 90
ORDER BY used_pct DESC;


PROMPT
PROMPT ================================================================
PROMPT 19. GROWTH SUMMARY
PROMPT ================================================================

SELECT
    COUNT(DISTINCT tablespace_id) AS tablespaces_tracked,
    MIN(rtime) AS oldest_sample,
    MAX(rtime) AS newest_sample
FROM dba_hist_tbspc_space_usage;


PROMPT
PROMPT ================================================================
PROMPT 20. OVERALL TABLESPACE GROWTH HEALTH
PROMPT ================================================================

WITH current_ts AS (
    SELECT
        df.tablespace_name,
        SUM(df.bytes) AS allocated_bytes,
        SUM(
            df.bytes - NVL(fs.free_bytes, 0)
        ) AS used_bytes
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
)
SELECT
    CASE
        WHEN COUNT(*) = 0
            THEN 'UNKNOWN - NO TABLESPACES FOUND'

        WHEN SUM(
                CASE
                    WHEN 100 * used_bytes
                         / NULLIF(allocated_bytes, 0) >= 95
                    THEN 1
                    ELSE 0
                END
             ) > 0
            THEN 'CRITICAL - TABLESPACE ABOVE 95%'

        WHEN SUM(
                CASE
                    WHEN 100 * used_bytes
                         / NULLIF(allocated_bytes, 0) >= 90
                    THEN 1
                    ELSE 0
                END
             ) > 0
            THEN 'WARNING - TABLESPACE ABOVE 90%'

        WHEN SUM(
                CASE
                    WHEN 100 * used_bytes
                         / NULLIF(allocated_bytes, 0) >= 80
                    THEN 1
                    ELSE 0
                END
             ) > 0
            THEN 'NOTICE - TABLESPACE ABOVE 80%'

        ELSE
            'HEALTHY - CURRENT CAPACITY OK'
    END AS tablespace_growth_health
FROM current_ts;


PROMPT
PROMPT ================================================================
PROMPT DBA CHECKLIST
PROMPT ================================================================
PROMPT
PROMPT [ ] Review current tablespace utilization.
PROMPT [ ] Review 24-hour growth.
PROMPT [ ] Review 7-day growth.
PROMPT [ ] Identify rapidly growing tablespaces.
PROMPT [ ] Check estimated time to 90% capacity.
PROMPT [ ] Check estimated time to 95% capacity.
PROMPT [ ] Review AUTOEXTEND and MAXBYTES.
PROMPT [ ] Check underlying ASM/filesystem capacity.
PROMPT [ ] Investigate unusual growth by segment/application.
PROMPT [ ] Review retention/purge jobs for unexpected growth.
PROMPT [ ] Consider historical growth trends before resizing.
PROMPT [ ] Validate capacity forecasts with business growth plans.
PROMPT
PROMPT ================================================================
PROMPT IMPORTANT NOTES
PROMPT ================================================================
PROMPT
PROMPT * This script is READ-ONLY.
PROMPT * It does not resize or modify tablespaces.
PROMPT * AWR growth sections require DBA_HIST views and appropriate
PROMPT   Oracle licensing/privileges.
PROMPT * Growth estimates are linear projections based on the
PROMPT   available historical window.
PROMPT * Linear forecasts can be misleading when growth is seasonal,
PROMPT   batch-driven, or affected by purge/archive jobs.
PROMPT * Tablespace free space and underlying storage free space
PROMPT   are different measurements.
PROMPT * AUTOEXTEND=YES does not mean unlimited storage capacity.
PROMPT * MAXBYTES may be limited by Oracle file-size restrictions
PROMPT   and the underlying storage platform.
PROMPT * A high-growth tablespace is not automatically a problem.
PROMPT   Investigate the source and business context.
PROMPT
PROMPT ================================================================
PROMPT END OF TABLESPACE GROWTH MONITORING
PROMPT ================================================================


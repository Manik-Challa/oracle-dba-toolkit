-- ============================================================
-- Oracle DBA Toolkit
-- File   : asm_space_forecast.sql
-- Purpose: Monitor ASM space usage and forecast capacity risk
-- Scope  : Current usage, growth trends, forecast, thresholds
--          and diskgroup capacity headroom
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

-- ============================================================
-- COLUMN FORMATS
-- ============================================================

COLUMN NAME                  FORMAT A20
COLUMN DB_UNIQUE_NAME        FORMAT A20
COLUMN INSTANCE_NAME         FORMAT A20
COLUMN HOST_NAME             FORMAT A40
COLUMN STATUS                FORMAT A15
COLUMN VERSION               FORMAT A20

COLUMN DISKGROUP_NAME        FORMAT A20
COLUMN TYPE                  FORMAT A12
COLUMN STATE                 FORMAT A15

COLUMN TOTAL_GB              FORMAT 999,999,999.99
COLUMN FREE_GB               FORMAT 999,999,999.99
COLUMN USABLE_GB             FORMAT 999,999,999.99
COLUMN USED_GB               FORMAT 999,999,999.99

COLUMN USED_PCT              FORMAT 990.99
COLUMN FREE_PCT              FORMAT 990.99
COLUMN USABLE_PCT            FORMAT 990.99

COLUMN REQUIRED_MIRROR_GB    FORMAT 999,999,999.99

COLUMN SAMPLE_DATE           FORMAT A20
COLUMN PREV_DATE             FORMAT A20

COLUMN DAILY_GROWTH_GB       FORMAT 999,999.99
COLUMN WEEKLY_GROWTH_GB      FORMAT 999,999.99
COLUMN DAILY_GROWTH_PCT      FORMAT 990.99
COLUMN DAYS_TO_80            FORMAT 999,999.99
COLUMN DAYS_TO_90            FORMAT 999,999.99
COLUMN DAYS_TO_FULL         FORMAT 999,999.99

COLUMN FORECAST_USED_GB      FORMAT 999,999,999.99
COLUMN FORECAST_USED_PCT     FORMAT 990.99

COLUMN HEADROOM_GB           FORMAT 999,999,999.99
COLUMN STATUS_TEXT           FORMAT A35
COLUMN HEALTH_STATUS         FORMAT A50

PROMPT
PROMPT ============================================================
PROMPT ASM SPACE USAGE & FORECAST
PROMPT ============================================================

-- ============================================================
-- 1. DATABASE / INSTANCE INFORMATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    d.name,
    d.db_unique_name,
    d.open_mode,
    d.database_role,
    i.instance_name,
    i.host_name,
    i.status,
    i.version
FROM v$database d
CROSS JOIN v$instance i;

-- ============================================================
-- 2. CURRENT ASM DISKGROUP CAPACITY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. CURRENT ASM DISKGROUP CAPACITY
PROMPT ============================================================

SELECT
    name AS diskgroup_name,
    type,
    state,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(usable_file_mb / 1024, 2) AS usable_gb,
    ROUND(
        (total_mb - free_mb) / NULLIF(total_mb, 0) * 100,
        2
    ) AS used_pct,
    ROUND(
        free_mb / NULLIF(total_mb, 0) * 100,
        2
    ) AS free_pct,
    ROUND(
        usable_file_mb / NULLIF(total_mb, 0) * 100,
        2
    ) AS usable_pct
FROM v$asm_diskgroup
ORDER BY
    used_pct DESC;

-- ============================================================
-- 3. DISKGROUPS ABOVE 80% USED
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. DISKGROUPS ABOVE 80% USED
PROMPT ============================================================

SELECT
    name AS diskgroup_name,
    type,
    state,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(
        (total_mb - free_mb) /
        NULLIF(total_mb, 0) * 100,
        2
    ) AS used_pct
FROM v$asm_diskgroup
WHERE (total_mb - free_mb) /
      NULLIF(total_mb, 0) * 100 >= 80
ORDER BY
    used_pct DESC;

-- ============================================================
-- 4. DISKGROUPS ABOVE 90% USED
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. DISKGROUPS ABOVE 90% USED
PROMPT ============================================================

SELECT
    name AS diskgroup_name,
    type,
    state,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(
        (total_mb - free_mb) /
        NULLIF(total_mb, 0) * 100,
        2
    ) AS used_pct
FROM v$asm_diskgroup
WHERE (total_mb - free_mb) /
      NULLIF(total_mb, 0) * 100 >= 90
ORDER BY
    used_pct DESC;

-- ============================================================
-- 5. USABLE FILE SPACE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. ASM USABLE FILE SPACE
PROMPT ============================================================

SELECT
    name AS diskgroup_name,
    type,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(usable_file_mb / 1024, 2) AS usable_gb,
    ROUND(required_mirror_free_mb / 1024, 2)
        AS required_mirror_gb
FROM v$asm_diskgroup
ORDER BY
    usable_file_mb;

-- ============================================================
-- 6. DISKGROUP HEADROOM
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. DISKGROUP HEADROOM
PROMPT ============================================================

SELECT
    name AS diskgroup_name,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(usable_file_mb / 1024, 2) AS usable_gb,
    ROUND(
        (total_mb - free_mb) /
        NULLIF(total_mb, 0) * 100,
        2
    ) AS used_pct,
    ROUND(
        total_mb / NULLIF(1024, 0) -
        (total_mb - free_mb) / 1024,
        2
    ) AS headroom_gb
FROM v$asm_diskgroup
ORDER BY
    used_pct DESC;

-- ============================================================
-- 7. CURRENT DISK CAPACITY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. ASM DISK CAPACITY
PROMPT ============================================================

SELECT
    dg.name AS diskgroup_name,
    COUNT(*) AS disk_count,
    ROUND(SUM(d.total_mb) / 1024, 2) AS total_gb,
    ROUND(SUM(d.free_mb) / 1024, 2) AS free_gb,
    ROUND(
        (SUM(d.total_mb) - SUM(d.free_mb)) /
        NULLIF(SUM(d.total_mb), 0) * 100,
        2
    ) AS used_pct
FROM v$asm_disk d
LEFT JOIN v$asm_diskgroup dg
    ON dg.group_number = d.group_number
WHERE d.group_number > 0
GROUP BY
    dg.name
ORDER BY
    used_pct DESC;

-- ============================================================
-- 8. RECENT ASM DISK OPERATIONS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. CURRENT ASM OPERATIONS
PROMPT ============================================================

SELECT
    o.group_number,
    o.operation,
    o.state,
    o.power,
    o.actual,
    o.sofar,
    o.est_work,
    o.est_rate,
    CASE
        WHEN o.est_rate > 0
        THEN ROUND(
            (o.est_work - o.sofar) / o.est_rate,
            2
        )
        ELSE NULL
    END AS est_minutes
FROM v$asm_operation o
ORDER BY
    o.group_number,
    o.operation;

-- ============================================================
-- 9. ASM SPACE PRESSURE INDICATORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. ASM SPACE PRESSURE INDICATORS
PROMPT ============================================================

SELECT
    name AS diskgroup_name,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(usable_file_mb / 1024, 2) AS usable_gb,
    ROUND(
        (total_mb - free_mb) /
        NULLIF(total_mb, 0) * 100,
        2
    ) AS used_pct,
    CASE
        WHEN usable_file_mb <= 0
            THEN 'CRITICAL - NO USABLE FILE SPACE'

        WHEN (total_mb - free_mb) /
             NULLIF(total_mb, 0) * 100 >= 95
            THEN 'CRITICAL - ASM >= 95% USED'

        WHEN (total_mb - free_mb) /
             NULLIF(total_mb, 0) * 100 >= 90
            THEN 'WARNING - ASM >= 90% USED'

        WHEN (total_mb - free_mb) /
             NULLIF(total_mb, 0) * 100 >= 80
            THEN 'WATCH - ASM >= 80% USED'

        ELSE 'OK'
    END AS status_text
FROM v$asm_diskgroup
ORDER BY
    used_pct DESC;

-- ============================================================
-- 10. AWR GROWTH HISTORY
--
-- Requires Diagnostics Pack / AWR access.
-- Uses DBA_HIST_SEG_STAT to estimate database segment growth.
-- This is database-level growth, not a direct ASM historical
-- free-space history.
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. AWR DATABASE GROWTH TREND
PROMPT ============================================================

SELECT
    TO_CHAR(s.end_interval_time, 'YYYY-MM-DD HH24:MI') AS sample_date,
    ROUND(
        SUM(NVL(ss.space_allocated_delta, 0)) /
        1024 / 1024 / 1024,
        2
    ) AS allocated_delta_gb
FROM dba_hist_seg_stat ss
JOIN dba_hist_snapshot s
    ON s.snap_id = ss.snap_id
   AND s.dbid = ss.dbid
   AND s.instance_number = ss.instance_number
WHERE s.end_interval_time >= SYSDATE - 7
GROUP BY
    TO_CHAR(s.end_interval_time, 'YYYY-MM-DD HH24:MI')
ORDER BY
    sample_date;

-- ============================================================
-- 11. DAILY DATABASE GROWTH
--
-- Positive SPACE_ALLOCATED_DELTA represents additional
-- allocated segment space during the AWR interval.
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. DAILY DATABASE GROWTH
PROMPT ============================================================

SELECT
    TRUNC(s.end_interval_time) AS sample_date,
    ROUND(
        SUM(NVL(ss.space_allocated_delta, 0)) /
        1024 / 1024 / 1024,
        2
    ) AS growth_gb
FROM dba_hist_seg_stat ss
JOIN dba_hist_snapshot s
    ON s.snap_id = ss.snap_id
   AND s.dbid = ss.dbid
   AND s.instance_number = ss.instance_number
WHERE s.end_interval_time >= SYSDATE - 30
GROUP BY
    TRUNC(s.end_interval_time)
ORDER BY
    sample_date;

-- ============================================================
-- 12. CURRENT ASM FORECAST
--
-- Forecast uses a simple linear model based on the last
-- 7 days of database segment allocation growth.
--
-- This is an estimate only. ASM free space can also change
-- because of disk additions/removals, rebalance, purge,
-- compression, data movement and workload changes.
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. ASM SPACE FORECAST
PROMPT ============================================================

WITH daily_growth AS
(
    SELECT
        TRUNC(s.end_interval_time) AS sample_date,
        SUM(NVL(ss.space_allocated_delta, 0)) /
            1024 / 1024 / 1024 AS growth_gb
    FROM dba_hist_seg_stat ss
    JOIN dba_hist_snapshot s
        ON s.snap_id = ss.snap_id
       AND s.dbid = ss.dbid
       AND s.instance_number = ss.instance_number
    WHERE s.end_interval_time >= SYSDATE - 7
    GROUP BY
        TRUNC(s.end_interval_time)
),
growth_summary AS
(
    SELECT
        AVG(growth_gb) AS daily_growth_gb
    FROM daily_growth
    WHERE growth_gb > 0
)
SELECT
    dg.name AS diskgroup_name,

    ROUND(
        dg.total_mb / 1024,
        2
    ) AS total_gb,

    ROUND(
        (dg.total_mb - dg.free_mb) / 1024,
        2
    ) AS used_gb,

    ROUND(
        dg.free_mb / 1024,
        2
    ) AS free_gb,

    ROUND(
        (dg.total_mb - dg.free_mb) /
        NULLIF(dg.total_mb, 0) * 100,
        2
    ) AS used_pct,

    ROUND(
        gs.daily_growth_gb,
        2
    ) AS daily_growth_gb,

    CASE
        WHEN gs.daily_growth_gb > 0
        THEN ROUND(
            (
                (dg.total_mb * 0.80) -
                (dg.total_mb - dg.free_mb)
            ) / 1024 /
            gs.daily_growth_gb,
            2
        )
        ELSE NULL
    END AS days_to_80,

    CASE
        WHEN gs.daily_growth_gb > 0
        THEN ROUND(
            (
                (dg.total_mb * 0.90) -
                (dg.total_mb - dg.free_mb)
            ) / 1024 /
            gs.daily_growth_gb,
            2
        )
        ELSE NULL
    END AS days_to_90,

    CASE
        WHEN gs.daily_growth_gb > 0
        THEN ROUND(
            dg.free_mb / 1024 /
            gs.daily_growth_gb,
            2
        )
        ELSE NULL
    END AS days_to_full

FROM v$asm_diskgroup dg
CROSS JOIN growth_summary gs
ORDER BY
    used_pct DESC;

-- ============================================================
-- 13. FORECAST RISK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. FORECAST RISK
PROMPT ============================================================

WITH daily_growth AS
(
    SELECT
        TRUNC(s.end_interval_time) AS sample_date,
        SUM(NVL(ss.space_allocated_delta, 0)) /
            1024 / 1024 / 1024 AS growth_gb
    FROM dba_hist_seg_stat ss
    JOIN dba_hist_snapshot s
        ON s.snap_id = ss.snap_id
       AND s.dbid = ss.dbid
       AND s.instance_number = ss.instance_number
    WHERE s.end_interval_time >= SYSDATE - 7
    GROUP BY
        TRUNC(s.end_interval_time)
),
growth_summary AS
(
    SELECT
        AVG(growth_gb) AS daily_growth_gb
    FROM daily_growth
    WHERE growth_gb > 0
)
SELECT
    dg.name AS diskgroup_name,

    ROUND(
        (dg.total_mb - dg.free_mb) /
        NULLIF(dg.total_mb, 0) * 100,
        2
    ) AS used_pct,

    ROUND(
        gs.daily_growth_gb,
        2
    ) AS daily_growth_gb,

    CASE
        WHEN dg.usable_file_mb <= 0
            THEN 'CRITICAL - NO USABLE SPACE'

        WHEN
            gs.daily_growth_gb > 0
            AND
            dg.free_mb / 1024 /
            gs.daily_growth_gb <= 7
            THEN 'CRITICAL - < 7 DAYS HEADROOM'

        WHEN
            gs.daily_growth_gb > 0
            AND
            dg.free_mb / 1024 /
            gs.daily_growth_gb <= 30
            THEN 'WARNING - < 30 DAYS HEADROOM'

        WHEN
            (dg.total_mb - dg.free_mb) /
            NULLIF(dg.total_mb, 0) * 100 >= 90
            THEN 'WARNING - >= 90% USED'

        WHEN
            (dg.total_mb - dg.free_mb) /
            NULLIF(dg.total_mb, 0) * 100 >= 80
            THEN 'WATCH - >= 80% USED'

        ELSE 'OK'
    END AS status_text

FROM v$asm_diskgroup dg
CROSS JOIN growth_summary gs
ORDER BY
    used_pct DESC;

-- ============================================================
-- 14. ASM SPACE HEALTH SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. ASM SPACE HEALTH SUMMARY
PROMPT ============================================================

WITH daily_growth AS
(
    SELECT
        TRUNC(s.end_interval_time) AS sample_date,
        SUM(NVL(ss.space_allocated_delta, 0)) /
            1024 / 1024 / 1024 AS growth_gb
    FROM dba_hist_seg_stat ss
    JOIN dba_hist_snapshot s
        ON s.snap_id = ss.snap_id
       AND s.dbid = ss.dbid
       AND s.instance_number = ss.instance_number
    WHERE s.end_interval_time >= SYSDATE - 7
    GROUP BY
        TRUNC(s.end_interval_time)
),
growth_summary AS
(
    SELECT
        AVG(growth_gb) AS daily_growth_gb
    FROM daily_growth
    WHERE growth_gb > 0
)
SELECT
    CASE
        WHEN SUM(
            CASE
                WHEN dg.usable_file_mb <= 0
                THEN 1
                ELSE 0
            END
        ) > 0
        THEN 'CRITICAL - DISKGROUP HAS NO USABLE FILE SPACE'

        WHEN SUM(
            CASE
                WHEN gs.daily_growth_gb > 0
                 AND dg.free_mb / 1024 /
                     gs.daily_growth_gb <= 7
                THEN 1
                ELSE 0
            END
        ) > 0
        THEN 'CRITICAL - DISKGROUP WITH < 7 DAYS HEADROOM'

        WHEN SUM(
            CASE
                WHEN gs.daily_growth_gb > 0
                 AND dg.free_mb / 1024 /
                     gs.daily_growth_gb <= 30
                THEN 1
                ELSE 0
            END
        ) > 0
        THEN 'WARNING - DISKGROUP WITH < 30 DAYS HEADROOM'

        WHEN MAX(
            (dg.total_mb - dg.free_mb) /
            NULLIF(dg.total_mb, 0) * 100
        ) >= 90
        THEN 'WARNING - ASM DISKGROUP >= 90% USED'

        WHEN MAX(
            (dg.total_mb - dg.free_mb) /
            NULLIF(dg.total_mb, 0) * 100
        ) >= 80
        THEN 'WATCH - ASM DISKGROUP >= 80% USED'

        ELSE 'HEALTHY - NO IMMEDIATE ASM SPACE RISK'
    END AS health_status
FROM v$asm_diskgroup dg
CROSS JOIN growth_summary gs;

-- ============================================================
-- 15. QUICK CAPACITY CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. QUICK CAPACITY CHECK
PROMPT ============================================================

SELECT
    name AS diskgroup_name,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    ROUND(usable_file_mb / 1024, 2) AS usable_gb,
    ROUND(
        (total_mb - free_mb) /
        NULLIF(total_mb, 0) * 100,
        2
    ) AS used_pct,
    CASE
        WHEN usable_file_mb <= 0
            THEN 'CRITICAL'

        WHEN (total_mb - free_mb) /
             NULLIF(total_mb, 0) * 100 >= 90
            THEN 'WARNING'

        WHEN (total_mb - free_mb) /
             NULLIF(total_mb, 0) * 100 >= 80
            THEN 'WATCH'

        ELSE 'OK'
    END AS status_text
FROM v$asm_diskgroup
ORDER BY
    used_pct DESC;

-- ============================================================
-- 16. DBA CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT DBA CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT 1. Review ASM diskgroup TOTAL / FREE / USABLE space.
PROMPT 2. Check diskgroups above 80% and 90% used.
PROMPT 3. Review REQUIRED_MIRROR_FREE and USABLE_FILE_MB.
PROMPT 4. Review current ASM disk capacity and failgroups.
PROMPT 5. Check active ASM rebalance/resync operations.
PROMPT 6. Review recent database segment allocation growth.
PROMPT 7. Use the forecast only as a planning estimate.
PROMPT 8. Validate actual storage expansion capacity before action.
PROMPT 9. Correlate ASM growth with tablespace/datafile growth.
PROMPT 10. On Exadata, correlate capacity with storage-cell capacity.
PROMPT
PROMPT ============================================================
PROMPT IMPORTANT NOTES
PROMPT ============================================================
PROMPT
PROMPT - Forecast is based on recent database segment growth.
PROMPT - It is NOT a direct historical ASM free-space measurement.
PROMPT - ASM free space can change due to disk additions/removals,
PROMPT   rebalance, purge, compression and data movement.
PROMPT - AWR queries require appropriate Diagnostics Pack access.
PROMPT - Thresholds in this script are DBA toolkit heuristics.
PROMPT - Validate ASM redundancy and usable_file_mb before action.
PROMPT - This script is READ ONLY and performs no ASM changes.
PROMPT
PROMPT ============================================================
PROMPT END OF ASM SPACE FORECAST
PROMPT ============================================================


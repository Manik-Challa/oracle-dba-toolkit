-- ============================================================================
-- guaranteed_restore_points.sql
-- Oracle DBA Toolkit
--
-- Purpose:
--   Monitor Oracle Guaranteed Restore Points and their impact on recovery
--   area usage.
--
-- Covers:
--   - Guaranteed restore points
--   - Restore point age
--   - SCN and timestamp
--   - Storage consumption
--   - FRA usage
--   - Old guaranteed restore points
--   - Restore point summary
--   - Recent FRA-related alerts
--   - Health indicators
--
-- Scope:
--   Read-only monitoring script.
--
-- Important:
--   Guaranteed restore points can cause Flashback Logs to be retained.
--   An old guaranteed restore point can therefore contribute significantly
--   to FRA growth.
--
--   Do not drop a restore point simply because it is old. Confirm that
--   it is no longer required for recovery before removing it.
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN db_name                    FORMAT A15
COLUMN db_unique_name             FORMAT A25
COLUMN database_role              FORMAT A20
COLUMN open_mode                  FORMAT A20
COLUMN flashback_on               FORMAT A20

COLUMN restore_point_name        FORMAT A50
COLUMN guarantee                  FORMAT A12
COLUMN preserved                  FORMAT A12

COLUMN scn                       FORMAT 99999999999999999999
COLUMN time                      FORMAT A25
COLUMN age_hours                 FORMAT 999999990.00
COLUMN age_days                  FORMAT 999999990.00

COLUMN storage_size_gb           FORMAT 999999990.00
COLUMN storage_size_mb           FORMAT 999999990.00

COLUMN space_limit_gb            FORMAT 999999990.00
COLUMN space_used_gb             FORMAT 999999990.00
COLUMN space_reclaimable_gb      FORMAT 999999990.00
COLUMN free_space_gb             FORMAT 999999990.00
COLUMN used_pct                  FORMAT 990.00

COLUMN file_type                 FORMAT A30
COLUMN number_of_files           FORMAT 999999999
COLUMN percent_space_used        FORMAT 990.00
COLUMN percent_space_reclaimable FORMAT 990.00

COLUMN originating_timestamp     FORMAT A25
COLUMN message_text              FORMAT A100

COLUMN health                    FORMAT A50
COLUMN warning_level             FORMAT A40


PROMPT
PROMPT ============================================================================
PROMPT 1. DATABASE INFORMATION
PROMPT ============================================================================

SELECT
    name AS db_name,
    db_unique_name,
    database_role,
    open_mode,
    flashback_on,
    log_mode
FROM v$database;


PROMPT
PROMPT ============================================================================
PROMPT 2. ALL RESTORE POINTS
PROMPT ============================================================================

SELECT
    name AS restore_point_name,
    scn,
    time,
    guarantee_flashback_database AS guarantee,
    storage_size,
    preserved
FROM v$restore_point
ORDER BY time DESC;


PROMPT
PROMPT ============================================================================
PROMPT 3. GUARANTEED RESTORE POINTS
PROMPT ============================================================================

SELECT
    name AS restore_point_name,
    scn,
    time,
    guarantee_flashback_database AS guarantee,
    storage_size,
    preserved
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES'
ORDER BY time DESC;


PROMPT
PROMPT ============================================================================
PROMPT 4. GUARANTEED RESTORE POINT AGE
PROMPT ============================================================================

SELECT
    name AS restore_point_name,
    time,
    ROUND(
        (SYSDATE - time) * 24,
        2
    ) AS age_hours,
    ROUND(
        SYSDATE - time,
        2
    ) AS age_days,
    scn,
    preserved
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES'
ORDER BY time;


PROMPT
PROMPT ============================================================================
PROMPT 5. GUARANTEED RESTORE POINT STORAGE
PROMPT ============================================================================

SELECT
    name AS restore_point_name,
    time,
    ROUND(
        storage_size / 1024 / 1024 / 1024,
        2
    ) AS storage_size_gb,
    ROUND(
        storage_size / 1024 / 1024,
        2
    ) AS storage_size_mb,
    scn
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES'
ORDER BY storage_size DESC;


PROMPT
PROMPT ============================================================================
PROMPT 6. TOTAL GUARANTEED RESTORE POINT STORAGE
PROMPT ============================================================================

SELECT
    COUNT(*) AS guaranteed_restore_points,
    ROUND(
        NVL(SUM(storage_size), 0) /
        1024 / 1024 / 1024,
        2
    ) AS total_storage_gb,
    ROUND(
        NVL(SUM(storage_size), 0) /
        1024 / 1024,
        2
    ) AS total_storage_mb
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES';


PROMPT
PROMPT ============================================================================
PROMPT 7. OLDEST GUARANTEED RESTORE POINT
PROMPT ============================================================================

SELECT
    name AS restore_point_name,
    time,
    scn,
    ROUND(
        SYSDATE - time,
        2
    ) AS age_days,
    ROUND(
        (SYSDATE - time) * 24,
        2
    ) AS age_hours,
    ROUND(
        storage_size / 1024 / 1024 / 1024,
        2
    ) AS storage_size_gb,
    preserved
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES'
ORDER BY time
FETCH FIRST 1 ROW ONLY;


PROMPT
PROMPT ============================================================================
PROMPT 8. NEWEST GUARANTEED RESTORE POINT
PROMPT ============================================================================

SELECT
    name AS restore_point_name,
    time,
    scn,
    ROUND(
        SYSDATE - time,
        2
    ) AS age_days,
    ROUND(
        storage_size / 1024 / 1024 / 1024,
        2
    ) AS storage_size_gb,
    preserved
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES'
ORDER BY time DESC
FETCH FIRST 1 ROW ONLY;


PROMPT
PROMPT ============================================================================
PROMPT 9. GUARANTEED RESTORE POINTS OLDER THAN 7 DAYS
PROMPT ============================================================================

SELECT
    name AS restore_point_name,
    time,
    ROUND(
        SYSDATE - time,
        2
    ) AS age_days,
    scn,
    ROUND(
        storage_size / 1024 / 1024 / 1024,
        2
    ) AS storage_size_gb,
    preserved,
    CASE
        WHEN SYSDATE - time >= 30
            THEN 'CRITICAL REVIEW - >= 30 DAYS'
        WHEN SYSDATE - time >= 14
            THEN 'REVIEW - >= 14 DAYS'
        ELSE 'REVIEW - >= 7 DAYS'
    END AS health
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES'
  AND time < SYSDATE - 7
ORDER BY time;


PROMPT
PROMPT ============================================================================
PROMPT 10. GUARANTEED RESTORE POINTS OLDER THAN 30 DAYS
PROMPT ============================================================================

SELECT
    name AS restore_point_name,
    time,
    ROUND(
        SYSDATE - time,
        2
    ) AS age_days,
    scn,
    ROUND(
        storage_size / 1024 / 1024 / 1024,
        2
    ) AS storage_size_gb,
    preserved
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES'
  AND time < SYSDATE - 30
ORDER BY time;


PROMPT
PROMPT ============================================================================
PROMPT 11. FRA SPACE SUMMARY
PROMPT ============================================================================

SELECT
    ROUND(
        space_limit / 1024 / 1024 / 1024,
        2
    ) AS space_limit_gb,
    ROUND(
        space_used / 1024 / 1024 / 1024,
        2
    ) AS space_used_gb,
    ROUND(
        space_reclaimable / 1024 / 1024 / 1024,
        2
    ) AS space_reclaimable_gb,
    ROUND(
        (space_limit - space_used) /
        1024 / 1024 / 1024,
        2
    ) AS free_space_gb,
    ROUND(
        space_used /
        NULLIF(space_limit, 0) * 100,
        2
    ) AS used_pct
FROM v$recovery_file_dest;


PROMPT
PROMPT ============================================================================
PROMPT 12. FRA USAGE BY FILE TYPE
PROMPT ============================================================================

SELECT
    file_type,
    number_of_files,
    ROUND(
        space_used / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(
        percent_space_used,
        2
    ) AS percent_used,
    ROUND(
        percent_space_reclaimable,
        2
    ) AS percent_reclaimable
FROM v$flash_recovery_area_usage
ORDER BY space_used DESC;


PROMPT
PROMPT ============================================================================
PROMPT 13. FLASHBACK LOG USAGE
PROMPT ============================================================================

SELECT
    file_type,
    number_of_files,
    ROUND(
        space_used / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(
        percent_space_used,
        2
    ) AS percent_used,
    ROUND(
        percent_space_reclaimable,
        2
    ) AS percent_reclaimable
FROM v$flash_recovery_area_usage
WHERE file_type = 'FLASHBACK LOG';


PROMPT
PROMPT ============================================================================
PROMPT 14. FRA PRESSURE
PROMPT ============================================================================

SELECT
    ROUND(
        space_limit / 1024 / 1024 / 1024,
        2
    ) AS limit_gb,
    ROUND(
        space_used / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(
        (space_limit - space_used) /
        1024 / 1024 / 1024,
        2
    ) AS free_gb,
    ROUND(
        space_used /
        NULLIF(space_limit, 0) * 100,
        2
    ) AS used_pct,
    CASE
        WHEN space_limit = 0
            THEN 'CHECK - FRA NOT CONFIGURED'
        WHEN space_used / space_limit * 100 >= 95
            THEN 'CRITICAL - FRA >= 95%'
        WHEN space_used / space_limit * 100 >= 90
            THEN 'WARNING - FRA >= 90%'
        WHEN space_used / space_limit * 100 >= 80
            THEN 'REVIEW - FRA >= 80%'
        ELSE 'OK - FRA BELOW 80%'
    END AS health
FROM v$recovery_file_dest;


PROMPT
PROMPT ============================================================================
PROMPT 15. GUARANTEED RESTORE POINTS VS FRA
PROMPT ============================================================================

SELECT
    COUNT(*) AS guaranteed_restore_points,
    ROUND(
        NVL(SUM(r.storage_size), 0) /
        1024 / 1024 / 1024,
        2
    ) AS restore_point_storage_gb,
    ROUND(
        f.space_used /
        NULLIF(f.space_limit, 0) * 100,
        2
    ) AS fra_used_pct
FROM v$restore_point r
CROSS JOIN v$recovery_file_dest f
WHERE r.guarantee_flashback_database = 'YES';


PROMPT
PROMPT ============================================================================
PROMPT 16. RESTORE POINT STORAGE AS PERCENTAGE OF FRA
PROMPT ============================================================================

SELECT
    ROUND(
        NVL(
            (
                SELECT SUM(storage_size)
                FROM v$restore_point
                WHERE guarantee_flashback_database = 'YES'
            ),
            0
        ) / 1024 / 1024 / 1024,
        2
    ) AS guaranteed_rp_storage_gb,
    ROUND(
        f.space_used / 1024 / 1024 / 1024,
        2
    ) AS fra_used_gb,
    ROUND(
        NVL(
            (
                SELECT SUM(storage_size)
                FROM v$restore_point
                WHERE guarantee_flashback_database = 'YES'
            ),
            0
        ) /
        NULLIF(f.space_used, 0) * 100,
        2
    ) AS pct_of_fra_used
FROM v$recovery_file_dest f;


PROMPT
PROMPT ============================================================================
PROMPT 17. RESTORE POINTS BY AGE
PROMPT ============================================================================

SELECT
    CASE
        WHEN SYSDATE - time < 1
            THEN '< 1 day'
        WHEN SYSDATE - time < 7
            THEN '1 - 7 days'
        WHEN SYSDATE - time < 14
            THEN '7 - 14 days'
        WHEN SYSDATE - time < 30
            THEN '14 - 30 days'
        ELSE '> 30 days'
    END AS age_group,
    COUNT(*) AS guaranteed_restore_points,
    ROUND(
        SUM(storage_size) /
        1024 / 1024 / 1024,
        2
    ) AS storage_gb
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES'
GROUP BY
    CASE
        WHEN SYSDATE - time < 1
            THEN '< 1 day'
        WHEN SYSDATE - time < 7
            THEN '1 - 7 days'
        WHEN SYSDATE - time < 14
            THEN '7 - 14 days'
        WHEN SYSDATE - time < 30
            THEN '14 - 30 days'
        ELSE '> 30 days'
    END
ORDER BY
    MIN(time);


PROMPT
PROMPT ============================================================================
PROMPT 18. GUARANTEED RESTORE POINT SUMMARY
PROMPT ============================================================================

SELECT
    COUNT(*) AS total_guaranteed_restore_points,
    COUNT(
        CASE
            WHEN time < SYSDATE - 7 THEN 1
        END
    ) AS older_than_7_days,
    COUNT(
        CASE
            WHEN time < SYSDATE - 30 THEN 1
        END
    ) AS older_than_30_days,
    ROUND(
        NVL(SUM(storage_size), 0) /
        1024 / 1024 / 1024,
        2
    ) AS total_storage_gb
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES';


PROMPT
PROMPT ============================================================================
PROMPT 19. RECENT FLASHBACK / FRA ALERTS
PROMPT ============================================================================

SELECT
    originating_timestamp,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND
  (
       UPPER(message_text) LIKE '%FLASHBACK%'
    OR UPPER(message_text) LIKE '%RESTORE POINT%'
    OR UPPER(message_text) LIKE '%ORA-387%'
    OR UPPER(message_text) LIKE '%ORA-198%'
    OR UPPER(message_text) LIKE '%RECOVERY AREA%'
  )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================================
PROMPT 20. RESTORE POINT / FLASHBACK CONFIGURATION
PROMPT ============================================================================

SELECT
    d.flashback_on,
    d.database_role,
    d.open_mode,
    p.value AS retention_target_minutes,
    ROUND(
        p.value / 60,
        2
    ) AS retention_target_hours
FROM v$database d
CROSS JOIN
(
    SELECT value
    FROM v$parameter
    WHERE name = 'db_flashback_retention_target'
) p;


PROMPT
PROMPT ============================================================================
PROMPT 21. GUARANTEED RESTORE POINT HEALTH
PROMPT ============================================================================

SELECT
    COUNT(*) AS guaranteed_restore_points,
    COUNT(
        CASE
            WHEN time < SYSDATE - 7 THEN 1
        END
    ) AS older_than_7_days,
    COUNT(
        CASE
            WHEN time < SYSDATE - 30 THEN 1
        END
    ) AS older_than_30_days,
    ROUND(
        NVL(SUM(storage_size), 0) /
        1024 / 1024 / 1024,
        2
    ) AS storage_gb,
    CASE
        WHEN COUNT(*) = 0
            THEN 'OK - NO GUARANTEED RESTORE POINTS'
        WHEN COUNT(
                 CASE
                     WHEN time < SYSDATE - 30 THEN 1
                 END
             ) > 0
            THEN 'CHECK - GUARANTEED RESTORE POINT >= 30 DAYS'
        WHEN COUNT(
                 CASE
                     WHEN time < SYSDATE - 7 THEN 1
                 END
             ) > 0
            THEN 'REVIEW - OLD GUARANTEED RESTORE POINT'
        ELSE 'OK - RECENT GUARANTEED RESTORE POINTS'
    END AS health
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES';


PROMPT
PROMPT ============================================================================
PROMPT 22. QUICK GUARANTEED RESTORE POINT CHECK
PROMPT ============================================================================

SELECT
    COUNT(*) AS guaranteed_restore_points,
    ROUND(
        NVL(SUM(storage_size), 0) /
        1024 / 1024 / 1024,
        2
    ) AS storage_gb,
    ROUND(
        (
            SELECT space_used
            FROM v$recovery_file_dest
        ) /
        NULLIF(
            (
                SELECT space_limit
                FROM v$recovery_file_dest
            ),
            0
        ) * 100,
        2
    ) AS fra_used_pct,
    COUNT(
        CASE
            WHEN time < SYSDATE - 7 THEN 1
        END
    ) AS older_than_7_days,
    COUNT(
        CASE
            WHEN time < SYSDATE - 30 THEN 1
        END
    ) AS older_than_30_days
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES';


PROMPT
PROMPT ============================================================================
PROMPT 23. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] Check whether any guaranteed restore points exist.
PROMPT [ ] Identify the oldest guaranteed restore point.
PROMPT [ ] Check restore point age.
PROMPT [ ] Check restore point storage consumption.
PROMPT [ ] Check total FRA usage.
PROMPT [ ] Check Flashback Log consumption.
PROMPT [ ] Check whether old restore points are still required.
PROMPT [ ] Confirm application/upgrade/testing activity associated with each point.
PROMPT [ ] Check for FRA pressure or ORA-198xx errors.
PROMPT [ ] Review Data Guard implications before changing recovery configuration.
PROMPT [ ] Do not drop a restore point without confirming it is no longer needed.
PROMPT [ ] Do not manually delete Flashback Logs from the filesystem.
PROMPT [ ] Use Oracle-supported commands for restore point management.
PROMPT
PROMPT ============================================================================
PROMPT 24. MANAGEMENT COMMAND EXAMPLES
PROMPT ============================================================================

PROMPT
PROMPT Example - Create a normal restore point:
PROMPT   CREATE RESTORE POINT before_change;
PROMPT
PROMPT Example - Create a guaranteed restore point:
PROMPT   CREATE RESTORE POINT before_upgrade GUARANTEE FLASHBACK DATABASE;
PROMPT
PROMPT Example - Drop a restore point after confirming it is no longer needed:
PROMPT   DROP RESTORE POINT before_upgrade;
PROMPT
PROMPT NOTE:
PROMPT   Execute management commands only after validating the recovery
PROMPT   requirement and change-management approval.
PROMPT
PROMPT ============================================================================
PROMPT END OF GUARANTEED RESTORE POINT CHECK
PROMPT ============================================================================


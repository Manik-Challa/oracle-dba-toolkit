-- ============================================================================
-- flashback_usage.sql
-- Oracle DBA Toolkit
--
-- Purpose:
--   Flashback Database usage and health monitoring.
--
-- Covers:
--   - Flashback Database status
--   - Flashback retention target
--   - Flashback log usage in FRA
--   - Flashback log generation
--   - FRA usage
--   - Flashback oldest SCN/time
--   - Flashback window
--   - Guaranteed restore points
--   - Restore point details
--   - Recent Flashback-related alert messages
--   - Flashback health indicators
--
-- Scope:
--   Read-only monitoring script.
--
-- Notes:
--   - Run as a user with access to the required V$ views.
--   - Flashback logs are managed by Oracle in the FRA.
--   - Flashback retention target is a target, not a guarantee.
--   - Actual flashback availability depends on available Flashback Logs,
--     workload, FRA space, restore points, and database configuration.
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
COLUMN flashback_on               FORMAT A15
COLUMN log_mode                   FORMAT A15

COLUMN retention_target_minutes   FORMAT 999999999
COLUMN retention_target_hours     FORMAT 999999990.00

COLUMN oldest_flashback_time      FORMAT A25
COLUMN oldest_flashback_scn       FORMAT 99999999999999999999
COLUMN current_scn                FORMAT 99999999999999999999
COLUMN flashback_window_minutes   FORMAT 999999990.00
COLUMN flashback_window_hours     FORMAT 999999990.00

COLUMN space_limit_gb             FORMAT 999999990.00
COLUMN space_used_gb              FORMAT 999999990.00
COLUMN space_reclaimable_gb       FORMAT 999999990.00
COLUMN free_space_gb              FORMAT 999999990.00
COLUMN used_pct                   FORMAT 990.00
COLUMN reclaimable_pct            FORMAT 990.00

COLUMN file_type                  FORMAT A30
COLUMN number_of_files            FORMAT 999999999
COLUMN percent_space_used         FORMAT 990.00
COLUMN percent_space_reclaimable  FORMAT 990.00

COLUMN name                       FORMAT A45
COLUMN restore_point_name         FORMAT A45
COLUMN guarantee                  FORMAT A12
COLUMN storage_size_gb            FORMAT 999999990.00
COLUMN time                      FORMAT A25
COLUMN scn                        FORMAT 99999999999999999999
COLUMN database_incarnation#      FORMAT 999999999
COLUMN preserved                  FORMAT A12

COLUMN originating_timestamp      FORMAT A25
COLUMN message_text               FORMAT A100

COLUMN warning_level              FORMAT A40
COLUMN health                     FORMAT A50


PROMPT
PROMPT ============================================================================
PROMPT 1. DATABASE INFORMATION
PROMPT ============================================================================

SELECT
    name AS db_name,
    db_unique_name,
    database_role,
    open_mode,
    log_mode,
    flashback_on
FROM v$database;


PROMPT
PROMPT ============================================================================
PROMPT 2. FLASHBACK CONFIGURATION
PROMPT ============================================================================

SELECT
    name,
    value
FROM v$parameter
WHERE name IN
(
    'db_flashback_retention_target',
    'db_recovery_file_dest',
    'db_recovery_file_dest_size'
)
ORDER BY name;


PROMPT
PROMPT ============================================================================
PROMPT 3. FLASHBACK RETENTION TARGET
PROMPT ============================================================================

SELECT
    value AS retention_target_minutes,
    ROUND(value / 60, 2) AS retention_target_hours
FROM v$parameter
WHERE name = 'db_flashback_retention_target';


PROMPT
PROMPT ============================================================================
PROMPT 4. FLASHBACK DATABASE STATUS
PROMPT ============================================================================

SELECT
    flashback_on,
    log_mode,
    database_role,
    open_mode
FROM v$database;


PROMPT
PROMPT ============================================================================
PROMPT 5. FLASHBACK LOG USAGE IN FRA
PROMPT ============================================================================

SELECT
    file_type,
    number_of_files,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(percent_space_used, 2) AS percent_used,
    ROUND(percent_space_reclaimable, 2) AS percent_reclaimable
FROM v$flash_recovery_area_usage
WHERE file_type = 'FLASHBACK LOG';


PROMPT
PROMPT ============================================================================
PROMPT 6. ALL FRA USAGE
PROMPT ============================================================================

SELECT
    file_type,
    number_of_files,
    ROUND(space_used / 1024 / 1024 / 1024, 2) AS used_gb,
    ROUND(percent_space_used, 2) AS percent_used,
    ROUND(percent_space_reclaimable, 2) AS percent_reclaimable
FROM v$flash_recovery_area_usage
ORDER BY space_used DESC;


PROMPT
PROMPT ============================================================================
PROMPT 7. FRA SPACE SUMMARY
PROMPT ============================================================================

SELECT
    ROUND(space_limit / 1024 / 1024 / 1024, 2)
        AS space_limit_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2)
        AS space_used_gb,
    ROUND(space_reclaimable / 1024 / 1024 / 1024, 2)
        AS space_reclaimable_gb,
    ROUND(
        (space_limit - space_used) / 1024 / 1024 / 1024,
        2
    ) AS free_space_gb,
    ROUND(
        space_used / NULLIF(space_limit, 0) * 100,
        2
    ) AS used_pct
FROM v$recovery_file_dest;


PROMPT
PROMPT ============================================================================
PROMPT 8. FLASHBACK WINDOW
PROMPT ============================================================================

SELECT
    oldest_flashback_time,
    oldest_flashback_scn,
    current_scn,
    flashback_window_minutes,
    ROUND(flashback_window_minutes / 60, 2)
        AS flashback_window_hours
FROM
(
    SELECT
        MIN(oldest_flashback_time) AS oldest_flashback_time,
        MIN(oldest_flashback_scn) AS oldest_flashback_scn,
        (SELECT current_scn FROM v$database) AS current_scn,
        (
            (SYSDATE - MIN(oldest_flashback_time))
            * 24 * 60
        ) AS flashback_window_minutes
    FROM v$flashback_database_log
);


PROMPT
PROMPT ============================================================================
PROMPT 9. FLASHBACK LOG RANGE
PROMPT ============================================================================

SELECT
    MIN(first_time) AS oldest_flashback_time,
    MAX(first_time) AS latest_flashback_time,
    ROUND(
        (MAX(first_time) - MIN(first_time)) * 24,
        2
    ) AS available_window_hours,
    ROUND(
        (MAX(first_time) - MIN(first_time)) * 24 * 60,
        2
    ) AS available_window_minutes
FROM v$flashback_database_log;


PROMPT
PROMPT ============================================================================
PROMPT 10. FLASHBACK LOG DETAILS
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    first_time,
    first_change#,
    next_change#,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM v$flashback_database_log
ORDER BY
    first_time DESC;


PROMPT
PROMPT ============================================================================
PROMPT 11. FLASHBACK LOG GENERATION BY DAY
PROMPT ============================================================================

SELECT
    TRUNC(first_time) AS flashback_date,
    COUNT(*) AS flashback_log_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS flashback_gb
FROM v$flashback_database_log
WHERE first_time >= SYSDATE - 30
GROUP BY TRUNC(first_time)
ORDER BY flashback_date DESC;


PROMPT
PROMPT ============================================================================
PROMPT 12. FLASHBACK LOG GENERATION - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    COUNT(*) AS flashback_log_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS flashback_gb,
    MIN(first_time) AS oldest_log,
    MAX(first_time) AS latest_log
FROM v$flashback_database_log
WHERE first_time >= SYSDATE - 1;


PROMPT
PROMPT ============================================================================
PROMPT 13. FLASHBACK LOG GENERATION - LAST 7 DAYS
PROMPT ============================================================================

SELECT
    COUNT(*) AS flashback_log_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS flashback_gb,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024 / 7,
        2
    ) AS avg_gb_per_day
FROM v$flashback_database_log
WHERE first_time >= SYSDATE - 7;


PROMPT
PROMPT ============================================================================
PROMPT 14. FLASHBACK LOG GENERATION BY HOUR
PROMPT ============================================================================

SELECT
    TO_CHAR(
        first_time,
        'YYYY-MM-DD HH24'
    ) AS flashback_hour,
    COUNT(*) AS flashback_log_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS flashback_gb
FROM v$flashback_database_log
WHERE first_time >= SYSDATE - 1
GROUP BY
    TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY
    flashback_hour;


PROMPT
PROMPT ============================================================================
PROMPT 15. LARGEST FLASHBACK LOGS
PROMPT ============================================================================

SELECT
    first_time,
    next_time,
    thread#,
    sequence#,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM v$flashback_database_log
ORDER BY bytes DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================================
PROMPT 16. GUARANTEED RESTORE POINTS
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
PROMPT 17. ALL RESTORE POINTS
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
PROMPT 18. GUARANTEED RESTORE POINT STORAGE
PROMPT ============================================================================

SELECT
    name AS restore_point_name,
    ROUND(storage_size / 1024 / 1024 / 1024, 2)
        AS storage_size_gb,
    time,
    scn
FROM v$restore_point
WHERE guarantee_flashback_database = 'YES'
ORDER BY storage_size DESC;


PROMPT
PROMPT ============================================================================
PROMPT 19. FLASHBACK DATABASE LOG SUMMARY
PROMPT ============================================================================

SELECT
    COUNT(*) AS flashback_log_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_flashback_gb,
    ROUND(
        AVG(bytes) / 1024 / 1024,
        2
    ) AS avg_flashback_log_mb,
    ROUND(
        MIN(bytes) / 1024 / 1024,
        2
    ) AS smallest_log_mb,
    ROUND(
        MAX(bytes) / 1024 / 1024,
        2
    ) AS largest_log_mb
FROM v$flashback_database_log;


PROMPT
PROMPT ============================================================================
PROMPT 20. FRA PRESSURE
PROMPT ============================================================================

SELECT
    ROUND(space_limit / 1024 / 1024 / 1024, 2)
        AS limit_gb,
    ROUND(space_used / 1024 / 1024 / 1024, 2)
        AS used_gb,
    ROUND(
        (space_limit - space_used) /
        1024 / 1024 / 1024,
        2
    ) AS free_gb,
    ROUND(
        space_used / NULLIF(space_limit, 0) * 100,
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
PROMPT 21. FLASHBACK RETENTION VS AVAILABLE WINDOW
PROMPT ============================================================================

SELECT
    p.value AS retention_target_minutes,
    ROUND(p.value / 60, 2) AS retention_target_hours,
    ROUND(
        (
            SELECT
                (MAX(first_time) - MIN(first_time)) * 24 * 60
            FROM v$flashback_database_log
        ),
        2
    ) AS available_window_minutes,
    ROUND(
        (
            SELECT
                (MAX(first_time) - MIN(first_time)) * 24
            FROM v$flashback_database_log
        ),
        2
    ) AS available_window_hours,
    CASE
        WHEN
            (
                SELECT
                    (MAX(first_time) - MIN(first_time)) * 24 * 60
                FROM v$flashback_database_log
            ) >= p.value
        THEN 'OK - TARGET WINDOW CURRENTLY AVAILABLE'
        ELSE 'CHECK - WINDOW BELOW TARGET'
    END AS health
FROM v$parameter p
WHERE p.name = 'db_flashback_retention_target';


PROMPT
PROMPT ============================================================================
PROMPT 22. FLASHBACK LOGS WITH RECENT ACTIVITY
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS log_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_gb
FROM v$flashback_database_log
WHERE first_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 23. RECENT FLASHBACK-RELATED ALERTS
PROMPT ============================================================================

SELECT
    originating_timestamp,
    message_text
FROM v$diag_alert_ext
WHERE originating_timestamp >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND
  (
       UPPER(message_text) LIKE '%FLASHBACK%'
    OR UPPER(message_text) LIKE '%ORA-387%'
    OR UPPER(message_text) LIKE '%ORA-198%'
    OR UPPER(message_text) LIKE '%RECOVERY AREA%'
  )
ORDER BY originating_timestamp DESC;


PROMPT
PROMPT ============================================================================
PROMPT 24. FLASHBACK CONFIGURATION HEALTH
PROMPT ============================================================================

SELECT
    d.flashback_on,
    p.value AS retention_target_minutes,
    ROUND(p.value / 60, 2) AS retention_target_hours,
    CASE
        WHEN d.flashback_on = 'YES'
            THEN 'FLASHBACK DATABASE ENABLED'
        WHEN d.flashback_on = 'RESTORE POINT ONLY'
            THEN 'FLASHBACK AVAILABLE FOR RESTORE POINTS'
        ELSE 'FLASHBACK DATABASE DISABLED'
    END AS health
FROM v$database d
CROSS JOIN
(
    SELECT value
    FROM v$parameter
    WHERE name = 'db_flashback_retention_target'
) p;


PROMPT
PROMPT ============================================================================
PROMPT 25. FLASHBACK LOG SPACE HEALTH
PROMPT ============================================================================

SELECT
    file_type,
    number_of_files,
    ROUND(space_used / 1024 / 1024 / 1024, 2)
        AS used_gb,
    ROUND(percent_space_used, 2)
        AS percent_used,
    ROUND(percent_space_reclaimable, 2)
        AS percent_reclaimable,
    CASE
        WHEN percent_space_used >= 50
            THEN 'CHECK - HIGH FLASHBACK LOG CONSUMPTION'
        WHEN percent_space_used >= 25
            THEN 'REVIEW'
        ELSE 'OK'
    END AS health
FROM v$flash_recovery_area_usage
WHERE file_type = 'FLASHBACK LOG';


PROMPT
PROMPT ============================================================================
PROMPT 26. FLASHBACK HEALTH SUMMARY
PROMPT ============================================================================

SELECT
    d.flashback_on,
    ROUND(
        f.space_used / NULLIF(f.space_limit, 0) * 100,
        2
    ) AS fra_used_pct,
    ROUND(
        (
            SELECT
                (MAX(first_time) - MIN(first_time)) * 24
            FROM v$flashback_database_log
        ),
        2
    ) AS available_window_hours,
    ROUND(
        p.value / 60,
        2
    ) AS target_window_hours,
    (
        SELECT COUNT(*)
        FROM v$restore_point
        WHERE guarantee_flashback_database = 'YES'
    ) AS guaranteed_restore_points,
    CASE
        WHEN d.flashback_on = 'NO'
            THEN 'CHECK - FLASHBACK DATABASE DISABLED'
        WHEN f.space_used / NULLIF(f.space_limit, 0) * 100 >= 95
            THEN 'CRITICAL - FRA PRESSURE'
        WHEN
            (
                SELECT
                    (MAX(first_time) - MIN(first_time)) * 24 * 60
                FROM v$flashback_database_log
            ) < p.value
            THEN 'CHECK - FLASHBACK WINDOW BELOW TARGET'
        ELSE 'OK - FLASHBACK CONFIGURATION LOOKS HEALTHY'
    END AS health
FROM v$database d
CROSS JOIN v$recovery_file_dest f
CROSS JOIN
(
    SELECT value
    FROM v$parameter
    WHERE name = 'db_flashback_retention_target'
) p;


PROMPT
PROMPT ============================================================================
PROMPT 27. QUICK FLASHBACK CHECK
PROMPT ============================================================================

SELECT
    flashback_on,
    (
        SELECT
            value
        FROM v$parameter
        WHERE name = 'db_flashback_retention_target'
    ) AS retention_target_minutes,
    (
        SELECT
            COUNT(*)
        FROM v$flashback_database_log
    ) AS flashback_log_count,
    (
        SELECT
            ROUND(
                SUM(bytes) / 1024 / 1024 / 1024,
                2
            )
        FROM v$flashback_database_log
    ) AS flashback_log_gb,
    (
        SELECT
            ROUND(
                space_used / NULLIF(space_limit, 0) * 100,
                2
            )
        FROM v$recovery_file_dest
    ) AS fra_used_pct
FROM v$database;


PROMPT
PROMPT ============================================================================
PROMPT 28. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] Confirm FLASHBACK DATABASE status.
PROMPT [ ] Check DB_FLASHBACK_RETENTION_TARGET.
PROMPT [ ] Check actual Flashback Log availability.
PROMPT [ ] Compare available Flashback window with the target.
PROMPT [ ] Check FRA total and used space.
PROMPT [ ] Identify Flashback Log FRA consumption.
PROMPT [ ] Check for guaranteed restore points.
PROMPT [ ] Review storage consumed by guaranteed restore points.
PROMPT [ ] Check recent Flashback/FRA-related alert messages.
PROMPT [ ] Review archive log generation and FRA growth.
PROMPT [ ] Check whether backup activity is consuming FRA space.
PROMPT [ ] Verify Flashback requirements before changing FRA size.
PROMPT [ ] Do not manually delete Flashback Logs from the filesystem.
PROMPT [ ] Use RMAN/Oracle-supported commands for recovery-area management.
PROMPT [ ] Remember that retention target is a target, not a guaranteed window.
PROMPT [ ] For critical recovery requirements, perform an actual recovery test.
PROMPT
PROMPT ============================================================================
PROMPT END OF FLASHBACK USAGE CHECK
PROMPT ============================================================================


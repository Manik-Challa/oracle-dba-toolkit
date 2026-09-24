-- ============================================================================
-- Oracle DBA Toolkit
-- Script   : redo_log_switches.sql
-- Purpose  : Monitor Oracle redo log switch frequency and trends
-- Author   : Manik Challa
-- Version  : 1.0
-- ============================================================================
--
-- READ-ONLY SCRIPT
--
-- Covers:
--   1. Database / instance information
--   2. Redo log configuration
--   3. Current redo log status
--   4. Log switches - last 24 hours
--   5. Hourly switch frequency
--   6. Daily switch frequency
--   7. RAC thread switch activity
--   8. Recent log switches
--   9. Peak switch hours
--  10. Average switches per hour
--  11. Redo generation statistics
--  12. Redo log size
--  13. Switch frequency health indicator
--  14. DBA investigation checklist
--
-- Notes:
--   * V$LOG_HISTORY is cumulative/history based.
--   * Available history depends on control-file retention.
--   * Frequent log switches should be correlated with redo volume and
--     workload before resizing redo logs.
--   * Thresholds below are investigation indicators, not Oracle requirements.
--   * This script does NOT add, drop, resize or switch redo logs.
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF
SET FEEDBACK ON

COLUMN database_name FORMAT A15
COLUMN instance_name FORMAT A15
COLUMN host_name FORMAT A30
COLUMN log_mode FORMAT A15
COLUMN force_logging FORMAT A15

COLUMN thread# FORMAT 999
COLUMN group# FORMAT 999
COLUMN sequence# FORMAT 999999999
COLUMN status FORMAT A12
COLUMN archived FORMAT A8

COLUMN switch_date FORMAT A12
COLUMN switch_hour FORMAT A18
COLUMN switch_count FORMAT 999,999
COLUMN avg_switches_per_hour FORMAT 999,999.99
COLUMN max_switches_per_hour FORMAT 999,999
COLUMN redo_mb FORMAT 999,999,999.99
COLUMN redo_gb FORMAT 999,999.99
COLUMN bytes_mb FORMAT 999,999,999
COLUMN switch_rate FORMAT 999,999.99
COLUMN health_status FORMAT A60


PROMPT
PROMPT ============================================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ============================================================================

SELECT
    d.name AS database_name,
    d.open_mode,
    d.log_mode,
    d.force_logging,
    i.instance_name,
    i.host_name,
    i.thread#
FROM v$database d
CROSS JOIN v$instance i;


PROMPT
PROMPT ============================================================================
PROMPT 2. REDO LOG CONFIGURATION
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS log_groups,
    ROUND(MIN(bytes) / 1024 / 1024, 2) AS min_size_mb,
    ROUND(MAX(bytes) / 1024 / 1024, 2) AS max_size_mb,
    ROUND(AVG(bytes) / 1024 / 1024, 2) AS avg_size_mb
FROM v$log
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 3. CURRENT REDO LOG STATUS
PROMPT ============================================================================

SELECT
    thread#,
    group#,
    sequence#,
    status,
    archived,
    ROUND(bytes / 1024 / 1024, 2) AS bytes_mb
FROM v$log
ORDER BY
    thread#,
    group#;


PROMPT
PROMPT ============================================================================
PROMPT 4. TOTAL LOG SWITCHES - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    COUNT(*) AS total_switches,
    COUNT(DISTINCT thread#) AS active_threads,
    ROUND(
        COUNT(*) / 24,
        2
    ) AS avg_switches_per_hour
FROM v$log_history
WHERE first_time >= SYSDATE - 1;


PROMPT
PROMPT ============================================================================
PROMPT 5. LOG SWITCHES BY THREAD - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS switch_count,
    ROUND(COUNT(*) / 24, 2) AS avg_switches_per_hour,
    MIN(first_time) AS first_switch,
    MAX(first_time) AS last_switch
FROM v$log_history
WHERE first_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 6. HOURLY LOG SWITCH FREQUENCY - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS switch_hour,
    thread#,
    COUNT(*) AS switch_count
FROM v$log_history
WHERE first_time >= SYSDATE - 1
GROUP BY
    TO_CHAR(first_time, 'YYYY-MM-DD HH24'),
    thread#
ORDER BY
    switch_hour,
    thread#;


PROMPT
PROMPT ============================================================================
PROMPT 7. HOURLY LOG SWITCH SUMMARY - ALL THREADS
PROMPT ============================================================================

SELECT
    TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS switch_hour,
    COUNT(*) AS switch_count
FROM v$log_history
WHERE first_time >= SYSDATE - 1
GROUP BY
    TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY
    switch_hour;


PROMPT
PROMPT ============================================================================
PROMPT 8. PEAK SWITCH HOURS - LAST 24 HOURS
PROMPT ============================================================================

SELECT
    TO_CHAR(first_time, 'YYYY-MM-DD HH24') AS switch_hour,
    COUNT(*) AS switch_count
FROM v$log_history
WHERE first_time >= SYSDATE - 1
GROUP BY
    TO_CHAR(first_time, 'YYYY-MM-DD HH24')
ORDER BY
    switch_count DESC
FETCH FIRST 10 ROWS ONLY;


PROMPT
PROMPT ============================================================================
PROMPT 9. DAILY LOG SWITCH FREQUENCY - LAST 7 DAYS
PROMPT ============================================================================

SELECT
    TRUNC(first_time) AS switch_date,
    COUNT(*) AS switch_count,
    COUNT(DISTINCT thread#) AS threads_active,
    ROUND(COUNT(*) / 24, 2) AS avg_switches_per_hour
FROM v$log_history
WHERE first_time >= SYSDATE - 7
GROUP BY TRUNC(first_time)
ORDER BY switch_date DESC;


PROMPT
PROMPT ============================================================================
PROMPT 10. DAILY LOG SWITCH FREQUENCY - LAST 30 DAYS
PROMPT ============================================================================

SELECT
    TRUNC(first_time) AS switch_date,
    COUNT(*) AS switch_count,
    COUNT(DISTINCT thread#) AS threads_active
FROM v$log_history
WHERE first_time >= SYSDATE - 30
GROUP BY TRUNC(first_time)
ORDER BY switch_date DESC;


PROMPT
PROMPT ============================================================================
PROMPT 11. SWITCH FREQUENCY BY RAC THREAD - LAST 7 DAYS
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS switch_count,
    ROUND(COUNT(*) / (7 * 24), 2) AS avg_switches_per_hour,
    MIN(first_time) AS first_switch,
    MAX(first_time) AS last_switch
FROM v$log_history
WHERE first_time >= SYSDATE - 7
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 12. RECENT REDO LOG SWITCHES
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    first_time,
    first_change#,
    next_change#
FROM v$log_history
WHERE first_time >= SYSDATE - 1
ORDER BY
    first_time DESC,
    thread# DESC;


PROMPT
PROMPT ============================================================================
PROMPT 13. REDO SWITCH INTERVAL - RECENT SWITCHES
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    first_time,
    ROUND(
        (first_time -
         LAG(first_time) OVER
         (
             PARTITION BY thread#
             ORDER BY first_time
         )) * 24 * 60,
        2
    ) AS minutes_since_previous_switch
FROM v$log_history
WHERE first_time >= SYSDATE - 1
ORDER BY
    thread#,
    first_time DESC;


PROMPT
PROMPT ============================================================================
PROMPT 14. SWITCHES WITH LESS THAN 15 MINUTES BETWEEN SWITCHES
PROMPT ============================================================================

SELECT
    thread#,
    sequence#,
    first_time,
    ROUND(
        (first_time -
         LAG(first_time) OVER
         (
             PARTITION BY thread#
             ORDER BY first_time
         )) * 24 * 60,
        2
    ) AS minutes_since_previous_switch
FROM v$log_history
WHERE first_time >= SYSDATE - 1
QUALIFY 1 = 1
ORDER BY
    thread#,
    first_time DESC;


PROMPT
PROMPT NOTE:
PROMPT The query above displays switch intervals for investigation.
PROMPT Review intervals below 15 minutes as potential frequent-switch indicators.
PROMPT Thresholds are workload-dependent and are NOT Oracle requirements.


PROMPT
PROMPT ============================================================================
PROMPT 15. REDO GENERATION STATISTICS
PROMPT ============================================================================
PROMPT Values are cumulative since instance startup.

SELECT
    name,
    ROUND(value / 1024 / 1024, 2) AS redo_mb
FROM v$sysstat
WHERE name = 'redo size';


PROMPT
PROMPT ============================================================================
PROMPT 16. REDO GENERATION DETAILS
PROMPT ============================================================================

SELECT
    name,
    value
FROM v$sysstat
WHERE name IN
(
    'redo size',
    'redo entries',
    'redo writes',
    'redo wastage',
    'redo synch writes',
    'redo synch time'
)
ORDER BY name;


PROMPT
PROMPT ============================================================================
PROMPT 17. REDO GENERATED PER SWITCH - APPROXIMATE
PROMPT ============================================================================
PROMPT This is an approximate indicator based on cumulative redo size
PROMPT divided by historical switch count. It is NOT a time-based rate.

SELECT
    ROUND(
        (
            SELECT value
            FROM v$sysstat
            WHERE name = 'redo size'
        ) / NULLIF(
            (SELECT COUNT(*) FROM v$log_history),
            0
        ) / 1024 / 1024,
        2
    ) AS approx_redo_mb_per_switch
FROM dual;


PROMPT
PROMPT ============================================================================
PROMPT 18. LOG SWITCH COUNT BY HOUR - LAST 7 DAYS
PROMPT ============================================================================

SELECT
    TO_CHAR(first_time, 'DY') AS day_name,
    TO_CHAR(first_time, 'HH24') AS hour_of_day,
    COUNT(*) AS switch_count
FROM v$log_history
WHERE first_time >= SYSDATE - 7
GROUP BY
    TO_CHAR(first_time, 'DY'),
    TO_CHAR(first_time, 'HH24')
ORDER BY
    day_name,
    hour_of_day;


PROMPT
PROMPT ============================================================================
PROMPT 19. REDO LOG GROUP COUNT VS SWITCH ACTIVITY
PROMPT ============================================================================

SELECT
    l.thread#,
    COUNT(*) AS log_groups,
    ROUND(MIN(l.bytes) / 1024 / 1024, 2) AS min_log_size_mb,
    ROUND(MAX(l.bytes) / 1024 / 1024, 2) AS max_log_size_mb,
    (
        SELECT COUNT(*)
        FROM v$log_history h
        WHERE h.thread# = l.thread#
          AND h.first_time >= SYSDATE - 1
    ) AS switches_last_24h
FROM v$log l
GROUP BY l.thread#
ORDER BY l.thread#;


PROMPT
PROMPT ============================================================================
PROMPT 20. REDO LOG SWITCH HEALTH INDICATOR
PROMPT ============================================================================
PROMPT Threshold:
PROMPT   0-4 switches/hour  : NORMAL INDICATOR
PROMPT   5-12 switches/hour : REVIEW
PROMPT   >12 switches/hour  : INVESTIGATE
PROMPT
PROMPT These are investigation thresholds only and are not Oracle standards.

SELECT
    ROUND(COUNT(*) / 24, 2) AS avg_switches_per_hour,
    CASE
        WHEN COUNT(*) / 24 > 12
            THEN 'INVESTIGATE - HIGH SWITCH FREQUENCY'
        WHEN COUNT(*) / 24 >= 5
            THEN 'REVIEW - FREQUENT SWITCHING'
        ELSE
            'NORMAL INDICATOR'
    END AS health_status
FROM v$log_history
WHERE first_time >= SYSDATE - 1;


PROMPT
PROMPT ============================================================================
PROMPT 21. THREAD-LEVEL SWITCH HEALTH
PROMPT ============================================================================

SELECT
    thread#,
    COUNT(*) AS switches_last_24h,
    ROUND(COUNT(*) / 24, 2) AS avg_switches_per_hour,
    CASE
        WHEN COUNT(*) / 24 > 12
            THEN 'INVESTIGATE'
        WHEN COUNT(*) / 24 >= 5
            THEN 'REVIEW'
        ELSE
            'NORMAL INDICATOR'
    END AS health_status
FROM v$log_history
WHERE first_time >= SYSDATE - 1
GROUP BY thread#
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 22. CURRENT LOG AGE
PROMPT ============================================================================

SELECT
    thread#,
    group#,
    sequence#,
    status,
    first_time,
    ROUND(
        (SYSDATE - first_time) * 24 * 60,
        2
    ) AS current_log_age_minutes
FROM v$log
WHERE status = 'CURRENT'
ORDER BY thread#;


PROMPT
PROMPT ============================================================================
PROMPT 23. REDO SWITCH SUMMARY
PROMPT ============================================================================

SELECT
    (SELECT COUNT(*)
       FROM v$log_history
      WHERE first_time >= SYSDATE - 1) AS switches_24h,

    (SELECT COUNT(*)
       FROM v$log_history
      WHERE first_time >= SYSDATE - 7) AS switches_7d,

    (SELECT COUNT(*)
       FROM v$log_history
      WHERE first_time >= SYSDATE - 30) AS switches_30d,

    (SELECT ROUND(
                COUNT(*) / 24,
                2
            )
       FROM v$log_history
      WHERE first_time >= SYSDATE - 1) AS avg_switches_per_hour_24h
FROM dual;


PROMPT
PROMPT ============================================================================
PROMPT 24. DBA INVESTIGATION CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] Check redo switch frequency for the last 24 hours.
PROMPT [ ] Check hourly and daily switch trends.
PROMPT [ ] Check RAC thread-level switch activity.
PROMPT [ ] Check redo log size per thread.
PROMPT [ ] Check redo generation volume.
PROMPT [ ] Check time between consecutive switches.
PROMPT [ ] Check archive destination health.
PROMPT [ ] Check LGWR / redo-related wait events if switching is excessive.
PROMPT [ ] Correlate switches with application batch jobs and peak workload.
PROMPT [ ] Check whether redo logs are too small for the workload.
PROMPT [ ] Check whether archiving is keeping pace.
PROMPT [ ] Review AWR/ASH for historical performance correlation where available.
PROMPT [ ] Do not resize redo logs based on switch count alone.
PROMPT
PROMPT ============================================================================
PROMPT END OF REDO LOG SWITCH MONITORING
PROMPT ============================================================================


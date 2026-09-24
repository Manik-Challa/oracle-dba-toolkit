-- ============================================================
-- Oracle DBA Toolkit
-- Database Uptime Monitoring
--
-- Purpose:
--   Monitor Oracle database and instance uptime.
--
-- Key checks:
--   - Instance startup time
--   - Instance uptime
--   - Database creation time
--   - Database open mode
--   - Database role
--   - RAC instance uptime
--   - Recent startup information
--
-- Notes:
--   Instance uptime resets whenever the Oracle instance restarts.
--   Database creation time does not change after a restart.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name       FORMAT A18
COLUMN host_name           FORMAT A35
COLUMN version             FORMAT A18
COLUMN status              FORMAT A12
COLUMN database_name       FORMAT A20
COLUMN db_unique_name      FORMAT A25
COLUMN open_mode           FORMAT A20
COLUMN database_role       FORMAT A20
COLUMN startup_time        FORMAT A20
COLUMN current_time        FORMAT A20
COLUMN uptime              FORMAT A30
COLUMN uptime_days         FORMAT 999,999,990.00
COLUMN created             FORMAT A20
COLUMN logins              FORMAT A15
COLUMN instance_number     FORMAT 999
COLUMN thread               FORMAT 999

PROMPT
PROMPT ============================================================
PROMPT 1. INSTANCE UPTIME
PROMPT ============================================================

SELECT
    instance_name,
    host_name,
    version,
    status,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time,
    TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') AS current_time,
    ROUND((SYSDATE - startup_time), 2) AS uptime_days,
    FLOOR(SYSDATE - startup_time) || ' days ' ||
    FLOOR(MOD((SYSDATE - startup_time) * 24, 24)) || ' hours ' ||
    FLOOR(MOD((SYSDATE - startup_time) * 1440, 60)) || ' minutes'
        AS uptime
FROM v$instance;


PROMPT
PROMPT ============================================================
PROMPT 2. DATABASE INFORMATION
PROMPT ============================================================

SELECT
    name AS database_name,
    db_unique_name,
    open_mode,
    database_role,
    log_mode,
    TO_CHAR(created, 'YYYY-MM-DD HH24:MI:SS') AS created,
    TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') AS current_time
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 3. INSTANCE STARTUP DETAILS
PROMPT ============================================================

SELECT
    instance_name,
    instance_number,
    host_name,
    status,
    startup_time,
    logins,
    parallel,
    thread#
FROM v$instance;


PROMPT
PROMPT ============================================================
PROMPT 4. DATABASE AGE
PROMPT ============================================================

SELECT
    name AS database_name,
    TO_CHAR(created, 'YYYY-MM-DD HH24:MI:SS') AS database_created,
    ROUND(SYSDATE - created, 2) AS database_age_days,
    FLOOR((SYSDATE - created) / 365) AS approx_years,
    FLOOR(MOD(SYSDATE - created, 365) / 30) AS approx_months
FROM v$database;


PROMPT
PROMPT ============================================================
PROMPT 5. RAC INSTANCE UPTIME
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    instance_number,
    thread#,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time,
    ROUND(SYSDATE - startup_time, 2) AS uptime_days,
    FLOOR(SYSDATE - startup_time) || ' days ' ||
    FLOOR(MOD((SYSDATE - startup_time) * 24, 24)) || ' hours ' ||
    FLOOR(MOD((SYSDATE - startup_time) * 1440, 60)) || ' minutes'
        AS uptime
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 6. INSTANCE STATUS SUMMARY
PROMPT ============================================================

SELECT
    status,
    COUNT(*) AS instance_count
FROM gv$instance
GROUP BY status
ORDER BY status;


PROMPT
PROMPT ============================================================
PROMPT 7. INSTANCES WITH SHORT UPTIME
PROMPT    Review instances restarted within the last 24 hours.
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time,
    ROUND((SYSDATE - startup_time) * 24, 2) AS uptime_hours
FROM gv$instance
WHERE startup_time >= SYSDATE - 1
ORDER BY startup_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. INSTANCES RESTARTED WITHIN LAST 7 DAYS
PROMPT ============================================================

SELECT
    inst_id,
    instance_name,
    host_name,
    status,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time,
    ROUND(SYSDATE - startup_time, 2) AS uptime_days
FROM gv$instance
WHERE startup_time >= SYSDATE - 7
ORDER BY startup_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. CURRENT DATABASE TIME
PROMPT ============================================================

SELECT
    TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') AS database_time,
    TO_CHAR(SYSTIMESTAMP, 'YYYY-MM-DD HH24:MI:SS.FF3 TZH:TZM')
        AS database_timestamp
FROM dual;


PROMPT
PROMPT ============================================================
PROMPT 10. STARTUP / UPTIME SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS instance_count,
    MIN(startup_time) AS oldest_startup,
    MAX(startup_time) AS newest_startup,
    ROUND(MIN(SYSDATE - startup_time), 2) AS minimum_uptime_days,
    ROUND(MAX(SYSDATE - startup_time), 2) AS maximum_uptime_days,
    ROUND(AVG(SYSDATE - startup_time), 2) AS average_uptime_days
FROM gv$instance;


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION NOTES
PROMPT ============================================================
PROMPT
PROMPT 1. V$INSTANCE.STARTUP_TIME shows when the current instance started.
PROMPT 2. Instance uptime resets after shutdown/startup or instance restart.
PROMPT 3. In RAC, check GV$INSTANCE for uptime of every instance.
PROMPT 4. A recently restarted instance should be correlated with:
PROMPT      - Alert log
PROMPT      - OS reboot history
PROMPT      - Clusterware events
PROMPT      - Database errors
PROMPT      - Maintenance / patching activity
PROMPT 5. Database creation time is different from instance startup time.
PROMPT 6. Short uptime does not automatically indicate a problem.
PROMPT 7. Investigate unexpected restarts using alert.log and OS logs.
PROMPT
PROMPT ============================================================
PROMPT END OF DATABASE UPTIME MONITORING
PROMPT ============================================================


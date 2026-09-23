-- ============================================================
-- Oracle Scheduler Jobs Monitoring
-- File   : scheduler_jobs.sql
-- Purpose: Monitor Oracle DBMS_SCHEDULER jobs
-- Author : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN owner              FORMAT A25
COLUMN job_name           FORMAT A50
COLUMN job_type           FORMAT A20
COLUMN job_action         FORMAT A60 WORD_WRAP
COLUMN state              FORMAT A18
COLUMN enabled            FORMAT A10
COLUMN run_count          FORMAT 999,999,999
COLUMN failure_count      FORMAT 999,999,999
COLUMN retry_count        FORMAT 999,999,999
COLUMN run_duration       FORMAT A20
COLUMN actual_start_date  FORMAT A25
COLUMN next_run_date      FORMAT A25
COLUMN last_start_date    FORMAT A25
COLUMN last_run_duration  FORMAT A20
COLUMN status             FORMAT A20
COLUMN error#             FORMAT 999999999
COLUMN additional_info    FORMAT A80 WORD_WRAP

PROMPT
PROMPT ============================================================
PROMPT ORACLE SCHEDULER JOB MONITORING
PROMPT ============================================================
PROMPT

-- ============================================================
-- 1. DATABASE INFORMATION
-- ============================================================

PROMPT ============================================================
PROMPT 1. DATABASE INFORMATION
PROMPT ============================================================

SELECT
    name,
    db_unique_name,
    open_mode,
    database_role
FROM v$database;

SELECT
    instance_name,
    host_name,
    status,
    startup_time
FROM v$instance;

-- ============================================================
-- 2. SCHEDULER JOB SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. SCHEDULER JOB SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS total_jobs,
    SUM(CASE WHEN enabled = 'TRUE' THEN 1 ELSE 0 END) AS enabled_jobs,
    SUM(CASE WHEN enabled = 'FALSE' THEN 1 ELSE 0 END) AS disabled_jobs,
    SUM(CASE WHEN state = 'RUNNING' THEN 1 ELSE 0 END) AS running_jobs,
    SUM(CASE WHEN state = 'FAILED' THEN 1 ELSE 0 END) AS failed_jobs,
    SUM(CASE WHEN state = 'BROKEN' THEN 1 ELSE 0 END) AS broken_jobs
FROM dba_scheduler_jobs;

-- ============================================================
-- 3. ALL SCHEDULER JOBS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. ALL SCHEDULER JOBS
PROMPT ============================================================

SELECT
    owner,
    job_name,
    job_type,
    enabled,
    state,
    run_count,
    failure_count,
    retry_count,
    last_start_date,
    next_run_date
FROM dba_scheduler_jobs
ORDER BY owner, job_name;

-- ============================================================
-- 4. FAILED JOBS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. FAILED SCHEDULER JOBS
PROMPT ============================================================

SELECT
    owner,
    job_name,
    job_type,
    state,
    enabled,
    run_count,
    failure_count,
    retry_count,
    last_start_date,
    next_run_date
FROM dba_scheduler_jobs
WHERE state IN ('FAILED', 'BROKEN')
   OR failure_count > 0
ORDER BY failure_count DESC, owner, job_name;

-- ============================================================
-- 5. CURRENTLY RUNNING JOBS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. CURRENTLY RUNNING JOBS
PROMPT ============================================================

SELECT
    owner,
    job_name,
    session_id,
    running_instance,
    elapsed_time,
    cpu_used,
    slave_process_id,
    actual_start_date
FROM dba_scheduler_running_jobs
ORDER BY actual_start_date;

-- ============================================================
-- 6. LONG-RUNNING JOBS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. LONG-RUNNING JOBS
PROMPT ============================================================

SELECT
    owner,
    job_name,
    session_id,
    running_instance,
    elapsed_time,
    cpu_used,
    actual_start_date
FROM dba_scheduler_running_jobs
WHERE actual_start_date < SYSTIMESTAMP - INTERVAL '30' MINUTE
ORDER BY actual_start_date;

-- ============================================================
-- 7. DISABLED JOBS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. DISABLED SCHEDULER JOBS
PROMPT ============================================================

SELECT
    owner,
    job_name,
    job_type,
    state,
    enabled,
    run_count,
    failure_count,
    last_start_date,
    next_run_date
FROM dba_scheduler_jobs
WHERE enabled = 'FALSE'
ORDER BY owner, job_name;

-- ============================================================
-- 8. BROKEN JOBS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. BROKEN SCHEDULER JOBS
PROMPT ============================================================

SELECT
    owner,
    job_name,
    job_type,
    state,
    enabled,
    failure_count,
    retry_count,
    last_start_date,
    next_run_date
FROM dba_scheduler_jobs
WHERE state = 'BROKEN'
ORDER BY failure_count DESC, owner, job_name;

-- ============================================================
-- 9. JOBS WITH HIGH FAILURE COUNTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. JOBS WITH HIGH FAILURE COUNTS
PROMPT ============================================================

SELECT
    owner,
    job_name,
    state,
    run_count,
    failure_count,
    retry_count,
    ROUND(
        CASE
            WHEN run_count > 0
            THEN failure_count * 100 / run_count
            ELSE 0
        END,
        2
    ) AS failure_pct,
    last_start_date,
    next_run_date
FROM dba_scheduler_jobs
WHERE failure_count > 0
ORDER BY failure_count DESC, failure_pct DESC;

-- ============================================================
-- 10. JOB RUN HISTORY - LAST 24 HOURS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. JOB RUN HISTORY - LAST 24 HOURS
PROMPT ============================================================

SELECT
    log_date,
    owner,
    job_name,
    status,
    run_duration,
    additional_info
FROM dba_scheduler_job_run_details
WHERE log_date >= SYSTIMESTAMP - INTERVAL '24' HOUR
ORDER BY log_date DESC;

-- ============================================================
-- 11. FAILED JOB RUNS - LAST 24 HOURS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. FAILED JOB RUNS - LAST 24 HOURS
PROMPT ============================================================

SELECT
    log_date,
    owner,
    job_name,
    status,
    error#,
    run_duration,
    additional_info
FROM dba_scheduler_job_run_details
WHERE log_date >= SYSTIMESTAMP - INTERVAL '24' HOUR
  AND status = 'FAILED'
ORDER BY log_date DESC;

-- ============================================================
-- 12. FAILED JOB RUNS - LAST 7 DAYS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. FAILED JOB RUNS - LAST 7 DAYS
PROMPT ============================================================

SELECT
    owner,
    job_name,
    COUNT(*) AS failed_runs,
    MAX(log_date) AS last_failure
FROM dba_scheduler_job_run_details
WHERE log_date >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND status = 'FAILED'
GROUP BY owner, job_name
ORDER BY failed_runs DESC, last_failure DESC;

-- ============================================================
-- 13. JOB RUN SUMMARY - LAST 7 DAYS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. JOB RUN SUMMARY - LAST 7 DAYS
PROMPT ============================================================

SELECT
    owner,
    job_name,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN status = 'SUCCEEDED' THEN 1 ELSE 0 END)
        AS successful_runs,
    SUM(CASE WHEN status = 'FAILED' THEN 1 ELSE 0 END)
        AS failed_runs,
    MAX(log_date) AS last_run
FROM dba_scheduler_job_run_details
WHERE log_date >= SYSTIMESTAMP - INTERVAL '7' DAY
GROUP BY owner, job_name
ORDER BY failed_runs DESC, total_runs DESC;

-- ============================================================
-- 14. JOBS WITH REPEATED FAILURES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. JOBS WITH REPEATED FAILURES
PROMPT ============================================================

SELECT
    owner,
    job_name,
    COUNT(*) AS failed_runs,
    MIN(log_date) AS first_failure,
    MAX(log_date) AS latest_failure
FROM dba_scheduler_job_run_details
WHERE log_date >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND status = 'FAILED'
GROUP BY owner, job_name
HAVING COUNT(*) >= 3
ORDER BY failed_runs DESC;

-- ============================================================
-- 15. LONGEST JOB RUNS - LAST 7 DAYS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. LONGEST JOB RUNS - LAST 7 DAYS
PROMPT ============================================================

SELECT
    owner,
    job_name,
    log_date,
    status,
    run_duration,
    additional_info
FROM dba_scheduler_job_run_details
WHERE log_date >= SYSTIMESTAMP - INTERVAL '7' DAY
ORDER BY run_duration DESC
FETCH FIRST 50 ROWS ONLY;

-- ============================================================
-- 16. RECENT JOB ERRORS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. RECENT JOB ERRORS
PROMPT ============================================================

SELECT
    log_date,
    owner,
    job_name,
    status,
    error#,
    additional_info
FROM dba_scheduler_job_run_details
WHERE log_date >= SYSTIMESTAMP - INTERVAL '7' DAY
  AND error# IS NOT NULL
ORDER BY log_date DESC;

-- ============================================================
-- 17. JOB DETAILS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. JOB ACTION DETAILS
PROMPT ============================================================

SELECT
    owner,
    job_name,
    job_type,
    job_action,
    enabled,
    state,
    run_count,
    failure_count,
    retry_count
FROM dba_scheduler_jobs
ORDER BY owner, job_name;

-- ============================================================
-- 18. JOBS WITH NO RECENT RUN
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. ENABLED JOBS WITH NO RECENT RUN
PROMPT ============================================================

SELECT
    owner,
    job_name,
    state,
    enabled,
    last_start_date,
    next_run_date,
    run_count
FROM dba_scheduler_jobs
WHERE enabled = 'TRUE'
  AND (
        last_start_date IS NULL
        OR last_start_date < SYSTIMESTAMP - INTERVAL '30' DAY
      )
ORDER BY last_start_date NULLS FIRST;

-- ============================================================
-- 19. JOBS BY OWNER
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 19. SCHEDULER JOBS BY OWNER
PROMPT ============================================================

SELECT
    owner,
    COUNT(*) AS total_jobs,
    SUM(CASE WHEN enabled = 'TRUE' THEN 1 ELSE 0 END)
        AS enabled_jobs,
    SUM(CASE WHEN enabled = 'FALSE' THEN 1 ELSE 0 END)
        AS disabled_jobs,
    SUM(CASE WHEN state = 'RUNNING' THEN 1 ELSE 0 END)
        AS running_jobs,
    SUM(CASE WHEN state IN ('FAILED', 'BROKEN') THEN 1 ELSE 0 END)
        AS failed_or_broken
FROM dba_scheduler_jobs
GROUP BY owner
ORDER BY failed_or_broken DESC, total_jobs DESC;

-- ============================================================
-- 20. JOB HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 20. SCHEDULER HEALTH CHECK
PROMPT ============================================================

SELECT
    COUNT(*) AS total_jobs,
    SUM(CASE WHEN state IN ('FAILED', 'BROKEN')
             THEN 1 ELSE 0 END) AS failed_or_broken,
    SUM(CASE WHEN enabled = 'FALSE'
             THEN 1 ELSE 0 END) AS disabled_jobs,
    SUM(CASE WHEN state = 'RUNNING'
             THEN 1 ELSE 0 END) AS running_jobs
FROM dba_scheduler_jobs;

-- ============================================================
-- 21. QUICK STATUS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 21. QUICK SCHEDULER STATUS
PROMPT ============================================================

SELECT
    CASE
        WHEN SUM(
                 CASE
                     WHEN state IN ('FAILED', 'BROKEN')
                     THEN 1
                     ELSE 0
                 END
             ) > 0
            THEN 'ATTENTION - Failed or broken jobs detected'

        WHEN SUM(
                 CASE
                     WHEN enabled = 'FALSE'
                     THEN 1
                     ELSE 0
                 END
             ) > 0
            THEN 'WARNING - Disabled scheduler jobs detected'

        ELSE 'HEALTHY - No failed or broken jobs detected'
    END AS scheduler_status,
    COUNT(*) AS total_jobs
FROM dba_scheduler_jobs;

PROMPT
PROMPT ============================================================
PROMPT INVESTIGATION NOTES
PROMPT ============================================================
PROMPT
PROMPT 1. Check DBA_SCHEDULER_JOB_RUN_DETAILS for actual failures.
PROMPT 2. Review ERROR# and ADDITIONAL_INFO for failed executions.
PROMPT 3. Check long-running jobs for unexpected runtime increases.
PROMPT 4. A DISABLED job may be intentional - verify before changing it.
PROMPT 5. A BROKEN job may require credential, program, or job-action checks.
PROMPT 6. Repeated failures should be correlated with alert.log and application logs.
PROMPT 7. Check job owner privileges before troubleshooting job actions.
PROMPT 8. In RAC, verify RUNNING_INSTANCE and service configuration.
PROMPT 9. Do not enable, disable, stop, or alter jobs from a monitoring script.
PROMPT
PROMPT ============================================================
PROMPT END OF SCHEDULER MONITORING
PROMPT ============================================================


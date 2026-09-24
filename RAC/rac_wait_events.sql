-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_wait_events.sql
-- Purpose: RAC-wide wait event monitoring and analysis
-- Scope  : System waits, current session waits, RAC/GC waits,
--          I/O waits, concurrency, CPU/resource manager waits,
--          instance comparison and SQL correlation
--
-- IMPORTANT:
-- V$SYSTEM_EVENT / GV$SYSTEM_EVENT statistics are cumulative
-- since instance startup.
--
-- This script is READ-ONLY.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name FORMAT A18
COLUMN host_name     FORMAT A30
COLUMN event         FORMAT A65
COLUMN wait_class    FORMAT A25
COLUMN sql_id        FORMAT A15
COLUMN username      FORMAT A25
COLUMN service_name  FORMAT A35
COLUMN machine       FORMAT A35
COLUMN program       FORMAT A40
COLUMN module        FORMAT A30

PROMPT
PROMPT ============================================================
PROMPT 1. RAC INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    inst_id,
    instance_number,
    instance_name,
    host_name,
    status,
    database_status,
    TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI:SS') AS startup_time
FROM gv$instance
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 2. TOP SYSTEM WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        (time_waited /
         NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE wait_class <> 'Idle'
ORDER BY time_waited DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 3. TOP WAIT EVENTS BY AVERAGE LATENCY
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        (time_waited /
         NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE wait_class <> 'Idle'
  AND total_waits > 0
ORDER BY
    (time_waited /
     NULLIF(total_waits, 0)) DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 4. WAIT CLASS SUMMARY BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    wait_class,
    SUM(total_waits) AS total_waits,
    ROUND(
        SUM(time_waited) / 100,
        2
    ) AS time_waited_sec,
    ROUND(
        SUM(time_waited) /
        NULLIF(SUM(total_waits), 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE wait_class <> 'Idle'
GROUP BY
    inst_id,
    wait_class
ORDER BY
    inst_id,
    time_waited_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 5. RAC CACHE FUSION / GLOBAL CACHE WAITS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 6. GC CURRENT BLOCK WAITS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc current%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 7. GC CONSISTENT READ WAITS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc cr%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. CURRENT RAC WAITERS
PROMPT ============================================================

SELECT
    inst_id,
    sid,
    serial# AS serial,
    username,
    status,
    sql_id,
    event,
    wait_class,
    state,
    seconds_in_wait,
    service_name,
    machine,
    program
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
ORDER BY seconds_in_wait DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 9. LONGEST CURRENT WAITS
PROMPT ============================================================

SELECT
    inst_id,
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    seconds_in_wait,
    service_name,
    machine
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
ORDER BY seconds_in_wait DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 10. CURRENT WAITERS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    wait_class,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS longest_wait_sec
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
GROUP BY
    inst_id,
    wait_class
ORDER BY
    inst_id,
    waiting_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 11. CURRENT WAITERS BY EVENT
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS longest_wait_sec
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
GROUP BY
    inst_id,
    event,
    wait_class
ORDER BY
    waiting_sessions DESC,
    longest_wait_sec DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 12. I/O WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE wait_class = 'User I/O'
ORDER BY time_waited DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 13. CONCURRENCY WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE wait_class = 'Concurrency'
ORDER BY time_waited DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 14. COMMIT / REDO WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE '%log file%'
   OR LOWER(event) LIKE '%commit%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. CPU / RESOURCE MANAGER WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE '%resmgr%'
   OR LOWER(event) LIKE '%cpu quantum%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 16. NETWORK / SQL*NET WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE '%sql*net%'
ORDER BY time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 17. CURRENT GC WAITERS
PROMPT ============================================================

SELECT
    inst_id,
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    state,
    seconds_in_wait,
    service_name,
    machine,
    program
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND LOWER(event) LIKE 'gc %'
ORDER BY seconds_in_wait DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 18. CURRENT I/O WAITERS
PROMPT ============================================================

SELECT
    inst_id,
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    seconds_in_wait,
    service_name,
    machine,
    program
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class = 'User I/O'
ORDER BY seconds_in_wait DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 19. CURRENT CONCURRENCY WAITERS
PROMPT ============================================================

SELECT
    inst_id,
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    seconds_in_wait,
    service_name,
    machine,
    program
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class = 'Concurrency'
ORDER BY seconds_in_wait DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 20. WAIT EVENTS BY SERVICE
PROMPT ============================================================

SELECT
    inst_id,
    service_name,
    wait_class,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS longest_wait_sec
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
GROUP BY
    inst_id,
    service_name,
    wait_class
ORDER BY
    waiting_sessions DESC,
    longest_wait_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 21. WAIT EVENTS BY USER
PROMPT ============================================================

SELECT
    inst_id,
    username,
    wait_class,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS longest_wait_sec
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
GROUP BY
    inst_id,
    username,
    wait_class
ORDER BY
    waiting_sessions DESC,
    longest_wait_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 22. SQL ASSOCIATED WITH CURRENT WAITS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sql_id,
    s.username,
    s.event,
    s.wait_class,
    COUNT(*) AS waiting_sessions,
    MAX(s.seconds_in_wait) AS longest_wait_sec,
    MIN(s.service_name) AS service_name
FROM gv$session s
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND s.state = 'WAITING'
  AND s.wait_class <> 'Idle'
GROUP BY
    s.inst_id,
    s.sql_id,
    s.username,
    s.event,
    s.wait_class
ORDER BY
    waiting_sessions DESC,
    longest_wait_sec DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 23. SQL DETAILS FOR CURRENT WAITERS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sql_id,
    s.username,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    q.plan_hash_value,
    q.executions,
    ROUND(q.cpu_time / 1000000, 2) AS cpu_seconds,
    ROUND(q.elapsed_time / 1000000, 2) AS elapsed_seconds,
    q.buffer_gets,
    q.disk_reads,
    SUBSTR(q.sql_text, 1, 200) AS sql_text
FROM gv$session s
JOIN gv$sql q
    ON q.inst_id = s.inst_id
   AND q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND s.state = 'WAITING'
  AND s.wait_class <> 'Idle'
ORDER BY s.seconds_in_wait DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 24. GC WAITERS BY SQL
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sql_id,
    COUNT(*) AS gc_waiting_sessions,
    MAX(s.seconds_in_wait) AS longest_gc_wait_sec,
    MIN(s.service_name) AS service_name
FROM gv$session s
WHERE s.username IS NOT NULL
  AND s.status = 'ACTIVE'
  AND s.state = 'WAITING'
  AND LOWER(s.event) LIKE 'gc %'
GROUP BY
    s.inst_id,
    s.sql_id
ORDER BY
    gc_waiting_sessions DESC,
    longest_gc_wait_sec DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 25. BLOCKING SESSIONS WITH WAITS
PROMPT ============================================================

SELECT
    w.inst_id AS waiter_inst,
    w.sid AS waiter_sid,
    w.serial# AS waiter_serial,
    w.username AS waiter_user,
    w.sql_id AS waiter_sql_id,
    w.event AS waiter_event,
    w.wait_class,
    w.seconds_in_wait,

    b.inst_id AS blocker_inst,
    b.sid AS blocker_sid,
    b.serial# AS blocker_serial,
    b.username AS blocker_user,
    b.status AS blocker_status,
    b.sql_id AS blocker_sql_id,
    b.machine AS blocker_machine,
    b.program AS blocker_program
FROM gv$session w
JOIN gv$session b
    ON b.inst_id = w.blocking_instance
   AND b.sid = w.blocking_session
WHERE w.blocking_session IS NOT NULL
ORDER BY w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 26. CROSS-INSTANCE BLOCKING
PROMPT ============================================================

SELECT
    w.inst_id AS waiter_inst,
    w.sid AS waiter_sid,
    w.username AS waiter_user,
    w.sql_id AS waiter_sql_id,
    w.event,
    w.seconds_in_wait,

    b.inst_id AS blocker_inst,
    b.sid AS blocker_sid,
    b.username AS blocker_user,
    b.sql_id AS blocker_sql_id,
    b.machine,
    b.program
FROM gv$session w
JOIN gv$session b
    ON b.inst_id = w.blocking_instance
   AND b.sid = w.blocking_session
WHERE w.blocking_session IS NOT NULL
  AND w.blocking_instance <> w.inst_id
ORDER BY w.seconds_in_wait DESC;


PROMPT
PROMPT ============================================================
PROMPT 27. WAIT EVENT DISTRIBUTION BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    COUNT(*) AS non_idle_waiters,
    SUM(
        CASE
            WHEN wait_class = 'User I/O'
            THEN 1
            ELSE 0
        END
    ) AS io_waiters,
    SUM(
        CASE
            WHEN wait_class = 'Concurrency'
            THEN 1
            ELSE 0
        END
    ) AS concurrency_waiters,
    SUM(
        CASE
            WHEN LOWER(event) LIKE 'gc %'
            THEN 1
            ELSE 0
        END
    ) AS gc_waiters,
    SUM(
        CASE
            WHEN LOWER(event) LIKE '%resmgr%'
            THEN 1
            ELSE 0
        END
    ) AS resource_manager_waiters
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 28. INSTANCE WAIT TIME SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    SUM(total_waits) AS total_waits,
    ROUND(
        SUM(time_waited) / 100,
        2
    ) AS total_wait_time_sec,
    ROUND(
        SUM(time_waited) /
        NULLIF(SUM(total_waits), 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE wait_class <> 'Idle'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 29. TOP WAIT EVENTS ACROSS ENTIRE RAC
PROMPT ============================================================

SELECT
    event,
    wait_class,
    SUM(total_waits) AS total_waits,
    ROUND(
        SUM(time_waited) / 100,
        2
    ) AS total_wait_time_sec,
    ROUND(
        SUM(time_waited) /
        NULLIF(SUM(total_waits), 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE wait_class <> 'Idle'
GROUP BY
    event,
    wait_class
ORDER BY total_wait_time_sec DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 30. TOP GC EVENTS ACROSS RAC
PROMPT ============================================================

SELECT
    event,
    SUM(total_waits) AS total_waits,
    ROUND(
        SUM(time_waited) / 100,
        2
    ) AS total_wait_time_sec,
    ROUND(
        SUM(time_waited) /
        NULLIF(SUM(total_waits), 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE 'gc %'
GROUP BY event
ORDER BY total_wait_time_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 31. INSTANCE COMPARISON
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    COUNT(s.sid) AS active_waiters,
    SUM(
        CASE
            WHEN s.wait_class = 'User I/O'
            THEN 1
            ELSE 0
        END
    ) AS io_waiters,
    SUM(
        CASE
            WHEN LOWER(s.event) LIKE 'gc %'
            THEN 1
            ELSE 0
        END
    ) AS gc_waiters,
    SUM(
        CASE
            WHEN s.wait_class = 'Concurrency'
            THEN 1
            ELSE 0
        END
    ) AS concurrency_waiters
FROM gv$instance i
LEFT JOIN gv$session s
    ON s.inst_id = i.inst_id
   AND s.username IS NOT NULL
   AND s.status = 'ACTIVE'
   AND s.state = 'WAITING'
   AND s.wait_class <> 'Idle'
GROUP BY
    i.inst_id,
    i.instance_name,
    i.host_name
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 32. RAC WAIT EVENT HEALTH SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    CASE
        WHEN COUNT(*) = 0
            THEN 'NO NON-IDLE WAITERS'
        WHEN SUM(
                 CASE
                     WHEN LOWER(event) LIKE 'gc %'
                     THEN 1
                     ELSE 0
                 END
             ) > 0
            THEN 'REVIEW CACHE FUSION ACTIVITY'
        WHEN SUM(
                 CASE
                     WHEN wait_class = 'User I/O'
                     THEN 1
                     ELSE 0
                 END
             ) > 0
            THEN 'REVIEW I/O WAITS'
        WHEN SUM(
                 CASE
                     WHEN wait_class = 'Concurrency'
                     THEN 1
                     ELSE 0
                 END
             ) > 0
            THEN 'REVIEW CONCURRENCY WAITS'
        ELSE 'REVIEW CURRENT WAITS'
    END AS health_status
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 33. QUICK RAC WAIT EVENT CHECK
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    COUNT(*) AS current_waiters,
    MAX(seconds_in_wait) AS longest_wait_sec
FROM gv$session
WHERE username IS NOT NULL
  AND status = 'ACTIVE'
  AND state = 'WAITING'
  AND wait_class <> 'Idle'
GROUP BY
    inst_id,
    event,
    wait_class
ORDER BY
    current_waiters DESC,
    longest_wait_sec DESC
FETCH FIRST 20 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 34. DBA WAIT EVENT INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT 1. Identify top non-idle wait events.
PROMPT 2. Compare wait events across RAC instances.
PROMPT 3. Check current longest-running waits.
PROMPT 4. Review User I/O waits.
PROMPT 5. Review Concurrency waits.
PROMPT 6. Review Commit / Redo waits.
PROMPT 7. Review Resource Manager CPU waits.
PROMPT 8. Review SQL*Net/network waits.
PROMPT 9. Review GC current waits.
PROMPT 10. Review GC consistent-read waits.
PROMPT 11. Identify SQL associated with waits.
PROMPT 12. Check cross-instance blocking.
PROMPT 13. Compare service-level wait distribution.
PROMPT 14. Correlate GC waits with RAC interconnect health.
PROMPT 15. Correlate I/O waits with storage and Exadata metrics.
PROMPT 16. Use ASH/AWR for historical wait analysis when available.
PROMPT 17. Use OS/network tools for infrastructure-level issues.
PROMPT
PROMPT ============================================================
PROMPT Important Notes:
PROMPT
PROMPT - GV$SYSTEM_EVENT statistics are cumulative since startup.
PROMPT - Current GV$SESSION waits are a point-in-time snapshot.
PROMPT - High wait counts alone do not prove a performance problem.
PROMPT - GC waits are normal RAC Cache Fusion activity.
PROMPT - GC waits alone do not prove an interconnect problem.
PROMPT - SQL*Net waits can be normal depending on session state.
PROMPT - Wait class must be interpreted together with workload.
PROMPT - Use interval samples for rates and trend analysis.
PROMPT - AWR/ASH can provide historical wait analysis when
PROMPT   the required licensing and privileges are available.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC WAIT EVENT MONITORING COMPLETE
PROMPT ============================================================
 
-- ============================================================================
-- Oracle DBA Toolkit
-- Script  : library_cache_locks.sql
-- Purpose : Monitor Oracle Library Cache Locks, Pins and Contention
-- Author  : Manik Challa
-- Usage   : SQL*Plus / SQLcl
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN sid              FORMAT 99999
COLUMN serial           FORMAT 999999
COLUMN username         FORMAT A20
COLUMN sql_id           FORMAT A15
COLUMN event            FORMAT A45
COLUMN wait_class       FORMAT A20
COLUMN object_name      FORMAT A40
COLUMN object_type      FORMAT A25
COLUMN owner            FORMAT A20
COLUMN machine          FORMAT A30
COLUMN program          FORMAT A35
COLUMN blocking_sid     FORMAT 99999
COLUMN status           FORMAT A10
COLUMN namespace        FORMAT A20
COLUMN lock_mode        FORMAT A15
COLUMN pin_mode         FORMAT A15

PROMPT
PROMPT ================================================================
PROMPT ORACLE LIBRARY CACHE LOCK MONITORING
PROMPT ================================================================
PROMPT

-- ============================================================================
-- 1. Current Library Cache Waits
-- ============================================================================

PROMPT
PROMPT [1] CURRENT LIBRARY CACHE WAITS
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.blocking_session AS blocking_sid,
    s.machine,
    s.program
FROM v$session s
WHERE s.event LIKE 'library cache%'
   OR s.event LIKE '%cursor:%'
ORDER BY s.seconds_in_wait DESC;

-- ============================================================================
-- 2. Library Cache Wait Event Summary
-- ============================================================================

PROMPT
PROMPT [2] LIBRARY CACHE WAIT EVENT SUMMARY
PROMPT

SELECT
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_sec,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN (time_waited / total_waits) / 100
            ELSE 0
        END,
        4
    ) AS avg_wait_sec
FROM v$system_event
WHERE event LIKE 'library cache%'
   OR event LIKE '%cursor:%'
ORDER BY time_waited DESC;

-- ============================================================================
-- 3. Library Cache Locks and Pins
-- ============================================================================

PROMPT
PROMPT [3] LIBRARY CACHE LOCKS / PINS
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.blocking_session AS blocking_sid,
    s.machine,
    s.program
FROM v$session s
WHERE s.event IN (
        'library cache lock',
        'library cache pin',
        'library cache load lock'
      )
ORDER BY s.seconds_in_wait DESC;

-- ============================================================================
-- 4. Cursor-Related Library Cache Contention
-- ============================================================================

PROMPT
PROMPT [4] CURSOR-RELATED CONTENTION
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.blocking_session AS blocking_sid,
    s.machine,
    s.program
FROM v$session s
WHERE s.event LIKE 'cursor:%'
ORDER BY s.seconds_in_wait DESC;

-- ============================================================================
-- 5. Library Cache Lock / Pin Wait Summary
-- ============================================================================

PROMPT
PROMPT [5] LIBRARY CACHE LOCK / PIN SUMMARY
PROMPT

SELECT
    CASE
        WHEN event = 'library cache lock'
            THEN 'Library Cache Lock'
        WHEN event = 'library cache pin'
            THEN 'Library Cache Pin'
        WHEN event = 'library cache load lock'
            THEN 'Library Cache Load Lock'
        ELSE event
    END AS wait_type,
    COUNT(*) AS waiting_sessions,
    MAX(seconds_in_wait) AS max_wait_sec
FROM v$session
WHERE event IN (
        'library cache lock',
        'library cache pin',
        'library cache load lock'
      )
GROUP BY
    CASE
        WHEN event = 'library cache lock'
            THEN 'Library Cache Lock'
        WHEN event = 'library cache pin'
            THEN 'Library Cache Pin'
        WHEN event = 'library cache load lock'
            THEN 'Library Cache Load Lock'
        ELSE event
    END
ORDER BY waiting_sessions DESC;

-- ============================================================================
-- 6. Sessions Waiting on Library Cache with SQL Details
-- ============================================================================

PROMPT
PROMPT [6] LIBRARY CACHE WAITS WITH SQL DETAILS
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.event,
    s.seconds_in_wait,
    s.blocking_session AS blocking_sid,
    s.machine,
    s.program,
    SUBSTR(q.sql_text, 1, 100) AS sql_text
FROM v$session s
LEFT JOIN v$sql q
       ON q.sql_id = s.sql_id
      AND q.child_number = s.sql_child_number
WHERE s.event IN (
        'library cache lock',
        'library cache pin',
        'library cache load lock'
      )
ORDER BY s.seconds_in_wait DESC;

-- ============================================================================
-- 7. Blocking Sessions for Library Cache Waits
-- ============================================================================

PROMPT
PROMPT [7] BLOCKING SESSIONS
PROMPT

SELECT
    bs.sid AS blocking_sid,
    bs.serial# AS blocking_serial,
    bs.username AS blocking_user,
    COUNT(ws.sid) AS blocked_sessions,
    bs.sql_id AS blocking_sql_id,
    bs.status,
    bs.machine,
    bs.program
FROM v$session ws
JOIN v$session bs
  ON bs.sid = ws.blocking_session
WHERE ws.event IN (
        'library cache lock',
        'library cache pin',
        'library cache load lock'
      )
GROUP BY
    bs.sid,
    bs.serial#,
    bs.username,
    bs.sql_id,
    bs.status,
    bs.machine,
    bs.program
ORDER BY blocked_sessions DESC;

-- ============================================================================
-- 8. Blocking / Waiting Session Details
-- ============================================================================

PROMPT
PROMPT [8] BLOCKER / WAITER DETAILS
PROMPT

SELECT
    ws.sid AS waiting_sid,
    ws.serial# AS waiting_serial,
    ws.username AS waiting_user,
    ws.sql_id AS waiting_sql_id,
    ws.event AS waiting_event,
    ws.seconds_in_wait,
    bs.sid AS blocking_sid,
    bs.serial# AS blocking_serial,
    bs.username AS blocking_user,
    bs.sql_id AS blocking_sql_id,
    bs.status AS blocking_status,
    bs.machine AS blocking_machine,
    bs.program AS blocking_program
FROM v$session ws
LEFT JOIN v$session bs
       ON bs.sid = ws.blocking_session
WHERE ws.event IN (
        'library cache lock',
        'library cache pin',
        'library cache load lock'
      )
ORDER BY ws.seconds_in_wait DESC;

-- ============================================================================
-- 9. Library Cache Statistics
-- ============================================================================

PROMPT
PROMPT [9] LIBRARY CACHE STATISTICS
PROMPT

SELECT
    namespace,
    gets,
    gethits,
    ROUND(
        CASE
            WHEN gets > 0
            THEN gethits / gets * 100
            ELSE 0
        END,
        2
    ) AS get_hit_pct,
    pins,
    pinhits,
    ROUND(
        CASE
            WHEN pins > 0
            THEN pinhits / pins * 100
            ELSE 0
        END,
        2
    ) AS pin_hit_pct,
    reloads,
    invalidations
FROM v$librarycache
ORDER BY namespace;

-- ============================================================================
-- 10. Library Cache Reloads and Invalidations
-- ============================================================================

PROMPT
PROMPT [10] LIBRARY CACHE RELOADS / INVALIDATIONS
PROMPT

SELECT
    namespace,
    reloads,
    invalidations,
    pins,
    pinhits,
    gets,
    gethits
FROM v$librarycache
ORDER BY reloads DESC, invalidations DESC;

-- ============================================================================
-- 11. Top SQL with High Invalidations
-- ============================================================================

PROMPT
PROMPT [11] SQL WITH HIGH INVALIDATIONS
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        executions,
        invalidations,
        loads,
        parse_calls,
        version_count,
        ROUND(cpu_time / 1000000, 2) AS cpu_sec,
        ROUND(elapsed_time / 1000000, 2) AS elapsed_sec,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sql
    WHERE invalidations > 0
    ORDER BY invalidations DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 12. SQL with High Version Counts
-- ============================================================================

PROMPT
PROMPT [12] SQL WITH HIGH CURSOR VERSION COUNTS
PROMPT

SELECT *
FROM (
    SELECT
        sql_id,
        version_count,
        executions,
        loads,
        invalidations,
        parse_calls,
        SUBSTR(sql_text, 1, 100) AS sql_text
    FROM v$sqlarea
    WHERE version_count > 1
    ORDER BY version_count DESC
)
WHERE ROWNUM <= 20;

-- ============================================================================
-- 13. Library Cache Related System Statistics
-- ============================================================================

PROMPT
PROMPT [13] LIBRARY CACHE RELATED SYSTEM STATISTICS
PROMPT

SELECT
    name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%parse%'
   OR LOWER(name) LIKE '%cursor%'
ORDER BY name;

-- ============================================================================
-- 14. Longest Current Library Cache Waits
-- ============================================================================

PROMPT
PROMPT [14] LONGEST CURRENT LIBRARY CACHE WAITS
PROMPT

SELECT
    sid,
    serial# AS serial,
    username,
    sql_id,
    event,
    wait_class,
    seconds_in_wait,
    state,
    blocking_session AS blocking_sid,
    machine,
    program
FROM v$session
WHERE event LIKE 'library cache%'
   OR event LIKE 'cursor:%'
ORDER BY seconds_in_wait DESC;

PROMPT
PROMPT ================================================================
PROMPT LIBRARY CACHE INVESTIGATION COMPLETE
PROMPT ================================================================
PROMPT
PROMPT DBA CHECKLIST:
PROMPT 1. Identify the exact library cache wait event.
PROMPT 2. Identify waiting and blocking sessions.
PROMPT 3. Check blocker SQL_ID and application details.
PROMPT 4. Review library cache reloads and invalidations.
PROMPT 5. Check SQL version counts and cursor proliferation.
PROMPT 6. Investigate frequent parsing and hard parses.
PROMPT 7. Check recent DDL or object invalidation activity.
PROMPT 8. Review application connection and cursor management.
PROMPT 9. Check shared pool pressure when appropriate.
PROMPT


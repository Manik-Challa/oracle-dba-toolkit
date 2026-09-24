-- ============================================================
-- Oracle DBA Toolkit
-- Script  : session_pga.sql
-- Purpose : Monitor Oracle session-level PGA usage
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET VERIFY OFF

COLUMN SID FORMAT 99999
COLUMN SERIAL FORMAT 99999
COLUMN USERNAME FORMAT A20
COLUMN STATUS FORMAT A10
COLUMN SQL_ID FORMAT A15
COLUMN PGA_USED_MB FORMAT 999,999.99
COLUMN PGA_ALLOC_MB FORMAT 999,999.99
COLUMN PGA_MAX_MB FORMAT 999,999.99
COLUMN PGA_FREE_MB FORMAT 999,999.99
COLUMN WORKAREA_MB FORMAT 999,999.99
COLUMN MACHINE FORMAT A35
COLUMN PROGRAM FORMAT A40
COLUMN EVENT FORMAT A45

PROMPT
PROMPT ============================================================
PROMPT                 PGA USAGE SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    name AS statistic,
    ROUND(value / 1024 / 1024, 2) AS value_mb
FROM
    v$pgastat
WHERE
    name IN
    (
        'total PGA allocated',
        'total PGA inuse',
        'total freeable PGA memory',
        'maximum PGA allocated'
    )
ORDER BY
    name;

PROMPT
PROMPT ============================================================
PROMPT                 PGA TARGET / LIMIT
PROMPT ============================================================
PROMPT

SELECT
    name,
    value,
    display_value
FROM
    v$parameter
WHERE
    name IN
    (
        'pga_aggregate_target',
        'pga_aggregate_limit'
    )
ORDER BY
    name;

PROMPT
PROMPT ============================================================
PROMPT                 TOP PGA CONSUMING SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    ROUND(p.pga_used_mem / 1024 / 1024, 2) AS pga_used_mb,
    ROUND(p.pga_alloc_mem / 1024 / 1024, 2) AS pga_alloc_mb,
    ROUND(p.pga_freeable_mem / 1024 / 1024, 2) AS pga_free_mb,
    ROUND(p.pga_max_mem / 1024 / 1024, 2) AS pga_max_mb,
    s.machine,
    s.program
FROM
    v$session s
JOIN
    v$process p
ON
    s.paddr = p.addr
WHERE
    s.username IS NOT NULL
ORDER BY
    p.pga_used_mem DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 TOP PGA ALLOCATED SESSIONS
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    ROUND(p.pga_alloc_mem / 1024 / 1024, 2) AS pga_alloc_mb,
    ROUND(p.pga_max_mem / 1024 / 1024, 2) AS pga_max_mb,
    s.machine,
    s.program
FROM
    v$session s
JOIN
    v$process p
ON
    s.paddr = p.addr
WHERE
    s.username IS NOT NULL
ORDER BY
    p.pga_alloc_mem DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 PGA USAGE BY USER
PROMPT ============================================================
PROMPT

SELECT
    s.username,
    COUNT(*) AS sessions,
    ROUND(
        SUM(p.pga_used_mem) / 1024 / 1024,
        2
    ) AS pga_used_mb,
    ROUND(
        SUM(p.pga_alloc_mem) / 1024 / 1024,
        2
    ) AS pga_alloc_mb,
    ROUND(
        MAX(p.pga_max_mem) / 1024 / 1024,
        2
    ) AS max_session_pga_mb
FROM
    v$session s
JOIN
    v$process p
ON
    s.paddr = p.addr
WHERE
    s.username IS NOT NULL
GROUP BY
    s.username
ORDER BY
    pga_used_mb DESC;

PROMPT
PROMPT ============================================================
PROMPT                 ACTIVE SESSIONS WITH HIGH PGA
PROMPT ============================================================
PROMPT

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    ROUND(p.pga_used_mem / 1024 / 1024, 2) AS pga_used_mb,
    ROUND(p.pga_alloc_mem / 1024 / 1024, 2) AS pga_alloc_mb,
    s.event,
    s.machine,
    s.program
FROM
    v$session s
JOIN
    v$process p
ON
    s.paddr = p.addr
WHERE
    s.username IS NOT NULL
    AND s.status = 'ACTIVE'
ORDER BY
    p.pga_used_mem DESC
FETCH FIRST 30 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 PGA WORKAREA ACTIVITY
PROMPT ============================================================
PROMPT

SELECT
    name AS statistic,
    value
FROM
    v$sysstat
WHERE
    name IN
    (
        'workarea executions - optimal',
        'workarea executions - onepass',
        'workarea executions - multipass'
    )
ORDER BY
    name;

PROMPT
PROMPT ============================================================
PROMPT                 PGA ADVISORY
PROMPT ============================================================
PROMPT

SELECT
    ROUND(pga_target_for_estimate / 1024 / 1024, 0) AS pga_target_mb,
    estd_pga_cache_hit_percentage,
    estd_overalloc_count
FROM
    v$pga_target_advice
ORDER BY
    pga_target_for_estimate;

PROMPT
PROMPT ============================================================
PROMPT                 PGA OVERALL STATISTICS
PROMPT ============================================================
PROMPT

SELECT
    name,
    CASE
        WHEN name LIKE '%bytes%'
        THEN ROUND(value / 1024 / 1024, 2)
        ELSE value
    END AS value
FROM
    v$pgastat
ORDER BY
    name;

PROMPT
PROMPT ============================================================
PROMPT                 SESSION PGA MONITORING COMPLETE
PROMPT ============================================================


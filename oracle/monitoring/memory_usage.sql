-- ============================================================
-- Oracle DBA Toolkit
-- Script  : memory_usage.sql
-- Purpose : Monitor Oracle SGA and PGA memory usage
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100
SET TRIMSPOOL ON

COLUMN NAME FORMAT A40
COLUMN VALUE_MB FORMAT 999,999,999.99
COLUMN COMPONENT FORMAT A35
COLUMN CURRENT_SIZE_MB FORMAT 999,999,999.99
COLUMN MIN_SIZE_MB FORMAT 999,999,999.99
COLUMN MAX_SIZE_MB FORMAT 999,999,999.99

PROMPT
PROMPT ============================================================
PROMPT                 ORACLE MEMORY SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    name,
    ROUND(value / 1024 / 1024, 2) AS value_mb
FROM
    v$parameter
WHERE
    name IN
    (
        'sga_target',
        'sga_max_size',
        'pga_aggregate_target',
        'pga_aggregate_limit',
        'memory_target',
        'memory_max_target'
    )
ORDER BY
    name;

PROMPT
PROMPT ============================================================
PROMPT                 SGA COMPONENTS
PROMPT ============================================================
PROMPT

SELECT
    component,
    ROUND(current_size / 1024 / 1024, 2) AS current_size_mb,
    ROUND(min_size / 1024 / 1024, 2) AS min_size_mb,
    ROUND(max_size / 1024 / 1024, 2) AS max_size_mb
FROM
    v$sga_dynamic_components
WHERE
    current_size > 0
ORDER BY
    current_size DESC;

PROMPT
PROMPT ============================================================
PROMPT                 SGA TOTAL
PROMPT ============================================================
PROMPT

SELECT
    ROUND(SUM(value) / 1024 / 1024, 2) AS sga_total_mb
FROM
    v$sga;

PROMPT
PROMPT ============================================================
PROMPT                 SGA FREE MEMORY
PROMPT ============================================================
PROMPT

SELECT
    ROUND(
        SUM(bytes) / 1024 / 1024,
        2
    ) AS free_sga_mb
FROM
    v$sgastat
WHERE
    name = 'free memory';

PROMPT
PROMPT ============================================================
PROMPT                 PGA TARGET AND LIMIT
PROMPT ============================================================
PROMPT

SELECT
    name,
    ROUND(value / 1024 / 1024, 2) AS value_mb
FROM
    v$pgastat
WHERE
    name IN
    (
        'aggregate PGA target parameter',
        'aggregate PGA auto target',
        'maximum PGA allocated',
        'total PGA allocated',
        'total PGA inuse'
    )
ORDER BY
    name;

PROMPT
PROMPT ============================================================
PROMPT                 PGA USAGE
PROMPT ============================================================
PROMPT

COLUMN PGA_ALLOCATED_MB FORMAT 999,999,999.99
COLUMN PGA_INUSE_MB FORMAT 999,999,999.99
COLUMN PGA_FREE_MB FORMAT 999,999,999.99
COLUMN PGA_INUSE_PCT FORMAT 999.99

SELECT
    ROUND(
        MAX(
            CASE
                WHEN name = 'total PGA allocated'
                THEN value
            END
        ) / 1024 / 1024,
        2
    ) AS pga_allocated_mb,

    ROUND(
        MAX(
            CASE
                WHEN name = 'total PGA inuse'
                THEN value
            END
        ) / 1024 / 1024,
        2
    ) AS pga_inuse_mb,

    ROUND(
        (
            MAX(
                CASE
                    WHEN name = 'total PGA allocated'
                    THEN value
                END
            )
            -
            MAX(
                CASE
                    WHEN name = 'total PGA inuse'
                    THEN value
                END
            )
        ) / 1024 / 1024,
        2
    ) AS pga_free_mb,

    ROUND(
        MAX(
            CASE
                WHEN name = 'total PGA inuse'
                THEN value
            END
        )
        /
        NULLIF(
            MAX(
                CASE
                    WHEN name = 'total PGA allocated'
                    THEN value
                END
            ),
            0
        ) * 100,
        2
    ) AS pga_inuse_pct
FROM
    v$pgastat;

PROMPT
PROMPT ============================================================
PROMPT                 PGA WORKAREA STATISTICS
PROMPT ============================================================
PROMPT

COLUMN W_NAME FORMAT A35
COLUMN W_VALUE FORMAT 999,999,999,999

SELECT
    name AS w_name,
    value AS w_value
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
PROMPT                 MEMORY ADVISOR - SGA
PROMPT ============================================================
PROMPT

COLUMN SGA_SIZE_MB FORMAT 999,999,999
COLUMN ESTD_DB_TIME_FACTOR FORMAT 999.999
COLUMN ESTD_PHYSICAL_READS FORMAT 999,999,999,999

SELECT
    sga_size / 1024 / 1024 AS sga_size_mb,
    estd_db_time_factor,
    estd_physical_reads
FROM
    v$sga_target_advice
ORDER BY
    sga_size;

PROMPT
PROMPT ============================================================
PROMPT                 MEMORY ADVISOR - PGA
PROMPT ============================================================
PROMPT

COLUMN PGA_TARGET_MB FORMAT 999,999,999
COLUMN ESTD_EXTRA_BYTES_READ FORMAT 999,999,999,999
COLUMN ESTD_EXTRA_BYTES_WRITTEN FORMAT 999,999,999,999

SELECT
    pga_target_for_estimate / 1024 / 1024 AS pga_target_mb,
    estd_pga_cache_hit_percentage,
    estd_extra_bytes_rw
FROM
    v$pga_target_advice
ORDER BY
    pga_target_for_estimate;

PROMPT
PROMPT ============================================================
PROMPT                 TOP PGA CONSUMING SESSIONS
PROMPT ============================================================
PROMPT

COLUMN SID FORMAT 99999
COLUMN SERIAL FORMAT 99999
COLUMN USERNAME FORMAT A20
COLUMN PGA_USED_MB FORMAT 999,999.99
COLUMN PGA_ALLOC_MB FORMAT 999,999.99
COLUMN PGA_MAX_MB FORMAT 999,999.99
COLUMN PROGRAM FORMAT A35

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    ROUND(p.pga_used_mem / 1024 / 1024, 2) AS pga_used_mb,
    ROUND(p.pga_alloc_mem / 1024 / 1024, 2) AS pga_alloc_mb,
    ROUND(p.pga_max_mem / 1024 / 1024, 2) AS pga_max_mb,
    s.program
FROM
    v$process p
JOIN
    v$session s
ON
    p.addr = s.paddr
WHERE
    s.username IS NOT NULL
ORDER BY
    p.pga_used_mem DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 MEMORY MONITORING COMPLETE
PROMPT ============================================================


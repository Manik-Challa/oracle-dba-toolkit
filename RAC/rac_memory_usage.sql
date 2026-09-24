-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_memory_usage.sql
-- Purpose: Monitor Oracle RAC memory usage
-- Scope  : SGA, PGA, memory targets, PGA sessions,
--          workareas, memory pressure and instance comparison
--
-- IMPORTANT:
-- Most memory statistics are current snapshots or cumulative
-- counters. They do not represent OS physical memory utilization.
--
-- This script is READ-ONLY.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name       FORMAT A18
COLUMN host_name           FORMAT A30
COLUMN name                FORMAT A45
COLUMN component           FORMAT A40
COLUMN username            FORMAT A25
COLUMN service_name        FORMAT A35
COLUMN machine             FORMAT A35
COLUMN program             FORMAT A40
COLUMN sql_id              FORMAT A15
COLUMN parameter_name      FORMAT A35
COLUMN parameter_value     FORMAT A50

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
PROMPT 2. MEMORY PARAMETERS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    name AS parameter_name,
    value AS parameter_value
FROM gv$parameter
WHERE name IN
(
    'memory_target',
    'memory_max_target',
    'sga_target',
    'sga_max_size',
    'pga_aggregate_target',
    'pga_aggregate_limit',
    'use_large_pages'
)
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 3. SGA TARGET / CURRENT SIZE
PROMPT ============================================================

SELECT
    inst_id,
    ROUND(sga_target / 1024 / 1024, 2) AS sga_target_mb,
    ROUND(sga_max_size / 1024 / 1024, 2) AS sga_max_mb,
    ROUND(total_sga / 1024 / 1024, 2) AS total_sga_mb
FROM gv$sga
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 4. SGA COMPONENTS BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    component,
    ROUND(current_size / 1024 / 1024, 2) AS current_mb,
    ROUND(min_size / 1024 / 1024, 2) AS min_mb,
    ROUND(max_size / 1024 / 1024, 2) AS max_mb,
    ROUND(user_specified_size / 1024 / 1024, 2) AS user_specified_mb
FROM gv$sga_dynamic_components
ORDER BY
    inst_id,
    current_size DESC;


PROMPT
PROMPT ============================================================
PROMPT 5. SGA COMPONENT SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    ROUND(
        SUM(current_size) / 1024 / 1024,
        2
    ) AS total_component_mb,
    ROUND(
        SUM(max_size) / 1024 / 1024,
        2
    ) AS max_component_mb,
    COUNT(*) AS component_count
FROM gv$sga_dynamic_components
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 6. SGA FREE MEMORY
PROMPT ============================================================

SELECT
    inst_id,
    ROUND(
        SUM(bytes) / 1024 / 1024,
        2
    ) AS free_sga_mb
FROM gv$sgastat
WHERE name = 'free memory'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 7. TOP SGA COMPONENTS
PROMPT ============================================================

SELECT
    inst_id,
    pool,
    name,
    ROUND(bytes / 1024 / 1024, 2) AS size_mb
FROM gv$sgastat
WHERE bytes > 0
ORDER BY bytes DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 8. SGA COMPONENTS BY POOL
PROMPT ============================================================

SELECT
    inst_id,
    NVL(pool, 'SGA') AS pool,
    ROUND(
        SUM(bytes) / 1024 / 1024,
        2
    ) AS pool_mb
FROM gv$sgastat
GROUP BY
    inst_id,
    NVL(pool, 'SGA')
ORDER BY
    inst_id,
    pool_mb DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. PGA TARGET / LIMIT / CURRENT USAGE
PROMPT ============================================================

SELECT
    inst_id,
    name,
    ROUND(value / 1024 / 1024, 2) AS value_mb
FROM gv$pgastat
WHERE name IN
(
    'aggregate PGA target parameter',
    'aggregate PGA auto target',
    'maximum PGA allocated',
    'total PGA allocated',
    'total PGA inuse',
    'total freeable PGA memory',
    'over allocation count'
)
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 10. PGA SUMMARY BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    ROUND(
        MAX(
            CASE
                WHEN name = 'aggregate PGA target parameter'
                THEN value
            END
        ) / 1024 / 1024,
        2
    ) AS pga_target_mb,
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
        MAX(
            CASE
                WHEN name = 'maximum PGA allocated'
                THEN value
            END
        ) / 1024 / 1024,
        2
    ) AS max_pga_allocated_mb,
    MAX(
        CASE
            WHEN name = 'over allocation count'
            THEN value
        END
    ) AS over_allocation_count
FROM gv$pgastat
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 11. PGA TARGET UTILIZATION
PROMPT ============================================================

WITH pga AS
(
    SELECT
        inst_id,
        MAX(
            CASE
                WHEN name = 'aggregate PGA target parameter'
                THEN value
            END
        ) AS target_bytes,
        MAX(
            CASE
                WHEN name = 'total PGA allocated'
                THEN value
            END
        ) AS allocated_bytes,
        MAX(
            CASE
                WHEN name = 'total PGA inuse'
                THEN value
            END
        ) AS inuse_bytes
    FROM gv$pgastat
    GROUP BY inst_id
)
SELECT
    inst_id,
    ROUND(target_bytes / 1024 / 1024, 2) AS target_mb,
    ROUND(allocated_bytes / 1024 / 1024, 2) AS allocated_mb,
    ROUND(inuse_bytes / 1024 / 1024, 2) AS inuse_mb,
    ROUND(
        allocated_bytes * 100 /
        NULLIF(target_bytes, 0),
        2
    ) AS allocated_pct_of_target,
    ROUND(
        inuse_bytes * 100 /
        NULLIF(target_bytes, 0),
        2
    ) AS inuse_pct_of_target
FROM pga
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 12. PGA ADVICE BY INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    ROUND(pga_target_for_estimate / 1024 / 1024, 2)
        AS pga_target_mb,
    ROUND(
        estd_extra_bytes_rw / 1024 / 1024,
        2
    ) AS extra_rw_mb,
    estd_overalloc_count,
    estd_pga_cache_hit_percentage
FROM gv$pga_target_advice
ORDER BY
    inst_id,
    pga_target_for_estimate;


PROMPT
PROMPT ============================================================
PROMPT 13. TOP PGA-CONSUMING SESSIONS
PROMPT ============================================================

SELECT
    s.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    ROUND(
        pga.pga_used / 1024 / 1024,
        2
    ) AS pga_used_mb,
    ROUND(
        pga.pga_alloc_mem / 1024 / 1024,
        2
    ) AS pga_allocated_mb,
    s.service_name,
    s.machine,
    s.program
FROM gv$session s
JOIN gv$process p
    ON p.inst_id = s.inst_id
   AND p.addr = s.paddr
JOIN gv$process_memory pga
    ON pga.inst_id = p.inst_id
   AND pga.pid = p.pid
WHERE s.username IS NOT NULL
ORDER BY pga.pga_used DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 14. PGA USAGE BY USER
PROMPT ============================================================

SELECT
    s.inst_id,
    s.username,
    COUNT(*) AS sessions,
    ROUND(
        SUM(
            NVL(pga.pga_used, 0)
        ) / 1024 / 1024,
        2
    ) AS pga_used_mb,
    ROUND(
        SUM(
            NVL(pga.pga_alloc_mem, 0)
        ) / 1024 / 1024,
        2
    ) AS pga_allocated_mb
FROM gv$session s
JOIN gv$process p
    ON p.inst_id = s.inst_id
   AND p.addr = s.paddr
JOIN gv$process_memory pga
    ON pga.inst_id = p.inst_id
   AND pga.pid = p.pid
WHERE s.username IS NOT NULL
GROUP BY
    s.inst_id,
    s.username
ORDER BY pga_used_mb DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. WORKAREA MEMORY USAGE
PROMPT ============================================================

SELECT
    inst_id,
    policy,
    ROUND(
        SUM(total_bytes) / 1024 / 1024,
        2
    ) AS total_mb,
    ROUND(
        SUM(used_bytes) / 1024 / 1024,
        2
    ) AS used_mb,
    ROUND(
        SUM(max_bytes) / 1024 / 1024,
        2
    ) AS max_mb
FROM gv$sql_workarea
GROUP BY
    inst_id,
    policy
ORDER BY
    inst_id,
    used_mb DESC;


PROMPT
PROMPT ============================================================
PROMPT 16. WORKAREA EXECUTION STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name,
    value
FROM gv$sysstat
WHERE LOWER(name) LIKE '%workarea%'
   OR LOWER(name) LIKE '%sort%'
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 17. MEMORY-RELATED SQL / WORKAREA ACTIVITY
PROMPT ============================================================

SELECT
    inst_id,
    sql_id,
    child_number,
    operation_type,
    policy,
    ROUND(actual_mem_used / 1024 / 1024, 2)
        AS actual_mem_mb,
    ROUND(max_mem_used / 1024 / 1024, 2)
        AS max_mem_mb,
    number_passes,
    tempseg_size
FROM gv$sql_workarea
WHERE actual_mem_used > 0
ORDER BY actual_mem_used DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 18. PGA / TEMP PRESSURE INDICATORS
PROMPT ============================================================

SELECT
    inst_id,
    name,
    value
FROM gv$sysstat
WHERE LOWER(name) LIKE '%workarea executions - optimal%'
   OR LOWER(name) LIKE '%workarea executions - onepass%'
   OR LOWER(name) LIKE '%workarea executions - multipass%'
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 19. MEMORY-RELATED WAIT EVENTS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(time_waited / 100, 2) AS total_wait_sec,
    ROUND(
        (time_waited /
         NULLIF(total_waits, 0)) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE '%memory%'
   OR LOWER(event) LIKE '%pga%'
   OR LOWER(event) LIKE '%workarea%'
ORDER BY
    inst_id,
    time_waited DESC;


PROMPT
PROMPT ============================================================
PROMPT 20. MEMORY RESOURCE LIMITS
PROMPT ============================================================

SELECT
    inst_id,
    resource_name,
    current_utilization,
    max_utilization,
    limit_value
FROM gv$resource_limit
WHERE resource_name IN
(
    'sessions',
    'processes',
    'transactions'
)
ORDER BY
    inst_id,
    resource_name;


PROMPT
PROMPT ============================================================
PROMPT 21. MEMORY ADVISOR / SGA ADVICE
PROMPT ============================================================

SELECT
    inst_id,
    sga_size,
    sga_size_factor,
    estd_db_time,
    estd_db_time_factor,
    estd_physical_reads
FROM gv$sga_target_advice
ORDER BY
    inst_id,
    sga_size;


PROMPT
PROMPT ============================================================
PROMPT 22. INSTANCE MEMORY COMPARISON
PROMPT ============================================================

WITH memory_data AS
(
    SELECT
        inst_id,
        MAX(
            CASE
                WHEN name = 'total PGA allocated'
                THEN value
            END
        ) AS pga_allocated,
        MAX(
            CASE
                WHEN name = 'total PGA inuse'
                THEN value
            END
        ) AS pga_inuse
    FROM gv$pgastat
    GROUP BY inst_id
)
SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    ROUND(
        i.total_memory / 1024 / 1024,
        2
    ) AS instance_memory_mb,
    ROUND(
        m.pga_allocated / 1024 / 1024,
        2
    ) AS pga_allocated_mb,
    ROUND(
        m.pga_inuse / 1024 / 1024,
        2
    ) AS pga_inuse_mb
FROM gv$instance i
LEFT JOIN memory_data m
    ON m.inst_id = i.inst_id
ORDER BY i.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 23. MEMORY HEALTH SUMMARY
PROMPT ============================================================

WITH pga AS
(
    SELECT
        inst_id,
        MAX(
            CASE
                WHEN name = 'aggregate PGA target parameter'
                THEN value
            END
        ) AS target_bytes,
        MAX(
            CASE
                WHEN name = 'total PGA allocated'
                THEN value
            END
        ) AS allocated_bytes,
        MAX(
            CASE
                WHEN name = 'over allocation count'
                THEN value
            END
        ) AS overalloc_count
    FROM gv$pgastat
    GROUP BY inst_id
)
SELECT
    p.inst_id,
    i.instance_name,
    i.host_name,
    ROUND(
        p.target_bytes / 1024 / 1024,
        2
    ) AS pga_target_mb,
    ROUND(
        p.allocated_bytes / 1024 / 1024,
        2
    ) AS pga_allocated_mb,
    ROUND(
        p.allocated_bytes * 100 /
        NULLIF(p.target_bytes, 0),
        2
    ) AS pga_allocated_pct,
    p.overalloc_count,
    CASE
        WHEN i.status <> 'OPEN'
            THEN 'WARNING - INSTANCE NOT OPEN'

        WHEN p.overalloc_count > 0
            THEN 'REVIEW - PGA OVERALLOCATION'

        WHEN p.allocated_bytes >
             p.target_bytes * 0.90
            THEN 'REVIEW - PGA ABOVE 90% TARGET'

        ELSE
            'NO OBVIOUS PGA PRESSURE'
    END AS health_status
FROM pga p
JOIN gv$instance i
    ON i.inst_id = p.inst_id
ORDER BY p.inst_id;


PROMPT
PROMPT ============================================================
PROMPT 24. QUICK RAC MEMORY CHECK
PROMPT ============================================================

SELECT
    inst_id,
    ROUND(
        sga_target / 1024 / 1024,
        2
    ) AS sga_target_mb,
    ROUND(
        total_sga / 1024 / 1024,
        2
    ) AS total_sga_mb
FROM gv$sga
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 25. DBA MEMORY INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT If RAC memory usage appears high:
PROMPT
PROMPT 1. Compare SGA size across RAC instances.
PROMPT 2. Compare PGA target and allocated memory.
PROMPT 3. Check PGA over-allocation count.
PROMPT 4. Review top PGA-consuming sessions.
PROMPT 5. Review PGA usage by user/service.
PROMPT 6. Check workarea optimal/one-pass/multipass execution.
PROMPT 7. Review PGA and SGA advisory information.
PROMPT 8. Check TEMP usage when workareas spill to disk.
PROMPT 9. Check sessions/processes resource utilization.
PROMPT 10. Correlate with OS memory and swap usage.
PROMPT 11. Check HugePages / large pages configuration.
PROMPT 12. Compare memory configuration across RAC instances.
PROMPT 13. Check whether workload is intentionally asymmetric.
PROMPT 14. Do NOT assume high SGA/PGA allocation means memory
PROMPT     pressure by itself.
PROMPT
PROMPT ============================================================
PROMPT Important Notes:
PROMPT
PROMPT - SGA/PGA values are database memory metrics.
PROMPT - They do not represent complete OS physical memory usage.
PROMPT - PGA allocated can exceed PGA target under workload.
PROMPT - PGA over-allocation is an important pressure indicator.
PROMPT - Workarea one-pass/multipass operations may indicate
PROMPT   insufficient PGA for the workload.
PROMPT - High PGA usage can be workload-driven.
PROMPT - Correlate with OS free memory, swap and HugePages.
PROMPT - RAC instances can legitimately have different workloads.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC MEMORY USAGE MONITORING COMPLETE
PROMPT ============================================================
 
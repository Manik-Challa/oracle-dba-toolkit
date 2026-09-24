-- ============================================================
-- Oracle DBA Toolkit
-- File   : rac_temp_usage.sql
-- Purpose: RAC-wide TEMP usage and pressure monitoring
-- Scope  : TEMP capacity, tempfile usage, session consumers,
--          SQL consumers, sort/hash activity, waits and
--          RAC instance comparison
--
-- IMPORTANT:
-- - GV$TEMPSEG_USAGE is a current snapshot.
-- - GV$SQL statistics are cumulative cursor statistics.
-- - High TEMP usage does not automatically mean a problem.
-- - This script is READ-ONLY.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN instance_name       FORMAT A18
COLUMN host_name           FORMAT A30
COLUMN tablespace_name     FORMAT A25
COLUMN tempfile_name       FORMAT A80
COLUMN username            FORMAT A25
COLUMN sql_id              FORMAT A15
COLUMN sql_opname          FORMAT A25
COLUMN segtype             FORMAT A15
COLUMN event               FORMAT A60
COLUMN wait_class          FORMAT A20
COLUMN machine             FORMAT A35
COLUMN program             FORMAT A40
COLUMN service_name        FORMAT A35
COLUMN sql_text            FORMAT A100 WORD_WRAP

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
PROMPT 2. TEMP TABLESPACE SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    tablespace_name,
    status,
    contents,
    extent_management,
    segment_space_management
FROM gv$tablespace
WHERE contents = 'TEMPORARY'
ORDER BY
    inst_id,
    tablespace_name;


PROMPT
PROMPT ============================================================
PROMPT 3. TEMPFILE CAPACITY
PROMPT ============================================================

SELECT
    inst_id,
    tablespace_name,
    COUNT(*) AS tempfile_count,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS current_size_gb,
    ROUND(
        SUM(maxbytes) / 1024 / 1024 / 1024,
        2
    ) AS max_size_gb,
    SUM(
        CASE
            WHEN autoextensible = 'YES' THEN 1
            ELSE 0
        END
    ) AS autoextend_files
FROM gv$tempfile
GROUP BY
    inst_id,
    tablespace_name
ORDER BY
    inst_id,
    tablespace_name;


PROMPT
PROMPT ============================================================
PROMPT 4. TEMPFILE DETAILS
PROMPT ============================================================

SELECT
    inst_id,
    file# AS file_id,
    tablespace_name,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb,
    autoextensible,
    ROUND(
        maxbytes / 1024 / 1024 / 1024,
        2
    ) AS max_size_gb,
    ROUND(
        increment_by * 8192 / 1024 / 1024,
        2
    ) AS autoextend_mb
FROM gv$tempfile
ORDER BY
    inst_id,
    tablespace_name,
    file#;


PROMPT
PROMPT ============================================================
PROMPT 5. TEMP USAGE BY TABLESPACE / INSTANCE
PROMPT ============================================================

SELECT
    u.inst_id,
    u.tablespace,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024 / 1024,
        2
    ) AS temp_used_gb,
    COUNT(DISTINCT u.session_addr) AS sessions_using_temp
FROM gv$tempseg_usage u
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
GROUP BY
    u.inst_id,
    u.tablespace,
    ts.block_size
ORDER BY temp_used_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 6. TOP TEMP-CONSUMING SESSIONS
PROMPT ============================================================

SELECT
    u.inst_id,
    u.session_addr,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.sql_child_number,
    s.service_name,
    s.machine,
    s.program,
    u.tablespace,
    u.segtype,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024,
        2
    ) AS temp_mb
FROM gv$tempseg_usage u
JOIN gv$session s
    ON s.inst_id = u.inst_id
   AND s.saddr = u.session_addr
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
GROUP BY
    u.inst_id,
    u.session_addr,
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    s.sql_child_number,
    s.service_name,
    s.machine,
    s.program,
    u.tablespace,
    u.segtype,
    ts.block_size
ORDER BY temp_mb DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 7. TEMP USAGE BY USER
PROMPT ============================================================

SELECT
    u.inst_id,
    s.username,
    COUNT(DISTINCT s.sid) AS sessions,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024,
        2
    ) AS temp_mb
FROM gv$tempseg_usage u
JOIN gv$session s
    ON s.inst_id = u.inst_id
   AND s.saddr = u.session_addr
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
WHERE s.username IS NOT NULL
GROUP BY
    u.inst_id,
    s.username,
    ts.block_size
ORDER BY temp_mb DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 8. TEMP USAGE BY SERVICE
PROMPT ============================================================

SELECT
    u.inst_id,
    s.service_name,
    COUNT(DISTINCT s.sid) AS sessions,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024,
        2
    ) AS temp_mb
FROM gv$tempseg_usage u
JOIN gv$session s
    ON s.inst_id = u.inst_id
   AND s.saddr = u.session_addr
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
GROUP BY
    u.inst_id,
    s.service_name,
    ts.block_size
ORDER BY temp_mb DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. TEMP USAGE BY SEGMENT TYPE
PROMPT ============================================================

SELECT
    u.inst_id,
    u.segtype,
    COUNT(*) AS allocations,
    COUNT(DISTINCT u.session_addr) AS sessions,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024,
        2
    ) AS temp_mb
FROM gv$tempseg_usage u
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
GROUP BY
    u.inst_id,
    u.segtype,
    ts.block_size
ORDER BY temp_mb DESC;


PROMPT
PROMPT ============================================================
PROMPT 10. TOP TEMP-CONSUMING SQL
PROMPT ============================================================

SELECT
    u.inst_id,
    s.sql_id,
    s.username,
    s.service_name,
    COUNT(DISTINCT s.sid) AS sessions,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024,
        2
    ) AS temp_mb
FROM gv$tempseg_usage u
JOIN gv$session s
    ON s.inst_id = u.inst_id
   AND s.saddr = u.session_addr
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
WHERE s.sql_id IS NOT NULL
GROUP BY
    u.inst_id,
    s.sql_id,
    s.username,
    s.service_name,
    ts.block_size
ORDER BY temp_mb DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 11. TOP TEMP SQL WITH SQL DETAILS
PROMPT ============================================================

SELECT
    u.inst_id,
    s.sql_id,
    s.username,
    s.service_name,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024,
        2
    ) AS temp_mb,
    q.executions,
    q.disk_reads,
    q.buffer_gets,
    ROUND(
        q.cpu_time / 1000000,
        2
    ) AS cpu_seconds,
    ROUND(
        q.elapsed_time / 1000000,
        2
    ) AS elapsed_seconds,
    SUBSTR(q.sql_text, 1, 200) AS sql_text
FROM gv$tempseg_usage u
JOIN gv$session s
    ON s.inst_id = u.inst_id
   AND s.saddr = u.session_addr
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
JOIN gv$sql q
    ON q.inst_id = s.inst_id
   AND q.sql_id = s.sql_id
   AND q.child_number = s.sql_child_number
GROUP BY
    u.inst_id,
    s.sql_id,
    s.username,
    s.service_name,
    q.executions,
    q.disk_reads,
    q.buffer_gets,
    q.cpu_time,
    q.elapsed_time,
    q.sql_text,
    ts.block_size
ORDER BY temp_mb DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 12. TEMP USERS ABOVE 1 GB
PROMPT ============================================================

SELECT
    u.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.service_name,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024 / 1024,
        2
    ) AS temp_gb,
    s.machine,
    s.program
FROM gv$tempseg_usage u
JOIN gv$session s
    ON s.inst_id = u.inst_id
   AND s.saddr = u.session_addr
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
GROUP BY
    u.inst_id,
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    s.service_name,
    s.machine,
    s.program,
    ts.block_size
HAVING
    SUM(u.blocks) * ts.block_size /
    1024 / 1024 / 1024 >= 1
ORDER BY temp_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 13. TEMP USERS ABOVE 5 GB
PROMPT ============================================================

SELECT
    u.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.sql_id,
    s.service_name,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024 / 1024,
        2
    ) AS temp_gb,
    s.machine,
    s.program
FROM gv$tempseg_usage u
JOIN gv$session s
    ON s.inst_id = u.inst_id
   AND s.saddr = u.session_addr
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
GROUP BY
    u.inst_id,
    s.sid,
    s.serial#,
    s.username,
    s.sql_id,
    s.service_name,
    s.machine,
    s.program,
    ts.block_size
HAVING
    SUM(u.blocks) * ts.block_size /
    1024 / 1024 / 1024 >= 5
ORDER BY temp_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. CURRENT TEMP-RELATED WAIT EVENTS
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
  AND (
        LOWER(event) LIKE '%temp%'
        OR LOWER(event) LIKE '%sort%'
        OR LOWER(event) LIKE '%direct path%'
      )
GROUP BY
    inst_id,
    event,
    wait_class
ORDER BY
    waiting_sessions DESC,
    longest_wait_sec DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. TEMP SPACE / SORT RELATED SYSTEM WAITS
PROMPT ============================================================

SELECT
    inst_id,
    event,
    wait_class,
    total_waits,
    ROUND(
        time_waited / 100,
        2
    ) AS time_waited_sec,
    ROUND(
        time_waited /
        NULLIF(total_waits, 0) * 10,
        2
    ) AS avg_wait_ms
FROM gv$system_event
WHERE LOWER(event) LIKE '%temp%'
   OR LOWER(event) LIKE '%sort%'
   OR LOWER(event) LIKE '%direct path%'
ORDER BY time_waited DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 16. WORKAREA EXECUTION STATISTICS
PROMPT ============================================================

SELECT
    inst_id,
    name,
    value
FROM gv$sysstat
WHERE LOWER(name) LIKE 'workarea executions%'
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 17. WORKAREA ONE-PASS / MULTIPASS SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    SUM(
        CASE
            WHEN LOWER(name) = 'workarea executions - optimal'
            THEN value
            ELSE 0
        END
    ) AS optimal_executions,
    SUM(
        CASE
            WHEN LOWER(name) = 'workarea executions - onepass'
            THEN value
            ELSE 0
        END
    ) AS onepass_executions,
    SUM(
        CASE
            WHEN LOWER(name) = 'workarea executions - multipass'
            THEN value
            ELSE 0
        END
    ) AS multipass_executions
FROM gv$sysstat
WHERE LOWER(name) LIKE 'workarea executions%'
GROUP BY inst_id
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 18. PGA / TEMP PRESSURE INDICATORS
PROMPT ============================================================

SELECT
    inst_id,
    name,
    value
FROM gv$sysstat
WHERE LOWER(name) IN
(
    'workarea executions - onepass',
    'workarea executions - multipass',
    'physical reads direct temporary tablespace',
    'physical writes direct temporary tablespace'
)
ORDER BY
    inst_id,
    name;


PROMPT
PROMPT ============================================================
PROMPT 19. CURRENT TEMP USAGE BY INSTANCE
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    COUNT(DISTINCT u.session_addr) AS sessions_using_temp,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024 / 1024,
        2
    ) AS temp_used_gb
FROM gv$instance i
LEFT JOIN gv$tempseg_usage u
    ON u.inst_id = i.inst_id
LEFT JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
GROUP BY
    i.inst_id,
    i.instance_name,
    i.host_name,
    ts.block_size
ORDER BY temp_used_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 20. TEMP USAGE BY MACHINE
PROMPT ============================================================

SELECT
    u.inst_id,
    s.machine,
    COUNT(DISTINCT s.sid) AS sessions,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024,
        2
    ) AS temp_mb
FROM gv$tempseg_usage u
JOIN gv$session s
    ON s.inst_id = u.inst_id
   AND s.saddr = u.session_addr
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
GROUP BY
    u.inst_id,
    s.machine,
    ts.block_size
ORDER BY temp_mb DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 21. ACTIVE SESSIONS CONSUMING TEMP
PROMPT ============================================================

SELECT
    u.inst_id,
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.service_name,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024,
        2
    ) AS temp_mb
FROM gv$tempseg_usage u
JOIN gv$session s
    ON s.inst_id = u.inst_id
   AND s.saddr = u.session_addr
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
WHERE s.status = 'ACTIVE'
GROUP BY
    u.inst_id,
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.sql_id,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    s.service_name,
    ts.block_size
ORDER BY temp_mb DESC
FETCH FIRST 100 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 22. TEMP USAGE BY SERVICE / INSTANCE
PROMPT ============================================================

SELECT
    u.inst_id,
    s.service_name,
    COUNT(DISTINCT s.sid) AS sessions,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024 / 1024,
        2
    ) AS temp_gb
FROM gv$tempseg_usage u
JOIN gv$session s
    ON s.inst_id = u.inst_id
   AND s.saddr = u.session_addr
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
GROUP BY
    u.inst_id,
    s.service_name,
    ts.block_size
ORDER BY temp_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 23. TEMP-HEAVY SQL WITH CURRENT WAITS
PROMPT ============================================================

SELECT
    u.inst_id,
    s.sql_id,
    s.username,
    s.service_name,
    ROUND(
        SUM(u.blocks) * ts.block_size /
        1024 / 1024,
        2
    ) AS temp_mb,
    s.event,
    s.wait_class,
    s.seconds_in_wait
FROM gv$tempseg_usage u
JOIN gv$session s
    ON s.inst_id = u.inst_id
   AND s.saddr = u.session_addr
JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
WHERE s.status = 'ACTIVE'
GROUP BY
    u.inst_id,
    s.sql_id,
    s.username,
    s.service_name,
    s.event,
    s.wait_class,
    s.seconds_in_wait,
    ts.block_size
ORDER BY
    temp_mb DESC,
    s.seconds_in_wait DESC
FETCH FIRST 50 ROWS ONLY;


PROMPT
PROMPT ============================================================
PROMPT 24. TEMPFILE AUTOEXTEND HEADROOM
PROMPT ============================================================

SELECT
    inst_id,
    tablespace_name,
    file# AS file_id,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    autoextensible,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (maxbytes - bytes) /
        1024 / 1024 / 1024,
        2
    ) AS headroom_gb
FROM gv$tempfile
ORDER BY
    inst_id,
    headroom_gb;


PROMPT
PROMPT ============================================================
PROMPT 25. TEMPFILE NEAR MAXIMUM SIZE
PROMPT ============================================================

SELECT
    inst_id,
    tablespace_name,
    file# AS file_id,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        bytes / NULLIF(maxbytes, 0) * 100,
        2
    ) AS pct_of_max
FROM gv$tempfile
WHERE maxbytes > 0
  AND bytes / maxbytes >= 0.90
ORDER BY pct_of_max DESC;


PROMPT
PROMPT ============================================================
PROMPT 26. TEMP PRESSURE SUMMARY BY INSTANCE
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    i.host_name,
    COUNT(DISTINCT u.session_addr) AS temp_sessions,
    ROUND(
        NVL(
            SUM(u.blocks * ts.block_size),
            0
        ) / 1024 / 1024 / 1024,
        2
    ) AS temp_used_gb,
    (
        SELECT COUNT(*)
        FROM gv$session s
        WHERE s.inst_id = i.inst_id
          AND s.username IS NOT NULL
          AND s.status = 'ACTIVE'
          AND s.state = 'WAITING'
          AND (
                LOWER(s.event) LIKE '%temp%'
                OR LOWER(s.event) LIKE '%sort%'
                OR LOWER(s.event) LIKE '%direct path%'
              )
    ) AS temp_waiters
FROM gv$instance i
LEFT JOIN gv$tempseg_usage u
    ON u.inst_id = i.inst_id
LEFT JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
GROUP BY
    i.inst_id,
    i.instance_name,
    i.host_name
ORDER BY temp_used_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 27. TEMP HEALTH SUMMARY
PROMPT ============================================================

SELECT
    inst_id,
    temp_used_gb,
    temp_sessions,
    temp_waiters,
    CASE
        WHEN temp_used_gb >= 10
             AND temp_waiters > 0
            THEN 'CRITICAL - REVIEW TEMP PRESSURE'
        WHEN temp_used_gb >= 5
             OR temp_waiters > 0
            THEN 'WARNING - REVIEW TEMP USAGE'
        WHEN temp_used_gb >= 1
            THEN 'WATCH - TEMP USAGE'
        ELSE 'NORMAL'
    END AS health_status
FROM
(
    SELECT
        i.inst_id,
        COUNT(DISTINCT u.session_addr) AS temp_sessions,
        ROUND(
            NVL(
                SUM(u.blocks * ts.block_size),
                0
            ) / 1024 / 1024 / 1024,
            2
        ) AS temp_used_gb,
        (
            SELECT COUNT(*)
            FROM gv$session s
            WHERE s.inst_id = i.inst_id
              AND s.username IS NOT NULL
              AND s.status = 'ACTIVE'
              AND s.state = 'WAITING'
              AND (
                    LOWER(s.event) LIKE '%temp%'
                    OR LOWER(s.event) LIKE '%sort%'
                    OR LOWER(s.event) LIKE '%direct path%'
                  )
        ) AS temp_waiters
    FROM gv$instance i
    LEFT JOIN gv$tempseg_usage u
        ON u.inst_id = i.inst_id
    LEFT JOIN gv$tablespace ts
        ON ts.inst_id = u.inst_id
       AND ts.ts# = u.tablespace
    GROUP BY i.inst_id
)
ORDER BY inst_id;


PROMPT
PROMPT ============================================================
PROMPT 28. QUICK RAC TEMP CHECK
PROMPT ============================================================

SELECT
    i.inst_id,
    i.instance_name,
    COUNT(DISTINCT u.session_addr) AS temp_sessions,
    ROUND(
        NVL(
            SUM(u.blocks * ts.block_size),
            0
        ) / 1024 / 1024 / 1024,
        2
    ) AS temp_used_gb
FROM gv$instance i
LEFT JOIN gv$tempseg_usage u
    ON u.inst_id = i.inst_id
LEFT JOIN gv$tablespace ts
    ON ts.inst_id = u.inst_id
   AND ts.ts# = u.tablespace
GROUP BY
    i.inst_id,
    i.instance_name
ORDER BY temp_used_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 29. DBA TEMP INVESTIGATION CHECKLIST
PROMPT ============================================================

PROMPT
PROMPT 1. Check TEMP tablespace and tempfile capacity.
PROMPT 2. Identify current TEMP-consuming sessions.
PROMPT 3. Identify top TEMP-consuming SQL.
PROMPT 4. Check TEMP usage by RAC instance.
PROMPT 5. Check TEMP usage by user and service.
PROMPT 6. Check TEMP usage by segment type.
PROMPT 7. Identify sessions using more than 1 GB TEMP.
PROMPT 8. Identify sessions using more than 5 GB TEMP.
PROMPT 9. Review direct TEMP I/O waits.
PROMPT 10. Review workarea one-pass executions.
PROMPT 11. Review workarea multipass executions.
PROMPT 12. Check tempfile autoextend headroom.
PROMPT 13. Correlate TEMP consumers with SQL execution plans.
PROMPT 14. Check for large ORDER BY / GROUP BY / HASH operations.
PROMPT 15. Check parallel execution and PX-related TEMP usage.
PROMPT 16. Compare TEMP pressure across RAC instances.
PROMPT 17. Do not resize TEMP based only on current utilization.
PROMPT 18. Investigate the SQL or workload causing TEMP growth first.
PROMPT
PROMPT ============================================================
PROMPT Important Notes:
PROMPT
PROMPT - GV$TEMPSEG_USAGE is a point-in-time view.
PROMPT - TEMP usage can change rapidly.
PROMPT - High TEMP usage can be normal for large sorts/hashes.
PROMPT - One-pass and multipass workareas are stronger indicators
PROMPT   of memory/workarea pressure than TEMP usage alone.
PROMPT - TEMP usage does not automatically mean TEMP is undersized.
PROMPT - Autoextend still requires underlying storage capacity.
PROMPT - TEMP pressure can differ significantly between RAC nodes.
PROMPT - Current TEMP usage should be correlated with SQL activity,
PROMPT   PGA pressure, I/O and workload.
PROMPT - This script is READ-ONLY.
PROMPT ============================================================

PROMPT
PROMPT RAC TEMP USAGE MONITORING COMPLETE
PROMPT ============================================================
 
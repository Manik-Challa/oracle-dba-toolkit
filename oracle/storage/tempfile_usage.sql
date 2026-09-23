-- ============================================================
-- Oracle DBA Toolkit
-- Script   : tempfile_usage.sql
-- Purpose  : Monitor TEMP tempfile capacity and usage
-- Author   : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN tablespace_name FORMAT A25
COLUMN file_name       FORMAT A70
COLUMN status          FORMAT A10
COLUMN autoextensible  FORMAT A14

COLUMN total_gb        FORMAT 999,999,990.00
COLUMN used_gb         FORMAT 999,999,990.00
COLUMN free_gb         FORMAT 999,999,990.00
COLUMN free_pct        FORMAT 990.00
COLUMN used_pct        FORMAT 990.00
COLUMN max_gb          FORMAT 999,999,990.00
COLUMN headroom_gb     FORMAT 999,999,990.00

PROMPT
PROMPT ============================================================
PROMPT TEMPFILE USAGE MONITORING
PROMPT ============================================================


-- ============================================================
-- 1. DATABASE / INSTANCE INFORMATION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 1. DATABASE / INSTANCE INFORMATION
PROMPT ============================================================

SELECT
    d.name AS database_name,
    i.instance_name,
    i.host_name,
    d.open_mode,
    d.database_role
FROM v$database d
CROSS JOIN v$instance i;


-- ============================================================
-- 2. TEMPORARY TABLESPACE SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. TEMPORARY TABLESPACE SUMMARY
PROMPT ============================================================

SELECT
    tablespace_name,
    ROUND(tablespace_size / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(
        (tablespace_size - free_space)
        / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(free_space / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(
        (tablespace_size - free_space)
        / tablespace_size * 100,
        2
    ) AS used_pct,
    ROUND(
        free_space / tablespace_size * 100,
        2
    ) AS free_pct
FROM dba_temp_free_space
ORDER BY used_pct DESC;


-- ============================================================
-- 3. TEMPFILE DETAILS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. TEMPFILE DETAILS
PROMPT ============================================================

SELECT
    tablespace_name,
    file_id,
    file_name,
    status,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS total_gb,
    autoextensible
FROM dba_temp_files
ORDER BY tablespace_name, file_id;


-- ============================================================
-- 4. TEMPFILE SIZE AND AUTOEXTEND HEADROOM
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. TEMPFILE SIZE AND AUTOEXTEND HEADROOM
PROMPT ============================================================

SELECT
    tablespace_name,
    file_id,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (maxbytes - bytes) / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    autoextensible
FROM dba_temp_files
ORDER BY headroom_gb;


-- ============================================================
-- 5. TEMPFILES WITH LIMITED AUTOEXTEND HEADROOM
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. TEMPFILES WITH LIMITED AUTOEXTEND HEADROOM
PROMPT ============================================================

SELECT
    tablespace_name,
    file_id,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    ROUND(maxbytes / 1024 / 1024 / 1024, 2) AS max_gb,
    ROUND(
        (maxbytes - bytes) / 1024 / 1024 / 1024,
        2
    ) AS headroom_gb,
    autoextensible
FROM dba_temp_files
WHERE autoextensible = 'YES'
  AND (maxbytes - bytes) / 1024 / 1024 / 1024 < 10
ORDER BY headroom_gb;


-- ============================================================
-- 6. TEMPFILES THAT CANNOT AUTOEXTEND
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. TEMPFILES THAT CANNOT AUTOEXTEND
PROMPT ============================================================

SELECT
    tablespace_name,
    file_id,
    file_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS current_gb,
    autoextensible
FROM dba_temp_files
WHERE autoextensible = 'NO'
ORDER BY tablespace_name, file_id;


-- ============================================================
-- 7. TEMP USAGE BY SESSION
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. TEMP USAGE BY SESSION
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.machine,
    s.program,
    u.tablespace,
    ROUND(u.blocks * ts.block_size / 1024 / 1024, 2) AS temp_mb,
    s.sql_id,
    s.event
FROM v$tempseg_usage u
JOIN v$session s
    ON u.session_addr = s.saddr
JOIN dba_tablespaces ts
    ON u.tablespace = ts.tablespace_name
ORDER BY temp_mb DESC;


-- ============================================================
-- 8. TOP TEMP SPACE CONSUMERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. TOP TEMP SPACE CONSUMERS
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.machine,
    s.program,
    ROUND(
        SUM(u.blocks * ts.block_size)
        / 1024 / 1024,
        2
    ) AS temp_mb,
    s.sql_id
FROM v$tempseg_usage u
JOIN v$session s
    ON u.session_addr = s.saddr
JOIN dba_tablespaces ts
    ON u.tablespace = ts.tablespace_name
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.machine,
    s.program,
    s.sql_id
ORDER BY temp_mb DESC;


-- ============================================================
-- 9. TEMP USAGE BY USER
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. TEMP USAGE BY USER
PROMPT ============================================================

SELECT
    s.username,
    COUNT(DISTINCT s.sid) AS sessions,
    ROUND(
        SUM(u.blocks * ts.block_size)
        / 1024 / 1024,
        2
    ) AS temp_mb
FROM v$tempseg_usage u
JOIN v$session s
    ON u.session_addr = s.saddr
JOIN dba_tablespaces ts
    ON u.tablespace = ts.tablespace_name
WHERE s.username IS NOT NULL
GROUP BY s.username
ORDER BY temp_mb DESC;


-- ============================================================
-- 10. TEMP USAGE BY TABLESPACE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. TEMP USAGE BY TABLESPACE
PROMPT ============================================================

SELECT
    u.tablespace,
    COUNT(DISTINCT u.session_addr) AS sessions,
    ROUND(
        SUM(u.blocks * ts.block_size)
        / 1024 / 1024,
        2
    ) AS temp_mb
FROM v$tempseg_usage u
JOIN dba_tablespaces ts
    ON u.tablespace = ts.tablespace_name
GROUP BY u.tablespace
ORDER BY temp_mb DESC;


-- ============================================================
-- 11. TEMP USAGE BY SEGMENT TYPE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. TEMP USAGE BY SEGMENT TYPE
PROMPT ============================================================

SELECT
    u.segtype,
    COUNT(*) AS allocations,
    ROUND(
        SUM(u.blocks * ts.block_size)
        / 1024 / 1024,
        2
    ) AS temp_mb
FROM v$tempseg_usage u
JOIN dba_tablespaces ts
    ON u.tablespace = ts.tablespace_name
GROUP BY u.segtype
ORDER BY temp_mb DESC;


-- ============================================================
-- 12. SESSIONS USING MORE THAN 1 GB TEMP
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. SESSIONS USING MORE THAN 1 GB TEMP
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.machine,
    s.program,
    ROUND(
        SUM(u.blocks * ts.block_size)
        / 1024 / 1024 / 1024,
        2
    ) AS temp_gb,
    s.sql_id
FROM v$tempseg_usage u
JOIN v$session s
    ON u.session_addr = s.saddr
JOIN dba_tablespaces ts
    ON u.tablespace = ts.tablespace_name
GROUP BY
    s.sid,
    s.serial#,
    s.username,
    s.machine,
    s.program,
    s.sql_id
HAVING
    SUM(u.blocks * ts.block_size)
    / 1024 / 1024 / 1024 > 1
ORDER BY temp_gb DESC;


-- ============================================================
-- 13. TEMP USAGE AND ACTIVE SQL
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. TEMP USAGE AND ACTIVE SQL
PROMPT ============================================================

SELECT
    s.sid,
    s.serial# AS serial,
    s.username,
    s.status,
    s.sql_id,
    s.event,
    s.wait_class,
    ROUND(
        u.blocks * ts.block_size
        / 1024 / 1024,
        2
    ) AS temp_mb,
    SUBSTR(q.sql_text, 1, 100) AS sql_text
FROM v$tempseg_usage u
JOIN v$session s
    ON u.session_addr = s.saddr
JOIN dba_tablespaces ts
    ON u.tablespace = ts.tablespace_name
LEFT JOIN v$sql q
    ON s.sql_id = q.sql_id
   AND s.sql_child_number = q.child_number
WHERE s.status = 'ACTIVE'
ORDER BY temp_mb DESC;


-- ============================================================
-- 14. TEMP-RELATED WAIT EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. TEMP-RELATED WAIT EVENTS
PROMPT ============================================================

SELECT
    event,
    total_waits,
    ROUND(time_waited / 100, 2) AS time_waited_seconds,
    ROUND(
        CASE
            WHEN total_waits > 0
            THEN (time_waited / 100) / total_waits
        END,
        4
    ) AS avg_wait_seconds
FROM v$system_event
WHERE LOWER(event) LIKE '%temp%'
   OR LOWER(event) LIKE '%sort%'
ORDER BY time_waited DESC;


-- ============================================================
-- 15. CURRENT SESSIONS WAITING ON TEMP / SORT ACTIVITY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. CURRENT TEMP / SORT WAITERS
PROMPT ============================================================

SELECT
    sid,
    serial# AS serial,
    username,
    status,
    sql_id,
    event,
    wait_class,
    seconds_in_wait,
    state,
    machine,
    program
FROM v$session
WHERE wait_class <> 'Idle'
  AND (
       LOWER(event) LIKE '%temp%'
       OR LOWER(event) LIKE '%sort%'
      )
ORDER BY seconds_in_wait DESC;


-- ============================================================
-- 16. TEMP USAGE SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. TEMP USAGE SUMMARY
PROMPT ============================================================

SELECT
    COUNT(*) AS temp_tablespaces,
    ROUND(
        SUM(tablespace_size) / 1024 / 1024 / 1024,
        2
    ) AS total_temp_gb,
    ROUND(
        SUM(tablespace_size - free_space)
        / 1024 / 1024 / 1024,
        2
    ) AS used_temp_gb,
    ROUND(
        SUM(free_space) / 1024 / 1024 / 1024,
        2
    ) AS free_temp_gb,
    ROUND(
        SUM(tablespace_size - free_space)
        / SUM(tablespace_size) * 100,
        2
    ) AS used_pct
FROM dba_temp_free_space;


-- ============================================================
-- 17. TEMP HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. TEMP HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN MAX(
            (tablespace_size - free_space)
            / tablespace_size * 100
        ) >= 95
        THEN 'CRITICAL - TEMP >= 95% USED'

        WHEN MAX(
            (tablespace_size - free_space)
            / tablespace_size * 100
        ) >= 90
        THEN 'WARNING - TEMP >= 90% USED'

        ELSE 'HEALTHY - TEMP BELOW 90% USED'
    END AS health_status
FROM dba_temp_free_space;


-- ============================================================
-- 18. QUICK TEMPFILE CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. QUICK TEMPFILE CHECK
PROMPT ============================================================

SELECT
    t.tablespace_name,
    ROUND(t.tablespace_size / 1024 / 1024 / 1024, 2) AS total_gb,
    ROUND(
        (t.tablespace_size - t.free_space)
        / 1024 / 1024 / 1024,
        2
    ) AS used_gb,
    ROUND(t.free_space / 1024 / 1024 / 1024, 2) AS free_gb,
    ROUND(
        (t.tablespace_size - t.free_space)
        / t.tablespace_size * 100,
        2
    ) AS used_pct,
    CASE
        WHEN (t.tablespace_size - t.free_space)
             / t.tablespace_size * 100 >= 95
            THEN 'CRITICAL'
        WHEN (t.tablespace_size - t.free_space)
             / t.tablespace_size * 100 >= 90
            THEN 'WARNING'
        ELSE 'HEALTHY'
    END AS status
FROM dba_temp_free_space t
ORDER BY used_pct DESC;


-- ============================================================
-- DBA CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT DBA CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT 1. Check TEMP total, used and free space.
PROMPT 2. Identify sessions consuming large TEMP.
PROMPT 3. Check SQL_ID for high TEMP consumers.
PROMPT 4. Review SORT / HASH / CREATE INDEX operations.
PROMPT 5. Check TEMPFILE AUTOEXTEND and MAXBYTES.
PROMPT 6. Verify underlying ASM/filesystem capacity.
PROMPT 7. Check TEMP-related wait events.
PROMPT 8. Investigate sudden TEMP growth with SQL activity.
PROMPT 9. Do not resize TEMP solely because it is heavily used.
PROMPT 10. TEMP usage can be workload-driven and temporary.
PROMPT
PROMPT ============================================================
PROMPT END OF TEMPFILE USAGE CHECK
PROMPT ============================================================


-- ============================================================
-- Oracle DBA Toolkit
-- Script   : datafile_io.sql
-- Purpose  : Monitor datafile-level I/O activity and latency
-- Author   : Manik Challa
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF

COLUMN tablespace_name FORMAT A25
COLUMN file_name       FORMAT A75
COLUMN status          FORMAT A10

COLUMN reads           FORMAT 999,999,999,990
COLUMN writes          FORMAT 999,999,999,990
COLUMN read_mb         FORMAT 999,999,990.00
COLUMN write_mb        FORMAT 999,999,990.00
COLUMN read_iops       FORMAT 999,999,990.00
COLUMN write_iops      FORMAT 999,999,990.00
COLUMN read_latency_ms FORMAT 999,999,990.00
COLUMN write_latency_ms FORMAT 999,999,990.00
COLUMN read_pct        FORMAT 990.00
COLUMN write_pct       FORMAT 990.00
COLUMN total_gb        FORMAT 999,999,990.00

PROMPT
PROMPT ============================================================
PROMPT DATAFILE I/O MONITORING
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
-- 2. DATAFILE I/O SUMMARY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 2. DATAFILE I/O SUMMARY
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS total_gb,
    fs.phyrds AS reads,
    fs.phywrts AS writes,
    ROUND(
        fs.readtim / NULLIF(fs.phyrds, 0) * 10,
        2
    ) AS read_latency_ms,
    ROUND(
        fs.writetim / NULLIF(fs.phywrts, 0) * 10,
        2
    ) AS write_latency_ms
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
ORDER BY fs.phyrds + fs.phywrts DESC;


-- ============================================================
-- 3. TOP DATAFILES BY PHYSICAL READS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 3. TOP DATAFILES BY PHYSICAL READS
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    fs.phyrds AS physical_reads,
    ROUND(
        fs.readtim / NULLIF(fs.phyrds, 0) * 10,
        2
    ) AS read_latency_ms,
    ROUND(
        fs.phyrds / NULLIF(
            SUM(fs.phyrds) OVER (),
            0
        ) * 100,
        2
    ) AS read_pct
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
ORDER BY fs.phyrds DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================
-- 4. TOP DATAFILES BY PHYSICAL WRITES
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 4. TOP DATAFILES BY PHYSICAL WRITES
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    fs.phywrts AS physical_writes,
    ROUND(
        fs.writetim / NULLIF(fs.phywrts, 0) * 10,
        2
    ) AS write_latency_ms,
    ROUND(
        fs.phywrts / NULLIF(
            SUM(fs.phywrts) OVER (),
            0
        ) * 100,
        2
    ) AS write_pct
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
ORDER BY fs.phywrts DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================
-- 5. DATAFILES WITH HIGHEST READ LATENCY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 5. DATAFILES WITH HIGHEST READ LATENCY
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    fs.phyrds AS physical_reads,
    ROUND(
        fs.readtim / NULLIF(fs.phyrds, 0) * 10,
        2
    ) AS read_latency_ms
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
WHERE fs.phyrds > 0
ORDER BY read_latency_ms DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================
-- 6. DATAFILES WITH HIGHEST WRITE LATENCY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 6. DATAFILES WITH HIGHEST WRITE LATENCY
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    fs.phywrts AS physical_writes,
    ROUND(
        fs.writetim / NULLIF(fs.phywrts, 0) * 10,
        2
    ) AS write_latency_ms
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
WHERE fs.phywrts > 0
ORDER BY write_latency_ms DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================
-- 7. DATAFILES WITH HIGH READ + WRITE ACTIVITY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 7. TOP DATAFILES BY TOTAL I/O
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    fs.phyrds AS reads,
    fs.phywrts AS writes,
    fs.phyrds + fs.phywrts AS total_io,
    ROUND(
        fs.readtim / NULLIF(fs.phyrds, 0) * 10,
        2
    ) AS read_latency_ms,
    ROUND(
        fs.writetim / NULLIF(fs.phywrts, 0) * 10,
        2
    ) AS write_latency_ms
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
ORDER BY total_io DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================
-- 8. DATAFILE I/O BY TABLESPACE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 8. DATAFILE I/O BY TABLESPACE
PROMPT ============================================================

SELECT
    df.tablespace_name,
    COUNT(*) AS datafiles,
    SUM(fs.phyrds) AS physical_reads,
    SUM(fs.phywrts) AS physical_writes,
    SUM(fs.phyrds + fs.phywrts) AS total_io,
    ROUND(
        SUM(fs.readtim)
        / NULLIF(SUM(fs.phyrds), 0) * 10,
        2
    ) AS read_latency_ms,
    ROUND(
        SUM(fs.writetim)
        / NULLIF(SUM(fs.phywrts), 0) * 10,
        2
    ) AS write_latency_ms
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
GROUP BY df.tablespace_name
ORDER BY total_io DESC;


-- ============================================================
-- 9. DATAFILE I/O BY FILE SIZE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 9. DATAFILE SIZE VS I/O
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS total_gb,
    fs.phyrds AS physical_reads,
    fs.phywrts AS physical_writes,
    fs.phyrds + fs.phywrts AS total_io
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
ORDER BY total_gb DESC;


-- ============================================================
-- 10. READS PER GB OF DATAFILE
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 10. PHYSICAL READS PER GB
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS total_gb,
    fs.phyrds AS physical_reads,
    ROUND(
        fs.phyrds
        / NULLIF(df.bytes / 1024 / 1024 / 1024, 0),
        2
    ) AS reads_per_gb
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
ORDER BY reads_per_gb DESC;


-- ============================================================
-- 11. WRITE ACTIVITY PER GB
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 11. PHYSICAL WRITES PER GB
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS total_gb,
    fs.phywrts AS physical_writes,
    ROUND(
        fs.phywrts
        / NULLIF(df.bytes / 1024 / 1024 / 1024, 0),
        2
    ) AS writes_per_gb
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
ORDER BY writes_per_gb DESC;


-- ============================================================
-- 12. DATAFILE I/O WAIT EVENTS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 12. DATAFILE-RELATED I/O WAIT EVENTS
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
WHERE wait_class = 'User I/O'
ORDER BY time_waited DESC
FETCH FIRST 30 ROWS ONLY;


-- ============================================================
-- 13. CURRENT USER I/O WAITERS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 13. CURRENT USER I/O WAITERS
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
WHERE wait_class = 'User I/O'
ORDER BY seconds_in_wait DESC;


-- ============================================================
-- 14. DATAFILE I/O STATISTICS
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 14. DATAFILE I/O STATISTICS
PROMPT ============================================================

SELECT
    name AS statistic_name,
    value
FROM v$sysstat
WHERE LOWER(name) LIKE '%physical read%'
   OR LOWER(name) LIKE '%physical write%'
   OR LOWER(name) LIKE '%db block%'
ORDER BY name;


-- ============================================================
-- 15. TOP DATAFILES WITH HIGH READ LATENCY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 15. READ LATENCY FOCUS
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    fs.phyrds,
    ROUND(
        fs.readtim / NULLIF(fs.phyrds, 0) * 10,
        2
    ) AS avg_read_latency_ms,
    CASE
        WHEN fs.phyrds = 0
            THEN 'NO READ ACTIVITY'
        WHEN fs.readtim / NULLIF(fs.phyrds, 0) * 10 >= 20
            THEN 'HIGH'
        WHEN fs.readtim / NULLIF(fs.phyrds, 0) * 10 >= 10
            THEN 'ELEVATED'
        ELSE 'NORMAL'
    END AS latency_status
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
WHERE fs.phyrds > 0
ORDER BY avg_read_latency_ms DESC;


-- ============================================================
-- 16. TOP DATAFILES WITH HIGH WRITE LATENCY
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 16. WRITE LATENCY FOCUS
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    df.file_name,
    fs.phywrts,
    ROUND(
        fs.writetim / NULLIF(fs.phywrts, 0) * 10,
        2
    ) AS avg_write_latency_ms,
    CASE
        WHEN fs.phywrts = 0
            THEN 'NO WRITE ACTIVITY'
        WHEN fs.writetim / NULLIF(fs.phywrts, 0) * 10 >= 20
            THEN 'HIGH'
        WHEN fs.writetim / NULLIF(fs.phywrts, 0) * 10 >= 10
            THEN 'ELEVATED'
        ELSE 'NORMAL'
    END AS latency_status
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
WHERE fs.phywrts > 0
ORDER BY avg_write_latency_ms DESC;


-- ============================================================
-- 17. DATAFILE I/O HEALTH CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 17. DATAFILE I/O HEALTH CHECK
PROMPT ============================================================

SELECT
    CASE
        WHEN MAX(
            CASE
                WHEN fs.phyrds > 0
                 AND fs.readtim / fs.phyrds * 10 >= 20
                THEN 1
                ELSE 0
            END
        ) = 1
        THEN 'WARNING - HIGH DATAFILE READ LATENCY'

        WHEN MAX(
            CASE
                WHEN fs.phywrts > 0
                 AND fs.writetim / fs.phywrts * 10 >= 20
                THEN 1
                ELSE 0
            END
        ) = 1
        THEN 'WARNING - HIGH DATAFILE WRITE LATENCY'

        ELSE 'HEALTHY - NO HIGH DATAFILE LATENCY DETECTED'
    END AS health_status
FROM v$filestat fs;


-- ============================================================
-- 18. QUICK DATAFILE I/O CHECK
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT 18. QUICK DATAFILE I/O CHECK
PROMPT ============================================================

SELECT
    df.tablespace_name,
    df.file_id,
    ROUND(df.bytes / 1024 / 1024 / 1024, 2) AS total_gb,
    fs.phyrds AS reads,
    fs.phywrts AS writes,
    fs.phyrds + fs.phywrts AS total_io,
    ROUND(
        fs.readtim / NULLIF(fs.phyrds, 0) * 10,
        2
    ) AS read_ms,
    ROUND(
        fs.writetim / NULLIF(fs.phywrts, 0) * 10,
        2
    ) AS write_ms,
    CASE
        WHEN (
            fs.phyrds > 0
            AND fs.readtim / fs.phyrds * 10 >= 20
        )
        OR (
            fs.phywrts > 0
            AND fs.writetim / fs.phywrts * 10 >= 20
        )
            THEN 'WARNING'
        ELSE 'HEALTHY'
    END AS status
FROM v$filestat fs
JOIN dba_data_files df
    ON fs.file# = df.file_id
ORDER BY total_io DESC;


-- ============================================================
-- DBA CHECKLIST
-- ============================================================

PROMPT
PROMPT ============================================================
PROMPT DBA CHECKLIST
PROMPT ============================================================
PROMPT
PROMPT 1. Identify datafiles with high physical reads.
PROMPT 2. Identify datafiles with high physical writes.
PROMPT 3. Review average read/write latency.
PROMPT 4. Correlate high I/O with User I/O wait events.
PROMPT 5. Identify SQL generating physical I/O.
PROMPT 6. Check ASM/storage-cell performance separately.
PROMPT 7. For Exadata, correlate with CELL and CellCLI statistics.
PROMPT 8. Remember V$FILESTAT counters are cumulative.
PROMPT 9. Use before/after snapshots to calculate IOPS and MB/sec.
PROMPT 10. High I/O does not automatically indicate a storage problem.
PROMPT
PROMPT ============================================================
PROMPT END OF DATAFILE I/O CHECK
PROMPT ============================================================


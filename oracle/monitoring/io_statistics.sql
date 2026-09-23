-- ============================================================
-- Oracle DBA Toolkit
-- Script  : io_statistics.sql
-- Purpose : Monitor Oracle database I/O activity
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100
SET TRIMSPOOL ON

COLUMN NAME FORMAT A45
COLUMN PHYRDS FORMAT 999,999,999,999
COLUMN PHYWRTS FORMAT 999,999,999,999
COLUMN READS_MB FORMAT 999,999,999.99
COLUMN WRITES_MB FORMAT 999,999,999.99
COLUMN READS_PER_SEC FORMAT 999,999,999.99
COLUMN WRITES_PER_SEC FORMAT 999,999,999.99

PROMPT
PROMPT ============================================================
PROMPT                 DATABASE I/O SUMMARY
PROMPT ============================================================
PROMPT

SELECT
    ROUND(
        SUM(phyrds * phyblkrd) / 1024 / 1024,
        2
    ) AS reads_mb,
    ROUND(
        SUM(phywrts * phyblkwrt) / 1024 / 1024,
        2
    ) AS writes_mb,
    SUM(phyrds) AS physical_reads,
    SUM(phywrts) AS physical_writes
FROM
    v$filestat;

PROMPT
PROMPT ============================================================
PROMPT                 DATAFILE I/O
PROMPT ============================================================
PROMPT

COLUMN FILE_NAME FORMAT A70
COLUMN TABLESPACE_NAME FORMAT A25

SELECT
    df.tablespace_name,
    df.file_name,
    fs.phyrds AS physical_reads,
    fs.phywrts AS physical_writes,
    ROUND(
        fs.phyrds * fs.phyblkrd / 1024 / 1024,
        2
    ) AS reads_mb,
    ROUND(
        fs.phywrts * fs.phyblkwrt / 1024 / 1024,
        2
    ) AS writes_mb
FROM
    dba_data_files df
JOIN
    v$datafile f
ON
    df.file_id = f.file#
JOIN
    v$filestat fs
ON
    f.file# = fs.file#
ORDER BY
    (fs.phyrds + fs.phywrts) DESC;

PROMPT
PROMPT ============================================================
PROMPT                 TOP DATAFILES BY READ I/O
PROMPT ============================================================
PROMPT

SELECT
    df.tablespace_name,
    df.file_name,
    fs.phyrds AS physical_reads,
    ROUND(
        fs.phyrds * fs.phyblkrd / 1024 / 1024,
        2
    ) AS reads_mb
FROM
    dba_data_files df
JOIN
    v$datafile f
ON
    df.file_id = f.file#
JOIN
    v$filestat fs
ON
    f.file# = fs.file#
ORDER BY
    fs.phyrds DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 TOP DATAFILES BY WRITE I/O
PROMPT ============================================================
PROMPT

SELECT
    df.tablespace_name,
    df.file_name,
    fs.phywrts AS physical_writes,
    ROUND(
        fs.phywrts * fs.phyblkwrt / 1024 / 1024,
        2
    ) AS writes_mb
FROM
    dba_data_files df
JOIN
    v$datafile f
ON
    df.file_id = f.file#
JOIN
    v$filestat fs
ON
    f.file# = fs.file#
ORDER BY
    fs.phywrts DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 I/O BY TABLESPACE
PROMPT ============================================================
PROMPT

COLUMN TOTAL_READS FORMAT 999,999,999,999
COLUMN TOTAL_WRITES FORMAT 999,999,999,999

SELECT
    df.tablespace_name,
    SUM(fs.phyrds) AS total_reads,
    SUM(fs.phywrts) AS total_writes,
    ROUND(
        SUM(fs.phyrds * fs.phyblkrd) / 1024 / 1024,
        2
    ) AS reads_mb,
    ROUND(
        SUM(fs.phywrts * fs.phyblkwrt) / 1024 / 1024,
        2
    ) AS writes_mb
FROM
    dba_data_files df
JOIN
    v$datafile f
ON
    df.file_id = f.file#
JOIN
    v$filestat fs
ON
    f.file# = fs.file#
GROUP BY
    df.tablespace_name
ORDER BY
    (SUM(fs.phyrds) + SUM(fs.phywrts)) DESC;

PROMPT
PROMPT ============================================================
PROMPT                 TOP SQL BY PHYSICAL READS
PROMPT ============================================================
PROMPT

COLUMN SQL_ID FORMAT A15
COLUMN EXECUTIONS FORMAT 999,999,999
COLUMN DISK_READS FORMAT 999,999,999,999
COLUMN BUFFER_GETS FORMAT 999,999,999,999
COLUMN SQL_TEXT FORMAT A70 WORD_WRAPPED

SELECT
    sql_id,
    executions,
    disk_reads,
    buffer_gets,
    sql_text
FROM
(
    SELECT
        sql_id,
        executions,
        disk_reads,
        buffer_gets,
        sql_text
    FROM
        v$sql
    WHERE
        executions > 0
    ORDER BY
        disk_reads DESC
)
WHERE
    ROWNUM <= 20;

PROMPT
PROMPT ============================================================
PROMPT                 I/O-RELATED WAIT EVENTS
PROMPT ============================================================
PROMPT

COLUMN EVENT FORMAT A55
COLUMN WAIT_CLASS FORMAT A20
COLUMN WAITING_SESSIONS FORMAT 999,999

SELECT
    event,
    wait_class,
    COUNT(*) AS waiting_sessions
FROM
    v$session
WHERE
    username IS NOT NULL
    AND wait_class <> 'Idle'
    AND
    (
        LOWER(event) LIKE '%read%'
        OR LOWER(event) LIKE '%write%'
        OR LOWER(event) LIKE '%io%'
        OR LOWER(event) LIKE '%i/o%'
    )
GROUP BY
    event,
    wait_class
ORDER BY
    waiting_sessions DESC;

PROMPT
PROMPT ============================================================
PROMPT                 I/O STATISTICS COMPLETE
PROMPT ============================================================


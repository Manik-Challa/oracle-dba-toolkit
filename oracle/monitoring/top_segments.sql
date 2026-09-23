-- ============================================================
-- Oracle DBA Toolkit
-- Script  : top_segments.sql
-- Purpose : Identify the largest database segments
-- Usage   : SQL*Plus / SQLcl
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100
SET TRIMSPOOL ON

COLUMN OWNER FORMAT A25
COLUMN SEGMENT_NAME FORMAT A40
COLUMN PARTITION_NAME FORMAT A30
COLUMN SEGMENT_TYPE FORMAT A25
COLUMN TABLESPACE_NAME FORMAT A30
COLUMN SIZE_GB FORMAT 999,999,999.99

PROMPT
PROMPT ============================================================
PROMPT                 TOP 20 LARGEST SEGMENTS
PROMPT ============================================================
PROMPT

SELECT
    owner,
    segment_name,
    partition_name,
    segment_type,
    tablespace_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM
    dba_segments
ORDER BY
    bytes DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 LARGEST TABLE SEGMENTS
PROMPT ============================================================
PROMPT

SELECT
    owner,
    segment_name,
    tablespace_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM
    dba_segments
WHERE
    segment_type LIKE 'TABLE%'
ORDER BY
    bytes DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 LARGEST INDEX SEGMENTS
PROMPT ============================================================
PROMPT

SELECT
    owner,
    segment_name,
    tablespace_name,
    ROUND(bytes / 1024 / 1024 / 1024, 2) AS size_gb
FROM
    dba_segments
WHERE
    segment_type LIKE 'INDEX%'
ORDER BY
    bytes DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 SEGMENT SIZE BY OWNER
PROMPT ============================================================
PROMPT

COLUMN TOTAL_GB FORMAT 999,999,999.99

SELECT
    owner,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_gb
FROM
    dba_segments
GROUP BY
    owner
ORDER BY
    total_gb DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 SEGMENT SIZE BY TABLESPACE
PROMPT ============================================================
PROMPT

SELECT
    tablespace_name,
    ROUND(
        SUM(bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_gb
FROM
    dba_segments
GROUP BY
    tablespace_name
ORDER BY
    total_gb DESC;

PROMPT
PROMPT ============================================================
PROMPT                 LARGEST LOB SEGMENTS
PROMPT ============================================================
PROMPT

SELECT
    owner,
    segment_name,
    tablespace_name,
    ROUND(
        bytes / 1024 / 1024 / 1024,
        2
    ) AS size_gb
FROM
    dba_segments
WHERE
    segment_type LIKE 'LOB%'
ORDER BY
    bytes DESC
FETCH FIRST 20 ROWS ONLY;

PROMPT
PROMPT ============================================================
PROMPT                 TOP SEGMENTS REPORT COMPLETE
PROMPT ============================================================


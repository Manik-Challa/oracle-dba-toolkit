-- ============================================================
-- Oracle DBA Toolkit
-- Script  : top_sql.sql
-- Purpose : Find top SQL statements by elapsed time
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100
SET LONG 100000
SET LONGCHUNKSIZE 100000
SET TRIMSPOOL ON

COLUMN SQL_ID FORMAT A15
COLUMN EXECUTIONS FORMAT 999,999,999
COLUMN ELAPSED_SEC FORMAT 999,999,999.99
COLUMN CPU_SEC FORMAT 999,999,999.99
COLUMN BUFFER_GETS FORMAT 999,999,999,999
COLUMN DISK_READS FORMAT 999,999,999
COLUMN SQL_TEXT FORMAT A80 WORD_WRAPPED

PROMPT
PROMPT ============================================================
PROMPT              TOP SQL BY ELAPSED TIME
PROMPT ============================================================
PROMPT

SELECT
    *
FROM
(
    SELECT
        sql_id,
        executions,
        elapsed_time / 1000000 AS elapsed_sec,
        cpu_time / 1000000 AS cpu_sec,
        buffer_gets,
        disk_reads,
        sql_text
    FROM
        v$sql
    WHERE
        executions > 0
    ORDER BY
        elapsed_time DESC
)
WHERE
    ROWNUM <= 10;

PROMPT
PROMPT ============================================================
PROMPT              END OF REPORT
PROMPT ============================================================


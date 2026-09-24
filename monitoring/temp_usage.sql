-- ============================================================
-- Oracle DBA Toolkit
-- Script  : temp_usage.sql
-- Purpose : Monitor TEMP tablespace usage
-- ============================================================

SET LINESIZE 200
SET PAGESIZE 100

COLUMN TABLESPACE_NAME FORMAT A25
COLUMN TOTAL_MB FORMAT 999,999,999
COLUMN USED_MB FORMAT 999,999,999
COLUMN FREE_MB FORMAT 999,999,999
COLUMN PCT_USED FORMAT 999.99

PROMPT
PROMPT ============================================================
PROMPT                    TEMP USAGE
PROMPT ============================================================
PROMPT

SELECT
    tablespace_name,
    ROUND(tablespace_size * block_size / 1024 / 1024) AS total_mb,
    ROUND(
        (tablespace_size - free_blocks) * block_size
        / 1024 / 1024
    ) AS used_mb,
    ROUND(
        free_blocks * block_size
        / 1024 / 1024
    ) AS free_mb,
    ROUND(
        ((tablespace_size - free_blocks)
        / tablespace_size) * 100,
        2
    ) AS pct_used
FROM
    dba_temp_free_space
ORDER BY
    pct_used DESC;

PROMPT
PROMPT ============================================================
PROMPT                    END OF REPORT
PROMPT ============================================================


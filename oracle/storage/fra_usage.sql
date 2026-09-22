-- ============================================================
-- Oracle DBA Toolkit
-- Script  : fra_usage.sql
-- Purpose : Check Fast Recovery Area (FRA) usage
-- ============================================================

SET LINESIZE 200
SET PAGESIZE 100

COLUMN NAME FORMAT A60
COLUMN SPACE_LIMIT_MB FORMAT 999,999,999
COLUMN SPACE_USED_MB FORMAT 999,999,999
COLUMN SPACE_RECLAIMABLE_MB FORMAT 999,999,999
COLUMN USED_PERCENT FORMAT 999.99

PROMPT
PROMPT ============================================================
PROMPT              FAST RECOVERY AREA USAGE
PROMPT ============================================================
PROMPT

SELECT
    name,
    ROUND(space_limit / 1024 / 1024, 2) AS space_limit_mb,
    ROUND(space_used / 1024 / 1024, 2) AS space_used_mb,
    ROUND(space_reclaimable / 1024 / 1024, 2) AS space_reclaimable_mb,
    ROUND(
        CASE
            WHEN space_limit > 0
            THEN (space_used / space_limit) * 100
            ELSE 0
        END,
        2
    ) AS used_percent
FROM
    v$recovery_file_dest;

PROMPT
PROMPT ============================================================
PROMPT              END OF REPORT
PROMPT ============================================================
 

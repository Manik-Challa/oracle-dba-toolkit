-- ============================================================
-- Oracle DBA Toolkit
-- Script  : asm_disk_health.sql
-- Purpose : Check ASM disk status and health
-- Run     : Connected to an ASM instance
-- ============================================================

SET LINESIZE 250
SET PAGESIZE 100

COLUMN GROUP_NAME FORMAT A20
COLUMN DISK_NAME FORMAT A25
COLUMN PATH FORMAT A60
COLUMN HEADER_STATUS FORMAT A15
COLUMN MODE_STATUS FORMAT A15
COLUMN STATE FORMAT A15
COLUMN TOTAL_MB FORMAT 999,999,999
COLUMN FREE_MB FORMAT 999,999,999

PROMPT
PROMPT ============================================================
PROMPT                  ASM DISK HEALTH
PROMPT ============================================================
PROMPT

SELECT
    g.name AS group_name,
    d.name AS disk_name,
    d.path,
    d.header_status,
    d.mode_status,
    d.state,
    d.total_mb,
    d.free_mb
FROM
    v$asm_disk d
LEFT JOIN
    v$asm_diskgroup g
ON
    d.group_number = g.group_number
ORDER BY
    g.name,
    d.name;

PROMPT
PROMPT ============================================================
PROMPT                  ASM DISKGROUP SUMMARY
PROMPT ============================================================
PROMPT

COLUMN NAME FORMAT A20
COLUMN TYPE FORMAT A10
COLUMN TOTAL_MB FORMAT 999,999,999
COLUMN FREE_MB FORMAT 999,999,999
COLUMN USABLE_FILE_MB FORMAT 999,999,999
COLUMN PCT_USED FORMAT 999.99

SELECT
    name,
    type,
    total_mb,
    free_mb,
    usable_file_mb,
    ROUND(
        (total_mb - free_mb) / total_mb * 100,
        2
    ) AS pct_used
FROM
    v$asm_diskgroup
ORDER BY
    pct_used DESC;

PROMPT
PROMPT ============================================================
PROMPT                  END OF REPORT
PROMPT ============================================================


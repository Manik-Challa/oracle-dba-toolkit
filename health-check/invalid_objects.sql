-- ============================================================
-- Oracle DBA Toolkit
-- Script  : invalid_objects.sql
-- Purpose : Find invalid database objects
-- ============================================================

SET LINESIZE 200
SET PAGESIZE 100

COLUMN OWNER FORMAT A25
COLUMN OBJECT_NAME FORMAT A40
COLUMN OBJECT_TYPE FORMAT A25
COLUMN STATUS FORMAT A10

PROMPT
PROMPT ================================================
PROMPT       INVALID DATABASE OBJECTS
PROMPT ================================================
PROMPT

SELECT
    owner,
    object_name,
    object_type,
    status
FROM
    dba_objects
WHERE
    status = 'INVALID'
ORDER BY
    owner,
    object_type,
    object_name;

PROMPT
PROMPT ================================================
PROMPT       INVALID OBJECT SUMMARY
PROMPT ================================================
PROMPT

SELECT
    owner,
    object_type,
    COUNT(*) AS invalid_count
FROM
    dba_objects
WHERE
    status = 'INVALID'
GROUP BY
    owner,
    object_type
ORDER BY
    owner,
    object_type;

PROMPT
PROMPT ================================================
PROMPT       END OF REPORT
PROMPT ================================================


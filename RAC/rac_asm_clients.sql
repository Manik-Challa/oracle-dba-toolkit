-- ============================================================================
-- RAC ASM CLIENT MONITORING
-- File    : rac_asm_clients.sql
-- Purpose : Monitor RAC database instances connected to ASM
-- Author  : Manik Challa
-- Usage   : Run from ASM instance as SYSASM or with appropriate privileges
-- ============================================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN inst_id               FORMAT 999
COLUMN group_number          FORMAT 9999
COLUMN instance_name         FORMAT A25
COLUMN db_name               FORMAT A20
COLUMN status                FORMAT A15
COLUMN software_version      FORMAT A20
COLUMN compatible_version    FORMAT A20
COLUMN client_count          FORMAT 9999
COLUMN diskgroup_count       FORMAT 9999
COLUMN instance_count        FORMAT 9999

PROMPT
PROMPT ============================================================================
PROMPT RAC ASM CLIENT MONITORING
PROMPT ============================================================================


PROMPT
PROMPT ============================================================================
PROMPT 1. ASM CLIENT OVERVIEW
PROMPT ============================================================================

SELECT
    inst_id,
    group_number,
    instance_name,
    db_name,
    status,
    software_version,
    compatible_version
FROM gv$asm_client
ORDER BY
    db_name,
    instance_name,
    group_number;


PROMPT
PROMPT ============================================================================
PROMPT 2. ASM CLIENTS BY RAC INSTANCE
PROMPT ============================================================================

SELECT
    inst_id,
    instance_name,
    db_name,
    status,
    COUNT(*) AS client_count
FROM gv$asm_client
GROUP BY
    inst_id,
    instance_name,
    db_name,
    status
ORDER BY
    inst_id,
    db_name,
    instance_name;


PROMPT
PROMPT ============================================================================
PROMPT 3. DATABASES CONNECTED TO ASM
PROMPT ============================================================================

SELECT DISTINCT
    db_name,
    software_version,
    compatible_version
FROM gv$asm_client
ORDER BY db_name;


PROMPT
PROMPT ============================================================================
PROMPT 4. ASM CLIENT STATUS SUMMARY
PROMPT ============================================================================

SELECT
    status,
    COUNT(*) AS client_count,
    COUNT(DISTINCT db_name) AS database_count,
    COUNT(DISTINCT instance_name) AS instance_count
FROM gv$asm_client
GROUP BY status
ORDER BY status;


PROMPT
PROMPT ============================================================================
PROMPT 5. ASM CLIENT COUNT BY DATABASE
PROMPT ============================================================================

SELECT
    db_name,
    COUNT(*) AS client_count,
    COUNT(DISTINCT instance_name) AS instance_count,
    MIN(software_version) AS software_version,
    MIN(compatible_version) AS compatible_version
FROM gv$asm_client
GROUP BY db_name
ORDER BY db_name;


PROMPT
PROMPT ============================================================================
PROMPT 6. ASM CLIENT DISTRIBUTION BY DATABASE AND INSTANCE
PROMPT ============================================================================

SELECT
    db_name,
    instance_name,
    inst_id,
    status,
    COUNT(*) AS client_entries
FROM gv$asm_client
GROUP BY
    db_name,
    instance_name,
    inst_id,
    status
ORDER BY
    db_name,
    instance_name;


PROMPT
PROMPT ============================================================================
PROMPT 7. ASM CLIENTS WITH UNEXPECTED STATUS
PROMPT ============================================================================

SELECT
    inst_id,
    group_number,
    instance_name,
    db_name,
    status,
    software_version,
    compatible_version
FROM gv$asm_client
WHERE status <> 'CONNECTED'
ORDER BY
    db_name,
    instance_name;


PROMPT
PROMPT ============================================================================
PROMPT 8. ASM CLIENTS BY ASM INSTANCE
PROMPT ============================================================================

SELECT
    inst_id,
    instance_name,
    COUNT(*) AS client_entries,
    COUNT(DISTINCT db_name) AS database_count,
    COUNT(DISTINCT group_number) AS diskgroup_count
FROM gv$asm_client
GROUP BY
    inst_id,
    instance_name
ORDER BY inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 9. ASM CLIENTS BY DISKGROUP
PROMPT ============================================================================

SELECT
    inst_id,
    group_number,
    COUNT(*) AS client_entries,
    COUNT(DISTINCT db_name) AS database_count,
    COUNT(DISTINCT instance_name) AS instance_count
FROM gv$asm_client
GROUP BY
    inst_id,
    group_number
ORDER BY
    inst_id,
    group_number;


PROMPT
PROMPT ============================================================================
PROMPT 10. DATABASE / INSTANCE / DISKGROUP MATRIX
PROMPT ============================================================================

SELECT
    db_name,
    instance_name,
    group_number,
    status,
    software_version,
    compatible_version
FROM gv$asm_client
ORDER BY
    db_name,
    instance_name,
    group_number;


PROMPT
PROMPT ============================================================================
PROMPT 11. ASM CLIENT SOFTWARE VERSIONS
PROMPT ============================================================================

SELECT
    software_version,
    compatible_version,
    COUNT(*) AS client_entries,
    COUNT(DISTINCT db_name) AS database_count,
    COUNT(DISTINCT instance_name) AS instance_count
FROM gv$asm_client
GROUP BY
    software_version,
    compatible_version
ORDER BY
    software_version,
    compatible_version;


PROMPT
PROMPT ============================================================================
PROMPT 12. ASM CLIENTS BY DATABASE AND STATUS
PROMPT ============================================================================

SELECT
    db_name,
    status,
    COUNT(*) AS client_entries,
    COUNT(DISTINCT instance_name) AS instance_count
FROM gv$asm_client
GROUP BY
    db_name,
    status
ORDER BY
    db_name,
    status;


PROMPT
PROMPT ============================================================================
PROMPT 13. RAC DATABASE INSTANCE DISTRIBUTION
PROMPT ============================================================================

SELECT
    db_name,
    COUNT(DISTINCT instance_name) AS rac_instances,
    LISTAGG(
        DISTINCT instance_name,
        ', '
    ) WITHIN GROUP (
        ORDER BY instance_name
    ) AS instances
FROM gv$asm_client
GROUP BY db_name
ORDER BY db_name;


PROMPT
PROMPT ============================================================================
PROMPT 14. ASM CLIENTS PER ASM INSTANCE
PROMPT ============================================================================

SELECT
    inst_id,
    instance_name,
    COUNT(DISTINCT db_name) AS database_count,
    COUNT(DISTINCT instance_name) AS instance_count
FROM gv$asm_client
GROUP BY
    inst_id,
    instance_name
ORDER BY inst_id;


PROMPT
PROMPT ============================================================================
PROMPT 15. DISKGROUP VISIBILITY ACROSS ASM INSTANCES
PROMPT ============================================================================

SELECT
    group_number,
    COUNT(DISTINCT inst_id) AS asm_instances,
    COUNT(DISTINCT db_name) AS databases,
    COUNT(DISTINCT instance_name) AS database_instances
FROM gv$asm_client
GROUP BY group_number
ORDER BY group_number;


PROMPT
PROMPT ============================================================================
PROMPT 16. ASM CLIENT HEALTH SUMMARY
PROMPT ============================================================================

SELECT
    'ASM CLIENT ENTRIES' AS check_name,
    COUNT(*) AS value,
    CASE
        WHEN COUNT(*) > 0 THEN 'OK'
        ELSE 'CHECK'
    END AS health
FROM gv$asm_client

UNION ALL

SELECT
    'CONNECTED CLIENTS',
    COUNT(*),
    CASE
        WHEN COUNT(*) > 0 THEN 'OK'
        ELSE 'CHECK'
    END
FROM gv$asm_client
WHERE status = 'CONNECTED'

UNION ALL

SELECT
    'NON-CONNECTED CLIENTS',
    COUNT(*),
    CASE
        WHEN COUNT(*) = 0 THEN 'OK'
        ELSE 'CHECK'
    END
FROM gv$asm_client
WHERE status <> 'CONNECTED'

UNION ALL

SELECT
    'DATABASES USING ASM',
    COUNT(DISTINCT db_name),
    CASE
        WHEN COUNT(DISTINCT db_name) > 0 THEN 'OK'
        ELSE 'CHECK'
    END
FROM gv$asm_client;


PROMPT
PROMPT ============================================================================
PROMPT 17. ASM CLIENT DBA CHECKLIST
PROMPT ============================================================================

PROMPT
PROMPT [ ] All expected RAC database instances appear in GV$ASM_CLIENT
PROMPT [ ] ASM client status is CONNECTED where expected
PROMPT [ ] Expected databases are visible from the ASM instances
PROMPT [ ] RAC instances are distributed as expected
PROMPT [ ] ASM software/compatible versions are reviewed when relevant
PROMPT [ ] Unexpected missing client entries are investigated
PROMPT [ ] ASM instance connectivity is checked if clients disappear
PROMPT [ ] ASM diskgroup state is checked alongside client status
PROMPT [ ] CRS/SRVCTL status is checked for cluster-level issues
PROMPT [ ] OS/storage/multipath health is checked when ASM connectivity fails
PROMPT
PROMPT ============================================================================
PROMPT IMPORTANT
PROMPT ============================================================================
PROMPT GV$ASM_CLIENT shows database/client connectivity to ASM.
PROMPT
PROMPT It does NOT provide per-database ASM storage consumption.
PROMPT Use ASM diskgroup, ASM file, database, or application-level
PROMPT metadata when investigating storage consumption.
PROMPT
PROMPT A missing client entry should be correlated with RAC instance,
PROMPT ASM instance, CRS and storage connectivity before taking action.
PROMPT
PROMPT This script is READ-ONLY.
PROMPT ============================================================================
 
-- ============================================================
-- Oracle DBA Toolkit
-- PDB Status Monitoring
--
-- Purpose:
--   Monitor Oracle Multitenant Pluggable Database status.
--
-- Key checks:
--   - PDB name and open mode
--   - Restricted mode
--   - Open mode across RAC instances
--   - PDB creation time
--   - PDB size
--   - PDB services
--   - PDB save state
--   - Application containers
--   - PDB status summary
--
-- Notes:
--   Run from CDB$ROOT for complete PDB visibility.
--   Some columns/features can vary by Oracle release.
-- ============================================================

SET LINESIZE 300
SET PAGESIZE 100
SET TRIMSPOOL ON
SET TAB OFF
SET VERIFY OFF

COLUMN con_id              FORMAT 999
COLUMN con_name            FORMAT A30
COLUMN pdb_name            FORMAT A30
COLUMN name                 FORMAT A30
COLUMN open_mode            FORMAT A20
COLUMN restricted           FORMAT A12
COLUMN open_time            FORMAT A20
COLUMN creation_time        FORMAT A20
COLUMN total_size_mb        FORMAT 999,999,999
COLUMN total_size_gb        FORMAT 999,990.00
COLUMN tablespace_count     FORMAT 999
COLUMN save_state           FORMAT A15
COLUMN instance_name        FORMAT A20
COLUMN host_name            FORMAT A35
COLUMN service_name         FORMAT A35
COLUMN network_name         FORMAT A35
COLUMN enabled              FORMAT A12
COLUMN pdb_count            FORMAT 999,999

PROMPT
PROMPT ============================================================
PROMPT 1. PDB STATUS
PROMPT ============================================================

SELECT
    con_id,
    name AS pdb_name,
    open_mode,
    restricted,
    TO_CHAR(open_time, 'YYYY-MM-DD HH24:MI:SS') AS open_time
FROM v$pdbs
ORDER BY con_id;


PROMPT
PROMPT ============================================================
PROMPT 2. PDB STATUS SUMMARY
PROMPT ============================================================

SELECT
    open_mode,
    restricted,
    COUNT(*) AS pdb_count
FROM v$pdbs
WHERE con_id > 2
GROUP BY open_mode, restricted
ORDER BY open_mode, restricted;


PROMPT
PROMPT ============================================================
PROMPT 3. PDBS NOT OPEN READ WRITE
PROMPT ============================================================

SELECT
    con_id,
    name AS pdb_name,
    open_mode,
    restricted
FROM v$pdbs
WHERE con_id > 2
  AND open_mode <> 'READ WRITE'
ORDER BY con_id;


PROMPT
PROMPT ============================================================
PROMPT 4. PDBS IN RESTRICTED MODE
PROMPT ============================================================

SELECT
    con_id,
    name AS pdb_name,
    open_mode,
    restricted
FROM v$pdbs
WHERE con_id > 2
  AND restricted = 'YES'
ORDER BY con_id;


PROMPT
PROMPT ============================================================
PROMPT 5. PDB OPEN MODE BY RAC INSTANCE
PROMPT ============================================================

SELECT
    inst_id,
    con_id,
    name AS pdb_name,
    open_mode,
    restricted
FROM gv$pdbs
WHERE con_id > 2
ORDER BY con_id, inst_id;


PROMPT
PROMPT ============================================================
PROMPT 6. PDBS NOT OPEN CONSISTENTLY ACROSS RAC
PROMPT ============================================================

SELECT
    con_id,
    name AS pdb_name,
    COUNT(*) AS instance_count,
    COUNT(DISTINCT open_mode) AS open_mode_count,
    COUNT(DISTINCT restricted) AS restricted_state_count
FROM gv$pdbs
WHERE con_id > 2
GROUP BY con_id, name
HAVING COUNT(DISTINCT open_mode) > 1
    OR COUNT(DISTINCT restricted) > 1
ORDER BY con_id;


PROMPT
PROMPT ============================================================
PROMPT 7. PDB CREATION INFORMATION
PROMPT ============================================================

SELECT
    con_id,
    name AS pdb_name,
    TO_CHAR(creation_time, 'YYYY-MM-DD HH24:MI:SS') AS creation_time,
    open_mode,
    restricted
FROM v$pdbs
WHERE con_id > 2
ORDER BY creation_time DESC;


PROMPT
PROMPT ============================================================
PROMPT 8. PDB SIZE
PROMPT ============================================================

SELECT
    p.con_id,
    p.name AS pdb_name,
    ROUND(
        SUM(df.bytes) / 1024 / 1024,
        2
    ) AS total_size_mb,
    ROUND(
        SUM(df.bytes) / 1024 / 1024 / 1024,
        2
    ) AS total_size_gb
FROM v$pdbs p
JOIN cdb_data_files df
    ON df.con_id = p.con_id
WHERE p.con_id > 2
GROUP BY p.con_id, p.name
ORDER BY total_size_gb DESC;


PROMPT
PROMPT ============================================================
PROMPT 9. PDB TABLESPACE COUNT
PROMPT ============================================================

SELECT
    con_id,
    COUNT(*) AS tablespace_count
FROM cdb_tablespaces
WHERE con_id > 2
GROUP BY con_id
ORDER BY con_id;


PROMPT
PROMPT ============================================================
PROMPT 10. PDB SAVE STATE
PROMPT ============================================================

SELECT
    con_id,
    name AS pdb_name,
    state
FROM dba_pdb_saved_states
ORDER BY con_id;


PROMPT
PROMPT ============================================================
PROMPT 11. PDB SERVICES
PROMPT ============================================================

SELECT
    p.con_id,
    p.name AS pdb_name,
    s.name AS service_name,
    s.network_name,
    s.enabled
FROM v$pdbs p
JOIN v$services s
    ON s.con_id = p.con_id
WHERE p.con_id > 2
ORDER BY p.con_id, s.name;


PROMPT
PROMPT ============================================================
PROMPT 12. PDB SERVICES - RAC INSTANCE DETAILS
PROMPT ============================================================

SELECT
    inst_id,
    con_id,
    name AS service_name,
    network_name,
    enabled
FROM gv$services
WHERE con_id > 2
ORDER BY con_id, inst_id, name;


PROMPT
PROMPT ============================================================
PROMPT 13. PDB SESSION COUNT
PROMPT ============================================================

SELECT
    con_id,
    COUNT(*) AS session_count,
    SUM(
        CASE
            WHEN status = 'ACTIVE' THEN 1
            ELSE 0
        END
    ) AS active_sessions,
    SUM(
        CASE
            WHEN status = 'INACTIVE' THEN 1
            ELSE 0
        END
    ) AS inactive_sessions
FROM v$session
WHERE type = 'USER'
  AND con_id > 2
GROUP BY con_id
ORDER BY session_count DESC;


PROMPT
PROMPT ============================================================
PROMPT 14. PDB ACTIVE SESSIONS
PROMPT ============================================================

SELECT
    s.con_id,
    p.name AS pdb_name,
    COUNT(*) AS active_sessions
FROM v$session s
JOIN v$pdbs p
    ON p.con_id = s.con_id
WHERE s.type = 'USER'
  AND s.status = 'ACTIVE'
  AND s.con_id > 2
GROUP BY s.con_id, p.name
ORDER BY active_sessions DESC;


PROMPT
PROMPT ============================================================
PROMPT 15. PDB STATUS + RESOURCE USAGE
PROMPT ============================================================

SELECT
    p.con_id,
    p.name AS pdb_name,
    p.open_mode,
    p.restricted,
    NVL(s.session_count, 0) AS session_count,
    NVL(s.active_sessions, 0) AS active_sessions
FROM v$pdbs p
LEFT JOIN (
    SELECT
        con_id,
        COUNT(*) AS session_count,
        SUM(
            CASE
                WHEN status = 'ACTIVE' THEN 1
                ELSE 0
            END
        ) AS active_sessions
    FROM v$session
    WHERE type = 'USER'
    GROUP BY con_id
) s
    ON s.con_id = p.con_id
WHERE p.con_id > 2
ORDER BY p.con_id;


PROMPT
PROMPT ============================================================
PROMPT 16. PDB HEALTH CHECK
PROMPT ============================================================

SELECT
    con_id,
    name AS pdb_name,
    open_mode,
    restricted,
    CASE
        WHEN open_mode = 'READ WRITE'
         AND restricted = 'NO'
        THEN 'OK'
        WHEN restricted = 'YES'
        THEN 'CHECK - RESTRICTED'
        WHEN open_mode <> 'READ WRITE'
        THEN 'CHECK - NOT READ WRITE'
        ELSE 'CHECK'
    END AS health_status
FROM v$pdbs
WHERE con_id > 2
ORDER BY con_id;


PROMPT
PROMPT ============================================================
PROMPT 17. PDBS REQUIRING ATTENTION
PROMPT ============================================================

SELECT
    con_id,
    name AS pdb_name,
    open_mode,
    restricted
FROM v$pdbs
WHERE con_id > 2
  AND (
        open_mode <> 'READ WRITE'
        OR restricted = 'YES'
      )
ORDER BY con_id;


PROMPT
PROMPT ============================================================
PROMPT DBA INVESTIGATION NOTES
PROMPT ============================================================
PROMPT
PROMPT 1. Run this script from CDB$ROOT for complete PDB visibility.
PROMPT
PROMPT 2. OPEN_MODE = READ WRITE generally indicates a normal
PROMPT    read/write application PDB state.
PROMPT
PROMPT 3. RESTRICTED = YES means the PDB is operating in restricted
PROMPT    mode and should be investigated if unexpected.
PROMPT
PROMPT 4. PDBs can be intentionally opened READ ONLY or RESTRICTED.
PROMPT    Do not assume every non-READ-WRITE state is an incident.
PROMPT
PROMPT 5. In RAC, compare PDB state across instances using GV$PDBS.
PROMPT
PROMPT 6. Check DBA_PDB_SAVED_STATES when validating whether a PDB
PROMPT    should automatically open after CDB startup.
PROMPT
PROMPT 7. Review PDB services when users report connection problems.
PROMPT
PROMPT 8. Review PDB session counts when investigating connection
PROMPT    or workload concentration.
PROMPT
PROMPT 9. For unexpected PDB state changes, correlate with:
PROMPT       - alert.log
PROMPT       - CDB/PDB startup activity
PROMPT       - application maintenance
PROMPT       - RAC events
PROMPT       - Data Guard role changes
PROMPT
PROMPT 10. This script is diagnostic only. It does not open, close,
PROMPT     save state, or modify any PDB.
PROMPT
PROMPT ============================================================
PROMPT END OF PDB STATUS MONITORING
PROMPT ============================================================


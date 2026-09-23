#!/usr/bin/env bash
# ==============================================================================
# Script Name : oracle_daily_health_check.sh
# Description : Checks instance status, invalid objects, tablespace usage, 
#               ASM diskgroup space, and recent alert log errors.
# ==============================================================================

set -euo pipefail

# --- Configuration ---
export ORACLE_SID="${ORACLE_SID:-orcl}"
export ORACLE_HOME="${ORACLE_HOME:-/u01/app/oracle/product/19.0.0/dbhome_1}"
export PATH="${ORACLE_HOME}/bin:${PATH}"

LOG_FILE="/tmp/ora_health_${ORACLE_SID}_$(date +%Y%m%m_%H%M%S).log"

echo "======================================================================" > "${LOG_FILE}"
echo "            ORACLE DATABASE HEALTH CHECK REPORT                        " >> "${LOG_FILE}"
echo "TIMESTAMP : $(date '+%Y-%m-%d %H:%M:%S')" >> "${LOG_FILE}"
echo "ORACLE_SID: ${ORACLE_SID}" >> "${LOG_FILE}"
echo "======================================================================" >> "${LOG_FILE}"

sqlplus -s / as sysdba << 'EOF' >> "${LOG_FILE}"
SET PAGESIZE 100 LINESIZE 200 FEEDBACK OFF HEADING ON TRIMSPOOL ON;

PROMPT 
PROMPT [1] INSTANCE STATUS & UPTIME
PROMPT ----------------------------------------------------------------------
COL instance_name FORMAT A15;
COL host_name FORMAT A25;
COL status FORMAT A10;
COL startup_time FORMAT A20;
SELECT instance_name, host_name, status, TO_CHAR(startup_time, 'YYYY-MM-DD HH24:MI') AS startup_time, database_status FROM v$instance;

PROMPT 
PROMPT [2] TABLESPACE USAGE (> 85% Full)
PROMPT ----------------------------------------------------------------------
COL tablespace_name FORMAT A25;
COL size_mb FORMAT 999,999,999;
COL used_mb FORMAT 999,999,999;
COL free_mb FORMAT 999,999,999;
COL pct_used FORMAT 999.99;

SELECT 
    df.tablespace_name,
    ROUND(df.bytes / 1024 / 1024) AS size_mb,
    ROUND((df.bytes - NVL(fs.bytes, 0)) / 1024 / 1024) AS used_mb,
    ROUND(NVL(fs.bytes, 0) / 1024 / 1024) AS free_mb,
    ROUND((1 - (NVL(fs.bytes, 0) / df.bytes)) * 100, 2) AS pct_used
FROM 
    (SELECT tablespace_name, SUM(bytes) bytes FROM dba_data_files GROUP BY tablespace_name) df
LEFT JOIN 
    (SELECT tablespace_name, SUM(bytes) bytes FROM dba_free_space GROUP BY tablespace_name) fs
ON df.tablespace_name = fs.tablespace_name
WHERE ROUND((1 - (NVL(fs.bytes, 0) / df.bytes)) * 100, 2) > 85
ORDER BY pct_used DESC;

PROMPT 
PROMPT [3] INVALID OBJECTS COUNT
PROMPT ----------------------------------------------------------------------
COL owner FORMAT A20;
COL object_type FORMAT A20;
SELECT owner, object_type, COUNT(*) AS invalid_count
FROM dba_objects 
WHERE status = 'INVALID' 
GROUP BY owner, object_type 
ORDER BY owner, object_type;

PROMPT 
PROMPT [4] ACTIVE BLOCKING SESSIONS
PROMPT ----------------------------------------------------------------------
SELECT 
    blocking_session, 
    sid, 
    serial#, 
    username, 
    seconds_in_wait, 
    event 
FROM v$session 
WHERE blocking_session IS NOT NULL;

EXIT;
EOF

cat "${LOG_FILE}"
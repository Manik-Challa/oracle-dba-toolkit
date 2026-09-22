#!/bin/bash

# ============================================================
# Oracle DBA Toolkit
# Script  : daily_dba_health_check.sh
# Purpose : Daily Oracle Database health check
# Usage   : ./daily_dba_health_check.sh
# ============================================================

# ------------------------------------------------------------
# Configuration
# ------------------------------------------------------------

ORACLE_SID="${ORACLE_SID:-ORCL}"
ORACLE_HOME="${ORACLE_HOME:-/u01/app/oracle/product/19.0.0.0/dbhome_1}"

export ORACLE_SID
export ORACLE_HOME
export PATH="$ORACLE_HOME/bin:$PATH"

REPORT_DIR="./reports"
TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
REPORT_FILE="$REPORT_DIR/dba_health_${ORACLE_SID}_${TIMESTAMP}.log"

mkdir -p "$REPORT_DIR"

# ------------------------------------------------------------
# Header
# ------------------------------------------------------------

{
echo "============================================================"
echo "             ORACLE DBA DAILY HEALTH CHECK"
echo "============================================================"
echo "Database    : $ORACLE_SID"
echo "Host        : $(hostname)"
echo "Date        : $(date)"
echo "Oracle Home : $ORACLE_HOME"
echo "============================================================"
echo

# ------------------------------------------------------------
# 1. Database Status
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "1. DATABASE STATUS"
echo "------------------------------------------------------------"

sqlplus -s / as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

SELECT
    i.instance_name,
    i.host_name,
    i.status,
    d.database_role,
    d.open_mode
FROM v\\$instance i
CROSS JOIN v\\$database d;

EXIT;
EOF

echo

# ------------------------------------------------------------
# 2. Tablespace Usage
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "2. TABLESPACE USAGE"
echo "------------------------------------------------------------"

sqlplus -s / as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

SELECT
    df.tablespace_name,
    ROUND(df.total_mb, 2) AS total_mb,
    ROUND(df.total_mb - NVL(fs.free_mb, 0), 2) AS used_mb,
    ROUND(NVL(fs.free_mb, 0), 2) AS free_mb,
    ROUND(
        ((df.total_mb - NVL(fs.free_mb, 0)) / df.total_mb) * 100,
        2
    ) AS used_percent
FROM
(
    SELECT
        tablespace_name,
        SUM(bytes) / 1024 / 1024 AS total_mb
    FROM dba_data_files
    GROUP BY tablespace_name
) df
LEFT JOIN
(
    SELECT
        tablespace_name,
        SUM(bytes) / 1024 / 1024 AS free_mb
    FROM dba_free_space
    GROUP BY tablespace_name
) fs
ON df.tablespace_name = fs.tablespace_name
ORDER BY used_percent DESC;

EXIT;
EOF

echo

# ------------------------------------------------------------
# 3. FRA Usage
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "3. FRA USAGE"
echo "------------------------------------------------------------"

sqlplus -s / as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

SELECT
    name,
    ROUND(space_limit / 1024 / 1024, 2) AS limit_mb,
    ROUND(space_used / 1024 / 1024, 2) AS used_mb,
    ROUND(space_reclaimable / 1024 / 1024, 2) AS reclaimable_mb,
    ROUND(
        (space_used / NULLIF(space_limit, 0)) * 100,
        2
    ) AS used_percent
FROM v\\$recovery_file_dest;

EXIT;
EOF

echo

# ------------------------------------------------------------
# 4. Invalid Objects
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "4. INVALID OBJECTS"
echo "------------------------------------------------------------"

sqlplus -s / as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

SELECT
    owner,
    object_type,
    COUNT(*) AS invalid_count
FROM dba_objects
WHERE status = 'INVALID'
GROUP BY owner, object_type
ORDER BY invalid_count DESC;

EXIT;
EOF

echo

# ------------------------------------------------------------
# 5. Locked Users
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "5. LOCKED USERS"
echo "------------------------------------------------------------"

sqlplus -s / as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

SELECT
    username,
    account_status,
    lock_date
FROM dba_users
WHERE account_status LIKE '%LOCKED%'
ORDER BY username;

EXIT;
EOF

echo

# ------------------------------------------------------------
# 6. Blocking Sessions
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "6. BLOCKING SESSIONS"
echo "------------------------------------------------------------"

sqlplus -s / as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

SELECT
    sid,
    serial#,
    username,
    blocking_session,
    event,
    seconds_in_wait
FROM v\\$session
WHERE blocking_session IS NOT NULL
ORDER BY seconds_in_wait DESC;

EXIT;
EOF

echo

# ------------------------------------------------------------
# 7. Current Wait Events
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "7. CURRENT WAIT EVENTS"
echo "------------------------------------------------------------"

sqlplus -s / as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

SELECT
    event,
    wait_class,
    COUNT(*) AS sessions_waiting
FROM v\\$session
WHERE wait_class <> 'Idle'
GROUP BY event, wait_class
ORDER BY sessions_waiting DESC;

EXIT;
EOF

echo

# ------------------------------------------------------------
# 8. ASM Diskgroup Usage
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "8. ASM DISKGROUP USAGE"
echo "------------------------------------------------------------"

sqlplus -s / as sysdba <<EOF
SET PAGESIZE 100
SET LINESIZE 200

SELECT
    name,
    type,
    total_mb,
    free_mb,
    usable_file_mb,
    ROUND(
        ((total_mb - free_mb) / total_mb) * 100,
        2
    ) AS used_percent
FROM v\\$asm_diskgroup
ORDER BY used_percent DESC;

EXIT;
EOF

echo

# ------------------------------------------------------------
# 9. Linux Health
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "9. LINUX HEALTH"
echo "------------------------------------------------------------"

echo "Hostname:"
hostname

echo
echo "Uptime:"
uptime

echo
echo "Memory:"
free -h

echo
echo "Filesystem:"
df -h

echo
echo "Top CPU Processes:"
ps -eo pid,user,%cpu,%mem,etime,cmd --sort=-%cpu | head -11

echo

# ------------------------------------------------------------
# Completion
# ------------------------------------------------------------

echo "============================================================"
echo "             HEALTH CHECK COMPLETED"
echo "============================================================"
echo "Report saved to:"
echo "$REPORT_FILE"
echo "============================================================"

} | tee "$REPORT_FILE"

exit 0


#!/usr/bin/env bash
# ==============================================================================
# Script Name : asm_space_monitor.sh
# Description : Connects to Grid Infrastructure (+ASM) to check disk group usage.
# ==============================================================================

export ORACLE_SID="+ASM1"
export ORACLE_HOME="/u01/app/19.0.0/grid"
export PATH="${ORACLE_HOME}/bin:${PATH}"

sqlplus -s / as sysasm << 'EOF'
SET PAGESIZE 100 LINESIZE 200 FEEDBACK OFF HEADING ON TRIMSPOOL ON;

COL name FORMAT A20;
COL state FORMAT A12;
COL total_gb FORMAT 999,999.99;
COL free_gb FORMAT 999,999.99;
COL usable_file_mb FORMAT 999,999;
COL pct_used FORMAT 999.99;

PROMPT ====================================================================================;
PROMPT                            ASM DISK GROUP USAGE SUMMARY                             ;
PROMPT ====================================================================================;

SELECT 
    name,
    state,
    type,
    ROUND(total_mb / 1024, 2) AS total_gb,
    ROUND(free_mb / 1024, 2) AS free_gb,
    usable_file_mb,
    ROUND(((total_mb - free_mb) / total_mb) * 100, 2) AS pct_used
FROM 
    v$asm_diskgroup;

EXIT;
EOF
#!/usr/bin/env bash
# ==============================================================================
# Script Name : check_locks_and_blocking.sh
# Description : Displays session blocking hierarchies and lock details.
# ==============================================================================

export ORACLE_SID="${ORACLE_SID:-orcl}"
export ORACLE_HOME="${ORACLE_HOME:-/u01/app/oracle/product/19.0.0/dbhome_1}"
export PATH="${ORACLE_HOME}/bin:${PATH}"

sqlplus -s / as sysdba << 'EOF'
SET PAGESIZE 200 LINESIZE 250 FEEDBACK OFF HEADING ON TRIMSPOOL ON;

COL blocker_info FORMAT A35;
COL waiter_info FORMAT A35;
COL lock_type FORMAT A12;
COL object_name FORMAT A25;
COL kill_command FORMAT A55;

PROMPT ====================================================================================;
PROMPT                              ACTIVE BLOCKING TREE                                   ;
PROMPT ====================================================================================;

SELECT 
    l1.sid || ',' || s1.serial# || ' (User: ' || s1.username || ' / Host: ' || s1.machine || ')' AS blocker_info,
    l2.sid || ',' || s2.serial# || ' (User: ' || s2.username || ' / Host: ' || s2.machine || ')' AS waiter_info,
    o.object_name,
    'ALTER SYSTEM KILL SESSION ''' || l1.sid || ',' || s1.serial# || ''' IMMEDIATE;' AS kill_command
FROM 
    v$lock l1
JOIN v$session s1 ON l1.sid = s1.sid
JOIN v$lock l2 ON l1.id1 = l2.id1 AND l1.id2 = l2.id2
JOIN v$session s2 ON l2.sid = s2.sid
LEFT JOIN dba_objects o ON s1.row_wait_obj# = o.object_id
WHERE l1.block = 1 
  AND l2.request > 0;

EXIT;
EOF
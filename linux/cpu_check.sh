#!/bin/bash

# ============================================================
# Oracle DBA Toolkit
# Script  : cpu_check.sh
# Purpose : Check Linux CPU utilization and load
# Usage   : ./cpu_check.sh
# ============================================================

TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
HOSTNAME=$(hostname)

echo "============================================================"
echo "                LINUX CPU HEALTH CHECK"
echo "============================================================"
echo "Host      : $HOSTNAME"
echo "Date      : $TIMESTAMP"
echo "============================================================"
echo

# ------------------------------------------------------------
# 1. CPU Information
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "1. CPU INFORMATION"
echo "------------------------------------------------------------"

if command -v lscpu >/dev/null 2>&1; then
    lscpu | grep -E \
        'Architecture|CPU\(s\)|Thread|Core|Socket|Model name'
else
    echo "lscpu command is not available."
fi

echo

# ------------------------------------------------------------
# 2. Load Average
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "2. SYSTEM LOAD"
echo "------------------------------------------------------------"

uptime

echo

# ------------------------------------------------------------
# 3. CPU Utilization
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "3. CPU UTILIZATION"
echo "------------------------------------------------------------"

if command -v mpstat >/dev/null 2>&1; then
    mpstat 1 1
else
    echo "mpstat is not installed."
    echo "Install the sysstat package to use mpstat."
fi

echo

# ------------------------------------------------------------
# 4. Top CPU Processes
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "4. TOP CPU-CONSUMING PROCESSES"
echo "------------------------------------------------------------"

ps -eo pid,ppid,user,%cpu,%mem,etime,cmd \
    --sort=-%cpu | head -16

echo

# ------------------------------------------------------------
# 5. Top Oracle Processes
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "5. TOP ORACLE PROCESSES"
echo "------------------------------------------------------------"

ps -eo pid,ppid,user,%cpu,%mem,etime,cmd \
    --sort=-%cpu |
    awk 'NR==1 || $3 == "oracle"' |
    head -16

echo

# ------------------------------------------------------------
# 6. CPU Load Per Core
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "6. CPU LOAD PER CORE"
echo "------------------------------------------------------------"

if command -v mpstat >/dev/null 2>&1; then
    mpstat -P ALL 1 1
else
    echo "mpstat is not installed."
fi

echo

# ------------------------------------------------------------
# 7. Load Average vs CPU Count
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "7. LOAD vs CPU COUNT"
echo "------------------------------------------------------------"

CPU_COUNT=$(nproc 2>/dev/null || echo 1)
LOAD_1=$(awk '{print $1}' /proc/loadavg)

LOAD_PER_CPU=$(awk \
    -v load="$LOAD_1" \
    -v cpu="$CPU_COUNT" \
    'BEGIN { printf "%.2f", load / cpu }')

echo "CPU Count        : $CPU_COUNT"
echo "1-Min Load       : $LOAD_1"
echo "Load per CPU     : $LOAD_PER_CPU"

echo

if awk -v value="$LOAD_PER_CPU" 'BEGIN { exit !(value >= 1) }'
then
    echo "WARNING: Load average is at or above CPU capacity."
    echo "Investigate CPU saturation and runnable processes."
else
    echo "INFO: Load average is below CPU capacity."
fi

echo

# ------------------------------------------------------------
# 8. Quick DBA Investigation
# ------------------------------------------------------------

echo "------------------------------------------------------------"
echo "8. DBA INVESTIGATION CHECKLIST"
echo "------------------------------------------------------------"

echo "If CPU usage is high, check:"
echo
echo "  [1] Top CPU-consuming processes"
echo "  [2] Oracle foreground/background processes"
echo "  [3] Active database sessions"
echo "  [4] SQL_ID consuming CPU"
echo "  [5] Top SQL by CPU time"
echo "  [6] Execution plans"
echo "  [7] Parallel execution"
echo "  [8] Recent application workload"
echo "  [9] OS memory pressure"
echo " [10] I/O and storage latency"

echo

echo "============================================================"
echo "              CPU CHECK COMPLETED"
echo "============================================================"


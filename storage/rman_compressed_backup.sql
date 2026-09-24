#!/usr/bin/env bash
# ==============================================================================
# Script Name : rman_compressed_backup.sh
# Description : Executes a compressed RMAN Level 0 backup and purges old logs.
# ==============================================================================

set -euo pipefail

export ORACLE_SID="${ORACLE_SID:-orcl}"
export ORACLE_HOME="${ORACLE_HOME:-/u01/app/oracle/product/19.0.0/dbhome_1}"
export PATH="${ORACLE_HOME}/bin:${PATH}"

BACKUP_DIR="/u02/backup/${ORACLE_SID}"
LOG_FILE="${BACKUP_DIR}/rman_backup_$(date +%Y%m%d_%H%M%S).log"

mkdir -p "${BACKUP_DIR}"

echo "Starting RMAN Backup for SID: ${ORACLE_SID} at $(date)" > "${LOG_FILE}"

rman target / msglog "${LOG_FILE}" append << 'EOF'
RUN {
    # Configure channels and defaults
    CONFIGURE CONTROLFILE AUTOBACKUP ON;
    CONFIGURE CONTROLFILE AUTOBACKUP FORMAT FOR DEVICE TYPE DISK TO '/u02/backup/%d/ctrl_%F';
    
    # Allocate channels
    ALLOCATE CHANNEL c1 DEVICE TYPE DISK;
    ALLOCATE CHANNEL c2 DEVICE TYPE DISK;
    
    # Backup Database with Compression
    BACKUP AS COMPRESSED BACKUPSET 
    INCREMENTAL LEVEL 0 
    DATABASE 
    TAG 'FULL_DB_L0'
    FORMAT '/u02/backup/%d/db_full_%U';
    
    # Backup Archivelogs and Delete Input
    BACKUP AS COMPRESSED BACKUPSET 
    ARCHIVELOG ALL 
    DELETE INPUT 
    TAG 'ARCH_LOGS'
    FORMAT '/u02/backup/%d/arch_%U';
    
    # Maintenance
    CROSSCHECK BACKUP;
    DELETE NOPROMPT EXPIRED BACKUP;
    DELETE NOPROMPT OBSOLETE;
    
    RELEASE CHANNEL c1;
    RELEASE CHANNEL c2;
}
EXIT;
EOF

echo "RMAN Backup finished at $(date)" >> "${LOG_FILE}"
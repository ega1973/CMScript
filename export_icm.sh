#!/bin/bash
################################################################################
# IBM Content Manager Export Script for Linux - Enhanced Version
################################################################################
# Usage:
#   Single itemtype: export_icm.sh <export_name> <base_folder> <itemtype>
#   Multiple itemtypes: export_icm.sh <export_name> <base_folder> <itemtype_list_file>
#
# Examples:
#   ./export_icm.sh 007ClientesFacRI /backup/007_Clientes_Fac_RI "V03206007002D"
#   ./export_icm.sh 007ClientesFacRI /backup/007_Clientes_Fac_RI itemtypes.txt
#
# Features:
#   - Process single or multiple itemtypes from a file
#   - Resume capability: if process stops, automatically resume from last position
#   - Detailed logging of progress and resume information
#   - Automatic detection of last itemid from .etk file for resume
################################################################################

# Function to display usage
usage() {
    echo "Error: $1"
    echo ""
    echo "Usage:"
    echo "  Single itemtype: $0 <export_name> <base_folder> <itemtype>"
    echo "  Multiple itemtypes: $0 <export_name> <base_folder> <itemtype_list_file>"
    echo ""
    echo "Parameters:"
    echo "  export_name         : Name of the export file"
    echo "  base_folder         : Base folder path for export"
    echo "  itemtype            : Item type identifier (in quotes)"
    echo "  itemtype_list_file  : File containing list of itemtypes (one per line)"
    echo ""
    echo "Examples:"
    echo "  $0 007ClientesFacRI /backup/007_Clientes_Fac_RI \"V03206007002D\""
    echo "  $0 007ClientesFacRI /backup/007_Clientes_Fac_RI itemtypes.txt"
    echo ""
    exit 1
}

# Check if required parameters are provided
if [ -z "$1" ]; then
    usage "Export name is required"
fi

if [ -z "$2" ]; then
    usage "Base folder is required"
fi

if [ -z "$3" ]; then
    usage "Itemtype or itemtype list file is required"
fi

# Set parameters
EXPORT_NAME="$1"
BASE_FOLDER="$2"
ITEMTYPE_PARAM="$3"
LOG_FOLDER="${BASE_FOLDER}/log"
PROGRESS_LOG="${LOG_FOLDER}/export_progress.log"
RESUME_LOG="${LOG_FOLDER}/export_resume.log"

# Determine if we're processing a single itemtype or a list
IS_FILE=0
if [ -f "$ITEMTYPE_PARAM" ]; then
    IS_FILE=1
    ITEMTYPE_LIST_FILE="$ITEMTYPE_PARAM"
else
    # Single itemtype - create temporary file
    ITEMTYPE_LIST_FILE="/tmp/itemtypes_temp_$$.txt"
    echo "$ITEMTYPE_PARAM" > "$ITEMTYPE_LIST_FILE"
fi

# Configuration - DB2 and IBM paths
DB2_PROFILE="/home/db2cli1/sqllib/db2profile"
IBM_HOME="/IBM"
DB2_SQLLIB="/IBM/SQLLIB"

# ICM credentials (can be modified as needed)
ICM_USER="icmadmin"
ICM_PASSWORD="Evolucion"

################################################################################
# Create required folders
################################################################################
echo ""
echo "============================================================================"
echo "Creating folder structure..."
echo "============================================================================"
echo "Base folder: ${BASE_FOLDER}"
echo "Log folder: ${LOG_FOLDER}"
echo ""

if [ ! -d "${BASE_FOLDER}" ]; then
    echo "Creating base folder: ${BASE_FOLDER}"
    mkdir -p "${BASE_FOLDER}"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create base folder"
        exit 1
    fi
    echo "Base folder created successfully"
else
    echo "Base folder already exists"
fi

if [ ! -d "${LOG_FOLDER}" ]; then
    echo "Creating log folder: ${LOG_FOLDER}"
    mkdir -p "${LOG_FOLDER}"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create log folder"
        exit 1
    fi
    echo "Log folder created successfully"
else
    echo "Log folder already exists"
fi

################################################################################
# Initialize progress log
################################################################################
if [ ! -f "${PROGRESS_LOG}" ]; then
    echo "Export Progress Log - Created: $(date)" > "${PROGRESS_LOG}"
    echo "============================================================================" >> "${PROGRESS_LOG}"
fi

################################################################################
# Source DB2 profile and set environment
################################################################################
echo ""
echo "============================================================================"
echo "Setting up DB2 environment..."
echo "============================================================================"

if [ -f "${DB2_PROFILE}" ]; then
    echo "Sourcing DB2 profile: ${DB2_PROFILE}"
    . "${DB2_PROFILE}"
    if [ $? -ne 0 ]; then
        echo "Warning: Failed to source DB2 profile"
    else
        echo "DB2 profile sourced successfully"
    fi
else
    echo "Warning: DB2 profile not found at ${DB2_PROFILE}"
    echo "Continuing with current environment..."
fi

################################################################################
# Set CLASSPATH
################################################################################
echo ""
echo "============================================================================"
echo "Setting up CLASSPATH..."
echo "============================================================================"

export CLASSPATH="${CLASSPATH}:${DB2_SQLLIB}/java/common.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/cmbsdk81.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/xsd.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/common.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/ecore.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/ecore.xmi.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/admin/common/sacommon.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/cmbicm81.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/cmbwcm81.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/cmbxmlmap.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/Clio4CM.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/jcache.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/cmbutil81.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/cmbutilicm81.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/icmrm81.jar"
export CLASSPATH="${CLASSPATH}:c:/IBM/lib/xerces.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/cmblog4j81.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/log4j-1.2.8.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/cmbsdk81.jar"
export CLASSPATH="${CLASSPATH}:${IBM_HOME}/lib/cmbwas81.jar"

echo "CLASSPATH configured successfully"
echo ""

################################################################################
# Function to get last itemid from ETK file
################################################################################
get_last_itemid() {
    local etk_file="${BASE_FOLDER}/${EXPORT_NAME}.etk"
    local last_itemid=""

    if [ -f "$etk_file" ]; then
        # Get the last line and extract itemid
        local last_line=$(tail -n 1 "$etk_file")
        # Extract itemid from the last line (format: <itemid>...</itemid> or similar)
        last_itemid=$(echo "$last_line" | grep -oP '(?<=<itemid>)[^<]+' | tail -n 1)

        # If the previous method didn't work, try alternative extraction
        if [ -z "$last_itemid" ]; then
            last_itemid=$(echo "$last_line" | sed -n 's/.*<itemid>\([^<]*\)<\/itemid>.*/\1/p')
        fi
    fi

    echo "$last_itemid"
}

################################################################################
# Process each itemtype
################################################################################
echo ""
echo "============================================================================"
echo "Starting IBM Content Manager Export..."
echo "============================================================================"
echo "Export Name: ${EXPORT_NAME}"
echo "Export Folder: ${BASE_FOLDER}"
echo "Log Folder: ${LOG_FOLDER}"
echo "User: ${ICM_USER}"
echo "Itemtype List File: ${ITEMTYPE_LIST_FILE}"
echo ""

TOTAL_ERRORS=0
ITEMTYPE_COUNT=0

# Read itemtypes from file
while IFS= read -r CURRENT_ITEMTYPE || [ -n "$CURRENT_ITEMTYPE" ]; do
    # Skip empty lines and comments
    if [ -z "$CURRENT_ITEMTYPE" ] || [[ "$CURRENT_ITEMTYPE" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    # Trim whitespace
    CURRENT_ITEMTYPE=$(echo "$CURRENT_ITEMTYPE" | xargs)

    ITEMTYPE_COUNT=$((ITEMTYPE_COUNT + 1))

    echo ""
    echo "========================================================================"
    echo "Processing Itemtype #${ITEMTYPE_COUNT}: ${CURRENT_ITEMTYPE}"
    echo "Started: $(date)"
    echo "========================================================================"

    # Log progress
    echo "[$(date)] Processing itemtype: ${CURRENT_ITEMTYPE}" >> "${PROGRESS_LOG}"

    # Check if this itemtype was already completed
    if grep -q "COMPLETED: ${CURRENT_ITEMTYPE}" "${PROGRESS_LOG}" 2>/dev/null; then
        echo ""
        echo "INFO: Itemtype ${CURRENT_ITEMTYPE} was already completed. Skipping..."
        echo "[$(date)] SKIPPED (already completed): ${CURRENT_ITEMTYPE}" >> "${PROGRESS_LOG}"
        continue
    fi

    # Check for resume point
    RESUME_ITEMID=""
    if [ -f "${RESUME_LOG}" ]; then
        RESUME_ITEMID=$(grep "^${CURRENT_ITEMTYPE}|" "${RESUME_LOG}" | cut -d'|' -f2)
    fi

    # Build export command
    EXPORT_CMD="java TExportManagerICM -u ${ICM_USER} -p ${ICM_PASSWORD} -m ${EXPORT_NAME} -l \"${LOG_FOLDER}\" -a \"${CURRENT_ITEMTYPE}\" -v \"${BASE_FOLDER}\""

    # Add resume parameters if we have a resume point
    if [ -n "$RESUME_ITEMID" ]; then
        echo ""
        echo "INFO: Resuming from ItemID: ${RESUME_ITEMID}"
        echo "[$(date)] RESUMING from ItemID: ${RESUME_ITEMID}" >> "${PROGRESS_LOG}"
        EXPORT_CMD="${EXPORT_CMD} -r -s \"${RESUME_ITEMID}\""
    fi

    echo ""
    echo "Command: ${EXPORT_CMD}"
    echo ""

    # Execute export
    eval ${EXPORT_CMD}
    EXPORT_STATUS=$?

    if [ ${EXPORT_STATUS} -ne 0 ]; then
        echo ""
        echo "===================================================================="
        echo "ERROR: Export failed for itemtype ${CURRENT_ITEMTYPE} with error code ${EXPORT_STATUS}"
        echo "===================================================================="
        echo "[$(date)] FAILED: ${CURRENT_ITEMTYPE} - Error code: ${EXPORT_STATUS}" >> "${PROGRESS_LOG}"

        # Get last itemid from ETK file for resume
        LAST_ITEMID=$(get_last_itemid)
        if [ -n "$LAST_ITEMID" ]; then
            echo "${CURRENT_ITEMTYPE}|${LAST_ITEMID}" > "${RESUME_LOG}"
            echo ""
            echo "RESUME INFO: Last exported ItemID: ${LAST_ITEMID}"
            echo "RESUME INFO: To resume, run the script again"
            echo "[$(date)] Last ItemID before failure: ${LAST_ITEMID}" >> "${PROGRESS_LOG}"
        fi

        TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
        # Continue with next itemtype instead of exiting
        continue
    else
        echo ""
        echo "===================================================================="
        echo "SUCCESS: Export completed for itemtype ${CURRENT_ITEMTYPE}"
        echo "Completed: $(date)"
        echo "===================================================================="
        echo "[$(date)] COMPLETED: ${CURRENT_ITEMTYPE}" >> "${PROGRESS_LOG}"

        # Remove resume point if exists
        if [ -f "${RESUME_LOG}" ]; then
            grep -v "^${CURRENT_ITEMTYPE}|" "${RESUME_LOG}" > "${RESUME_LOG}.tmp" 2>/dev/null
            mv "${RESUME_LOG}.tmp" "${RESUME_LOG}" 2>/dev/null
        fi
    fi

done < "${ITEMTYPE_LIST_FILE}"

################################################################################
# Summary
################################################################################
echo ""
echo "============================================================================"
echo "Export Process Summary"
echo "============================================================================"
echo "Total itemtypes processed: ${ITEMTYPE_COUNT}"
echo "Total errors: ${TOTAL_ERRORS}"
echo ""

################################################################################
# Parse ETK log file for package information
################################################################################
echo "============================================================================"
echo "Analyzing ETK log file..."
echo "============================================================================"
echo ""

# Find the ETK file in the log folder
ETK_FILE=$(find "${LOG_FOLDER}" -name "*.etk" -type f | head -n 1)

if [ -z "${ETK_FILE}" ]; then
    echo "Warning: No ETK file found in ${LOG_FOLDER}"
    echo "Skipping package analysis"
else
    echo "Found ETK file: ${ETK_FILE}"
    echo ""

    # Create temporary files for processing
    TEMP_COMPLETED=$(mktemp)
    TEMP_STARTED=$(mktemp)

    # Extract package information
    grep "Package Completed:" "${ETK_FILE}" > "${TEMP_COMPLETED}" 2>/dev/null || true
    grep "Package Started:" "${ETK_FILE}" > "${TEMP_STARTED}" 2>/dev/null || true

    COMPLETED_COUNT=$(wc -l < "${TEMP_COMPLETED}")
    STARTED_COUNT=$(wc -l < "${TEMP_STARTED}")

    echo "Package Summary:"
    echo "  - Packages Started: ${STARTED_COUNT}"
    echo "  - Packages Completed: ${COMPLETED_COUNT}"
    echo ""

    # Check for incomplete packages
    if [ ${STARTED_COUNT} -gt ${COMPLETED_COUNT} ]; then
        INCOMPLETE=$((STARTED_COUNT - COMPLETED_COUNT))
        echo "WARNING: Found ${INCOMPLETE} incomplete package(s)"
        echo ""

        # Extract the last started package number
        LAST_STARTED=$(tail -n 1 "${TEMP_STARTED}" | sed -n 's/.*Package Started:[[:space:]]*\([0-9]*\).*/\1/p')
        echo "Last package started: ${LAST_STARTED}"
        echo "This package did not complete (possible error or interruption)"
        echo ""
    fi

    # Display last completed package and its last item ID
    if [ ${COMPLETED_COUNT} -gt 0 ]; then
        echo "Last Completed Package Details:"
        LAST_COMPLETED_LINE=$(tail -n 1 "${TEMP_COMPLETED}")

        # Extract package number
        PACKAGE_NUM=$(echo "${LAST_COMPLETED_LINE}" | sed -n 's/.*Package Completed:[[:space:]]*\([0-9]*\).*/\1/p')

        # Extract the last item ID (the last value before the closing bracket ']')
        # Pattern: Extract content between quotes after the last comma before ']'
        LAST_ITEM_ID=$(echo "${LAST_COMPLETED_LINE}" | sed -n "s/.*,\s*'\([^']*\)'\s*\].*/\1/p")

        # Extract the path if present
        PACKAGE_PATH=$(echo "${LAST_COMPLETED_LINE}" | sed -n 's/.*\]\s*\(.*\)/\1/p')

        echo "  - Package Number: ${PACKAGE_NUM}"
        echo "  - Last Item ID: ${LAST_ITEM_ID}"
        if [ -n "${PACKAGE_PATH}" ]; then
            echo "  - Package Path: ${PACKAGE_PATH}"
        fi
        echo ""

        # Display all completed packages with their last item IDs
        echo "All Completed Packages:"
        while IFS= read -r line; do
            PKG_NUM=$(echo "${line}" | sed -n 's/.*Package Completed:[[:space:]]*\([0-9]*\).*/\1/p')
            ITEM_ID=$(echo "${line}" | sed -n "s/.*,\s*'\([^']*\)'\s*\].*/\1/p")
            PKG_PATH=$(echo "${line}" | sed -n 's/.*\]\s*\(.*\)/\1/p')

            if [ -n "${PKG_NUM}" ] && [ -n "${ITEM_ID}" ]; then
                echo "  Package ${PKG_NUM}: Last Item = ${ITEM_ID}"
                if [ -n "${PKG_PATH}" ]; then
                    echo "    Path: ${PKG_PATH}"
                fi
            fi
        done < "${TEMP_COMPLETED}"
        echo ""
    fi

    # Cleanup temporary files
    rm -f "${TEMP_COMPLETED}" "${TEMP_STARTED}"
fi

echo "============================================================================"
echo "Analysis Complete"
echo "============================================================================"
echo ""
echo "Check logs at: ${LOG_FOLDER}"
echo "  - Progress log: ${PROGRESS_LOG}"
echo "  - Resume log: ${RESUME_LOG}"
echo "Export files at: ${BASE_FOLDER}"
echo ""

# Clean up temp file if created
if [ ${IS_FILE} -eq 0 ]; then
    rm -f "${ITEMTYPE_LIST_FILE}"
fi

if [ ${TOTAL_ERRORS} -gt 0 ]; then
    echo "WARNING: ${TOTAL_ERRORS} itemtype(s) failed. Check logs for details."
    echo "[$(date)] Export finished with ${TOTAL_ERRORS} errors" >> "${PROGRESS_LOG}"
    exit 1
else
    echo "All exports completed successfully!"
    echo "[$(date)] All exports completed successfully" >> "${PROGRESS_LOG}"
    exit 0
fi

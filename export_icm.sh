#!/bin/bash
################################################################################
# IBM Content Manager Export Script for Linux - Enhanced Version
################################################################################
# Usage:
#   Single itemtype: export_icm.sh <export_name> <base_folder> <itemtype>
#   Multiple itemtypes: export_icm.sh <itemtype_list_file>
#
# Examples:
#   ./export_icm.sh 007ClientesFacRI /backup/007_Clientes_Fac_RI "V03206007002D"
#   ./export_icm.sh itemtypes.txt
#
# itemtypes.txt format (space or tab separated):
#   <export_name> <base_folder> <itemtype>
#   007ClientesFacRI /backup/007_Clientes_Fac_RI V03206007002D
#   007ClientesConstruya /backup/007_Clientes_Construya V03206007003D
#
# Features:
#   - Process single or multiple itemtypes from a file
#   - Each itemtype can have its own export name and base folder
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
    echo "  Multiple itemtypes: $0 <itemtype_list_file>"
    echo ""
    echo "Parameters:"
    echo "  export_name         : Name of the export file"
    echo "  base_folder         : Base folder path for export"
    echo "  itemtype            : Item type identifier (in quotes)"
    echo "  itemtype_list_file  : File containing itemtype configurations"
    echo ""
    echo "itemtypes.txt format (space or tab separated):"
    echo "  <export_name> <base_folder> <itemtype>"
    echo "  007ClientesFacRI /backup/007_Clientes_Fac_RI V03206007002D"
    echo "  007ClientesConstruya /backup/007_Clientes_Construya V03206007003D"
    echo ""
    echo "Examples:"
    echo "  $0 007ClientesFacRI /backup/007_Clientes_Fac_RI \"V03206007002D\""
    echo "  $0 itemtypes.txt"
    echo ""
    exit 1
}

# Check if required parameters are provided
if [ -z "$1" ]; then
    usage "At least one parameter is required"
fi

# Determine if we're processing a single itemtype or a list
IS_FILE=0
IS_MULTI_MODE=0

if [ -f "$1" ]; then
    # File mode: itemtypes.txt with three columns
    IS_FILE=1
    IS_MULTI_MODE=1
    ITEMTYPE_LIST_FILE="$1"
elif [ -n "$1" ] && [ -n "$2" ] && [ -n "$3" ]; then
    # Single itemtype mode: export_name base_folder itemtype
    IS_FILE=0
    IS_MULTI_MODE=0
    EXPORT_NAME="$1"
    BASE_FOLDER="$2"
    ITEMTYPE_PARAM="$3"
    LOG_FOLDER="${BASE_FOLDER}/log"
    PROGRESS_LOG="${LOG_FOLDER}/export_progress.log"
    RESUME_LOG="${LOG_FOLDER}/export_resume.log"
    # Create temporary file with three columns
    ITEMTYPE_LIST_FILE="/tmp/itemtypes_temp_$$.txt"
    echo "$EXPORT_NAME $BASE_FOLDER $ITEMTYPE_PARAM" > "$ITEMTYPE_LIST_FILE"
else
    usage "Invalid parameters. Provide either <itemtype_list_file> or <export_name> <base_folder> <itemtype>"
fi

# Configuration - DB2 and IBM paths
DB2_PROFILE="/home/db2cli1/sqllib/db2profile"
IBM_HOME="/IBM"
DB2_SQLLIB="/IBM/SQLLIB"

# ICM credentials (can be modified as needed)
ICM_USER="icmadmin"
ICM_PASSWORD="Evolucion"

################################################################################
# Create required folders (only for single itemtype mode)
################################################################################
if [ ${IS_MULTI_MODE} -eq 0 ]; then
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
    local export_name="$1"
    local base_folder="$2"
    local etk_file="${base_folder}/${export_name}.etk"
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
echo "User: ${ICM_USER}"
echo "Itemtype List File: ${ITEMTYPE_LIST_FILE}"
echo ""

TOTAL_ERRORS=0
ITEMTYPE_COUNT=0

# Read itemtypes from file (format: export_name base_folder itemtype)
while IFS=$' \t' read -r CURRENT_EXPORT_NAME CURRENT_BASE_FOLDER CURRENT_ITEMTYPE EXTRA || [ -n "$CURRENT_EXPORT_NAME" ]; do
    # Skip empty lines and comments
    if [ -z "$CURRENT_EXPORT_NAME" ] || [[ "$CURRENT_EXPORT_NAME" =~ ^[[:space:]]*# ]]; then
        continue
    fi

    # Validate that we have all three columns
    if [ -z "$CURRENT_EXPORT_NAME" ] || [ -z "$CURRENT_BASE_FOLDER" ] || [ -z "$CURRENT_ITEMTYPE" ]; then
        echo "WARNING: Skipping invalid line (missing columns): $CURRENT_EXPORT_NAME $CURRENT_BASE_FOLDER $CURRENT_ITEMTYPE"
        continue
    fi

    # Set up folders for this itemtype
    CURRENT_LOG_FOLDER="${CURRENT_BASE_FOLDER}/log"
    CURRENT_PROGRESS_LOG="${CURRENT_LOG_FOLDER}/export_progress.log"
    CURRENT_RESUME_LOG="${CURRENT_LOG_FOLDER}/export_resume.log"

    # Create folders for this itemtype
    if [ ! -d "${CURRENT_BASE_FOLDER}" ]; then
        mkdir -p "${CURRENT_BASE_FOLDER}"
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to create base folder: ${CURRENT_BASE_FOLDER}"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
            continue
        fi
    fi

    if [ ! -d "${CURRENT_LOG_FOLDER}" ]; then
        mkdir -p "${CURRENT_LOG_FOLDER}"
        if [ $? -ne 0 ]; then
            echo "ERROR: Failed to create log folder: ${CURRENT_LOG_FOLDER}"
            TOTAL_ERRORS=$((TOTAL_ERRORS + 1))
            continue
        fi
    fi

    # Initialize progress log if needed
    if [ ! -f "${CURRENT_PROGRESS_LOG}" ]; then
        echo "Export Progress Log - Created: $(date)" > "${CURRENT_PROGRESS_LOG}"
        echo "============================================================================" >> "${CURRENT_PROGRESS_LOG}"
    fi

    ITEMTYPE_COUNT=$((ITEMTYPE_COUNT + 1))

    echo ""
    echo "========================================================================"
    echo "Processing Itemtype #${ITEMTYPE_COUNT}"
    echo "Export Name: ${CURRENT_EXPORT_NAME}"
    echo "Base Folder: ${CURRENT_BASE_FOLDER}"
    echo "Itemtype: ${CURRENT_ITEMTYPE}"
    echo "Started: $(date)"
    echo "========================================================================"

    # Log progress
    echo "[$(date)] Processing itemtype: ${CURRENT_ITEMTYPE}" >> "${CURRENT_PROGRESS_LOG}"

    # Check if this itemtype was already completed
    if grep -q "COMPLETED: ${CURRENT_ITEMTYPE}" "${CURRENT_PROGRESS_LOG}" 2>/dev/null; then
        echo ""
        echo "INFO: Itemtype ${CURRENT_ITEMTYPE} was already completed. Skipping..."
        echo "[$(date)] SKIPPED (already completed): ${CURRENT_ITEMTYPE}" >> "${CURRENT_PROGRESS_LOG}"
        continue
    fi

    # Check for resume point
    RESUME_ITEMID=""
    if [ -f "${CURRENT_RESUME_LOG}" ]; then
        RESUME_ITEMID=$(grep "^${CURRENT_ITEMTYPE}|" "${CURRENT_RESUME_LOG}" | cut -d'|' -f2)
    fi

    # Build export command
    EXPORT_CMD="java TExportManagerICM -u ${ICM_USER} -p ${ICM_PASSWORD} -m ${CURRENT_EXPORT_NAME} -l \"${CURRENT_LOG_FOLDER}\" -a \"${CURRENT_ITEMTYPE}\" -v \"${CURRENT_BASE_FOLDER}\""

    # Add resume parameters if we have a resume point
    if [ -n "$RESUME_ITEMID" ]; then
        echo ""
        echo "INFO: Resuming from ItemID: ${RESUME_ITEMID}"
        echo "[$(date)] RESUMING from ItemID: ${RESUME_ITEMID}" >> "${CURRENT_PROGRESS_LOG}"
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
        echo "[$(date)] FAILED: ${CURRENT_ITEMTYPE} - Error code: ${EXPORT_STATUS}" >> "${CURRENT_PROGRESS_LOG}"

        # Get last itemid from ETK file for resume
        LAST_ITEMID=$(get_last_itemid "${CURRENT_EXPORT_NAME}" "${CURRENT_BASE_FOLDER}")
        if [ -n "$LAST_ITEMID" ]; then
            echo "${CURRENT_ITEMTYPE}|${LAST_ITEMID}" > "${CURRENT_RESUME_LOG}"
            echo ""
            echo "RESUME INFO: Last exported ItemID: ${LAST_ITEMID}"
            echo "RESUME INFO: To resume, run the script again"
            echo "[$(date)] Last ItemID before failure: ${LAST_ITEMID}" >> "${CURRENT_PROGRESS_LOG}"
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
        echo "[$(date)] COMPLETED: ${CURRENT_ITEMTYPE}" >> "${CURRENT_PROGRESS_LOG}"

        # Remove resume point if exists
        if [ -f "${CURRENT_RESUME_LOG}" ]; then
            grep -v "^${CURRENT_ITEMTYPE}|" "${CURRENT_RESUME_LOG}" > "${CURRENT_RESUME_LOG}.tmp" 2>/dev/null
            mv "${CURRENT_RESUME_LOG}.tmp" "${CURRENT_RESUME_LOG}" 2>/dev/null
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
# Parse ETK log file for package information (only for single itemtype mode)
################################################################################
if [ ${IS_MULTI_MODE} -eq 0 ]; then
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
else
    echo "============================================================================"
    echo "Multi-itemtype mode complete"
    echo "============================================================================"
    echo ""
    echo "Each itemtype has its own log folder. Check individual folders for details."
    echo ""
fi

# Clean up temp file if created
if [ ${IS_FILE} -eq 0 ]; then
    rm -f "${ITEMTYPE_LIST_FILE}"
fi

if [ ${TOTAL_ERRORS} -gt 0 ]; then
    echo "WARNING: ${TOTAL_ERRORS} itemtype(s) failed. Check logs for details."
    exit 1
else
    echo "All exports completed successfully!"
    exit 0
fi

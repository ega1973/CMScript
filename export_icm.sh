#!/bin/bash
################################################################################
# IBM Content Manager Export Script for Linux
################################################################################
# Usage: export_icm.sh <export_name> <base_folder> <itemtype>
# Example: ./export_icm.sh 007ClientesFacRI /backup/007_Clientes_Fac_RI "V03206007002D"
################################################################################

# Function to display usage
usage() {
    echo "Error: $1"
    echo ""
    echo "Usage: $0 <export_name> <base_folder> <itemtype>"
    echo ""
    echo "Parameters:"
    echo "  export_name  : Name of the export file"
    echo "  base_folder  : Base folder path for export"
    echo "  itemtype     : Item type identifier (in quotes)"
    echo ""
    echo "Example:"
    echo "  $0 007ClientesFacRI /backup/007_Clientes_Fac_RI \"V03206007002D\""
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
    usage "Itemtype is required"
fi

# Set parameters
EXPORT_NAME="$1"
BASE_FOLDER="$2"
ITEMTYPE="$3"
LOG_FOLDER="${BASE_FOLDER}/log"

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
# Execute export
################################################################################
echo "============================================================================"
echo "Starting IBM Content Manager Export..."
echo "============================================================================"
echo "Export Name: ${EXPORT_NAME}"
echo "Itemtype: ${ITEMTYPE}"
echo "Export Folder: ${BASE_FOLDER}"
echo "Log Folder: ${LOG_FOLDER}"
echo "User: ${ICM_USER}"
echo ""
echo "Command: java TExportManagerICM -u ${ICM_USER} -p ${ICM_PASSWORD} -m ${EXPORT_NAME} -l ${LOG_FOLDER} -a \"${ITEMTYPE}\" -v ${BASE_FOLDER}"
echo ""
echo "============================================================================"

java TExportManagerICM \
    -u "${ICM_USER}" \
    -p "${ICM_PASSWORD}" \
    -m "${EXPORT_NAME}" \
    -l "${LOG_FOLDER}" \
    -a "${ITEMTYPE}" \
    -v "${BASE_FOLDER}"

EXPORT_STATUS=$?

if [ ${EXPORT_STATUS} -ne 0 ]; then
    echo ""
    echo "============================================================================"
    echo "ERROR: Export failed with error code ${EXPORT_STATUS}"
    echo "============================================================================"
    exit ${EXPORT_STATUS}
fi

echo ""
echo "============================================================================"
echo "Export completed successfully"
echo "============================================================================"
echo ""
echo "Check logs at: ${LOG_FOLDER}"
echo "Export files at: ${BASE_FOLDER}"
echo ""

exit 0

# IBM Content Manager Export Scripts

This repository contains automation scripts for exporting IBM Content Manager item types on both Windows and Linux platforms.

## Scripts

- **Export-ICM.ps1** - PowerShell script (Windows)
- **export_icm.sh** - Linux shell script

## Features

Both scripts automatically:
1. Create the required folder structure (base folder and log subfolder)
2. Configure the CLASSPATH with all necessary IBM DB2 Content Manager libraries
3. Execute the TExportManagerICM Java tool with specified parameters
4. Parse ETK log files to analyze package completion status
5. Extract and display last item IDs from completed packages
6. Identify incomplete packages (started but not completed)
7. Provide detailed output and error handling

## Prerequisites

### Windows
- PowerShell 5.1 or later
- Java Development Kit (JDK) 1.6 or later
- IBM Content Manager client libraries
- DB2 client installed
- See [README-PowerShell.md](README-PowerShell.md) for complete PowerShell documentation

### Linux
- Java installed and available in PATH
- IBM DB2 Content Manager libraries at `/IBM/lib`
- DB2 profile at `/home/db2cli1/sqllib/db2profile`
- Appropriate permissions to create directories in the target location

## Usage

### Windows (PowerShell)

```powershell
.\Export-ICM.ps1 -ExportName "007ClientesConstruya" -BaseFolder "G:\007_Clientes_Construya" -ItemType "V03206007003D"
```

**Example:**
```powershell
.\Export-ICM.ps1 -ExportName "007ClientesConstruya" -BaseFolder "G:\007_Clientes_Construya" -ItemType "V03206007003D"
```

See [README-PowerShell.md](README-PowerShell.md) for complete PowerShell documentation including multiple itemtypes and resume functionality.

### Linux

```bash
./export_icm.sh <export_name> <base_folder> <itemtype>
```

**Example:**
```bash
./export_icm.sh 007ClientesFacRI /backup/007_Clientes_Fac_RI "V03206007002D"
```

## Parameters

| Parameter | Description | Example |
|-----------|-------------|---------|
| export_name | Name of the export file (used with -m parameter) | 007ClientesConstruya |
| base_folder | Base directory where exports will be stored | G:\007_Clientes_Construya (Windows)<br>/backup/007_Clientes_Fac_RI (Linux) |
| itemtype | Item type identifier to export (must be in quotes) | "V03206007003D" |

## What the Scripts Do

1. **Validate Parameters**: Ensure all required parameters are provided
2. **Create Folders**:
   - Create base folder if it doesn't exist
   - Create log subfolder inside base folder
3. **Configure Environment**:
   - Set CLASSPATH with all IBM DB2 Content Manager JAR files
   - Source DB2 profile (Linux only)
4. **Execute Export**: Run the TExportManagerICM Java tool with:
   - User credentials (from environment variables)
   - Export name
   - Log folder path
   - Item type
   - Export destination folder
5. **Report Results**: Display success/failure status and file locations

## Required Credentials

The scripts require ICM credentials to be set as environment variables before running:
- **ICM_USER**: IBM Content Manager username
- **ICM_PASSWORD**: IBM Content Manager password

**Example (Windows PowerShell):**
```powershell
$env:ICM_USER = "your_username"
$env:ICM_PASSWORD = "your_password"
.\Export-ICM.ps1 -ExportName "007ClientesConstruya" -BaseFolder "G:\007_Clientes_Construya" -ItemType "V03206007003D"
```

**Example (Linux):**
```bash
export ICM_USER="your_username"
export ICM_PASSWORD="your_password"
./export_icm.sh 007ClientesFacRI /backup/007_Clientes_Fac_RI "V03206007002D"
```

## Output

### Successful Export
- Export files will be created in the base folder
- Log files will be created in the log subfolder
- ETK log file analysis showing:
  - Number of packages started and completed
  - Warning if packages were started but not completed
  - Last completed package number and its last item ID
  - List of all completed packages with their last item IDs
  - Package paths (if available)
- Success message with paths displayed

### Failed Export
- Error message with error code displayed
- Check log files for detailed error information

## ETK Log File Analysis

After the export completes successfully, both scripts automatically analyze the ETK log file generated in the log folder. The analysis provides:

### Package Status Information
- **Packages Started**: Total number of packages that began processing
- **Packages Completed**: Total number of packages that finished successfully
- **Incomplete Packages**: Warning if any packages started but didn't complete (indicating errors or interruption)

### Item ID Extraction
For each completed package, the scripts extract:
- **Package Number**: The sequential package number
- **Last Item ID**: The last item ID processed in that package (e.g., 'A1001001A13C01A83636I46210')
- **Package Path**: The file system path where the package was stored (if available)

### Example Output
```
============================================================================
Analyzing ETK log file...
============================================================================

Found ETK file: G:\007_Clientes_Fac_RI\log\export_007ClientesFacRI.etk

Package Summary:
  - Packages Started: 833
  - Packages Completed: 832

WARNING: Found 1 incomplete package(s)

Last package started: 833
This package did not complete (possible error or interruption)

Last Completed Package Details:
  - Package Number: 832
  - Last Item ID: A1001001A13C01A83636I46210
  - Package Path: G:\007_Clientes_Fac_RI\masterPackage\package832

All Completed Packages:
  Package 1: Last Item = A1001001A13C01A82500G59521
    Path: G:\007_Clientes_Fac_RI\masterPackage\package1
  Package 2: Last Item = A1001001A13C01A82501G59522
    Path: G:\007_Clientes_Fac_RI\masterPackage\package2
  ...
  Package 832: Last Item = A1001001A13C01A83636I46210
    Path: G:\007_Clientes_Fac_RI\masterPackage\package832
```

### Understanding the Results
- If "Packages Started" equals "Packages Completed", all packages finished successfully
- If there are incomplete packages, check the ETK log file for error messages
- The last item ID can be used to resume exports or verify data integrity
- Package paths show where exported data is stored

## Customization

### Changing Installation Paths

**Windows (PowerShell):**
See [README-PowerShell.md](README-PowerShell.md) for PowerShell configuration options.

**Linux (export_icm.sh):**
```bash
DB2_PROFILE="/home/db2cli1/sqllib/db2profile"
IBM_HOME="/IBM"
DB2_SQLLIB="/IBM/SQLLIB"
```

### Setting Credentials

Credentials must be set as environment variables before running the scripts.

**Windows (PowerShell):**
```powershell
$env:ICM_USER = "your_username"
$env:ICM_PASSWORD = "your_password"
```

**Linux:**
```bash
export ICM_USER="your_username"
export ICM_PASSWORD="your_password"
```

**Note:** Do not hardcode credentials in the scripts for security reasons.

## Error Handling

Both scripts include:
- Parameter validation
- Folder creation error checking
- Export status verification
- Detailed error messages with exit codes
- **JVM Memory Management**: Automatic allocation of 2GB heap space to prevent OutOfMemoryError with large files

### Handling Large Files (170MB+)

The scripts are configured to handle large files by default with JVM memory parameters:
- **Maximum Heap Size**: 2048m (2GB) - handles files up to 200MB
- **Initial Heap Size**: 512m - for optimal performance

If you need to export larger files, you can adjust the memory settings at the top of each script. See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed instructions.

## Notes

- The itemtype parameter must be enclosed in quotes if it contains special characters
- Ensure you have write permissions to the target folder
- Log files are essential for troubleshooting - always check them if exports fail
- The scripts will NOT overwrite existing folders; they will use them if they already exist

## Example Use Cases

### Windows (PowerShell) Examples

```powershell
# Export client documents
.\Export-ICM.ps1 -ExportName "007ClientesConstruya" -BaseFolder "G:\007_Clientes_Construya" -ItemType "V03206007003D"

# Export invoice documents
.\Export-ICM.ps1 -ExportName "007ClientesFacRI" -BaseFolder "G:\007_Clientes_Fac_RI" -ItemType "V03206007002D"
```

### Linux Examples

```bash
# Export client documents
./export_icm.sh 007ClientesConstruya /backup/007_Clientes_Construya "V03206007003D"

# Export invoice documents
./export_icm.sh 007ClientesFacRI /backup/007_Clientes_Fac_RI "V03206007002D"
```

## Troubleshooting

For detailed troubleshooting information, see **[TROUBLESHOOTING.md](TROUBLESHOOTING.md)**.

### Common Issues

1. **OutOfMemoryError with large files (170MB+)**
   - **Fixed**: Scripts now automatically allocate 2GB heap space
   - For larger files, adjust `JAVA_MAX_HEAP` and `JAVA_MIN_HEAP` variables in the script
   - See [TROUBLESHOOTING.md](TROUBLESHOOTING.md#java-outofmemoryerror-with-large-files) for details

2. **Java not found**
   - Windows: Verify JAVA_HOME path in script
   - Linux: Ensure java is in PATH

3. **CLASSPATH errors**
   - Verify all IBM DB2 CM library paths exist
   - Check that all JAR files are present

4. **Permission denied**
   - Windows: Run as Administrator if accessing system folders
   - Linux: Ensure script is executable (`chmod +x export_icm.sh`)

5. **DB2 connection errors**
   - Verify DB2 is running
   - Check credentials are correct
   - Review DB2 profile sourcing (Linux)

6. **Export fails**
   - Check log files in the log subfolder
   - Verify itemtype exists in the system
   - Ensure sufficient disk space

6. **ETK file analysis issues**
   - If no ETK file is found, the export may have failed before creating logs
   - Incomplete packages indicate the export was interrupted or encountered errors
   - Check the ETK file directly for detailed error messages
   - The ETK file is a plain text file that can be opened with any text editor

## Support

For issues or questions:
1. Check the log files in the log subfolder
2. Verify all paths and credentials in the script
3. Ensure IBM Content Manager is properly installed and configured

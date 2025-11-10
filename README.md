# IBM Content Manager Export Scripts

Enhanced export automation scripts for IBM Content Manager, supporting both Windows and Linux platforms.

## Features

- **Single or Multiple Itemtype Export**: Process one itemtype or a list from a file
- **Automatic Resume**: If the process stops, automatically resume from the last position
- **Progress Tracking**: Detailed logging of all export operations
- **Resume from ItemID**: Automatic detection of last exported ItemID from .etk file
- **Error Recovery**: Continue processing remaining itemtypes even if one fails
- **Skip Completed**: Automatically skip itemtypes that were already successfully exported

## Files

- `export_icm.bat` - Windows batch script
- `export_icm.sh` - Linux shell script
- `itemtypes_example.txt` - Example itemtype list file

## Prerequisites

### Windows
- Java Development Kit (JDK) 1.6 or later
- IBM Content Manager client libraries
- DB2 client installed

### Linux
- Java Runtime Environment (JRE)
- IBM Content Manager client libraries
- DB2 client with profile configured

## Configuration

Before running the scripts, you may need to modify the following configuration variables:

### Windows (`export_icm.bat`)
```batch
SET JAVA_HOME=E:\jdk1.6.0_26
SET DB2_HOME=E:\IBM\db2cmv8
SET ICM_USER=icmadmin
SET ICM_PASSWORD=Evolucion
```

### Linux (`export_icm.sh`)
```bash
DB2_PROFILE="/home/db2cli1/sqllib/db2profile"
IBM_HOME="/IBM"
ICM_USER="icmadmin"
ICM_PASSWORD="Evolucion"
```

## Usage

### Single Itemtype Export

**Windows:**
```cmd
export_icm.bat <export_name> <base_folder> "<itemtype>"
```

**Linux:**
```bash
./export_icm.sh <export_name> <base_folder> "<itemtype>"
```

**Example:**
```cmd
REM Windows
export_icm.bat 007ClientesFacRI G:\007_Clientes_Fac_RI "V03206007002D"

# Linux
./export_icm.sh 007ClientesFacRI /backup/007_Clientes_Fac_RI "V03206007002D"
```

### Multiple Itemtypes Export

**Windows:**
```cmd
export_icm.bat <export_name> <base_folder> <itemtype_list_file>
```

**Linux:**
```bash
./export_icm.sh <export_name> <base_folder> <itemtype_list_file>
```

**Example:**
```cmd
REM Windows
export_icm.bat 007ClientesFacRI G:\007_Clientes_Fac_RI itemtypes.txt

# Linux
./export_icm.sh 007ClientesFacRI /backup/007_Clientes_Fac_RI itemtypes.txt
```

## Itemtype List File Format

Create a text file with one itemtype per line:

```
# This is a comment
V03206007002D
V03206007003D
A1001001A13D05B53912E71640

# Another comment
ITEMTYPE4
ITEMTYPE5
```

- Lines starting with `#` are comments and will be ignored
- Empty lines are ignored
- Whitespace is automatically trimmed

See `itemtypes_example.txt` for a template.

## Resume Functionality

### How It Works

1. **Progress Tracking**: The script logs each itemtype as it's processed
2. **Automatic Detection**: If a process fails or is interrupted, the script detects the last exported ItemID from the .etk file
3. **Resume Log**: The script creates a `export_resume.log` file with the resume point
4. **Automatic Resume**: When you run the script again, it automatically resumes from where it stopped

### Resume Process

If an export fails or is interrupted:

1. Check the logs in `<base_folder>/log/export_progress.log`
2. The last exported ItemID is automatically saved to `export_resume.log`
3. Simply run the same command again - the script will automatically:
   - Skip completed itemtypes
   - Resume failed itemtypes from the last ItemID using `-r -s` parameters

**Example Resume Command (automatically executed):**
```bash
java TExportManagerICM -u icmadmin -p Evolucion \
  -m 007ClientesFacRI \
  -l /backup/007_Clientes_Fac_RI/log \
  -a "V03206007002D" \
  -v /backup/007_Clientes_Fac_RI \
  -r -s "A1001001A13D05B53912E71640"
```

The `-r -s "A1001001A13D05B53912E71640"` parameters tell the export manager to resume from the specified ItemID.

## Log Files

All log files are created in `<base_folder>/log/`:

1. **export_progress.log** - Detailed progress log with timestamps
   - Shows start/completion time for each itemtype
   - Indicates which itemtypes were skipped (already completed)
   - Records any failures with error codes
   - Records resume points

2. **export_resume.log** - Resume information
   - Format: `ITEMTYPE|LAST_ITEMID`
   - Automatically created when an export fails
   - Automatically removed when itemtype completes successfully

3. **TExportManagerICM logs** - Standard IBM CM export logs
   - Created by the TExportManagerICM tool itself

## Example Output

```
============================================================================
Starting IBM Content Manager Export...
============================================================================
Export Name: 007ClientesFacRI
Export Folder: /backup/007_Clientes_Fac_RI
Log Folder: /backup/007_Clientes_Fac_RI/log
User: icmadmin
Itemtype List File: itemtypes.txt

========================================================================
Processing Itemtype #1: V03206007002D
Started: Mon Nov 10 10:30:00 2025
========================================================================

Command: java TExportManagerICM -u icmadmin -p Evolucion -m 007ClientesFacRI -l "/backup/007_Clientes_Fac_RI/log" -a "V03206007002D" -v "/backup/007_Clientes_Fac_RI"

====================================================================
SUCCESS: Export completed for itemtype V03206007002D
Completed: Mon Nov 10 10:45:00 2025
====================================================================

========================================================================
Processing Itemtype #2: V03206007003D
Started: Mon Nov 10 10:45:05 2025
========================================================================

INFO: Resuming from ItemID: A1001001A13D05B53912E71640

Command: java TExportManagerICM -u icmadmin -p Evolucion -m 007ClientesFacRI -l "/backup/007_Clientes_Fac_RI/log" -a "V03206007003D" -v "/backup/007_Clientes_Fac_RI" -r -s "A1001001A13D05B53912E71640"

============================================================================
Export Process Summary
============================================================================
Total itemtypes processed: 2
Total errors: 0

Check logs at: /backup/007_Clientes_Fac_RI/log
  - Progress log: /backup/007_Clientes_Fac_RI/log/export_progress.log
  - Resume log: /backup/007_Clientes_Fac_RI/log/export_resume.log
Export files at: /backup/007_Clientes_Fac_RI

All exports completed successfully!
```

## Error Handling

- If an itemtype export fails, the script:
  1. Logs the error with error code
  2. Extracts the last exported ItemID from the .etk file
  3. Saves the resume point to `export_resume.log`
  4. **Continues with the next itemtype** (doesn't stop the entire process)

- When you re-run the script:
  1. Completed itemtypes are automatically skipped
  2. Failed itemtypes are automatically resumed from the last ItemID

## Troubleshooting

### Script fails to start
- Verify Java is installed and JAVA_HOME is correct
- Check that DB2 libraries are accessible
- Verify ICM credentials are correct

### Export fails for a specific itemtype
- Check `export_progress.log` for error details
- Verify the itemtype exists in the system
- Check disk space in the target folder
- The script will automatically save the resume point

### Resume doesn't work
- Verify `export_resume.log` exists and contains the itemtype
- Check that the .etk file exists and contains ItemID information
- Ensure you're using the same export_name and base_folder

### Permission errors
- **Windows**: Run cmd.exe as Administrator
- **Linux**: Ensure script has execute permission: `chmod +x export_icm.sh`
- Verify write permissions for base_folder and log_folder

## Best Practices

1. **Test with a single itemtype first** before running large batches
2. **Monitor the first export** to ensure paths and credentials are correct
3. **Keep log files** for audit and troubleshooting purposes
4. **Use descriptive export names** that match the content being exported
5. **Schedule large exports** during off-peak hours
6. **Backup existing exports** before re-running failed jobs

## Technical Details

### IBM Content Manager TExportManagerICM Parameters

- `-u` : Username for ICM
- `-p` : Password for ICM
- `-m` : Export module/name
- `-l` : Log folder path
- `-a` : Itemtype to export
- `-v` : Export destination folder (vault)
- `-r` : Resume flag (resume a previous export)
- `-s` : Start ItemID for resume

### ETK File Format

The .etk file is created by TExportManagerICM and contains exported item information in XML format. The script parses this file to find the last exported ItemID for resume functionality.

## Version History

### Version 2.0 (Enhanced) - 2025-11-10
- Added support for multiple itemtypes from a file
- Implemented automatic resume functionality
- Added progress tracking and detailed logging
- Automatic ItemID detection from .etk file
- Skip already completed itemtypes
- Continue on error instead of stopping

### Version 1.0 (Original)
- Basic single itemtype export
- Windows and Linux support
- Simple error handling

## Support

For issues or questions:
1. Check the log files in `<base_folder>/log/`
2. Review the progress log for detailed error messages
3. Verify all configuration parameters
4. Ensure IBM Content Manager services are running

## License

These scripts are provided as-is for IBM Content Manager administrators.

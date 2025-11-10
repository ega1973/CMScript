# IBM Content Manager Export Scripts

This repository contains automation scripts for exporting IBM Content Manager item types on both Windows and Linux platforms.

## Scripts

- **export_icm.bat** - Windows batch script
- **export_icm.sh** - Linux shell script

## Features

Both scripts automatically:
1. Create the required folder structure (base folder and log subfolder)
2. Configure the CLASSPATH with all necessary IBM DB2 Content Manager libraries
3. Execute the TExportManagerICM Java tool with specified parameters
4. Provide detailed output and error handling

## Prerequisites

### Windows
- Java JDK 1.6.0_26 installed at `E:\jdk1.6.0_26`
- IBM DB2 Content Manager 8.1 installed at `E:\IBM\db2cmv8`
- Oracle JDBC drivers at `C:\oracle\ora92\jdbc\lib`
- DB2 Java libraries at `c:\sqllib\JAVA`

### Linux
- Java installed and available in PATH
- IBM DB2 Content Manager libraries at `/IBM/lib`
- DB2 profile at `/home/db2cli1/sqllib/db2profile`
- Appropriate permissions to create directories in the target location

## Usage

### Windows

```batch
export_icm.bat <export_name> <base_folder> <itemtype>
```

**Example:**
```batch
export_icm.bat 007ClientesConstruya G:\007_Clientes_Construya "V03206007003D"
```

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
   - User credentials (icmadmin/Evolucion)
   - Export name
   - Log folder path
   - Item type
   - Export destination folder
5. **Report Results**: Display success/failure status and file locations

## Default Credentials

The scripts use these default credentials (can be modified in the script):
- **Username**: icmadmin
- **Password**: Evolucion

## Output

### Successful Export
- Export files will be created in the base folder
- Log files will be created in the log subfolder
- Success message with paths displayed

### Failed Export
- Error message with error code displayed
- Check log files for detailed error information

## Customization

### Changing Installation Paths

**Windows (export_icm.bat):**
```batch
SET JAVA_HOME=E:\jdk1.6.0_26
SET DB2_HOME=E:\IBM\db2cmv8
```

**Linux (export_icm.sh):**
```bash
DB2_PROFILE="/home/db2cli1/sqllib/db2profile"
IBM_HOME="/IBM"
DB2_SQLLIB="/IBM/SQLLIB"
```

### Changing Credentials

**Windows:**
```batch
SET ICM_USER=icmadmin
SET ICM_PASSWORD=Evolucion
```

**Linux:**
```bash
ICM_USER="icmadmin"
ICM_PASSWORD="Evolucion"
```

## Error Handling

Both scripts include:
- Parameter validation
- Folder creation error checking
- Export status verification
- Detailed error messages with exit codes

## Notes

- The itemtype parameter must be enclosed in quotes if it contains special characters
- Ensure you have write permissions to the target folder
- Log files are essential for troubleshooting - always check them if exports fail
- The scripts will NOT overwrite existing folders; they will use them if they already exist

## Example Use Cases

### Windows Examples

```batch
REM Export client documents
export_icm.bat 007ClientesConstruya G:\007_Clientes_Construya "V03206007003D"

REM Export invoice documents
export_icm.bat 007ClientesFacRI G:\007_Clientes_Fac_RI "V03206007002D"
```

### Linux Examples

```bash
# Export client documents
./export_icm.sh 007ClientesConstruya /backup/007_Clientes_Construya "V03206007003D"

# Export invoice documents
./export_icm.sh 007ClientesFacRI /backup/007_Clientes_Fac_RI "V03206007002D"
```

## Troubleshooting

### Common Issues

1. **Java not found**
   - Windows: Verify JAVA_HOME path in script
   - Linux: Ensure java is in PATH

2. **CLASSPATH errors**
   - Verify all IBM DB2 CM library paths exist
   - Check that all JAR files are present

3. **Permission denied**
   - Windows: Run as Administrator if accessing system folders
   - Linux: Ensure script is executable (`chmod +x export_icm.sh`)

4. **DB2 connection errors**
   - Verify DB2 is running
   - Check credentials are correct
   - Review DB2 profile sourcing (Linux)

5. **Export fails**
   - Check log files in the log subfolder
   - Verify itemtype exists in the system
   - Ensure sufficient disk space

## Support

For issues or questions:
1. Check the log files in the log subfolder
2. Verify all paths and credentials in the script
3. Ensure IBM Content Manager is properly installed and configured

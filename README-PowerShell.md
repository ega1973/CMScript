# IBM Content Manager Export Script - PowerShell Version

## Overview

This PowerShell script is a complete rewrite of `export_icm.bat` with the following improvements:

- **Much easier to debug** - Clear error messages, structured code, verbose logging
- **Better error handling** - Try/catch blocks, proper exit codes
- **PowerShell 2.0 compatible** - Works on Windows Server 2008, Windows 7, and newer
- **Same functionality** - All features from the batch file are preserved
- **Cleaner code** - Functions, parameters, and structured programming

## Requirements

- **PowerShell Version**: 2.0 or higher
- **Environment Variables**:
  - `ICM_USER` - IBM Content Manager username
  - `ICM_PASSWORD` - IBM Content Manager password
- **Java**: JDK 1.6.0_26 (or update paths in script)
- **IBM DB2 Content Manager**: Version 8.x

## Setting Environment Variables

Before running the script, set your credentials:

```powershell
# PowerShell
$env:ICM_USER = "your_username"
$env:ICM_PASSWORD = "your_password"

# Or set them permanently
[Environment]::SetEnvironmentVariable("ICM_USER", "your_username", "User")
[Environment]::SetEnvironmentVariable("ICM_PASSWORD", "your_password", "User")
```

## Usage

### Single Itemtype Mode

Export a single itemtype:

```powershell
.\Export-ICM.ps1 -ExportName "007ClientesConstruya" `
                 -BaseFolder "G:\007_Clientes_Construya" `
                 -ItemType "V03206007003D"
```

Or using positional parameters:

```powershell
.\Export-ICM.ps1 "007ClientesConstruya" "G:\007_Clientes_Construya" "V03206007003D"
```

### Multiple Itemtypes Mode

Create a file `itemtypes.txt` with this format (space or tab separated):

```
# Export Name          Base Folder                    ItemType
007ClientesFacRI      G:\007_Clientes_Fac_RI         V03206007002D
007ClientesConstruya  G:\007_Clientes_Construya      V03206007003D
```

Then run:

```powershell
.\Export-ICM.ps1 -ItemTypeListFile "itemtypes.txt"
```

## Features

### 1. Resume Capability

If the export is interrupted, simply run the script again with the same parameters. It will:
- Detect the last successfully exported ItemID from the `.etk` file
- Automatically resume from that point
- Show resume information in yellow text

### 2. Progress Tracking

The script maintains detailed logs in the `log` folder:
- **export_progress.log** - Complete history of all exports
- **export_resume.log** - Resume points for interrupted exports
- **[ExportName].etk** - IBM CM export tracking file

### 3. ETK File Analysis

After export completes, the script analyzes the `.etk` file and shows:
- Export status (Completed/Failed/Incomplete)
- Package statistics (started vs completed)
- Any failures detected
- Last completed ItemID for resume
- Recently completed packages

### 4. Color-Coded Output

- **Green** - Success messages and verified paths
- **Yellow** - Warnings and resume info
- **Red** - Errors and missing files
- **Cyan** - Headers and important information
- **White/Gray** - Command details

### 5. CLASSPATH Verification

The script now displays the complete CLASSPATH when it starts:
- Lists every JAR and path being used (numbered for easy reference)
- Verifies critical paths exist (shows [OK] or [MISSING])
- Appends to existing CLASSPATH if one exists
- Shows total number of classpath entries
- Passes classpath explicitly to Java using `-classpath` argument

### 6. Verbose Mode

For detailed debugging, run with `-Verbose`:

```powershell
.\Export-ICM.ps1 -ExportName "007ClientesConstruya" `
                 -BaseFolder "G:\007_Clientes_Construya" `
                 -ItemType "V03206007003D" `
                 -Verbose
```

## Example CLASSPATH Output

### When no existing CLASSPATH is set:

```
============================================================================
Setting up CLASSPATH
============================================================================
No existing CLASSPATH, creating new one...

CLASSPATH configured successfully!

CURRENT CLASSPATH:
============================================================================
  [1] E:\IBM\db2cmv8\cmgmt
  [2] E:\IBM\db2cmv8\lib\cmbview81.jar
  [3] E:\IBM\db2cmv8\lib\cmb81.jar
  [4] E:\IBM\db2cmv8\lib\cmbcm81.jar
  ...
  [22] E:\IBM\db2cmv8\lib\cmbsdk81.jar
  [23] E:\IBM\db2cmv8\lib\cmbwas81.jar
============================================================================
Total classpath entries: 23

Verifying critical paths...
  [OK] E:\IBM\db2cmv8\lib\cmb81.jar
  [OK] E:\IBM\db2cmv8\lib\cmbicm81.jar
  [OK] c:\sqllib\JAVA\DB2JAVA.ZIP
```

### When existing CLASSPATH is present:

The script preserves your existing CLASSPATH and appends ICM libraries (matching batch behavior: `set CLASSPATH=%CLASSPATH%;new_paths`)

```
============================================================================
Setting up CLASSPATH
============================================================================
Existing CLASSPATH found, appending ICM libraries...
  Existing entries: 5
  Adding ICM entries: 23

CLASSPATH configured successfully!

CURRENT CLASSPATH:
============================================================================
  [1] C:\MyApp\lib\something.jar (from existing CLASSPATH)
  [2] C:\MyApp\lib\another.jar (from existing CLASSPATH)
  [3] C:\MyApp\lib\third.jar (from existing CLASSPATH)
  [4] C:\MyApp\lib\fourth.jar (from existing CLASSPATH)
  [5] C:\MyApp\lib\fifth.jar (from existing CLASSPATH)
  [6] E:\IBM\db2cmv8\cmgmt
  [7] E:\IBM\db2cmv8\lib\cmbview81.jar
  ...
  [28] E:\IBM\db2cmv8\lib\cmbwas81.jar
============================================================================
Total: 28 entries (5 existing + 23 ICM)
```

**Important**: Existing CLASSPATH entries come FIRST, then ICM paths are appended. This matches the batch file behavior exactly.

This makes it easy to verify that all required JARs are in the classpath and can be found by Java.

## Debugging

### Common Issues

1. **"ICM_USER environment variable is not set"**
   - Solution: Set the environment variables as shown above

2. **"File not found" for Java or JAR files**
   - Solution: Check the CLASSPATH output when the script starts
   - Look for `[MISSING]` markers in red next to critical paths
   - Update the paths in the Configuration section at the top of the script:
     ```powershell
     $script:JAVA_HOME = "E:\jdk1.6.0_26"  # Update this
     $script:DB2_HOME = "E:\IBM\db2cmv8"   # Update this
     ```
   - Verify the numbered CLASSPATH entries point to the correct locations

3. **Export fails with error code**
   - Check the `.etk` file in the log folder for detailed errors
   - Use `-Verbose` flag to see detailed execution info
   - The script will automatically save resume point

4. **Permission denied when creating folders**
   - Ensure you have write permissions to the base folder
   - Run PowerShell as Administrator if needed

### Getting Help

View built-in help:

```powershell
Get-Help .\Export-ICM.ps1 -Full
Get-Help .\Export-ICM.ps1 -Examples
```

## Comparison with Batch File

| Feature | Batch File | PowerShell |
|---------|-----------|------------|
| Debugging | Difficult (complex syntax) | Easy (clear errors) |
| Error Handling | Basic | Comprehensive |
| Code Structure | Linear with GOTOs | Functions & regions |
| Output | Plain text | Color-coded |
| Resume Detection | Manual parsing | Automatic |
| Verbose Logging | No | Yes (`-Verbose`) |
| Parameter Validation | Manual | Built-in |
| Help Documentation | Comments only | Built-in help |
| CLASSPATH Display | No | Yes (numbered list) |
| Path Verification | No | Yes (checks if files exist) |
| Explicit Classpath | Uses env var only | Passes `-classpath` to Java |

## Advanced Usage

### Running with Different Credentials

You can temporarily override credentials without changing environment variables:

```powershell
$env:ICM_USER = "temp_user"
$env:ICM_PASSWORD = "temp_pass"
.\Export-ICM.ps1 "ExportName" "G:\Folder" "ItemType"
```

### Scheduling with Task Scheduler

Create a scheduled task that runs:

```powershell
powershell.exe -ExecutionPolicy Bypass -File "C:\Scripts\Export-ICM.ps1" -ExportName "007ClientesConstruya" -BaseFolder "G:\007_Clientes_Construya" -ItemType "V03206007003D"
```

### Batch Processing Multiple Exports

Create a master script:

```powershell
# master-export.ps1
$env:ICM_USER = "your_username"
$env:ICM_PASSWORD = "your_password"

# Process first export
.\Export-ICM.ps1 "Export1" "G:\Folder1" "Type1"

# Process second export
.\Export-ICM.ps1 "Export2" "G:\Folder2" "Type2"
```

## File Structure

After running, your folder structure will look like:

```
G:\007_Clientes_Construya\
├── log\
│   ├── export_progress.log
│   ├── export_resume.log
│   └── 007ClientesConstruya.etk
├── masterPackage\
│   ├── package1\
│   ├── package2\
│   └── ...
└── [other export files]
```

## PowerShell Version Check

To verify your PowerShell version:

```powershell
$PSVersionTable
```

Expected output for PowerShell 2.0:

```
Name                           Value
----                           -----
PSVersion                      2.0
CLRVersion                     2.0.50727.3662
BuildVersion                   6.0.6002.18111
...
```

## Troubleshooting Tips

1. **Enable Script Execution** (if needed):
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```

2. **Test Java and Classpath**:
   ```powershell
   # Test Java
   & "E:\jdk1.6.0_26\bin\java.exe" -version

   # Test DB2 paths
   Test-Path "E:\IBM\db2cmv8\lib\cmb81.jar"
   ```

3. **View Real-Time Progress**:
   ```powershell
   # In another PowerShell window, tail the log
   Get-Content "G:\007_Clientes_Construya\log\export_progress.log" -Wait
   ```

## Support

For issues or questions:
1. Check the error message in red
2. Review the `.etk` file in the log folder
3. Run with `-Verbose` flag for detailed output
4. Check that all paths and credentials are correct

## License

Same as the original batch script - for use with IBM Content Manager.

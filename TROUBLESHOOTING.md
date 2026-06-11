# Troubleshooting Guide - IBM Content Manager Export Scripts

## Common Issues and Solutions

### Java OutOfMemoryError with Large Files

#### Problem

When exporting large files (e.g., 170MB or larger), you may encounter this error:

```
Exception in thread "main" java.lang.OutOfMemoryError: Java heap space
    at com.ibm.mm.sdk.common.DKLobICM.readContentToMem(DKLobICM.java:6040)
    at com.ibm.mm.sdk.common.DKLobICM.getHTTPGetResponse(DKLobICM.java:5936)
    at com.ibm.mm.sdk.common.DKLobICM.retrieve(DKLobICM.java:6226)
    ...
    at TExportManagerICM.main(TExportManagerICM.java:533)
```

#### Root Cause

The Java Virtual Machine (JVM) runs out of heap memory when trying to load large content files into memory. By default, Java may allocate insufficient memory for handling large document exports.

#### Solution

The scripts have been updated to include JVM memory parameters that allocate more heap space:

- **Maximum Heap Size (-Xmx)**: 2048m (2GB) by default
- **Initial Heap Size (-Xms)**: 512m (512MB) by default

These parameters are now automatically included when running the export.

#### Adjusting Memory Settings

If you're still experiencing OutOfMemoryError with the default settings, you can increase the memory allocation:

##### Linux (export_icm.sh)

Edit the configuration section near the top of the script (around line 89):

```bash
# JVM Memory Configuration
JAVA_MAX_HEAP="2048m"   # Maximum heap size (-Xmx)
JAVA_MIN_HEAP="512m"    # Initial heap size (-Xms)
```

**Recommended values based on file sizes:**

| Maximum File Size | JAVA_MAX_HEAP | JAVA_MIN_HEAP |
|-------------------|---------------|---------------|
| Up to 200MB       | 2048m (2GB)   | 512m          |
| Up to 500MB       | 4096m (4GB)   | 1024m (1GB)   |
| Up to 1GB         | 8192m (8GB)   | 2048m (2GB)   |
| Larger than 1GB   | 16384m (16GB) | 4096m (4GB)   |

##### Windows PowerShell (Export-ICM.ps1)

Edit the configuration section near the top of the script (around line 68):

```powershell
# JVM Memory Configuration
$script:JAVA_MAX_HEAP = "2048m"  # Maximum heap size (-Xmx)
$script:JAVA_MIN_HEAP = "512m"   # Initial heap size (-Xms)
```

Use the same recommended values as shown in the table above.

#### Important Notes

1. **System Memory**: Ensure your system has enough RAM available. The JVM will attempt to allocate the memory you specify.

2. **32-bit vs 64-bit Java**: 
   - 32-bit Java has a maximum heap size limit of approximately 1.5-2GB
   - For files larger than this, you must use 64-bit Java
   - Check your Java version: `java -version` (should show "64-Bit" for 64-bit)

3. **Multiple Concurrent Exports**: If running multiple exports simultaneously, each process will use the configured memory. Plan accordingly.

4. **Performance vs Memory**: Higher initial heap size (-Xms) can improve performance but uses more RAM from the start.

---

## Other Common Issues

### Permission Denied Errors

#### Problem
```
Error: Failed to create base folder
mkdir: cannot create directory: Permission denied
```

#### Solution

**Linux:**
```bash
# Ensure you have write permissions to the target directory
chmod -R u+w /backup/target_folder

# Or run with sudo (not recommended for production)
sudo ./export_icm.sh ...
```

**Windows:**
- Run PowerShell as Administrator
- Check folder permissions in Windows Explorer

---

### DB2 Connection Errors

#### Problem
```
Error: Unable to connect to datastore
```

#### Solution

**Linux:**
1. Verify DB2 profile is sourced correctly:
```bash
. /home/db2cli1/sqllib/db2profile
db2 connect to <database>
```

2. Check DB2 is running:
```bash
db2pd -alldbs
```

**Windows:**
1. Verify DB2 services are running in Services panel
2. Test connection with DB2 Command Window

---

### ClassNotFoundException

#### Problem
```
Exception in thread "main" java.lang.NoClassDefFoundError: TExportManagerICM
```

#### Solution

**Linux:**
Verify the IBM Content Manager library paths in the script configuration:
```bash
IBM_HOME="/IBM"
DB2_SQLLIB="/IBM/SQLLIB"
```

Ensure all required JAR files exist:
```bash
ls -la /IBM/lib/cmbsdk81.jar
ls -la /IBM/lib/cmbicm81.jar
```

**Windows:**
Verify paths in the PowerShell script:
```powershell
$script:DB2_HOME = "E:\IBM\db2cmv8"
$script:SAMPLE1_DIR = Join-Path $script:DB2_HOME "samples\java\icm\Sample1"
```

Ensure the Sample1 directory exists and contains TImportExportICM.ini

---

### Authentication Failures

#### Problem
```
Error: Invalid username or password
```

#### Solution

Ensure environment variables are set correctly:

**Linux:**
```bash
export ICM_USER="your_username"
export ICM_PASSWORD="your_password"

# Verify they're set
echo $ICM_USER
echo $ICM_PASSWORD
```

**Windows PowerShell:**
```powershell
$env:ICM_USER = "your_username"
$env:ICM_PASSWORD = "your_password"

# Verify they're set
$env:ICM_USER
$env:ICM_PASSWORD
```

---

### Resume Not Working

#### Problem
Export doesn't resume from the last position after interruption.

#### Solution

1. **Check for ETK file**: The resume feature requires the .etk log file:
   ```
   <base_folder>/log/<export_name>.etk
   ```

2. **Verify resume log**: Check the export_resume.log file:
   ```
   <base_folder>/log/export_resume.log
   ```

3. **Manual resume**: You can manually specify a resume point:
   
   **Linux:**
   ```bash
   # Add to the itemtypes.txt file or modify the script to use -r and -s flags
   java -Xmx2048m -Xms512m TExportManagerICM \
     -u $ICM_USER -p $ICM_PASSWORD \
     -m ExportName -l /path/to/log \
     -a "ItemType" -v /path/to/export \
     -r -s "LastItemID"
   ```

---

### Disk Space Issues

#### Problem
```
Error: No space left on device
```

#### Solution

1. **Check available space**:
   ```bash
   df -h /backup/path
   ```

2. **Estimate required space**: 
   - Export size is typically 1.2-1.5x the source data size
   - Log files can be 10-20% of data size
   - Ensure at least 2x the expected data size is available

3. **Clean up old exports**:
   ```bash
   # List exports by size
   du -sh /backup/*/
   
   # Remove old exports
   rm -rf /backup/old_export_folder
   ```

---

### Slow Export Performance

#### Problem
Export is running very slowly.

#### Solution

1. **Increase initial heap size**: Set JAVA_MIN_HEAP closer to JAVA_MAX_HEAP
   ```bash
   JAVA_MAX_HEAP="4096m"
   JAVA_MIN_HEAP="2048m"
   ```

2. **Check network latency**: If Content Manager is remote, network speed affects performance

3. **Disk I/O**: Ensure export target is on fast storage (SSD > HDD)

4. **DB2 Performance**: Check DB2 buffer pool sizes and table statistics

---

## Getting Additional Help

If you encounter issues not covered here:

1. **Check log files**:
   - Export logs: `<base_folder>/log/<export_name>.log`
   - ETK file: `<base_folder>/log/<export_name>.etk`
   - Progress log: `<base_folder>/log/export_progress.log`

2. **Enable verbose logging**: Add `-t` parameter to TExportManagerICM for detailed tracing

3. **IBM Content Manager Documentation**: Refer to IBM CM 8.1 documentation for TExportManagerICM

4. **System logs**:
   - Linux: `/var/log/messages` or `journalctl`
   - Windows: Event Viewer

---

## Script Version Information

- **Linux Script**: export_icm.sh (Enhanced with memory management)
- **Windows Script**: Export-ICM.ps1 (Enhanced with memory management)
- **Memory Configuration**: Configurable at top of each script
- **Default Max Heap**: 2048m (2GB)
- **Default Min Heap**: 512m

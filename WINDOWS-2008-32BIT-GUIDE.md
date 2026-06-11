# Quick Reference Guide - Windows 2008 32-bit with 32-bit Java

## Critical Limitations

### Maximum File Size You Can Export
- **With 32-bit Java**: **~150MB maximum** per file
- **Larger files**: Requires 64-bit Java (and 64-bit Windows)

### Maximum Java Heap Size (Memory)
- **Safe maximum**: 1280m (1.25 GB)
- **Absolute limit**: ~1536m (1.5 GB) - may fail
- **DO NOT use**: 2048m or higher - will fail immediately

---

## Current Script Configuration

The scripts are now configured with **safe defaults for 32-bit Java**:

```powershell
# In Export-ICM.ps1 (line ~73)
$script:JAVA_MAX_HEAP = "1280m"  # Safe for 32-bit
$script:JAVA_MIN_HEAP = "256m"   # Safe for 32-bit
```

**These settings work for files up to 150MB.**

---

## How to Check Your Java Version

Open **Command Prompt** and run:
```cmd
java -version
```

### If you see:
```
java version "1.6.0_26"
Java(TM) SE Runtime Environment (build 1.6.0_26-b03)
Java HotSpot(TM) 64-Bit Server VM (build 20.1-b02, mixed mode)
                  ^^^^^^
```
✅ **You have 64-bit Java** - You can use up to 2048m or more

### If you see:
```
java version "1.6.0_26"
Java(TM) SE Runtime Environment (build 1.6.0_26-b03)
Java HotSpot(TM) Client VM (build 20.1-b02, mixed mode)
```
⚠️ **You have 32-bit Java** - Maximum 1280m-1400m heap size

---

## Common Errors on 32-bit Java

### Error 1: "Could not reserve enough space"

```
Error occurred during initialization of VM
Could not reserve enough space for object heap
```

**Cause**: Heap size set too high for 32-bit Java

**Solution**: Reduce memory in script configuration:
```powershell
$script:JAVA_MAX_HEAP = "1024m"  # Try 1GB first
$script:JAVA_MIN_HEAP = "256m"
```

If still fails, try:
```powershell
$script:JAVA_MAX_HEAP = "768m"   # Try 768MB
$script:JAVA_MIN_HEAP = "256m"
```

### Error 2: "OutOfMemoryError" during export

```
Exception in thread "main" java.lang.OutOfMemoryError: Java heap space
```

**Cause**: File is too large for current heap size

**Solutions (in order of preference):**

1. **Increase heap to maximum safe value**:
   ```powershell
   $script:JAVA_MAX_HEAP = "1400m"  # Try maximum safe for 32-bit
   ```

2. **If still fails**: File is too large for 32-bit Java
   - Upgrade to 64-bit Java (requires 64-bit Windows)
   - Or split the export into smaller chunks

---

## File Size Guidelines for 32-bit Java

| File Size Range | Recommended Heap | Will it Work? |
|----------------|------------------|---------------|
| < 50MB         | 768m             | ✅ Yes        |
| 50MB - 100MB   | 1024m            | ✅ Yes        |
| 100MB - 150MB  | 1280m            | ✅ Probably   |
| 150MB - 175MB  | 1400m            | ⚠️ Maybe      |
| > 175MB        | N/A              | ❌ No - Need 64-bit |

---

## How to Adjust Memory Settings

### Step 1: Open the script in Notepad

```cmd
notepad Export-ICM.ps1
```

### Step 2: Find the memory configuration section

Look for these lines (around line 73):
```powershell
# JVM Memory Configuration
$script:JAVA_MAX_HEAP = "1280m"
$script:JAVA_MIN_HEAP = "256m"
```

### Step 3: Change the values

For files up to 100MB:
```powershell
$script:JAVA_MAX_HEAP = "1024m"
$script:JAVA_MIN_HEAP = "256m"
```

For files up to 150MB:
```powershell
$script:JAVA_MAX_HEAP = "1280m"
$script:JAVA_MIN_HEAP = "256m"
```

For files up to 175MB (risky on 32-bit):
```powershell
$script:JAVA_MAX_HEAP = "1400m"
$script:JAVA_MIN_HEAP = "256m"
```

### Step 4: Save and run

Save the file and run the script again.

---

## Example Usage

### For a 120MB file:

1. **Set memory** (in Export-ICM.ps1):
   ```powershell
   $script:JAVA_MAX_HEAP = "1280m"
   ```

2. **Set credentials** (in PowerShell):
   ```powershell
   $env:ICM_USER = "icmadmin"
   $env:ICM_PASSWORD = "your_password"
   ```

3. **Run export**:
   ```powershell
   .\Export-ICM.ps1 -ExportName "MyExport" -BaseFolder "G:\MyExport" -ItemType "V03206007003D"
   ```

---

## When You MUST Upgrade to 64-bit Java

You need 64-bit Java if:
- ❌ Files are larger than 150MB
- ❌ Getting "OutOfMemoryError" even with 1400m heap
- ❌ Need to export many large files efficiently

### Prerequisites for 64-bit Java:
- ✅ Windows Server 2008 **64-bit edition** (check with `systeminfo`)
- ✅ 32-bit Windows **CANNOT** run 64-bit Java

### To check your Windows version:
```cmd
systeminfo | findstr /C:"System Type"
```

If it says:
- `x64-based PC` → You can install 64-bit Java ✅
- `x86-based PC` → You cannot install 64-bit Java ❌

---

## Upgrading to 64-bit Java (if you have 64-bit Windows)

1. **Download JDK 6 64-bit**:
   - File: `jdk-6u26-windows-x64.exe`
   - From Oracle Java Archive

2. **Install to new folder**:
   - Install to: `E:\jdk1.6.0_26-x64`
   - Keep existing 32-bit Java

3. **Update script** (Export-ICM.ps1 line ~60):
   ```powershell
   $script:JAVA_HOME = "E:\jdk1.6.0_26-x64"
   ```

4. **Update memory** (line ~73):
   ```powershell
   $script:JAVA_MAX_HEAP = "2048m"  # Now you can use 2GB!
   $script:JAVA_MIN_HEAP = "512m"
   ```

5. **Verify**:
   ```cmd
   E:\jdk1.6.0_26-x64\bin\java -version
   ```
   Should show "64-Bit Server VM"

---

## Quick Troubleshooting Decision Tree

```
Export failing?
├─ Error: "Could not reserve enough space"?
│  └─ YES → Reduce JAVA_MAX_HEAP to 1024m or lower
│
├─ Error: "OutOfMemoryError: Java heap space"?
│  ├─ Current heap < 1280m?
│  │  └─ YES → Increase to 1280m
│  └─ Current heap = 1280m or higher?
│     ├─ Have 64-bit Windows?
│     │  └─ YES → Upgrade to 64-bit Java
│     └─ Have 32-bit Windows?
│        └─ File too large for 32-bit, cannot export
│
└─ Other error?
   └─ See TROUBLESHOOTING.md
```

---

## Summary

### ✅ What Works on 32-bit Java
- Files up to ~150MB
- Heap size up to 1280m (safe) or 1400m (risky)
- Current script defaults are optimized for 32-bit

### ❌ What Doesn't Work on 32-bit Java
- Files larger than 175MB
- Heap size over ~1536m
- Multiple large exports simultaneously

### 🚀 To Export Larger Files
- **Upgrade to 64-bit Java** (requires 64-bit Windows)
- Or split exports into smaller chunks

---

## Need More Help?

See the complete troubleshooting guide: [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

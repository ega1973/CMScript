<#
.SYNOPSIS
    IBM Content Manager Export Script for Windows - PowerShell Version

.DESCRIPTION
    This script exports data from IBM Content Manager with support for single or multiple itemtypes.
    Features:
    - Process single or multiple itemtypes from a file
    - Each itemtype can have its own export name and base folder
    - Resume capability: if process stops, automatically resume from last position
    - Detailed logging of progress and resume information
    - Automatic detection of last itemid from .etk file for resume

.PARAMETER ExportName
    The name for this export (single itemtype mode)

.PARAMETER BaseFolder
    The base folder where export files will be stored (single itemtype mode)

.PARAMETER ItemType
    The itemtype to export (single itemtype mode)

.PARAMETER ItemTypeListFile
    Path to a file containing multiple itemtypes to process (multi-itemtype mode)
    Format: <export_name> <base_folder> <itemtype> (space or tab separated)

.EXAMPLE
    .\Export-ICM.ps1 -ExportName "007ClientesConstruya" -BaseFolder "G:\007_Clientes_Construya" -ItemType "V03206007003D"

.EXAMPLE
    .\Export-ICM.ps1 -ItemTypeListFile "itemtypes.txt"

.NOTES
    PowerShell Version: 2.0+
    Requires: ICM_USER and ICM_PASSWORD environment variables
#>

[CmdletBinding(DefaultParameterSetName='SingleMode')]
param(
    [Parameter(ParameterSetName='SingleMode', Mandatory=$true, Position=0)]
    [string]$ExportName,

    [Parameter(ParameterSetName='SingleMode', Mandatory=$true, Position=1)]
    [string]$BaseFolder,

    [Parameter(ParameterSetName='SingleMode', Mandatory=$true, Position=2)]
    [string]$ItemType,

    [Parameter(ParameterSetName='MultiMode', Mandatory=$true, Position=0)]
    [string]$ItemTypeListFile
)

# Strict mode for better error detection
Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"

#region Configuration

# Java and DB2 paths
$script:JAVA_HOME = "E:\jdk1.6.0_26"
$script:DB2_HOME = "E:\IBM\db2cmv8"
$script:JAVA_EXE = Join-Path $JAVA_HOME "bin\java.exe"

#endregion

#region Helper Functions

function Write-Header {
    param([string]$Title)
    Write-Host ""
    Write-Host ("=" * 76)
    Write-Host $Title
    Write-Host ("=" * 76)
}

function Write-SubHeader {
    param([string]$Title)
    Write-Host ""
    Write-Host ("-" * 72)
    Write-Host $Title
    Write-Host ("-" * 72)
}

function Get-Timestamp {
    return Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

function Write-Log {
    param(
        [string]$Message,
        [string]$LogFile,
        [switch]$NoConsole
    )

    $timestamp = Get-Timestamp
    $logMessage = "[$timestamp] $Message"

    if (-not $NoConsole) {
        Write-Host $logMessage
    }

    if ($LogFile) {
        Add-Content -Path $LogFile -Value $logMessage
    }
}

function Get-LastItemIdFromETK {
    <#
    .SYNOPSIS
        Extracts the last completed ItemID from an ETK file
    .PARAMETER ExportName
        The export name to build the ETK filename
    .PARAMETER BaseFolder
        The base folder where logs are stored
    .OUTPUTS
        String containing the last ItemID, or $null if not found
    #>
    param(
        [string]$ExportName,
        [string]$BaseFolder
    )

    $logFolder = Join-Path $BaseFolder "log"
    $etkFile = Join-Path $logFolder "$ExportName.etk"
    $lastItemId = $null

    if (Test-Path $etkFile) {
        Write-Verbose "Analyzing ETK file: $etkFile"

        # Read all lines and find "Package Completed:" lines
        $content = Get-Content $etkFile
        $completedLines = $content | Where-Object { $_ -match "Package Completed:" }

        if ($completedLines) {
            # Get the last completed line
            if ($completedLines -is [Array]) {
                $lastCompletedLine = $completedLines[-1]
            } else {
                $lastCompletedLine = $completedLines
            }

            Write-Verbose "Last completed line: $lastCompletedLine"

            # Extract ItemID from format: Package Completed:  2814    : '291     ' ('A1001001A14D24B72939B49768', 'A1001001A20B28B71115J61199'] G:\...
            # We need the last ID before the ']'
            if ($lastCompletedLine -match '\[([^\]]+)\]') {
                $itemsPart = $matches[1]
                # Split by comma and get last item
                $items = $itemsPart -split ','
                $lastItem = $items[-1].Trim()
                # Remove quotes and spaces
                $lastItemId = $lastItem -replace "[' ]", ""
            }
        }

        # Fallback: try XML format if Package Completed format didn't work
        if (-not $lastItemId) {
            $lastLine = $content[-1]
            if ($lastLine -match '<itemid>([^<]+)</itemid>') {
                $lastItemId = $matches[1]
            }
        }
    }

    return $lastItemId
}

function New-FolderIfNotExists {
    param([string]$Path)

    if (-not (Test-Path $Path)) {
        Write-Verbose "Creating folder: $Path"
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
        Write-Host "Created folder: $Path"
        return $true
    } else {
        Write-Verbose "Folder already exists: $Path"
        return $false
    }
}

function Test-ItemTypeCompleted {
    param(
        [string]$ItemType,
        [string]$ProgressLog
    )

    if (Test-Path $ProgressLog) {
        $content = Get-Content $ProgressLog
        $completed = $content | Where-Object { $_ -match "COMPLETED: $ItemType" }
        return ($completed -ne $null)
    }
    return $false
}

function Get-ResumeItemId {
    param(
        [string]$ItemType,
        [string]$ResumeLog
    )

    if (Test-Path $ResumeLog) {
        $content = Get-Content $ResumeLog
        foreach ($line in $content) {
            if ($line -match "^$ItemType\|(.+)$") {
                return $matches[1]
            }
        }
    }
    return $null
}

function Remove-ResumePoint {
    param(
        [string]$ItemType,
        [string]$ResumeLog
    )

    if (Test-Path $ResumeLog) {
        $content = Get-Content $ResumeLog
        $filtered = $content | Where-Object { $_ -notmatch "^$ItemType\|" }
        $filtered | Set-Content $ResumeLog
    }
}

function Set-ICMClasspath {
    Write-Header "Setting up CLASSPATH"

    # Build the ICM-specific classpath items
    # Matches the exact order and paths from the working batch script
    $icmClasspathItems = @(
        (Join-Path $script:DB2_HOME "cmgmt")
        (Join-Path $script:DB2_HOME "lib\cmbview81.jar")
        (Join-Path $script:DB2_HOME "lib\cmb81.jar")
        (Join-Path $script:DB2_HOME "lib\cmbcm81.jar")
        (Join-Path $script:DB2_HOME "lib\xsd.jar")
        (Join-Path $script:DB2_HOME "lib\common.jar")
        (Join-Path $script:DB2_HOME "lib\ecore.jar")
        (Join-Path $script:DB2_HOME "lib\ecore.xmi.jar")
        (Join-Path $script:DB2_HOME "admin\common\sacommon.jar")
        (Join-Path $script:DB2_HOME "lib\cmbicm81.jar")
        (Join-Path $script:DB2_HOME "lib\cmbwcm81.jar")
        (Join-Path $script:DB2_HOME "lib\cmbxmlmap.jar")
        (Join-Path $script:DB2_HOME "lib\Clio4CM.jar")
        (Join-Path $script:DB2_HOME "lib\jcache.jar")
        (Join-Path $script:DB2_HOME "lib\cmbutil81.jar")
        (Join-Path $script:DB2_HOME "lib\cmbutilicm81.jar")
        (Join-Path $script:DB2_HOME "lib\icmrm81.jar")
        "c:\sqllib\JAVA\DB2JAVA.ZIP"
        (Join-Path $script:DB2_HOME "lib\xerces.jar")
        (Join-Path $script:DB2_HOME "lib\cmblog4j81.jar")
        (Join-Path $script:DB2_HOME "lib\log4j-1.2.8.jar")
        (Join-Path $script:DB2_HOME "lib\cmbsdk81.jar")
        (Join-Path $script:DB2_HOME "lib\cmbwas81.jar")
    )

    # Preserve existing CLASSPATH if any, then append ICM classpath
    # This matches batch file behavior: set CLASSPATH=%CLASSPATH%;new_paths
    $existingClasspath = $env:CLASSPATH
    $existingEntriesCount = 0

    if ($existingClasspath) {
        Write-Host "Existing CLASSPATH found, appending ICM libraries..." -ForegroundColor Yellow
        # Existing CLASSPATH comes FIRST (same as batch: %CLASSPATH%;new_items)
        $env:CLASSPATH = $existingClasspath + ";" + ($icmClasspathItems -join ";")
        # Count existing entries
        $existingEntriesCount = ($existingClasspath -split ";").Count
        Write-Host "  Existing entries: $existingEntriesCount"
        Write-Host "  Adding ICM entries: $($icmClasspathItems.Count)"
    } else {
        Write-Host "No existing CLASSPATH, creating new one..."
        $env:CLASSPATH = $icmClasspathItems -join ";"
    }

    # Store classpath in script variable for use in Java command
    $script:FULL_CLASSPATH = $env:CLASSPATH

    Write-Host ""
    Write-Host "CLASSPATH configured successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "CURRENT CLASSPATH:" -ForegroundColor Cyan
    Write-Host ("=" * 76) -ForegroundColor Cyan

    # Display each classpath entry on a separate line for easy verification
    $classpathEntries = $env:CLASSPATH -split ";"
    $entryNumber = 1
    foreach ($entry in $classpathEntries) {
        if ($entry) {
            # Mark entries that came from existing CLASSPATH
            if ($existingEntriesCount -gt 0 -and $entryNumber -le $existingEntriesCount) {
                Write-Host "  [$entryNumber] $entry" -ForegroundColor DarkGray -NoNewline
                Write-Host " (from existing CLASSPATH)" -ForegroundColor DarkYellow
            } else {
                Write-Host "  [$entryNumber] $entry"
            }
            $entryNumber++
        }
    }

    Write-Host ("=" * 76) -ForegroundColor Cyan
    if ($existingEntriesCount -gt 0) {
        Write-Host "Total: $($entryNumber - 1) entries ($existingEntriesCount existing + $($icmClasspathItems.Count) ICM)" -ForegroundColor Cyan
    } else {
        Write-Host "Total classpath entries: $($entryNumber - 1)" -ForegroundColor Cyan
    }
    Write-Host ""

    # Verify critical paths exist
    Write-Host "Verifying critical paths..." -ForegroundColor Yellow
    $criticalPaths = @(
        (Join-Path $script:DB2_HOME "lib\cmb81.jar")
        (Join-Path $script:DB2_HOME "lib\cmbicm81.jar")
        "c:\sqllib\JAVA\DB2JAVA.ZIP"
    )

    $missingPaths = 0
    foreach ($path in $criticalPaths) {
        if (Test-Path $path) {
            Write-Host "  [OK] $path" -ForegroundColor Green
        } else {
            Write-Host "  [MISSING] $path" -ForegroundColor Red
            $missingPaths++
        }
    }

    if ($missingPaths -gt 0) {
        Write-Host ""
        Write-Host "WARNING: $missingPaths critical path(s) not found!" -ForegroundColor Red
        Write-Host "Please verify your JAVA_HOME and DB2_HOME settings." -ForegroundColor Red
    }
    Write-Host ""
}

function Invoke-ICMExport {
    param(
        [string]$ExportName,
        [string]$BaseFolder,
        [string]$ItemType,
        [string]$User,
        [string]$Password,
        [string]$ResumeItemId
    )

    $logFolder = Join-Path $BaseFolder "log"

    # Build command arguments with explicit classpath
    $arguments = @(
        "-classpath", "`"$script:FULL_CLASSPATH`""
        "TExportManagerICM"
        "-u", $User
        "-p", $Password
        "-m", $ExportName
        "-l", "`"$logFolder`""
        "-a", "`"$ItemType`""
        "-v", "`"$BaseFolder`""
    )

    # Add resume parameters if needed
    if ($ResumeItemId) {
        Write-Host ""
        Write-Host "INFO: Resuming from ItemID: $ResumeItemId" -ForegroundColor Yellow
        $arguments += @("-r", "-s", "`"$ResumeItemId`"")
    }

    # Display command (shortened for readability)
    Write-Host ""
    Write-Host "Executing Java Export Command:" -ForegroundColor Cyan
    Write-Host ("=" * 76) -ForegroundColor Cyan
    Write-Host "Java Executable: $script:JAVA_EXE" -ForegroundColor White
    Write-Host "Main Class: TExportManagerICM" -ForegroundColor White
    Write-Host "User: $User" -ForegroundColor White
    Write-Host "Export Name: $ExportName" -ForegroundColor White
    Write-Host "ItemType: $ItemType" -ForegroundColor White
    Write-Host "Base Folder: $BaseFolder" -ForegroundColor White
    Write-Host "Log Folder: $logFolder" -ForegroundColor White
    if ($ResumeItemId) {
        Write-Host "Resume from ItemID: $ResumeItemId" -ForegroundColor Yellow
    }
    Write-Host ""
    Write-Host "Full Command Line:" -ForegroundColor Cyan
    $cmdDisplay = "`"$script:JAVA_EXE`" -classpath `"...(see above)...`" TExportManagerICM " + ($arguments[2..($arguments.Length-1)] -join " ")
    Write-Host $cmdDisplay -ForegroundColor Gray
    Write-Host ("=" * 76) -ForegroundColor Cyan
    Write-Host ""

    # Execute export with explicit classpath
    # Note: CLASSPATH environment variable is also set as fallback
    $process = Start-Process -FilePath $script:JAVA_EXE `
                            -ArgumentList $arguments `
                            -Wait `
                            -PassThru `
                            -NoNewWindow

    return $process.ExitCode
}

function Show-ETKAnalysis {
    param(
        [string]$LogFolder,
        [string]$ExportName
    )

    Write-Header "Analyzing ETK log file"

    # Find ETK file
    $etkFile = Join-Path $LogFolder "$ExportName.etk"

    if (-not (Test-Path $etkFile)) {
        Write-Host "Warning: No ETK file found at $etkFile" -ForegroundColor Yellow
        Write-Host "Skipping package analysis"
        return
    }

    Write-Host "Found ETK file: $etkFile"
    Write-Host ""

    # Read ETK content
    $content = Get-Content $etkFile

    # Extract package information
    $completedLines = $content | Where-Object { $_ -match "Package Completed:" }
    $startedLines = $content | Where-Object { $_ -match "Package Started:" }
    $failureLines = $content | Where-Object { $_ -match "(Failure at package-level:|Failure at master-level:)" }

    $completedCount = if ($completedLines) { ($completedLines | Measure-Object).Count } else { 0 }
    $startedCount = if ($startedLines) { ($startedLines | Measure-Object).Count } else { 0 }
    $failureCount = if ($failureLines) { ($failureLines | Measure-Object).Count } else { 0 }

    # Check export status
    $exportFinished = $content | Where-Object { $_ -match "Completed All Packages:" }
    $summaryCompleted = $content | Where-Object { $_ -match "Completed Writing Summary:" }

    # Display status
    Write-Host "Export Status:"
    if ($exportFinished -and $summaryCompleted) {
        Write-Host "  STATUS: [OK] COMPLETED SUCCESSFULLY" -ForegroundColor Green
        $completionLine = $exportFinished | Select-Object -First 1
        if ($completionLine -match "Completed All Packages:\s*(.+)$") {
            Write-Host "  Completion Date: $($matches[1])"
        }
    } elseif ($failureCount -gt 0) {
        Write-Host "  STATUS: [X] FAILED (errors detected)" -ForegroundColor Red
    } elseif ($startedCount -gt $completedCount) {
        Write-Host "  STATUS: [!] INCOMPLETE (process interrupted)" -ForegroundColor Yellow
    } else {
        Write-Host "  STATUS: [!] IN PROGRESS" -ForegroundColor Yellow
    }
    Write-Host ""

    # Package summary
    Write-Host "Package Summary:"
    Write-Host "  - Packages Started: $startedCount"
    Write-Host "  - Packages Completed: $completedCount"
    if ($failureCount -gt 0) {
        Write-Host "  - Failures Detected: $failureCount" -ForegroundColor Red
    }
    Write-Host ""

    # Show failures
    if ($failureCount -gt 0) {
        Write-Header "ERRORS DETECTED IN EXPORT"
        Write-Host ""
        Write-Host "Found $failureCount failure message(s) in the ETK file:" -ForegroundColor Red
        Write-Host ""

        $displayCount = [Math]::Min(5, $failureCount)
        for ($i = 0; $i -lt $displayCount; $i++) {
            $failureLine = $failureLines[$i]
            if ($failureLine -match "package-level") {
                Write-Host "  [X] Package-level failure:" -ForegroundColor Red
            } else {
                Write-Host "  [X] Master-level failure:" -ForegroundColor Red
            }
            $errorMsg = $failureLine.Substring(0, [Math]::Min(200, $failureLine.Length))
            Write-Host "    $errorMsg"
            Write-Host ""
        }

        if ($failureCount -gt 5) {
            $moreErrors = $failureCount - 5
            Write-Host "  ... and $moreErrors more error(s)"
            Write-Host ""
        }

        Write-Host "Full error details can be found in: $etkFile"
        Write-Host ("=" * 76)
        Write-Host ""
    }

    # Check for incomplete packages
    $incomplete = $startedCount - $completedCount
    if ($incomplete -gt 0) {
        Write-Host "WARNING: Found $incomplete incomplete package(s)" -ForegroundColor Yellow
        Write-Host ""

        # Get last started package
        $lastStartedLine = $startedLines[-1]
        if ($lastStartedLine -match "Package Started:\s+(\d+)") {
            $lastStarted = $matches[1]
            Write-Host "Last package started: $lastStarted"
            Write-Host "This package did not complete (possible error or interruption)"
        }
        Write-Host ""
    }

    # Display last completed package details
    if ($completedCount -gt 0) {
        Write-Host "Last Completed Package Details:"

        $lastCompletedLine = $completedLines[-1]

        # Extract package number
        if ($lastCompletedLine -match "Package Completed:\s+(\d+)") {
            $packageNum = $matches[1]
            Write-Host "  - Package Number: $packageNum"
        }

        # Extract last item ID
        if ($lastCompletedLine -match '\[([^\]]+)\]') {
            $itemsPart = $matches[1]
            $items = $itemsPart -split ','
            $lastItem = $items[-1].Trim() -replace "[' ]", ""
            Write-Host "  - Last Item ID: $lastItem"

            # Show resume info if export is incomplete
            if (-not $exportFinished -and $lastItem) {
                Write-Host ""
                Write-Host "RESUME INFORMATION:" -ForegroundColor Yellow
                Write-Host "  To resume this export from the last completed item, the script will"
                Write-Host "  automatically use ItemID: $lastItem"
                Write-Host "  Simply run the script again with the same parameters."
            }
        }

        # Extract package path
        if ($lastCompletedLine -match '\](.+)$') {
            $packagePath = $matches[1].Trim()
            if ($packagePath) {
                Write-Host "  - Package Path: $packagePath"
            }
        }
        Write-Host ""

        # Show recently completed packages (last 10)
        Write-Host "Recently Completed Packages (last 10):"
        $recentCount = [Math]::Min(10, $completedCount)
        $startIndex = [Math]::Max(0, $completedCount - 10)

        for ($i = $startIndex; $i -lt $completedCount; $i++) {
            $line = $completedLines[$i]

            if ($line -match "Package Completed:\s+(\d+)") {
                $pkgNum = $matches[1]

                if ($line -match '\[([^\]]+)\]') {
                    $itemsPart = $matches[1]
                    $items = $itemsPart -split ','
                    $lastItem = $items[-1].Trim() -replace "[' ]", ""

                    Write-Host "  Package ${pkgNum}: Last Item = $lastItem"
                }
            }
        }
        Write-Host ""
    }
}

function Process-ItemType {
    param(
        [string]$ExportName,
        [string]$BaseFolder,
        [string]$ItemType,
        [int]$ItemTypeNumber,
        [string]$User,
        [string]$Password
    )

    # Set up folders
    $logFolder = Join-Path $BaseFolder "log"
    $progressLog = Join-Path $logFolder "export_progress.log"
    $resumeLog = Join-Path $logFolder "export_resume.log"

    # Create folders
    try {
        New-FolderIfNotExists $BaseFolder | Out-Null
        New-FolderIfNotExists $logFolder | Out-Null
    } catch {
        Write-Host "ERROR: Failed to create folders for $ExportName" -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return 1
    }

    # Initialize progress log if needed
    if (-not (Test-Path $progressLog)) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "Export Progress Log - Created: $timestamp" | Set-Content $progressLog
        "=" * 76 | Add-Content $progressLog
    }

    # Display processing header
    Write-SubHeader "Processing Itemtype #$ItemTypeNumber"
    Write-Host "Export Name: $ExportName"
    Write-Host "Base Folder: $BaseFolder"
    Write-Host "Itemtype: $ItemType"
    Write-Host "Started: $(Get-Timestamp)"
    Write-Host ("-" * 72)

    Write-Log -Message "Processing itemtype: $ItemType" -LogFile $progressLog -NoConsole

    # Check if already completed
    if (Test-ItemTypeCompleted -ItemType $ItemType -ProgressLog $progressLog) {
        Write-Host ""
        Write-Host "INFO: Itemtype $ItemType was already completed. Skipping..." -ForegroundColor Yellow
        Write-Log -Message "SKIPPED (already completed): $ItemType" -LogFile $progressLog -NoConsole
        return 0
    }

    # Check for resume point
    $resumeItemId = Get-ResumeItemId -ItemType $ItemType -ResumeLog $resumeLog
    if ($resumeItemId) {
        Write-Log -Message "RESUMING from ItemID (from resume log): $resumeItemId" -LogFile $progressLog
    } else {
        # Check if there's an incomplete export in the ETK file
        # This handles cases where the export was interrupted without a proper failure
        $lastItemId = Get-LastItemIdFromETK -ExportName $ExportName -BaseFolder $BaseFolder
        if ($lastItemId) {
            # Check if export is actually incomplete (not finished)
            $etkFile = Join-Path $logFolder "$ExportName.etk"
            if (Test-Path $etkFile) {
                $content = Get-Content $etkFile
                $exportFinished = $content | Where-Object { $_ -match "Completed All Packages:" }

                if (-not $exportFinished) {
                    # Export is incomplete - resume from last item
                    $resumeItemId = $lastItemId
                    Write-Log -Message "RESUMING from ItemID (detected incomplete export): $resumeItemId" -LogFile $progressLog
                    Write-Host ""
                    Write-Host "INFO: Detected incomplete export. Resuming from ItemID: $resumeItemId" -ForegroundColor Yellow
                }
            }
        }
    }

    # Execute export
    $exitCode = Invoke-ICMExport -ExportName $ExportName `
                                 -BaseFolder $BaseFolder `
                                 -ItemType $ItemType `
                                 -User $User `
                                 -Password $Password `
                                 -ResumeItemId $resumeItemId

    if ($exitCode -ne 0) {
        Write-Host ""
        Write-Host ("=" * 72) -ForegroundColor Red
        Write-Host "ERROR: Export failed for itemtype $ItemType with error code $exitCode" -ForegroundColor Red
        Write-Host ("=" * 72) -ForegroundColor Red
        Write-Log -Message "FAILED: $ItemType - Error code: $exitCode" -LogFile $progressLog -NoConsole

        # Get last itemid from ETK file for resume
        $lastItemId = Get-LastItemIdFromETK -ExportName $ExportName -BaseFolder $BaseFolder
        if ($lastItemId) {
            "$ItemType|$lastItemId" | Set-Content $resumeLog
            Write-Host ""
            Write-Host "RESUME INFO: Last exported ItemID: $lastItemId" -ForegroundColor Yellow
            Write-Host "RESUME INFO: To resume, run the script again" -ForegroundColor Yellow
            Write-Log -Message "Last ItemID before failure: $lastItemId" -LogFile $progressLog -NoConsole
        }

        return 1
    } else {
        Write-Host ""
        Write-Host ("=" * 72) -ForegroundColor Green
        Write-Host "SUCCESS: Export completed for itemtype $ItemType" -ForegroundColor Green
        Write-Host "Completed: $(Get-Timestamp)" -ForegroundColor Green
        Write-Host ("=" * 72) -ForegroundColor Green
        Write-Log -Message "COMPLETED: $ItemType" -LogFile $progressLog -NoConsole

        # Remove resume point if exists
        Remove-ResumePoint -ItemType $ItemType -ResumeLog $resumeLog

        return 0
    }
}

#endregion

#region Main Script

try {
    # Check ICM credentials
    if (-not $env:ICM_USER) {
        Write-Host "Error: ICM_USER environment variable is not set" -ForegroundColor Red
        Write-Host "Please set ICM_USER before running this script"
        Write-Host "Example: `$env:ICM_USER = 'your_username'"
        exit 1
    }

    if (-not $env:ICM_PASSWORD) {
        Write-Host "Error: ICM_PASSWORD environment variable is not set" -ForegroundColor Red
        Write-Host "Please set ICM_PASSWORD before running this script"
        Write-Host "Example: `$env:ICM_PASSWORD = 'your_password'"
        exit 1
    }

    # Set up CLASSPATH
    Set-ICMClasspath

    # Determine processing mode and build item list
    $itemsToProcess = @()
    $isMultiMode = $false

    if ($PSCmdlet.ParameterSetName -eq 'SingleMode') {
        # Single itemtype mode
        $itemsToProcess += [PSCustomObject]@{
            ExportName = $ExportName
            BaseFolder = $BaseFolder
            ItemType = $ItemType
        }
    } else {
        # Multi itemtype mode
        $isMultiMode = $true

        if (-not (Test-Path $ItemTypeListFile)) {
            Write-Host "Error: File not found: $ItemTypeListFile" -ForegroundColor Red
            exit 1
        }

        Write-Host "Reading itemtypes from file: $ItemTypeListFile"

        $content = Get-Content $ItemTypeListFile
        foreach ($line in $content) {
            # Skip empty lines and comments
            if ([string]::IsNullOrWhiteSpace($line) -or $line.Trim().StartsWith("#")) {
                continue
            }

            # Split by pipe (for temp files) or whitespace
            if ($line -match '\|') {
                $parts = $line -split '\|'
            } else {
                $parts = $line -split '\s+'
            }

            if ($parts.Length -ge 3) {
                $itemsToProcess += [PSCustomObject]@{
                    ExportName = $parts[0].Trim()
                    BaseFolder = $parts[1].Trim()
                    ItemType = $parts[2].Trim()
                }
            }
        }

        if ($itemsToProcess.Count -eq 0) {
            Write-Host "Error: No valid itemtypes found in $ItemTypeListFile" -ForegroundColor Red
            exit 1
        }
    }

    # Process items
    Write-Header "Starting IBM Content Manager Export"
    Write-Host "User: $env:ICM_USER"
    Write-Host "Itemtypes to process: $($itemsToProcess.Count)"
    Write-Host ""

    $totalErrors = 0
    $itemTypeCount = 0

    foreach ($item in $itemsToProcess) {
        $itemTypeCount++

        $errorCount = Process-ItemType -ExportName $item.ExportName `
                                       -BaseFolder $item.BaseFolder `
                                       -ItemType $item.ItemType `
                                       -ItemTypeNumber $itemTypeCount `
                                       -User $env:ICM_USER `
                                       -Password $env:ICM_PASSWORD

        $totalErrors += $errorCount
    }

    # Summary
    Write-Header "Export Process Summary"
    Write-Host "Total itemtypes processed: $itemTypeCount"
    Write-Host "Total errors: $totalErrors"
    Write-Host ""

    # Show ETK analysis for single mode
    if (-not $isMultiMode) {
        $logFolder = Join-Path $BaseFolder "log"
        Show-ETKAnalysis -LogFolder $logFolder -ExportName $ExportName

        Write-Header "Analysis Complete"
        Write-Host "Check logs at: $logFolder"
        Write-Host "  - Progress log: $(Join-Path $logFolder 'export_progress.log')"
        Write-Host "  - Resume log: $(Join-Path $logFolder 'export_resume.log')"
        Write-Host "Export files at: $BaseFolder"
        Write-Host ""
    } else {
        Write-Header "Multi-itemtype mode complete"
        Write-Host ""
        Write-Host "Each itemtype has its own log folder. Check individual folders for details."
        Write-Host ""
    }

    # Exit with appropriate code
    if ($totalErrors -gt 0) {
        Write-Host "WARNING: $totalErrors itemtype(s) failed. Check logs for details." -ForegroundColor Yellow
        exit 1
    } else {
        Write-Host "All exports completed successfully!" -ForegroundColor Green
        exit 0
    }

} catch {
    Write-Host ""
    Write-Host "FATAL ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host $_.ScriptStackTrace -ForegroundColor Red
    exit 1
}

#endregion

@echo off
REM ============================================================================
REM IBM Content Manager Export Script for Windows - Enhanced Version
REM ============================================================================
REM Usage:
REM   Single itemtype: export_icm.bat <export_name> <base_folder> <itemtype>
REM   Multiple itemtypes: export_icm.bat <itemtype_list_file>
REM
REM Examples:
REM   export_icm.bat 007ClientesConstruya G:\007_Clientes_Construya "V03206007003D"
REM   export_icm.bat itemtypes.txt
REM
REM itemtypes.txt format (space or tab separated):
REM   <export_name> <base_folder> <itemtype>
REM   007ClientesFacRI G:\007_Clientes_Fac_RI V03206007002D
REM   007ClientesConstruya G:\007_Clientes_Construya V03206007003D
REM
REM Features:
REM   - Process single or multiple itemtypes from a file
REM   - Each itemtype can have its own export name and base folder
REM   - Resume capability: if process stops, automatically resume from last position
REM   - Detailed logging of progress and resume information
REM   - Automatic detection of last itemid from .etk file for resume
REM ============================================================================

SETLOCAL EnableDelayedExpansion

REM Check if required parameters are provided
IF "%~1"=="" (
    echo Error: At least one parameter is required
    echo.
    echo Usage:
    echo   Single itemtype: %0 ^<export_name^> ^<base_folder^> ^<itemtype^>
    echo   Multiple itemtypes: %0 ^<itemtype_list_file^>
    echo.
    echo itemtypes.txt format ^(space or tab separated^):
    echo   ^<export_name^> ^<base_folder^> ^<itemtype^>
    echo   007ClientesFacRI G:\007_Clientes_Fac_RI V03206007002D
    echo   007ClientesConstruya G:\007_Clientes_Construya V03206007003D
    echo.
    echo Examples:
    echo   %0 007ClientesConstruya G:\007_Clientes_Construya "V03206007003D"
    echo   %0 itemtypes.txt
    exit /b 1
)

REM Configuration - Java and DB2 paths
SET JAVA_HOME=E:\jdk1.6.0_26
SET DB2_HOME=E:\IBM\db2cmv8
SET JAVA_EXE=%JAVA_HOME%\bin\java

REM ICM credentials - MUST be set via environment variables before running
REM Example: SET ICM_USER=your_username
REM Example: SET ICM_PASSWORD=your_password
IF "%ICM_USER%"=="" (
    echo Error: ICM_USER environment variable is not set
    echo Please set ICM_USER before running this script
    echo Example: SET ICM_USER=your_username
    exit /b 1
)
IF "%ICM_PASSWORD%"=="" (
    echo Error: ICM_PASSWORD environment variable is not set
    echo Please set ICM_PASSWORD before running this script
    echo Example: SET ICM_PASSWORD=your_password
    exit /b 1
)

REM ============================================================================
REM Determine if we're processing a single itemtype or a list
REM ============================================================================
SET IS_FILE=0
SET IS_MULTI_MODE=0

IF EXIST "%~1" (
    REM File mode: itemtypes.txt with three columns
    SET IS_FILE=1
    SET IS_MULTI_MODE=1
    SET ITEMTYPE_LIST_FILE=%~1
) ELSE IF NOT "%~1"=="" IF NOT "%~2"=="" IF NOT "%~3"=="" (
    REM Single itemtype mode: export_name base_folder itemtype
    SET IS_FILE=0
    SET IS_MULTI_MODE=0
    SET EXPORT_NAME=%~1
    SET BASE_FOLDER=%~2
    SET ITEMTYPE_PARAM=%~3
    SET LOG_FOLDER=%~2\log
    SET PROGRESS_LOG=%~2\log\export_progress.log
    SET RESUME_LOG=%~2\log\export_resume.log

    REM Create folders first to avoid "path not found" errors
    IF NOT EXIST "%BASE_FOLDER%" mkdir "%BASE_FOLDER%"
    IF NOT EXIST "%LOG_FOLDER%" mkdir "%LOG_FOLDER%"

    REM Create temporary file with three columns in log folder
    SET ITEMTYPE_LIST_FILE=!LOG_FOLDER!\itemtypes_temp_%RANDOM%.txt
    echo !EXPORT_NAME! !BASE_FOLDER! !ITEMTYPE_PARAM!>"!ITEMTYPE_LIST_FILE!"
) ELSE (
    echo Error: Invalid parameters
    echo Provide either ^<itemtype_list_file^> or ^<export_name^> ^<base_folder^> ^<itemtype^>
    exit /b 1
)

REM ============================================================================
REM Create required folders (only for single itemtype mode)
REM ============================================================================
IF %IS_MULTI_MODE% EQU 0 (
    echo.
    echo ============================================================================
    echo Creating folder structure...
    echo ============================================================================
    echo Base folder: %BASE_FOLDER%
    echo Log folder: %LOG_FOLDER%
    echo.

    IF NOT EXIST "%BASE_FOLDER%" (
        echo Creating base folder: %BASE_FOLDER%
        mkdir "%BASE_FOLDER%"
        IF ERRORLEVEL 1 (
            echo Error: Failed to create base folder
            exit /b 1
        )
        echo Base folder created successfully
    ) ELSE (
        echo Base folder already exists
    )

    IF NOT EXIST "%LOG_FOLDER%" (
        echo Creating log folder: %LOG_FOLDER%
        mkdir "%LOG_FOLDER%"
        IF ERRORLEVEL 1 (
            echo Error: Failed to create log folder
            exit /b 1
        )
        echo Log folder created successfully
    ) ELSE (
        echo Log folder already exists
    )

    REM ============================================================================
    REM Initialize progress log
    REM ============================================================================
    IF NOT EXIST "%PROGRESS_LOG%" (
        echo Export Progress Log - Created: %DATE% %TIME% > "%PROGRESS_LOG%"
        echo ============================================================================ >> "%PROGRESS_LOG%"
    )
)

REM ============================================================================
REM Set CLASSPATH
REM ============================================================================
echo.
echo ============================================================================
echo Setting up CLASSPATH...
echo ============================================================================

set CLASSPATH=%CLASSPATH%;%DB2_HOME%\cmgmt
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\cmbview81.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\cmb81.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\cmbcm81.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\xsd.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\common.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\ecore.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\ecore.xmi.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\admin\common\sacommon.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\cmbicm81.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\cmbwcm81.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\cmbxmlmap.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\Clio4CM.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\jcache.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\cmbutil81.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\cmbutilicm81.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\icmrm81.jar
set CLASSPATH=%CLASSPATH%;c:\sqllib\JAVA\DB2JAVA.ZIP
set CLASSPATH=%CLASSPATH%;C:\oracle\ora92\jdbc\lib\ojdbc14.jar
set CLASSPATH=%CLASSPATH%;C:\oracle\ora92\jdbc\lib\nls_charset12.zip
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\xerces.jar
set CLASSPATH=%CLASSPATH%;\java\ibmjndi.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\cmblog4j81.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\log4j-1.2.8.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\cmbsdk81.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\lib\cmbwas81.jar
set CLASSPATH=%CLASSPATH%;%DB2_HOME%\samples\java\icm\Sample1

echo CLASSPATH configured successfully
echo.

REM Skip function definitions and go to main processing
goto :StartProcessing

REM ============================================================================
REM Function to get last itemid from ETK file
REM Parameters: %1=export_name, %2=base_folder
REM ============================================================================
:GetLastItemId
SET _EXPORT_NAME=%~1
SET _BASE_FOLDER=%~2
SET _LOG_FOLDER=%_BASE_FOLDER%\log
SET ETK_FILE=%_LOG_FOLDER%\%_EXPORT_NAME%.etk
SET LAST_ITEMID=
IF EXIST "%ETK_FILE%" (
    REM Look for the last "Package Completed:" line
    REM Format: Package Completed:  2814    : '291     ' ('A1001001A14D24B72939B49768', 'A1001001A20B28B71115J61199'] G:\007_Clientes_Fac_RI\masterPackage\package2814
    REM We need to extract the LAST itemid from the tuple (the one before '])
    SET LAST_COMPLETED_LINE=
    FOR /F "usebackq tokens=*" %%L IN (`findstr /C:"Package Completed:" "%ETK_FILE%"`) DO SET LAST_COMPLETED_LINE=%%L

    IF NOT "!LAST_COMPLETED_LINE!"=="" (
        REM Extract the last ItemID from the tuple
        REM Remove everything up to and including the opening bracket
        FOR /F "tokens=2 delims=[" %%B IN ("!LAST_COMPLETED_LINE!") DO SET TEMP_LINE=%%B
        REM Remove everything after and including the closing bracket
        FOR /F "tokens=1 delims=]" %%C IN ("!TEMP_LINE!") DO SET ITEMS_PART=%%C
        REM Get the last item (after the last comma)
        SET ITEM_RAW=
        FOR %%E IN (!ITEMS_PART!) DO SET ITEM_RAW=%%E
        REM Remove quotes, spaces, and commas from the item
        SET LAST_ITEMID=!ITEM_RAW:'=!
        SET LAST_ITEMID=!LAST_ITEMID: =!
        SET LAST_ITEMID=!LAST_ITEMID:,=!
    )

    REM Fallback: try XML format if Package Completed format didn't work
    IF "!LAST_ITEMID!"=="" (
        for /f "usebackq tokens=*" %%a in ("%ETK_FILE%") do (
            SET LAST_LINE=%%a
        )
        REM Extract itemid from XML tags (format: <itemid>...</itemid>)
        for /f "tokens=2 delims=<>" %%a in ("!LAST_LINE!") do (
            if "%%a" NEQ "itemid" (
                SET LAST_ITEMID=%%a
            )
        )
    )
)
goto :eof

REM ============================================================================
REM Main Processing Section
REM ============================================================================
:StartProcessing

REM ============================================================================
REM Process each itemtype
REM ============================================================================
echo.
echo ============================================================================
echo Starting IBM Content Manager Export...
echo ============================================================================
echo User: %ICM_USER%
echo Itemtype List File: !ITEMTYPE_LIST_FILE!
echo.

SET TOTAL_ERRORS=0
SET ITEMTYPE_COUNT=0

REM Read itemtypes from file (format: export_name base_folder itemtype)
for /f "usebackq tokens=1,2,3,*" %%a in ("!ITEMTYPE_LIST_FILE!") do (
    SET CURRENT_EXPORT_NAME=%%a
    SET CURRENT_BASE_FOLDER=%%b
    SET CURRENT_ITEMTYPE=%%c
    SET SHOULD_PROCESS=1

    REM Skip empty lines and comments
    IF "!CURRENT_EXPORT_NAME!"=="" SET SHOULD_PROCESS=0
    IF "!CURRENT_EXPORT_NAME:~0,1!"=="#" SET SHOULD_PROCESS=0
    IF "!CURRENT_BASE_FOLDER!"=="" SET SHOULD_PROCESS=0
    IF "!CURRENT_ITEMTYPE!"=="" SET SHOULD_PROCESS=0

    IF !SHOULD_PROCESS! EQU 1 (
        REM Set up folders for this itemtype
        SET CURRENT_LOG_FOLDER=!CURRENT_BASE_FOLDER!\log
        SET CURRENT_PROGRESS_LOG=!CURRENT_LOG_FOLDER!\export_progress.log
        SET CURRENT_RESUME_LOG=!CURRENT_LOG_FOLDER!\export_resume.log

        REM Create folders for this itemtype
        IF NOT EXIST "!CURRENT_BASE_FOLDER!" (
            mkdir "!CURRENT_BASE_FOLDER!"
            IF ERRORLEVEL 1 (
                echo ERROR: Failed to create base folder: !CURRENT_BASE_FOLDER!
                SET /A TOTAL_ERRORS+=1
                SET SHOULD_PROCESS=0
            )
        )

        IF !SHOULD_PROCESS! EQU 1 IF NOT EXIST "!CURRENT_LOG_FOLDER!" (
            mkdir "!CURRENT_LOG_FOLDER!"
            IF ERRORLEVEL 1 (
                echo ERROR: Failed to create log folder: !CURRENT_LOG_FOLDER!
                SET /A TOTAL_ERRORS+=1
                SET SHOULD_PROCESS=0
            )
        )

        REM Initialize progress log if needed
        IF NOT EXIST "!CURRENT_PROGRESS_LOG!" (
            echo Export Progress Log - Created: %DATE% %TIME% > "!CURRENT_PROGRESS_LOG!"
            echo ============================================================================ >> "!CURRENT_PROGRESS_LOG!"
        )

        SET /A ITEMTYPE_COUNT+=1

        echo.
        echo ========================================================================
        echo Processing Itemtype #!ITEMTYPE_COUNT!
        echo Export Name: !CURRENT_EXPORT_NAME!
        echo Base Folder: !CURRENT_BASE_FOLDER!
        echo Itemtype: !CURRENT_ITEMTYPE!
        echo Started: %DATE% %TIME%
        echo ========================================================================

        REM Log progress
        echo [%DATE% %TIME%] Processing itemtype: !CURRENT_ITEMTYPE! >> "!CURRENT_PROGRESS_LOG!"

        REM Check if this itemtype was already completed
        findstr /C:"COMPLETED: !CURRENT_ITEMTYPE!" "!CURRENT_PROGRESS_LOG!" >nul 2>&1
        IF !ERRORLEVEL! EQU 0 (
            echo.
            echo INFO: Itemtype !CURRENT_ITEMTYPE! was already completed. Skipping...
            echo [%DATE% %TIME%] SKIPPED (already completed): !CURRENT_ITEMTYPE! >> "!CURRENT_PROGRESS_LOG!"
            goto :SkipLine
        )

        REM Check for resume point
        SET RESUME_ITEMID=
        IF EXIST "!CURRENT_RESUME_LOG!" (
            for /f "usebackq tokens=1,2 delims=|" %%x in ("!CURRENT_RESUME_LOG!") do (
                if "%%x"=="!CURRENT_ITEMTYPE!" (
                    SET RESUME_ITEMID=%%y
                )
            )
        )

        REM Build export command
        SET EXPORT_CMD="%JAVA_EXE%" TExportManagerICM -u %ICM_USER% -p %ICM_PASSWORD% -m !CURRENT_EXPORT_NAME! -l "!CURRENT_LOG_FOLDER!" -a "!CURRENT_ITEMTYPE!" -v "!CURRENT_BASE_FOLDER!"

        REM Add resume parameters if we have a resume point
        IF NOT "!RESUME_ITEMID!"=="" (
            echo.
            echo INFO: Resuming from ItemID: !RESUME_ITEMID!
            echo [!DATE! !TIME!] RESUMING from ItemID: !RESUME_ITEMID! >> "!CURRENT_PROGRESS_LOG!"
            SET EXPORT_CMD=!EXPORT_CMD! -r -s "!RESUME_ITEMID!"
        )

        echo.
        echo Command: !EXPORT_CMD!
        echo.

        REM Execute export
        !EXPORT_CMD!

        SET EXPORT_STATUS=!ERRORLEVEL!

        IF !EXPORT_STATUS! NEQ 0 (
            echo.
            echo ====================================================================
            echo ERROR: Export failed for itemtype !CURRENT_ITEMTYPE! with error code !EXPORT_STATUS!
            echo ====================================================================
            echo [!DATE! !TIME!] FAILED: !CURRENT_ITEMTYPE! - Error code: !EXPORT_STATUS! >> "!CURRENT_PROGRESS_LOG!"

            REM Get last itemid from ETK file for resume
            call :GetLastItemId "!CURRENT_EXPORT_NAME!" "!CURRENT_BASE_FOLDER!"
            IF NOT "!LAST_ITEMID!"=="" (
                echo !CURRENT_ITEMTYPE!|!LAST_ITEMID! > "!CURRENT_RESUME_LOG!"
                echo.
                echo RESUME INFO: Last exported ItemID: !LAST_ITEMID!
                echo RESUME INFO: To resume, run the script again
                echo [!DATE! !TIME!] Last ItemID before failure: !LAST_ITEMID! >> "!CURRENT_PROGRESS_LOG!"
            )

            SET /A TOTAL_ERRORS+=1
        ) ELSE (
            echo.
            echo ====================================================================
            echo SUCCESS: Export completed for itemtype !CURRENT_ITEMTYPE!
            echo Completed: !DATE! !TIME!
            echo ====================================================================
            echo [!DATE! !TIME!] COMPLETED: !CURRENT_ITEMTYPE! >> "!CURRENT_PROGRESS_LOG!"

            REM Remove resume point if exists
            IF EXIST "!CURRENT_RESUME_LOG!" (
                findstr /V /C:"!CURRENT_ITEMTYPE!|" "!CURRENT_RESUME_LOG!" > "!CURRENT_RESUME_LOG!.tmp" 2>nul
                move /Y "!CURRENT_RESUME_LOG!.tmp" "!CURRENT_RESUME_LOG!" >nul 2>&1
            )
        )

        :SkipLine
    )
)

REM ============================================================================
REM Summary
REM ============================================================================
echo.
echo ============================================================================
echo Export Process Summary
echo ============================================================================
echo Total itemtypes processed: %ITEMTYPE_COUNT%
echo Total errors: %TOTAL_ERRORS%
echo.

REM ============================================================================
REM Parse ETK log file for package information (only for single itemtype mode)
REM ============================================================================
IF %IS_MULTI_MODE% EQU 0 (
    echo ============================================================================
    echo Analyzing ETK log file...
    echo ============================================================================
    echo.

    REM Find the ETK file in the log folder
    SET ETK_FILE=
    FOR %%F IN ("%LOG_FOLDER%\*.etk") DO (
        SET ETK_FILE=%%F
        GOTO :FoundETK
    )

    :FoundETK
    IF "%ETK_FILE%"=="" (
        echo Warning: No ETK file found in %LOG_FOLDER%
        echo Skipping package analysis
        GOTO :EndAnalysis
    )

    IF NOT EXIST "%ETK_FILE%" (
        echo Warning: No ETK file found in %LOG_FOLDER%
        echo Skipping package analysis
        GOTO :EndAnalysis
    )

echo Found ETK file: %ETK_FILE%
echo.

REM Create temporary files for processing in log folder
SET TEMP_COMPLETED=%LOG_FOLDER%\etk_completed_%RANDOM%.txt
SET TEMP_STARTED=%LOG_FOLDER%\etk_started_%RANDOM%.txt
SET TEMP_FAILURES=%LOG_FOLDER%\etk_failures_%RANDOM%.txt

REM Extract package information
findstr /C:"Package Completed:" "%ETK_FILE%" > "%TEMP_COMPLETED%" 2>nul
findstr /C:"Package Started:" "%ETK_FILE%" > "%TEMP_STARTED%" 2>nul
findstr /C:"Failure at package-level:" /C:"Failure at master-level:" "%ETK_FILE%" > "%TEMP_FAILURES%" 2>nul

REM Count lines in files
SET COMPLETED_COUNT=0
SET STARTED_COUNT=0
SET FAILURE_COUNT=0

FOR /F %%A IN ('type "%TEMP_COMPLETED%" 2^>nul ^| find /c /v ""') DO SET COMPLETED_COUNT=%%A
FOR /F %%A IN ('type "%TEMP_STARTED%" 2^>nul ^| find /c /v ""') DO SET STARTED_COUNT=%%A
FOR /F %%A IN ('type "%TEMP_FAILURES%" 2^>nul ^| find /c /v ""') DO SET FAILURE_COUNT=%%A

REM Check if export completed successfully
SET EXPORT_FINISHED=0
SET SUMMARY_COMPLETED=0
findstr /C:"Completed All Packages:" "%ETK_FILE%" >nul 2>&1 && SET EXPORT_FINISHED=1
findstr /C:"Completed Writing Summary:" "%ETK_FILE%" >nul 2>&1 && SET SUMMARY_COMPLETED=1

echo Export Status:
IF %EXPORT_FINISHED% EQU 1 IF %SUMMARY_COMPLETED% EQU 1 (
    echo   STATUS: [OK] COMPLETED SUCCESSFULLY
    FOR /F "usebackq tokens=2,* delims=:" %%D IN (`findstr /C:"Completed All Packages:" "%ETK_FILE%"`) DO (
        echo   Completion Date:%%D:%%E
    )
) ELSE IF %FAILURE_COUNT% GTR 0 (
    echo   STATUS: [X] FAILED ^(errors detected^)
) ELSE IF %STARTED_COUNT% GTR %COMPLETED_COUNT% (
    echo   STATUS: [!] INCOMPLETE ^(process interrupted^)
) ELSE (
    echo   STATUS: [!] IN PROGRESS
)
echo.

echo Package Summary:
echo   - Packages Started: %STARTED_COUNT%
echo   - Packages Completed: %COMPLETED_COUNT%
IF %FAILURE_COUNT% GTR 0 (
    echo   - Failures Detected: %FAILURE_COUNT%
)
echo.

REM Check for failures
IF %FAILURE_COUNT% GTR 0 (
    echo ============================================================================
    echo ERRORS DETECTED IN EXPORT
    echo ============================================================================
    echo.
    echo Found %FAILURE_COUNT% failure message^(s^) in the ETK file:
    echo.

    REM Display first 5 failures (to avoid overwhelming output)
    SET FAIL_COUNTER=0
    FOR /F "usebackq tokens=*" %%F IN ("%TEMP_FAILURES%") DO (
        IF !FAIL_COUNTER! LSS 5 (
            SET FAILURE_LINE=%%F
            echo !FAILURE_LINE! | findstr /C:"package-level" >nul 2>&1
            IF !ERRORLEVEL! EQU 0 (
                echo   [X] Package-level failure:
            ) ELSE (
                echo   [X] Master-level failure:
            )
            REM Display first 200 chars of error (batch limitation)
            SET ERROR_MSG=!FAILURE_LINE:~0,200!
            echo     !ERROR_MSG!
            echo.
            SET /A FAIL_COUNTER+=1
        )
    )

    IF %FAILURE_COUNT% GTR 5 (
        SET /A MORE_ERRORS=FAILURE_COUNT-5
        echo   ... and !MORE_ERRORS! more error^(s^)
        echo.
    )

    echo Full error details can be found in: %ETK_FILE%
    echo ============================================================================
    echo.
)

REM Check for incomplete packages
SET /A INCOMPLETE=STARTED_COUNT-COMPLETED_COUNT
IF %INCOMPLETE% GTR 0 (
    echo WARNING: Found %INCOMPLETE% incomplete package^(s^)
    echo.

    REM Extract the last started package number
    FOR /F "tokens=*" %%L IN (%TEMP_STARTED%) DO SET LAST_STARTED_LINE=%%L
    FOR /F "tokens=3" %%N IN ("!LAST_STARTED_LINE!") DO SET LAST_STARTED=%%N

    echo Last package started: !LAST_STARTED!
    echo This package did not complete ^(possible error or interruption^)

    REM Check for retries (multiple starts of same package)
    IF NOT "!LAST_STARTED!"=="" (
        SET RETRY_COUNT=0
        FOR /F %%R IN ('findstr /C:"Package Started:  !LAST_STARTED!" "%TEMP_STARTED%" ^| find /c /v ""') DO SET RETRY_COUNT=%%R
        IF !RETRY_COUNT! GTR 1 (
            echo Package !LAST_STARTED! was attempted !RETRY_COUNT! times ^(retries detected^)
        )
    )
    echo.
)

REM Display last completed package and its last item ID
IF %COMPLETED_COUNT% GTR 0 (
    echo Last Completed Package Details:

    REM Get the last completed line
    FOR /F "tokens=*" %%L IN (%TEMP_COMPLETED%) DO SET LAST_COMPLETED_LINE=%%L

    REM Extract package number (after "Package Completed:" and before ":")
    FOR /F "tokens=3 delims=: " %%N IN ("!LAST_COMPLETED_LINE!") DO SET PACKAGE_NUM=%%N

    REM Extract the last item ID (between the last single quote pair before ']')
    REM This is complex in batch, so we'll use a simpler approach
    SET LINE=!LAST_COMPLETED_LINE!

    REM Find the last item ID - it's between quotes after the last comma before ']'
    FOR /F "tokens=*" %%A IN ("!LINE!") DO (
        SET TEMP_LINE=%%A
        REM Remove everything up to and including the opening bracket
        FOR /F "tokens=2 delims=[" %%B IN ("!TEMP_LINE!") DO SET TEMP_LINE=%%B
        REM Remove everything after and including the closing bracket
        FOR /F "tokens=1 delims=]" %%C IN ("!TEMP_LINE!") DO SET ITEMS_PART=%%C
        REM Get the last item (after the last comma)
        FOR /F "tokens=* delims=," %%D IN ("!ITEMS_PART!") DO SET LAST_PART=%%D
        REM Find items separated by comma and get the last one
        SET ITEM_COUNTER=0
        FOR %%E IN (!ITEMS_PART!) DO (
            SET LAST_ITEM_RAW=%%E
            SET /A ITEM_COUNTER+=1
        )
        REM Remove quotes and spaces from the item
        SET LAST_ITEM_ID=!LAST_ITEM_RAW:'=!
        SET LAST_ITEM_ID=!LAST_ITEM_ID: =!
        SET LAST_ITEM_ID=!LAST_ITEM_ID:,=!
    )

    REM Extract the path (everything after ']')
    FOR /F "tokens=2 delims=]" %%P IN ("!LAST_COMPLETED_LINE!") DO SET PACKAGE_PATH=%%P

    echo   - Package Number: !PACKAGE_NUM!
    echo   - Last Item ID: !LAST_ITEM_ID!
    IF NOT "!PACKAGE_PATH!"=="" (
        echo   - Package Path:!PACKAGE_PATH!
    )
    echo.

    REM If export is incomplete, show resume information
    IF %EXPORT_FINISHED% EQU 0 IF NOT "!LAST_ITEM_ID!"=="" (
        echo RESUME INFORMATION:
        echo   To resume this export from the last completed item, the script will
        echo   automatically use ItemID: !LAST_ITEM_ID!
        echo   Simply run the script again with the same parameters.
        echo.
    )

    REM Display recently completed packages (last 10)
    echo Recently Completed Packages ^(last 10^):
    SET PKG_COUNTER=0
    SET /A TARGET_START=COMPLETED_COUNT-10
    IF %TARGET_START% LSS 0 SET TARGET_START=0
    FOR /F "usebackq tokens=*" %%L IN ("%TEMP_COMPLETED%") DO (
        SET /A PKG_COUNTER+=1
        IF !PKG_COUNTER! GTR %TARGET_START% (
            SET COMP_LINE=%%L

            REM Extract package number
            FOR /F "tokens=3 delims=: " %%N IN ("!COMP_LINE!") DO SET PKG_NUM=%%N

            REM Extract last item ID (simplified extraction)
            FOR /F "tokens=2 delims=[" %%B IN ("!COMP_LINE!") DO SET TEMP_ITEMS=%%B
            FOR /F "tokens=1 delims=]" %%C IN ("!TEMP_ITEMS!") DO SET ITEMS_ONLY=%%C

            REM Get the last element
            SET ITEM_RAW=
            FOR %%E IN (!ITEMS_ONLY!) DO SET ITEM_RAW=%%E
            SET ITEM_ID=!ITEM_RAW:'=!
            SET ITEM_ID=!ITEM_ID: =!
            SET ITEM_ID=!ITEM_ID:,=!

            IF NOT "!PKG_NUM!"=="" (
                IF NOT "!ITEM_ID!"=="" (
                    echo   Package !PKG_NUM!: Last Item = !ITEM_ID!
                )
            )
        )
    )
    echo.
)

    REM Cleanup temporary files
    IF EXIST "%TEMP_COMPLETED%" DEL /Q "%TEMP_COMPLETED%"
    IF EXIST "%TEMP_STARTED%" DEL /Q "%TEMP_STARTED%"
    IF EXIST "%TEMP_FAILURES%" DEL /Q "%TEMP_FAILURES%"

    :EndAnalysis
    echo ============================================================================
    echo Analysis Complete
    echo ============================================================================
    echo.
    echo Check logs at: %LOG_FOLDER%
    echo   - Progress log: %PROGRESS_LOG%
    echo   - Resume log: %RESUME_LOG%
    echo Export files at: %BASE_FOLDER%
    echo.
) ELSE (
    echo ============================================================================
    echo Multi-itemtype mode complete
    echo ============================================================================
    echo.
    echo Each itemtype has its own log folder. Check individual folders for details.
    echo.
)

REM Clean up temp file if created
IF %IS_FILE% EQU 0 (
    del "%ITEMTYPE_LIST_FILE%" >nul 2>&1
)

IF %TOTAL_ERRORS% GTR 0 (
    echo WARNING: %TOTAL_ERRORS% itemtype(s) failed. Check logs for details.
    ENDLOCAL
    exit /b 1
) ELSE (
    echo All exports completed successfully!
    ENDLOCAL
    exit /b 0
)

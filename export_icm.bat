@echo off
REM ============================================================================
REM IBM Content Manager Export Script for Windows - Enhanced Version
REM ============================================================================
REM Usage:
REM   Single itemtype: export_icm.bat <export_name> <base_folder> <itemtype>
REM   Multiple itemtypes: export_icm.bat <export_name> <base_folder> <itemtype_list_file>
REM
REM Examples:
REM   export_icm.bat 007ClientesConstruya G:\007_Clientes_Construya "V03206007003D"
REM   export_icm.bat 007ClientesFacRI G:\007_Clientes_Fac_RI itemtypes.txt
REM
REM Features:
REM   - Process single or multiple itemtypes from a file
REM   - Resume capability: if process stops, automatically resume from last position
REM   - Detailed logging of progress and resume information
REM   - Automatic detection of last itemid from .etk file for resume
REM ============================================================================

SETLOCAL EnableDelayedExpansion

REM Check if required parameters are provided
IF "%~1"=="" (
    echo Error: Export name is required
    echo.
    echo Usage:
    echo   Single itemtype: %0 ^<export_name^> ^<base_folder^> ^<itemtype^>
    echo   Multiple itemtypes: %0 ^<export_name^> ^<base_folder^> ^<itemtype_list_file^>
    echo.
    echo Examples:
    echo   %0 007ClientesConstruya G:\007_Clientes_Construya "V03206007003D"
    echo   %0 007ClientesFacRI G:\007_Clientes_Fac_RI itemtypes.txt
    exit /b 1
)

IF "%~2"=="" (
    echo Error: Base folder is required
    echo.
    echo Usage:
    echo   Single itemtype: %0 ^<export_name^> ^<base_folder^> ^<itemtype^>
    echo   Multiple itemtypes: %0 ^<export_name^> ^<base_folder^> ^<itemtype_list_file^>
    echo.
    echo Examples:
    echo   %0 007ClientesConstruya G:\007_Clientes_Construya "V03206007003D"
    echo   %0 007ClientesFacRI G:\007_Clientes_Fac_RI itemtypes.txt
    exit /b 1
)

IF "%~3"=="" (
    echo Error: Itemtype or itemtype list file is required
    echo.
    echo Usage:
    echo   Single itemtype: %0 ^<export_name^> ^<base_folder^> ^<itemtype^>
    echo   Multiple itemtypes: %0 ^<export_name^> ^<base_folder^> ^<itemtype_list_file^>
    echo.
    echo Examples:
    echo   %0 007ClientesConstruya G:\007_Clientes_Construya "V03206007003D"
    echo   %0 007ClientesFacRI G:\007_Clientes_Fac_RI itemtypes.txt
    exit /b 1
)

REM Set parameters
SET EXPORT_NAME=%~1
SET BASE_FOLDER=%~2
SET ITEMTYPE_PARAM=%~3
SET LOG_FOLDER=%BASE_FOLDER%\log
SET PROGRESS_LOG=%LOG_FOLDER%\export_progress.log
SET RESUME_LOG=%LOG_FOLDER%\export_resume.log

REM Configuration - Java and DB2 paths
SET JAVA_HOME=E:\jdk1.6.0_26
SET DB2_HOME=E:\IBM\db2cmv8
SET JAVA_EXE=%JAVA_HOME%\bin\java

REM ICM credentials (can be modified as needed)
SET ICM_USER=icmadmin
SET ICM_PASSWORD=Evolucion

REM ============================================================================
REM Determine if we're processing a single itemtype or a list
REM ============================================================================
SET IS_FILE=0
IF EXIST "%ITEMTYPE_PARAM%" (
    SET IS_FILE=1
    SET ITEMTYPE_LIST_FILE=%ITEMTYPE_PARAM%
) ELSE (
    REM Single itemtype - create temporary file
    SET ITEMTYPE_LIST_FILE=%TEMP%\itemtypes_temp_%RANDOM%.txt
    echo %ITEMTYPE_PARAM%>"%ITEMTYPE_LIST_FILE%"
)

REM ============================================================================
REM Create required folders
REM ============================================================================
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

echo CLASSPATH configured successfully
echo.

REM ============================================================================
REM Function to get last itemid from ETK file
REM ============================================================================
:GetLastItemId
SET ETK_FILE=%BASE_FOLDER%\%EXPORT_NAME%.etk
SET LAST_ITEMID=
IF EXIST "%ETK_FILE%" (
    for /f "usebackq tokens=*" %%a in ("%ETK_FILE%") do (
        SET LAST_LINE=%%a
    )
    REM Extract itemid from the last line (format: <itemid>...</itemid>)
    for /f "tokens=2 delims=<>" %%a in ("!LAST_LINE!") do (
        if "%%a" NEQ "itemid" (
            SET LAST_ITEMID=%%a
        )
    )
)
goto :eof

REM ============================================================================
REM Process each itemtype
REM ============================================================================
echo.
echo ============================================================================
echo Starting IBM Content Manager Export...
echo ============================================================================
echo Export Name: %EXPORT_NAME%
echo Export Folder: %BASE_FOLDER%
echo Log Folder: %LOG_FOLDER%
echo User: %ICM_USER%
echo Itemtype List File: %ITEMTYPE_LIST_FILE%
echo.

SET TOTAL_ERRORS=0
SET ITEMTYPE_COUNT=0

for /f "usebackq tokens=*" %%i in ("%ITEMTYPE_LIST_FILE%") do (
    SET CURRENT_ITEMTYPE=%%i
    SET /A ITEMTYPE_COUNT+=1

    REM Skip empty lines
    IF NOT "!CURRENT_ITEMTYPE!"=="" (
        echo.
        echo ========================================================================
        echo Processing Itemtype #!ITEMTYPE_COUNT!: !CURRENT_ITEMTYPE!
        echo Started: !DATE! !TIME!
        echo ========================================================================

        REM Log progress
        echo [!DATE! !TIME!] Processing itemtype: !CURRENT_ITEMTYPE! >> "%PROGRESS_LOG%"

        REM Check if this itemtype was already completed
        findstr /C:"COMPLETED: !CURRENT_ITEMTYPE!" "%PROGRESS_LOG%" >nul 2>&1
        IF !ERRORLEVEL! EQU 0 (
            echo.
            echo INFO: Itemtype !CURRENT_ITEMTYPE! was already completed. Skipping...
            echo [!DATE! !TIME!] SKIPPED (already completed): !CURRENT_ITEMTYPE! >> "%PROGRESS_LOG%"
            goto :NextItemtype
        )

        REM Check for resume point
        SET RESUME_ITEMID=
        IF EXIST "%RESUME_LOG%" (
            for /f "usebackq tokens=1,2 delims=|" %%a in ("%RESUME_LOG%") do (
                if "%%a"=="!CURRENT_ITEMTYPE!" (
                    SET RESUME_ITEMID=%%b
                )
            )
        )

        REM Build export command
        SET EXPORT_CMD="%JAVA_EXE%" TExportManagerICM -u %ICM_USER% -p %ICM_PASSWORD% -m %EXPORT_NAME% -l "%LOG_FOLDER%" -a "!CURRENT_ITEMTYPE!" -v "%BASE_FOLDER%"

        REM Add resume parameters if we have a resume point
        IF NOT "!RESUME_ITEMID!"=="" (
            echo.
            echo INFO: Resuming from ItemID: !RESUME_ITEMID!
            echo [!DATE! !TIME!] RESUMING from ItemID: !RESUME_ITEMID! >> "%PROGRESS_LOG%"
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
            echo [!DATE! !TIME!] FAILED: !CURRENT_ITEMTYPE! - Error code: !EXPORT_STATUS! >> "%PROGRESS_LOG%"

            REM Get last itemid from ETK file for resume
            call :GetLastItemId
            IF NOT "!LAST_ITEMID!"=="" (
                echo !CURRENT_ITEMTYPE!|!LAST_ITEMID! > "%RESUME_LOG%"
                echo.
                echo RESUME INFO: Last exported ItemID: !LAST_ITEMID!
                echo RESUME INFO: To resume, run the script again
                echo [!DATE! !TIME!] Last ItemID before failure: !LAST_ITEMID! >> "%PROGRESS_LOG%"
            )

            SET /A TOTAL_ERRORS+=1
            REM Continue with next itemtype instead of exiting
            goto :NextItemtype
        ) ELSE (
            echo.
            echo ====================================================================
            echo SUCCESS: Export completed for itemtype !CURRENT_ITEMTYPE!
            echo Completed: !DATE! !TIME!
            echo ====================================================================
            echo [!DATE! !TIME!] COMPLETED: !CURRENT_ITEMTYPE! >> "%PROGRESS_LOG%"

            REM Remove resume point if exists
            IF EXIST "%RESUME_LOG%" (
                findstr /V /C:"!CURRENT_ITEMTYPE!|" "%RESUME_LOG%" > "%RESUME_LOG%.tmp" 2>nul
                move /Y "%RESUME_LOG%.tmp" "%RESUME_LOG%" >nul 2>&1
            )
        )

        :NextItemtype
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
REM Parse ETK log file for package information
REM ============================================================================
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

REM Create temporary files for processing
SET TEMP_COMPLETED=%TEMP%\etk_completed_%RANDOM%.txt
SET TEMP_STARTED=%TEMP%\etk_started_%RANDOM%.txt

REM Extract package information
findstr /C:"Package Completed:" "%ETK_FILE%" > "%TEMP_COMPLETED%" 2>nul
findstr /C:"Package Started:" "%ETK_FILE%" > "%TEMP_STARTED%" 2>nul

REM Count lines in files
SET COMPLETED_COUNT=0
SET STARTED_COUNT=0

FOR /F %%A IN ('type "%TEMP_COMPLETED%" 2^>nul ^| find /c /v ""') DO SET COMPLETED_COUNT=%%A
FOR /F %%A IN ('type "%TEMP_STARTED%" 2^>nul ^| find /c /v ""') DO SET STARTED_COUNT=%%A

echo Package Summary:
echo   - Packages Started: %STARTED_COUNT%
echo   - Packages Completed: %COMPLETED_COUNT%
echo.

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

    REM Display all completed packages
    echo All Completed Packages:
    FOR /F "usebackq tokens=*" %%L IN ("%TEMP_COMPLETED%") DO (
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
    echo.
)

REM Cleanup temporary files
IF EXIST "%TEMP_COMPLETED%" DEL /Q "%TEMP_COMPLETED%"
IF EXIST "%TEMP_STARTED%" DEL /Q "%TEMP_STARTED%"

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

IF %TOTAL_ERRORS% GTR 0 (
    echo WARNING: %TOTAL_ERRORS% itemtype(s) failed. Check logs for details.
    echo [!DATE! !TIME!] Export finished with %TOTAL_ERRORS% errors >> "%PROGRESS_LOG%"

    REM Clean up temp file if created
    IF %IS_FILE% EQU 0 (
        del "%ITEMTYPE_LIST_FILE%" >nul 2>&1
    )

    ENDLOCAL
    exit /b 1
) ELSE (
    echo All exports completed successfully!
    echo [!DATE! !TIME!] All exports completed successfully >> "%PROGRESS_LOG%"

    REM Clean up temp file if created
    IF %IS_FILE% EQU 0 (
        del "%ITEMTYPE_LIST_FILE%" >nul 2>&1
    )

    ENDLOCAL
    exit /b 0
)

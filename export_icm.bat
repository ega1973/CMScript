@echo off
REM ============================================================================
REM IBM Content Manager Export Script for Windows
REM ============================================================================
REM Usage: export_icm.bat <export_name> <base_folder> <itemtype>
REM Example: export_icm.bat 007ClientesConstruya G:\007_Clientes_Construya "V03206007003D"
REM ============================================================================

SETLOCAL EnableDelayedExpansion

REM Check if required parameters are provided
IF "%~1"=="" (
    echo Error: Export name is required
    echo Usage: %0 ^<export_name^> ^<base_folder^> ^<itemtype^>
    echo Example: %0 007ClientesConstruya G:\007_Clientes_Construya "V03206007003D"
    exit /b 1
)

IF "%~2"=="" (
    echo Error: Base folder is required
    echo Usage: %0 ^<export_name^> ^<base_folder^> ^<itemtype^>
    echo Example: %0 007ClientesConstruya G:\007_Clientes_Construya "V03206007003D"
    exit /b 1
)

IF "%~3"=="" (
    echo Error: Itemtype is required
    echo Usage: %0 ^<export_name^> ^<base_folder^> ^<itemtype^>
    echo Example: %0 007ClientesConstruya G:\007_Clientes_Construya "V03206007003D"
    exit /b 1
)

REM Set parameters
SET EXPORT_NAME=%~1
SET BASE_FOLDER=%~2
SET ITEMTYPE=%~3
SET LOG_FOLDER=%BASE_FOLDER%\log

REM Configuration - Java and DB2 paths
SET JAVA_HOME=E:\jdk1.6.0_26
SET DB2_HOME=E:\IBM\db2cmv8
SET JAVA_EXE=%JAVA_HOME%\bin\java

REM ICM credentials (can be modified as needed)
SET ICM_USER=icmadmin
SET ICM_PASSWORD=Evolucion

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
REM Execute export
REM ============================================================================
echo ============================================================================
echo Starting IBM Content Manager Export...
echo ============================================================================
echo Export Name: %EXPORT_NAME%
echo Itemtype: %ITEMTYPE%
echo Export Folder: %BASE_FOLDER%
echo Log Folder: %LOG_FOLDER%
echo User: %ICM_USER%
echo.
echo Command: %JAVA_EXE% TExportManagerICM -u %ICM_USER% -p %ICM_PASSWORD% -m %EXPORT_NAME% -l %LOG_FOLDER% -a "%ITEMTYPE%" -v %BASE_FOLDER%
echo.
echo ============================================================================

"%JAVA_EXE%" TExportManagerICM -u %ICM_USER% -p %ICM_PASSWORD% -m %EXPORT_NAME% -l "%LOG_FOLDER%" -a "%ITEMTYPE%" -v "%BASE_FOLDER%"

IF ERRORLEVEL 1 (
    echo.
    echo ============================================================================
    echo ERROR: Export failed with error code %ERRORLEVEL%
    echo ============================================================================
    exit /b %ERRORLEVEL%
)

echo.
echo ============================================================================
echo Export completed successfully
echo ============================================================================
echo.
echo Check logs at: %LOG_FOLDER%
echo Export files at: %BASE_FOLDER%
echo.

ENDLOCAL
exit /b 0

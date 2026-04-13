@echo off
rem ----------------------------------------------------------------------------
rem  Copyright 2023-2026 WSO2, LLC. http://www.wso2.org
rem
rem  Licensed under the Apache License, Version 2.0 (the "License");
rem  you may not use this file except in compliance with the License.
rem  You may obtain a copy of the License at
rem
rem      http://www.apache.org/licenses/LICENSE-2.0
rem
rem  Unless required by applicable law or agreed to in writing, software
rem  distributed under the License is distributed on an "AS IS" BASIS,
rem  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
rem  See the License for the specific language governing permissions and
rem  limitations under the License.

setlocal enabledelayedexpansion

set BC_FIPS_VERSION=2.1.2
set BCPKIX_FIPS_VERSION=2.1.10
set BCUTIL_FIPS_VERSION=2.1.5
set BCPG_FIPS_VERSION=2.1.11
set BCTLS_FIPS_VERSION=2.1.22

set EXPECTED_BC_FIPS_CHECKSUM=061fbe8383f70489dda95a11a2a4739eb818ff2c
set EXPECTED_BCPKIX_FIPS_CHECKSUM=41d15c70437440d63b65225d7c00873a030d25d0
set EXPECTED_BCUTIL_FIPS_CHECKSUM=30b41ebc759a4f02e2ff7ab9acb09268923ee41f
set EXPECTED_BCPG_FIPS_CHECKSUM=727e087a843f3a5a8143e4f3a7518c8c3517df18
set EXPECTED_BCTLS_FIPS_CHECKSUM=d2979016bf75ef8b5e8aa17211399651a391a21f

rem ----- Only set CARBON_HOME if not already set ----------------------------
:checkServer
rem %~sdp0 is expanded pathname of the current script under NT with spaces in the path removed
if "%CARBON_HOME%"=="" set CARBON_HOME=%~sdp0..
SET curDrive=%cd:~0,1%
SET wsasDrive=%CARBON_HOME:~0,1%
if not "%curDrive%" == "%wsasDrive%" %wsasDrive%:

rem find CARBON_HOME if it does not exist due to either an invalid value passed
rem by the user or the %0 problem on Windows 9x
if not exist "%CARBON_HOME%\bin\version.txt" goto noServerHome

set ARGUMENT=%1
set bundles_info=%CARBON_HOME%\repository\components\default\configuration\org.eclipse.equinox.simpleconfigurator\bundles.info
set "homeDir=%userprofile%"
set server_restart_required=false

if "%ARGUMENT%"=="DISABLE" goto disableFipsMode
if "%ARGUMENT%"=="disable" goto disableFipsMode
if "%ARGUMENT%"=="VERIFY" goto verifyFipsMode
if "%ARGUMENT%"=="verify" goto verifyFipsMode
goto enableFipsMode

rem ===========================================================================
:disableFipsMode

rem Remove all FIPS jars from lib/ and dropins/
if exist "%CARBON_HOME%\repository\components\lib\bc-fips*.jar" (
    set server_restart_required=true
    echo Remove existing bc-fips jar from lib folder.
    DEL /F "%CARBON_HOME%\repository\components\lib\bc-fips*.jar"
    echo Successfully removed bc-fips-%BC_FIPS_VERSION%.jar from components\lib.
)
if exist "%CARBON_HOME%\repository\components\dropins\bc_fips*.jar" (
    set server_restart_required=true
    echo Remove existing bc_fips jar from dropins folder.
    DEL /F "%CARBON_HOME%\repository\components\dropins\bc_fips*.jar"
    echo Successfully removed bc_fips-%BC_FIPS_VERSION%.jar from components\dropins.
)
if exist "%CARBON_HOME%\repository\components\lib\bcpkix-fips*.jar" (
    set server_restart_required=true
    echo Remove existing bcpkix-fips jar from lib folder.
    DEL /F "%CARBON_HOME%\repository\components\lib\bcpkix-fips*.jar"
    echo Successfully removed bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar from components\lib.
)
if exist "%CARBON_HOME%\repository\components\dropins\bcpkix_fips*.jar" (
    set server_restart_required=true
    echo Remove existing bcpkix_fips jar from dropins folder.
    DEL /F "%CARBON_HOME%\repository\components\dropins\bcpkix_fips*.jar"
    echo Successfully removed bcpkix_fips-%BCPKIX_FIPS_VERSION%.jar from components\dropins.
)
if exist "%CARBON_HOME%\repository\components\lib\bcutil-fips*.jar" (
    set server_restart_required=true
    echo Remove existing bcutil-fips jar from lib folder.
    DEL /F "%CARBON_HOME%\repository\components\lib\bcutil-fips*.jar"
    echo Successfully removed bcutil-fips-%BCUTIL_FIPS_VERSION%.jar from components\lib.
)
if exist "%CARBON_HOME%\repository\components\dropins\bcutil_fips*.jar" (
    set server_restart_required=true
    echo Remove existing bcutil_fips jar from dropins folder.
    DEL /F "%CARBON_HOME%\repository\components\dropins\bcutil_fips*.jar"
    echo Successfully removed bcutil_fips-%BCUTIL_FIPS_VERSION%.jar from components\dropins.
)
if exist "%CARBON_HOME%\repository\components\lib\bcpg-fips*.jar" (
    set server_restart_required=true
    echo Remove existing bcpg-fips jar from lib folder.
    DEL /F "%CARBON_HOME%\repository\components\lib\bcpg-fips*.jar"
    echo Successfully removed bcpg-fips-%BCPG_FIPS_VERSION%.jar from components\lib.
)
if exist "%CARBON_HOME%\repository\components\dropins\bcpg_fips*.jar" (
    set server_restart_required=true
    echo Remove existing bcpg_fips jar from dropins folder.
    DEL /F "%CARBON_HOME%\repository\components\dropins\bcpg_fips*.jar"
    echo Successfully removed bcpg_fips-%BCPG_FIPS_VERSION%.jar from components\dropins.
)
if exist "%CARBON_HOME%\repository\components\lib\bctls-fips*.jar" (
    set server_restart_required=true
    echo Remove existing bctls-fips jar from lib folder.
    DEL /F "%CARBON_HOME%\repository\components\lib\bctls-fips*.jar"
    echo Successfully removed bctls-fips-%BCTLS_FIPS_VERSION%.jar from components\lib.
)
if exist "%CARBON_HOME%\repository\components\dropins\bctls_fips*.jar" (
    set server_restart_required=true
    echo Remove existing bctls_fips jar from dropins folder.
    DEL /F "%CARBON_HOME%\repository\components\dropins\bctls_fips*.jar"
    echo Successfully removed bctls_fips-%BCTLS_FIPS_VERSION%.jar from components\dropins.
)

rem Restore all non-FIPS jars from backup to plugins/
set bcprov_file_name=
set bcprov_version=
if not exist "%CARBON_HOME%\repository\components\plugins\bcprov-jdk18on*.jar" (
    set server_restart_required=true
    if exist "%homeDir%\.wso2-bc\backup\bcprov-jdk18on*.jar" (
        for /r "%homeDir%\.wso2-bc\backup\" %%G in (bcprov-jdk18on*.jar) do (
            set "bcprov_location=%%G"
            set "bcprov_file_name=%%~nxG"
            set "bcprov_stem=%%~nG"
            goto foundBcProvBackup
        )
        :foundBcProvBackup
        for /f "tokens=2 delims=_" %%v in ("!bcprov_stem!") do set "bcprov_version=%%v"
        move "!bcprov_location!" "%CARBON_HOME%\repository\components\plugins"
        echo Moved !bcprov_file_name! from %homeDir%\.wso2-bc\backup to components\plugins.
    ) else (
        echo Required bcprov-jdk18on jar is not available in %homeDir%\.wso2-bc\backup. Download the jar from maven central repository.
    )
)

set bcpkix_file_name=
set bcpkix_version=
if not exist "%CARBON_HOME%\repository\components\plugins\bcpkix-jdk18on*.jar" (
    set server_restart_required=true
    if exist "%homeDir%\.wso2-bc\backup\bcpkix-jdk18on*.jar" (
        for /r "%homeDir%\.wso2-bc\backup\" %%G in (bcpkix-jdk18on*.jar) do (
            set "bcpkix_location=%%G"
            set "bcpkix_file_name=%%~nxG"
            set "bcpkix_stem=%%~nG"
            goto foundBcPkixBackup
        )
        :foundBcPkixBackup
        for /f "tokens=2 delims=_" %%v in ("!bcpkix_stem!") do set "bcpkix_version=%%v"
        move "!bcpkix_location!" "%CARBON_HOME%\repository\components\plugins"
        echo Moved !bcpkix_file_name! from %homeDir%\.wso2-bc\backup to components\plugins.
    ) else (
        echo Required bcpkix-jdk18on jar is not available in %homeDir%\.wso2-bc\backup. Download the jar from maven central repository.
    )
)

set bcutil_file_name=
set bcutil_version=
if not exist "%CARBON_HOME%\repository\components\plugins\bcutil-jdk18on*.jar" (
    set server_restart_required=true
    if exist "%homeDir%\.wso2-bc\backup\bcutil-jdk18on*.jar" (
        for /r "%homeDir%\.wso2-bc\backup\" %%G in (bcutil-jdk18on*.jar) do (
            set "bcutil_location=%%G"
            set "bcutil_file_name=%%~nxG"
            set "bcutil_stem=%%~nG"
            goto foundBcUtilBackup
        )
        :foundBcUtilBackup
        for /f "tokens=2 delims=_" %%v in ("!bcutil_stem!") do set "bcutil_version=%%v"
        move "!bcutil_location!" "%CARBON_HOME%\repository\components\plugins"
        echo Moved !bcutil_file_name! from %homeDir%\.wso2-bc\backup to components\plugins.
    ) else (
        echo Required bcutil-jdk18on jar is not available in %homeDir%\.wso2-bc\backup. Download the jar from maven central repository.
    )
)

set bcpg_file_name=
set bcpg_version=
if not exist "%CARBON_HOME%\repository\components\plugins\bcpg-jdk18on*.jar" (
    set server_restart_required=true
    if exist "%homeDir%\.wso2-bc\backup\bcpg-jdk18on*.jar" (
        for /r "%homeDir%\.wso2-bc\backup\" %%G in (bcpg-jdk18on*.jar) do (
            set "bcpg_location=%%G"
            set "bcpg_file_name=%%~nxG"
            set "bcpg_stem=%%~nG"
            goto foundBcPgBackup
        )
        :foundBcPgBackup
        for /f "tokens=2 delims=_" %%v in ("!bcpg_stem!") do set "bcpg_version=%%v"
        move "!bcpg_location!" "%CARBON_HOME%\repository\components\plugins"
        echo Moved !bcpg_file_name! from %homeDir%\.wso2-bc\backup to components\plugins.
    ) else (
        echo Required bcpg-jdk18on jar is not available in %homeDir%\.wso2-bc\backup. Download the jar from maven central repository.
    )
)

set bctls_file_name=
set bctls_version=
if not exist "%CARBON_HOME%\repository\components\plugins\bctls-jdk18on*.jar" (
    set server_restart_required=true
    if exist "%homeDir%\.wso2-bc\backup\bctls-jdk18on*.jar" (
        for /r "%homeDir%\.wso2-bc\backup\" %%G in (bctls-jdk18on*.jar) do (
            set "bctls_location=%%G"
            set "bctls_file_name=%%~nxG"
            set "bctls_stem=%%~nG"
            goto foundBcTlsBackup
        )
        :foundBcTlsBackup
        for /f "tokens=2 delims=_" %%v in ("!bctls_stem!") do set "bctls_version=%%v"
        move "!bctls_location!" "%CARBON_HOME%\repository\components\plugins"
        echo Moved !bctls_file_name! from %homeDir%\.wso2-bc\backup to components\plugins.
    ) else (
        echo Required bctls-jdk18on jar is not available in %homeDir%\.wso2-bc\backup. Download the jar from maven central repository.
    )
)

rem Restore bundles.info entries for non-FIPS jars (only if jar was restored)
if not "!bcprov_version!"=="" if not "!bcprov_file_name!"=="" (
    set "bcprov_text=bcprov-jdk18on,!bcprov_version!,../plugins/!bcprov_file_name!,4,true"
    findstr /c:"!bcprov_text!" "%bundles_info%" >nul 2>&1
    if !errorlevel!==1 (
        set server_restart_required=true
        echo !bcprov_text!>>"%bundles_info%"
    )
) else (
    echo Skipping bundles.info entry for bcprov-jdk18on: JAR was not restored from backup.
)
if not "!bcpkix_version!"=="" if not "!bcpkix_file_name!"=="" (
    set "bcpkix_text=bcpkix-jdk18on,!bcpkix_version!,../plugins/!bcpkix_file_name!,4,true"
    findstr /c:"!bcpkix_text!" "%bundles_info%" >nul 2>&1
    if !errorlevel!==1 (
        set server_restart_required=true
        echo !bcpkix_text!>>"%bundles_info%"
    )
) else (
    echo Skipping bundles.info entry for bcpkix-jdk18on: JAR was not restored from backup.
)
if not "!bcutil_version!"=="" if not "!bcutil_file_name!"=="" (
    set "bcutil_text=bcutil-jdk18on,!bcutil_version!,../plugins/!bcutil_file_name!,4,true"
    findstr /c:"!bcutil_text!" "%bundles_info%" >nul 2>&1
    if !errorlevel!==1 (
        set server_restart_required=true
        echo !bcutil_text!>>"%bundles_info%"
    )
) else (
    echo Skipping bundles.info entry for bcutil-jdk18on: JAR was not restored from backup.
)
if not "!bcpg_version!"=="" if not "!bcpg_file_name!"=="" (
    set "bcpg_text=bcpg-jdk18on,!bcpg_version!,../plugins/!bcpg_file_name!,4,true"
    findstr /c:"!bcpg_text!" "%bundles_info%" >nul 2>&1
    if !errorlevel!==1 (
        set server_restart_required=true
        echo !bcpg_text!>>"%bundles_info%"
    )
) else (
    echo Skipping bundles.info entry for bcpg-jdk18on: JAR was not restored from backup.
)
if not "!bctls_version!"=="" if not "!bctls_file_name!"=="" (
    set "bctls_text=bctls-jdk18on,!bctls_version!,../plugins/!bctls_file_name!,4,true"
    findstr /c:"!bctls_text!" "%bundles_info%" >nul 2>&1
    if !errorlevel!==1 (
        set server_restart_required=true
        echo !bctls_text!>>"%bundles_info%"
    )
) else (
    echo Skipping bundles.info entry for bctls-jdk18on: JAR was not restored from backup.
)
goto printRestartMsg

rem ===========================================================================
:enableFipsMode
set arg1=
set arg2=
:parse_args
if "%~1" == "" goto done_args
if /I "%~1" == "-f" set "arg1=%~2" & shift
if /I "%~1" == "-m" set "arg2=%~2" & shift
shift
goto parse_args
:done_args

if not exist "%homeDir%\.wso2-bc" mkdir "%homeDir%\.wso2-bc"
if not exist "%homeDir%\.wso2-bc\backup" mkdir "%homeDir%\.wso2-bc\backup"

rem Move all non-FIPS jars from plugins/ to backup
if exist "%CARBON_HOME%\repository\components\plugins\bcprov-jdk18on*.jar" (
    set server_restart_required=true
    for /r "%CARBON_HOME%\repository\components\plugins\" %%G in (bcprov-jdk18on*.jar) do (
        set "bcprov_location=%%G"
        set "bcprov_file_name=%%~nxG"
        goto backupBcProv
    )
    :backupBcProv
    echo Remove existing bcprov-jdk18on jar from plugins folder.
    if exist "%homeDir%\.wso2-bc\backup\bcprov-jdk18on*.jar" DEL /F "%homeDir%\.wso2-bc\backup\bcprov-jdk18on*.jar"
    move "!bcprov_location!" "%homeDir%\.wso2-bc\backup"
    echo Successfully removed !bcprov_file_name! from components\plugins.
)

if exist "%CARBON_HOME%\repository\components\plugins\bcpkix-jdk18on*.jar" (
    set server_restart_required=true
    for /r "%CARBON_HOME%\repository\components\plugins\" %%G in (bcpkix-jdk18on*.jar) do (
        set "bcpkix_location=%%G"
        set "bcpkix_file_name=%%~nxG"
        goto backupBcPkix
    )
    :backupBcPkix
    echo Remove existing bcpkix-jdk18on jar from plugins folder.
    if exist "%homeDir%\.wso2-bc\backup\bcpkix-jdk18on*.jar" DEL /F "%homeDir%\.wso2-bc\backup\bcpkix-jdk18on*.jar"
    move "!bcpkix_location!" "%homeDir%\.wso2-bc\backup"
    echo Successfully removed !bcpkix_file_name! from components\plugins.
)

if exist "%CARBON_HOME%\repository\components\plugins\bcutil-jdk18on*.jar" (
    set server_restart_required=true
    for /r "%CARBON_HOME%\repository\components\plugins\" %%G in (bcutil-jdk18on*.jar) do (
        set "bcutil_location=%%G"
        set "bcutil_file_name=%%~nxG"
        goto backupBcUtil
    )
    :backupBcUtil
    echo Remove existing bcutil-jdk18on jar from plugins folder.
    if exist "%homeDir%\.wso2-bc\backup\bcutil-jdk18on*.jar" DEL /F "%homeDir%\.wso2-bc\backup\bcutil-jdk18on*.jar"
    move "!bcutil_location!" "%homeDir%\.wso2-bc\backup"
    echo Successfully removed !bcutil_file_name! from components\plugins.
)

if exist "%CARBON_HOME%\repository\components\plugins\bcpg-jdk18on*.jar" (
    set server_restart_required=true
    for /r "%CARBON_HOME%\repository\components\plugins\" %%G in (bcpg-jdk18on*.jar) do (
        set "bcpg_location=%%G"
        set "bcpg_file_name=%%~nxG"
        goto backupBcPg
    )
    :backupBcPg
    echo Remove existing bcpg-jdk18on jar from plugins folder.
    if exist "%homeDir%\.wso2-bc\backup\bcpg-jdk18on*.jar" DEL /F "%homeDir%\.wso2-bc\backup\bcpg-jdk18on*.jar"
    move "!bcpg_location!" "%homeDir%\.wso2-bc\backup"
    echo Successfully removed !bcpg_file_name! from components\plugins.
)

if exist "%CARBON_HOME%\repository\components\plugins\bctls-jdk18on*.jar" (
    set server_restart_required=true
    for /r "%CARBON_HOME%\repository\components\plugins\" %%G in (bctls-jdk18on*.jar) do (
        set "bctls_location=%%G"
        set "bctls_file_name=%%~nxG"
        goto backupBcTls
    )
    :backupBcTls
    echo Remove existing bctls-jdk18on jar from plugins folder.
    if exist "%homeDir%\.wso2-bc\backup\bctls-jdk18on*.jar" DEL /F "%homeDir%\.wso2-bc\backup\bctls-jdk18on*.jar"
    move "!bctls_location!" "%homeDir%\.wso2-bc\backup"
    echo Successfully removed !bctls_file_name! from components\plugins.
)

rem Remove non-FIPS entries from bundles.info
set temp_file=%CARBON_HOME%\repository\components\default\configuration\org.eclipse.equinox.simpleconfigurator\temp.info
findstr /v /c:"bcprov-jdk18on" /c:"bcpkix-jdk18on" /c:"bcutil-jdk18on" /c:"bcpg-jdk18on" /c:"bctls-jdk18on" "%bundles_info%" > "%temp_file%"
move /y "%temp_file%" "%bundles_info%" > nul

rem Ensure all FIPS jars are present and up to date in lib/

rem --- bc-fips ---
if exist "%CARBON_HOME%\repository\components\lib\bc-fips*.jar" (
    for /f "delims=" %%a in ('dir /b /s "%CARBON_HOME%\repository\components\lib\bc-fips*.jar"') do (
        set "bcfips_location=%%a"
        goto check_bcfips
    )
    :check_bcfips
    for %%f in ("!bcfips_location!") do set "bcfips_filename=%%~nxf"
    if not "!bcfips_filename!"=="bc-fips-%BC_FIPS_VERSION%.jar" (
        set server_restart_required=true
        echo There is an update for bc-fips. Therefore removing existing bc-fips jar from lib folder.
        del /q "%CARBON_HOME%\repository\components\lib\bc-fips*.jar" 2>nul
        echo Successfully removed bc-fips-%BC_FIPS_VERSION%.jar from components\lib.
        if exist "%CARBON_HOME%\repository\components\dropins\bc_fips*.jar" (
            echo Remove existing bc-fips jar from dropins folder.
            del /q "%CARBON_HOME%\repository\components\dropins\bc_fips*.jar" 2>nul
            echo Successfully removed bc_fips-%BC_FIPS_VERSION%.jar from components\dropins.
        )
    )
)
if not exist "%CARBON_HOME%\repository\components\lib\bc-fips*.jar" (
    set server_restart_required=true
    if not "%arg1%"=="" if "%arg2%"=="" (
        if not exist "%arg1%\bc-fips-%BC_FIPS_VERSION%.jar" (
            echo Can not be found required bc-fips-%BC_FIPS_VERSION%.jar in given file path : "%arg1%".
        ) else (
            copy "%arg1%\bc-fips-%BC_FIPS_VERSION%.jar" "%CARBON_HOME%\repository\components\lib\"
            if %errorlevel% equ 0 (echo bc-fips JAR file copied successfully.) else (echo Error copying bc-fips JAR file.)
        )
    ) else if not "%arg2%"=="" (
        echo Downloading required bc-fips jar : bc-fips-%BC_FIPS_VERSION%
        curl -f "%arg2%/org/bouncycastle/bc-fips/%BC_FIPS_VERSION%/bc-fips-%BC_FIPS_VERSION%.jar" -o "%CARBON_HOME%\repository\components\lib\bc-fips-%BC_FIPS_VERSION%.jar"
        if !errorlevel! neq 0 (
            echo Failed to download bc-fips-%BC_FIPS_VERSION%.jar.
            del /f "%CARBON_HOME%\repository\components\lib\bc-fips-%BC_FIPS_VERSION%.jar" 2>nul
        ) else (
            FOR /F "tokens=*" %%G IN ('certutil -hashfile "%CARBON_HOME%\repository\components\lib\bc-fips-%BC_FIPS_VERSION%.jar" SHA1 ^| FIND /V ":"') DO SET "actual_checksum=%%G"
            if "!actual_checksum!"=="%EXPECTED_BC_FIPS_CHECKSUM%" (
                echo Checksum verified: The downloaded bc-fips-%BC_FIPS_VERSION%.jar is valid.
            ) else (
                echo Checksum verification failed: The downloaded bc-fips-%BC_FIPS_VERSION%.jar may be corrupted.
                del /f "%CARBON_HOME%\repository\components\lib\bc-fips-%BC_FIPS_VERSION%.jar"
            )
        )
    ) else (
        echo Downloading required bc-fips jar : bc-fips-%BC_FIPS_VERSION%
        curl -f "https://repo1.maven.org/maven2/org/bouncycastle/bc-fips/%BC_FIPS_VERSION%/bc-fips-%BC_FIPS_VERSION%.jar" -o "%CARBON_HOME%\repository\components\lib\bc-fips-%BC_FIPS_VERSION%.jar"
        if !errorlevel! neq 0 (
            echo Failed to download bc-fips-%BC_FIPS_VERSION%.jar.
            del /f "%CARBON_HOME%\repository\components\lib\bc-fips-%BC_FIPS_VERSION%.jar" 2>nul
        ) else (
            FOR /F "tokens=*" %%G IN ('certutil -hashfile "%CARBON_HOME%\repository\components\lib\bc-fips-%BC_FIPS_VERSION%.jar" SHA1 ^| FIND /V ":"') DO SET "actual_checksum=%%G"
            if "!actual_checksum!"=="%EXPECTED_BC_FIPS_CHECKSUM%" (
                echo Checksum verified: The downloaded bc-fips-%BC_FIPS_VERSION%.jar is valid.
            ) else (
                echo Checksum verification failed: The downloaded bc-fips-%BC_FIPS_VERSION%.jar may be corrupted.
                del /f "%CARBON_HOME%\repository\components\lib\bc-fips-%BC_FIPS_VERSION%.jar"
            )
        )
    )
)

rem --- bcpkix-fips ---
if exist "%CARBON_HOME%\repository\components\lib\bcpkix-fips*.jar" (
    for /f "delims=" %%a in ('dir /b /s "%CARBON_HOME%\repository\components\lib\bcpkix-fips*.jar"') do (
        set "bcpkixfips_location=%%a"
        goto check_bcpkixfips
    )
    :check_bcpkixfips
    for %%f in ("!bcpkixfips_location!") do set "bcpkixfips_filename=%%~nxf"
    if not "!bcpkixfips_filename!"=="bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar" (
        set server_restart_required=true
        echo There is an update for bcpkix-fips. Therefore removing existing bcpkix-fips jar from lib folder.
        del /q "%CARBON_HOME%\repository\components\lib\bcpkix-fips*.jar" 2>nul
        echo Successfully removed bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar from components\lib.
        if exist "%CARBON_HOME%\repository\components\dropins\bcpkix_fips*.jar" (
            echo Remove existing bcpkix-fips jar from dropins folder.
            del /q "%CARBON_HOME%\repository\components\dropins\bcpkix_fips*.jar" 2>nul
            echo Successfully removed bcpkix_fips-%BCPKIX_FIPS_VERSION%.jar from components\dropins.
        )
    )
)
if not exist "%CARBON_HOME%\repository\components\lib\bcpkix-fips*.jar" (
    set server_restart_required=true
    if not "%arg1%"=="" if "%arg2%"=="" (
        if not exist "%arg1%\bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar" (
            echo Can not be found required bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar in given file path : "%arg1%".
        ) else (
            copy "%arg1%\bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar" "%CARBON_HOME%\repository\components\lib\"
            if %errorlevel% equ 0 (echo bcpkix-fips JAR file copied successfully.) else (echo Error copying bcpkix-fips JAR file.)
        )
    ) else if not "%arg2%"=="" (
        echo Downloading required bcpkix-fips jar : bcpkix-fips-%BCPKIX_FIPS_VERSION%
        curl -f "%arg2%/org/bouncycastle/bcpkix-fips/%BCPKIX_FIPS_VERSION%/bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar" -o "%CARBON_HOME%\repository\components\lib\bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar"
        if !errorlevel! neq 0 (
            echo Failed to download bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar.
            del /f "%CARBON_HOME%\repository\components\lib\bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar" 2>nul
        ) else (
            FOR /F "tokens=*" %%G IN ('certutil -hashfile "%CARBON_HOME%\repository\components\lib\bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar" SHA1 ^| FIND /V ":"') DO SET "actual_checksum=%%G"
            if "!actual_checksum!"=="%EXPECTED_BCPKIX_FIPS_CHECKSUM%" (
                echo Checksum verified: The downloaded bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar is valid.
            ) else (
                echo Checksum verification failed: The downloaded bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar may be corrupted.
                del /f "%CARBON_HOME%\repository\components\lib\bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar"
            )
        )
    ) else (
        echo Downloading required bcpkix-fips jar : bcpkix-fips-%BCPKIX_FIPS_VERSION%
        curl -f "https://repo1.maven.org/maven2/org/bouncycastle/bcpkix-fips/%BCPKIX_FIPS_VERSION%/bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar" -o "%CARBON_HOME%\repository\components\lib\bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar"
        if !errorlevel! neq 0 (
            echo Failed to download bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar.
            del /f "%CARBON_HOME%\repository\components\lib\bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar" 2>nul
        ) else (
            FOR /F "tokens=*" %%G IN ('certutil -hashfile "%CARBON_HOME%\repository\components\lib\bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar" SHA1 ^| FIND /V ":"') DO SET "actual_checksum=%%G"
            if "!actual_checksum!"=="%EXPECTED_BCPKIX_FIPS_CHECKSUM%" (
                echo Checksum verified: The downloaded bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar is valid.
            ) else (
                echo Checksum verification failed: The downloaded bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar may be corrupted.
                del /f "%CARBON_HOME%\repository\components\lib\bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar"
            )
        )
    )
)

rem --- bcutil-fips ---
if exist "%CARBON_HOME%\repository\components\lib\bcutil-fips*.jar" (
    for /f "delims=" %%a in ('dir /b /s "%CARBON_HOME%\repository\components\lib\bcutil-fips*.jar"') do (
        set "bcutilfips_location=%%a"
        goto check_bcutilfips
    )
    :check_bcutilfips
    for %%f in ("!bcutilfips_location!") do set "bcutilfips_filename=%%~nxf"
    if not "!bcutilfips_filename!"=="bcutil-fips-%BCUTIL_FIPS_VERSION%.jar" (
        set server_restart_required=true
        echo There is an update for bcutil-fips. Therefore removing existing bcutil-fips jar from lib folder.
        del /q "%CARBON_HOME%\repository\components\lib\bcutil-fips*.jar" 2>nul
        echo Successfully removed bcutil-fips-%BCUTIL_FIPS_VERSION%.jar from components\lib.
        if exist "%CARBON_HOME%\repository\components\dropins\bcutil_fips*.jar" (
            echo Remove existing bcutil-fips jar from dropins folder.
            del /q "%CARBON_HOME%\repository\components\dropins\bcutil_fips*.jar" 2>nul
            echo Successfully removed bcutil_fips-%BCUTIL_FIPS_VERSION%.jar from components\dropins.
        )
    )
)
if not exist "%CARBON_HOME%\repository\components\lib\bcutil-fips*.jar" (
    set server_restart_required=true
    if not "%arg1%"=="" if "%arg2%"=="" (
        if not exist "%arg1%\bcutil-fips-%BCUTIL_FIPS_VERSION%.jar" (
            echo Can not be found required bcutil-fips-%BCUTIL_FIPS_VERSION%.jar in given file path : "%arg1%".
        ) else (
            copy "%arg1%\bcutil-fips-%BCUTIL_FIPS_VERSION%.jar" "%CARBON_HOME%\repository\components\lib\"
            if %errorlevel% equ 0 (echo bcutil-fips JAR file copied successfully.) else (echo Error copying bcutil-fips JAR file.)
        )
    ) else if not "%arg2%"=="" (
        echo Downloading required bcutil-fips jar : bcutil-fips-%BCUTIL_FIPS_VERSION%
        curl -f "%arg2%/org/bouncycastle/bcutil-fips/%BCUTIL_FIPS_VERSION%/bcutil-fips-%BCUTIL_FIPS_VERSION%.jar" -o "%CARBON_HOME%\repository\components\lib\bcutil-fips-%BCUTIL_FIPS_VERSION%.jar"
        if !errorlevel! neq 0 (
            echo Failed to download bcutil-fips-%BCUTIL_FIPS_VERSION%.jar.
            del /f "%CARBON_HOME%\repository\components\lib\bcutil-fips-%BCUTIL_FIPS_VERSION%.jar" 2>nul
        ) else (
            FOR /F "tokens=*" %%G IN ('certutil -hashfile "%CARBON_HOME%\repository\components\lib\bcutil-fips-%BCUTIL_FIPS_VERSION%.jar" SHA1 ^| FIND /V ":"') DO SET "actual_checksum=%%G"
            if "!actual_checksum!"=="%EXPECTED_BCUTIL_FIPS_CHECKSUM%" (
                echo Checksum verified: The downloaded bcutil-fips-%BCUTIL_FIPS_VERSION%.jar is valid.
            ) else (
                echo Checksum verification failed: The downloaded bcutil-fips-%BCUTIL_FIPS_VERSION%.jar may be corrupted.
                del /f "%CARBON_HOME%\repository\components\lib\bcutil-fips-%BCUTIL_FIPS_VERSION%.jar"
            )
        )
    ) else (
        echo Downloading required bcutil-fips jar : bcutil-fips-%BCUTIL_FIPS_VERSION%
        curl -f "https://repo1.maven.org/maven2/org/bouncycastle/bcutil-fips/%BCUTIL_FIPS_VERSION%/bcutil-fips-%BCUTIL_FIPS_VERSION%.jar" -o "%CARBON_HOME%\repository\components\lib\bcutil-fips-%BCUTIL_FIPS_VERSION%.jar"
        if !errorlevel! neq 0 (
            echo Failed to download bcutil-fips-%BCUTIL_FIPS_VERSION%.jar.
            del /f "%CARBON_HOME%\repository\components\lib\bcutil-fips-%BCUTIL_FIPS_VERSION%.jar" 2>nul
        ) else (
            FOR /F "tokens=*" %%G IN ('certutil -hashfile "%CARBON_HOME%\repository\components\lib\bcutil-fips-%BCUTIL_FIPS_VERSION%.jar" SHA1 ^| FIND /V ":"') DO SET "actual_checksum=%%G"
            if "!actual_checksum!"=="%EXPECTED_BCUTIL_FIPS_CHECKSUM%" (
                echo Checksum verified: The downloaded bcutil-fips-%BCUTIL_FIPS_VERSION%.jar is valid.
            ) else (
                echo Checksum verification failed: The downloaded bcutil-fips-%BCUTIL_FIPS_VERSION%.jar may be corrupted.
                del /f "%CARBON_HOME%\repository\components\lib\bcutil-fips-%BCUTIL_FIPS_VERSION%.jar"
            )
        )
    )
)

rem --- bcpg-fips ---
if exist "%CARBON_HOME%\repository\components\lib\bcpg-fips*.jar" (
    for /f "delims=" %%a in ('dir /b /s "%CARBON_HOME%\repository\components\lib\bcpg-fips*.jar"') do (
        set "bcpgfips_location=%%a"
        goto check_bcpgfips
    )
    :check_bcpgfips
    for %%f in ("!bcpgfips_location!") do set "bcpgfips_filename=%%~nxf"
    if not "!bcpgfips_filename!"=="bcpg-fips-%BCPG_FIPS_VERSION%.jar" (
        set server_restart_required=true
        echo There is an update for bcpg-fips. Therefore removing existing bcpg-fips jar from lib folder.
        del /q "%CARBON_HOME%\repository\components\lib\bcpg-fips*.jar" 2>nul
        echo Successfully removed bcpg-fips-%BCPG_FIPS_VERSION%.jar from components\lib.
        if exist "%CARBON_HOME%\repository\components\dropins\bcpg_fips*.jar" (
            echo Remove existing bcpg-fips jar from dropins folder.
            del /q "%CARBON_HOME%\repository\components\dropins\bcpg_fips*.jar" 2>nul
            echo Successfully removed bcpg_fips-%BCPG_FIPS_VERSION%.jar from components\dropins.
        )
    )
)
if not exist "%CARBON_HOME%\repository\components\lib\bcpg-fips*.jar" (
    set server_restart_required=true
    if not "%arg1%"=="" if "%arg2%"=="" (
        if not exist "%arg1%\bcpg-fips-%BCPG_FIPS_VERSION%.jar" (
            echo Can not be found required bcpg-fips-%BCPG_FIPS_VERSION%.jar in given file path : "%arg1%".
        ) else (
            copy "%arg1%\bcpg-fips-%BCPG_FIPS_VERSION%.jar" "%CARBON_HOME%\repository\components\lib\"
            if %errorlevel% equ 0 (echo bcpg-fips JAR file copied successfully.) else (echo Error copying bcpg-fips JAR file.)
        )
    ) else if not "%arg2%"=="" (
        echo Downloading required bcpg-fips jar : bcpg-fips-%BCPG_FIPS_VERSION%
        curl -f "%arg2%/org/bouncycastle/bcpg-fips/%BCPG_FIPS_VERSION%/bcpg-fips-%BCPG_FIPS_VERSION%.jar" -o "%CARBON_HOME%\repository\components\lib\bcpg-fips-%BCPG_FIPS_VERSION%.jar"
        if !errorlevel! neq 0 (
            echo Failed to download bcpg-fips-%BCPG_FIPS_VERSION%.jar.
            del /f "%CARBON_HOME%\repository\components\lib\bcpg-fips-%BCPG_FIPS_VERSION%.jar" 2>nul
        ) else (
            FOR /F "tokens=*" %%G IN ('certutil -hashfile "%CARBON_HOME%\repository\components\lib\bcpg-fips-%BCPG_FIPS_VERSION%.jar" SHA1 ^| FIND /V ":"') DO SET "actual_checksum=%%G"
            if "!actual_checksum!"=="%EXPECTED_BCPG_FIPS_CHECKSUM%" (
                echo Checksum verified: The downloaded bcpg-fips-%BCPG_FIPS_VERSION%.jar is valid.
            ) else (
                echo Checksum verification failed: The downloaded bcpg-fips-%BCPG_FIPS_VERSION%.jar may be corrupted.
                del /f "%CARBON_HOME%\repository\components\lib\bcpg-fips-%BCPG_FIPS_VERSION%.jar"
            )
        )
    ) else (
        echo Downloading required bcpg-fips jar : bcpg-fips-%BCPG_FIPS_VERSION%
        curl -f "https://repo1.maven.org/maven2/org/bouncycastle/bcpg-fips/%BCPG_FIPS_VERSION%/bcpg-fips-%BCPG_FIPS_VERSION%.jar" -o "%CARBON_HOME%\repository\components\lib\bcpg-fips-%BCPG_FIPS_VERSION%.jar"
        if !errorlevel! neq 0 (
            echo Failed to download bcpg-fips-%BCPG_FIPS_VERSION%.jar.
            del /f "%CARBON_HOME%\repository\components\lib\bcpg-fips-%BCPG_FIPS_VERSION%.jar" 2>nul
        ) else (
            FOR /F "tokens=*" %%G IN ('certutil -hashfile "%CARBON_HOME%\repository\components\lib\bcpg-fips-%BCPG_FIPS_VERSION%.jar" SHA1 ^| FIND /V ":"') DO SET "actual_checksum=%%G"
            if "!actual_checksum!"=="%EXPECTED_BCPG_FIPS_CHECKSUM%" (
                echo Checksum verified: The downloaded bcpg-fips-%BCPG_FIPS_VERSION%.jar is valid.
            ) else (
                echo Checksum verification failed: The downloaded bcpg-fips-%BCPG_FIPS_VERSION%.jar may be corrupted.
                del /f "%CARBON_HOME%\repository\components\lib\bcpg-fips-%BCPG_FIPS_VERSION%.jar"
            )
        )
    )
)

rem --- bctls-fips ---
if exist "%CARBON_HOME%\repository\components\lib\bctls-fips*.jar" (
    for /f "delims=" %%a in ('dir /b /s "%CARBON_HOME%\repository\components\lib\bctls-fips*.jar"') do (
        set "bctlsfips_location=%%a"
        goto check_bctlsfips
    )
    :check_bctlsfips
    for %%f in ("!bctlsfips_location!") do set "bctlsfips_filename=%%~nxf"
    if not "!bctlsfips_filename!"=="bctls-fips-%BCTLS_FIPS_VERSION%.jar" (
        set server_restart_required=true
        echo There is an update for bctls-fips. Therefore removing existing bctls-fips jar from lib folder.
        del /q "%CARBON_HOME%\repository\components\lib\bctls-fips*.jar" 2>nul
        echo Successfully removed bctls-fips-%BCTLS_FIPS_VERSION%.jar from components\lib.
        if exist "%CARBON_HOME%\repository\components\dropins\bctls_fips*.jar" (
            echo Remove existing bctls-fips jar from dropins folder.
            del /q "%CARBON_HOME%\repository\components\dropins\bctls_fips*.jar" 2>nul
            echo Successfully removed bctls_fips-%BCTLS_FIPS_VERSION%.jar from components\dropins.
        )
    )
)
if not exist "%CARBON_HOME%\repository\components\lib\bctls-fips*.jar" (
    set server_restart_required=true
    if not "%arg1%"=="" if "%arg2%"=="" (
        if not exist "%arg1%\bctls-fips-%BCTLS_FIPS_VERSION%.jar" (
            echo Can not be found required bctls-fips-%BCTLS_FIPS_VERSION%.jar in given file path : "%arg1%".
        ) else (
            copy "%arg1%\bctls-fips-%BCTLS_FIPS_VERSION%.jar" "%CARBON_HOME%\repository\components\lib\"
            if %errorlevel% equ 0 (echo bctls-fips JAR file copied successfully.) else (echo Error copying bctls-fips JAR file.)
        )
    ) else if not "%arg2%"=="" (
        echo Downloading required bctls-fips jar : bctls-fips-%BCTLS_FIPS_VERSION%
        curl -f "%arg2%/org/bouncycastle/bctls-fips/%BCTLS_FIPS_VERSION%/bctls-fips-%BCTLS_FIPS_VERSION%.jar" -o "%CARBON_HOME%\repository\components\lib\bctls-fips-%BCTLS_FIPS_VERSION%.jar"
        if !errorlevel! neq 0 (
            echo Failed to download bctls-fips-%BCTLS_FIPS_VERSION%.jar.
            del /f "%CARBON_HOME%\repository\components\lib\bctls-fips-%BCTLS_FIPS_VERSION%.jar" 2>nul
        ) else (
            FOR /F "tokens=*" %%G IN ('certutil -hashfile "%CARBON_HOME%\repository\components\lib\bctls-fips-%BCTLS_FIPS_VERSION%.jar" SHA1 ^| FIND /V ":"') DO SET "actual_checksum=%%G"
            if "!actual_checksum!"=="%EXPECTED_BCTLS_FIPS_CHECKSUM%" (
                echo Checksum verified: The downloaded bctls-fips-%BCTLS_FIPS_VERSION%.jar is valid.
            ) else (
                echo Checksum verification failed: The downloaded bctls-fips-%BCTLS_FIPS_VERSION%.jar may be corrupted.
                del /f "%CARBON_HOME%\repository\components\lib\bctls-fips-%BCTLS_FIPS_VERSION%.jar"
            )
        )
    ) else (
        echo Downloading required bctls-fips jar : bctls-fips-%BCTLS_FIPS_VERSION%
        curl -f "https://repo1.maven.org/maven2/org/bouncycastle/bctls-fips/%BCTLS_FIPS_VERSION%/bctls-fips-%BCTLS_FIPS_VERSION%.jar" -o "%CARBON_HOME%\repository\components\lib\bctls-fips-%BCTLS_FIPS_VERSION%.jar"
        if !errorlevel! neq 0 (
            echo Failed to download bctls-fips-%BCTLS_FIPS_VERSION%.jar.
            del /f "%CARBON_HOME%\repository\components\lib\bctls-fips-%BCTLS_FIPS_VERSION%.jar" 2>nul
        ) else (
            FOR /F "tokens=*" %%G IN ('certutil -hashfile "%CARBON_HOME%\repository\components\lib\bctls-fips-%BCTLS_FIPS_VERSION%.jar" SHA1 ^| FIND /V ":"') DO SET "actual_checksum=%%G"
            if "!actual_checksum!"=="%EXPECTED_BCTLS_FIPS_CHECKSUM%" (
                echo Checksum verified: The downloaded bctls-fips-%BCTLS_FIPS_VERSION%.jar is valid.
            ) else (
                echo Checksum verification failed: The downloaded bctls-fips-%BCTLS_FIPS_VERSION%.jar may be corrupted.
                del /f "%CARBON_HOME%\repository\components\lib\bctls-fips-%BCTLS_FIPS_VERSION%.jar"
            )
        )
    )
)
goto printRestartMsg

rem ===========================================================================
:verifyFipsMode
set verify=true

rem Non-FIPS jars must NOT be in plugins/
for %%p in (bcprov-jdk18on bcpkix-jdk18on bcutil-jdk18on bcpg-jdk18on bctls-jdk18on) do (
    if exist "%CARBON_HOME%\repository\components\plugins\%%p*.jar" (
        for /r "%CARBON_HOME%\repository\components\plugins\" %%G in (%%p*.jar) do (
            set "found_name=%%~nxG"
            goto foundNonFips_%%p
        )
        :foundNonFips_%%p
        set verify=false
        echo Found !found_name! in plugins folder. This jar should be removed.
    )
)

rem Non-FIPS entries must NOT be in bundles.info
for %%p in (bcprov-jdk18on bcpkix-jdk18on bcutil-jdk18on bcpg-jdk18on bctls-jdk18on) do (
    findstr /i /c:"%%p" "%bundles_info%" >nul
    if !errorlevel!==0 (
        set verify=false
        echo Found %%p entry in bundles.info. This should be removed.
    )
)

rem FIPS jars must be present and at the correct version in lib/
if exist "%CARBON_HOME%\repository\components\lib\bc-fips*.jar" (
    if not exist "%CARBON_HOME%\repository\components\lib\bc-fips-%BC_FIPS_VERSION%.jar" (
        set verify=false
        echo There is an update for bc-fips. Run the script again to get updates.
    )
) else (
    set verify=false
    echo Can not be found bc-fips-%BC_FIPS_VERSION%.jar in components\lib folder. This jar should be added.
)
if exist "%CARBON_HOME%\repository\components\lib\bcpkix-fips*.jar" (
    if not exist "%CARBON_HOME%\repository\components\lib\bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar" (
        set verify=false
        echo There is an update for bcpkix-fips. Run the script again to get updates.
    )
) else (
    set verify=false
    echo Can not be found bcpkix-fips-%BCPKIX_FIPS_VERSION%.jar in components\lib folder. This jar should be added.
)
if exist "%CARBON_HOME%\repository\components\lib\bcutil-fips*.jar" (
    if not exist "%CARBON_HOME%\repository\components\lib\bcutil-fips-%BCUTIL_FIPS_VERSION%.jar" (
        set verify=false
        echo There is an update for bcutil-fips. Run the script again to get updates.
    )
) else (
    set verify=false
    echo Can not be found bcutil-fips-%BCUTIL_FIPS_VERSION%.jar in components\lib folder. This jar should be added.
)
if exist "%CARBON_HOME%\repository\components\lib\bcpg-fips*.jar" (
    if not exist "%CARBON_HOME%\repository\components\lib\bcpg-fips-%BCPG_FIPS_VERSION%.jar" (
        set verify=false
        echo There is an update for bcpg-fips. Run the script again to get updates.
    )
) else (
    set verify=false
    echo Can not be found bcpg-fips-%BCPG_FIPS_VERSION%.jar in components\lib folder. This jar should be added.
)
if exist "%CARBON_HOME%\repository\components\lib\bctls-fips*.jar" (
    if not exist "%CARBON_HOME%\repository\components\lib\bctls-fips-%BCTLS_FIPS_VERSION%.jar" (
        set verify=false
        echo There is an update for bctls-fips. Run the script again to get updates.
    )
) else (
    set verify=false
    echo Can not be found bctls-fips-%BCTLS_FIPS_VERSION%.jar in components\lib folder. This jar should be added.
)

if "%verify%"=="true" (
    echo Verified : Product is FIPS compliant.
) else (
    echo Verification failed : Product is not FIPS compliant.
)
goto end

rem ===========================================================================
:printRestartMsg
if "%server_restart_required%"=="true" echo Please restart the server.
goto end

:noServerHome
echo CARBON_HOME is set incorrectly or CARBON could not be located. Please set CARBON_HOME.
goto end

:end
endlocal

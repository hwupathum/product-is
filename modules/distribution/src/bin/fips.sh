#! /bin/bash
# ----------------------------------------------------------------------------
#  Copyright 2023-2026 WSO2, LLC. http://www.wso2.org
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.

BC_FIPS_VERSION=2.1.2
BCPKIX_FIPS_VERSION=2.1.10
BCUTIL_FIPS_VERSION=2.1.5
BCPG_FIPS_VERSION=2.1.11
BCTLS_FIPS_VERSION=2.1.22

EXPECTED_BC_FIPS_CHECKSUM="061fbe8383f70489dda95a11a2a4739eb818ff2c"
EXPECTED_BCPKIX_FIPS_CHECKSUM="41d15c70437440d63b65225d7c00873a030d25d0"
EXPECTED_BCUTIL_FIPS_CHECKSUM="30b41ebc759a4f02e2ff7ab9acb09268923ee41f"
EXPECTED_BCPG_FIPS_CHECKSUM="727e087a843f3a5a8143e4f3a7518c8c3517df18"
EXPECTED_BCTLS_FIPS_CHECKSUM="d2979016bf75ef8b5e8aa17211399651a391a21f"

PRGDIR=$(dirname "$PRG")

# Only set CARBON_HOME if not already set
[ -z "$CARBON_HOME" ] && CARBON_HOME=$(cd "$PRGDIR/.." || exit 1; pwd)

ARGUMENT=$1
bundles_info="$CARBON_HOME/repository/components/default/configuration/org.eclipse.equinox.simpleconfigurator/bundles.info"
homeDir="$HOME"
server_restart_required=false

# ---------------------------------------------------------------------------
# Helper: cross-platform SHA-1 checksum
# ---------------------------------------------------------------------------
sha1_checksum() {
    if command -v sha1sum > /dev/null 2>&1; then
        sha1sum "$1" | cut -d' ' -f1
    else
        shasum -a 1 "$1" | cut -d' ' -f1
    fi
}

# ---------------------------------------------------------------------------
# Helper: remove a FIPS jar from lib/ and its matching dropins/ jar if present
# ---------------------------------------------------------------------------
remove_fips_lib_jar() {
    local name_pattern="$1"
    local dropins_pattern="$2"
    local display_version="$3"

    if ls "$CARBON_HOME/repository/components/lib/$name_pattern"*.jar 1>/dev/null 2>&1; then
        server_restart_required=true
        echo "Remove existing $name_pattern jar from lib folder."
        rm "$CARBON_HOME/repository/components/lib/$name_pattern"*.jar 2>/dev/null
        echo "Successfully removed ${name_pattern}-${display_version}.jar from component/lib."
    fi
    if ls "$CARBON_HOME/repository/components/dropins/$dropins_pattern"*.jar 1>/dev/null 2>&1; then
        server_restart_required=true
        echo "Remove existing $dropins_pattern jar from dropins folder."
        rm "$CARBON_HOME/repository/components/dropins/$dropins_pattern"*.jar 2>/dev/null
        echo "Successfully removed ${dropins_pattern}-${display_version}.jar from component/dropins."
    fi
}

# ---------------------------------------------------------------------------
# Helper: restore a non-FIPS jar from backup to plugins/ and capture metadata
# Sets <var_prefix>_file_name and <var_prefix>_version in the caller's scope
# ---------------------------------------------------------------------------
restore_nonfips_jar() {
    local pattern="$1"
    local var_prefix="$2"

    if ! ls "$CARBON_HOME/repository/components/plugins/$pattern"*.jar 1>/dev/null 2>&1; then
        server_restart_required=true
        if ls "$homeDir/.wso2-bc/backup/$pattern"*.jar 1>/dev/null 2>&1; then
            local location
            location=$(find "$homeDir/.wso2-bc/backup/" -type f -name "${pattern}*.jar" | head -1)
            local file_name version
            file_name=$(basename "$location")
            version=${file_name#*_}
            version=${version%.jar}
            mv "$location" "$CARBON_HOME/repository/components/plugins"
            echo "Moved $file_name from $homeDir/.wso2-bc/backup to components/plugins."
            eval "${var_prefix}_file_name=\"$file_name\""
            eval "${var_prefix}_version=\"$version\""
        else
            echo "Required $pattern jar is not available in $homeDir/.wso2-bc/backup. Download the jar from maven central repository."
        fi
    fi
}

# ---------------------------------------------------------------------------
# Helper: backup a non-FIPS jar from plugins/ to ~/.wso2-bc/backup
# ---------------------------------------------------------------------------
backup_nonfips_jar() {
    local pattern="$1"

    if ls "$CARBON_HOME/repository/components/plugins/$pattern"*.jar 1>/dev/null 2>&1; then
        server_restart_required=true
        local location
        location=$(find "$CARBON_HOME/repository/components/plugins/" -type f -name "${pattern}*.jar" | head -1)
        echo "Remove existing $pattern jar from plugins folder."
        if ls "$homeDir/.wso2-bc/backup/$pattern"*.jar 1>/dev/null 2>&1; then
            rm "$homeDir/.wso2-bc/backup/$pattern"*.jar
        fi
        mv "$location" "$homeDir/.wso2-bc/backup"
        echo "Successfully removed $(basename "$location") from component/plugins."
    fi
}

# ---------------------------------------------------------------------------
# Helper: ensure a FIPS jar is present and up to date in lib/
# ---------------------------------------------------------------------------
ensure_fips_jar() {
    local name="$1"
    local version="$2"
    local expected_checksum="$3"
    local maven_artifact="$4"
    local arg1="$5"
    local arg2="$6"
    local lib="$CARBON_HOME/repository/components/lib"
    local dropins="$CARBON_HOME/repository/components/dropins"
    local dropins_pattern
    dropins_pattern=$(echo "$name" | tr '-' '_')

    # Remove outdated version if present
    if ls "$lib/$name"*.jar 1>/dev/null 2>&1; then
        local location
        location=$(find "$lib/" -type f -name "${name}*.jar" | head -1)
        if [ ! "$location" = "$lib/$name-$version.jar" ]; then
            server_restart_required=true
            echo "There is an update for $name. Therefore removing existing $name jar from lib folder."
            rm "$lib/$name"*.jar 2>/dev/null
            echo "Successfully removed ${name}-${version}.jar from component/lib."
            if ls "$dropins/${dropins_pattern}"*.jar 1>/dev/null 2>&1; then
                echo "Remove existing $name jar from dropins folder."
                rm "$dropins/${dropins_pattern}"*.jar 2>/dev/null
                echo "Successfully removed ${dropins_pattern}-${version}.jar from component/dropins."
            fi
        fi
    fi

    # Download or copy if still missing
    if ! ls "$lib/$name"*.jar 1>/dev/null 2>&1; then
        server_restart_required=true
        if [ -z "$arg1" ] && [ -z "$arg2" ]; then
            echo "Downloading required $name jar : $name-$version"
            if curl -f "https://repo1.maven.org/maven2/org/bouncycastle/$maven_artifact/$version/$maven_artifact-$version.jar" \
                -o "$lib/$name-$version.jar"; then
                local actual_checksum
                actual_checksum=$(sha1_checksum "$lib/$name-$version.jar")
                if [ "$expected_checksum" = "$actual_checksum" ]; then
                    echo "Checksum verified: The downloaded $name-$version.jar is valid."
                else
                    echo "Checksum verification failed: The downloaded $name-$version.jar may be corrupted."
                    rm "$lib/$name-$version.jar"
                fi
            else
                echo "Failed to download $name-$version.jar."
                rm -f "$lib/$name-$version.jar"
            fi
        elif [ -n "$arg1" ] && [ -z "$arg2" ]; then
            if [ ! -e "$arg1/$name-$version.jar" ]; then
                echo "Can not be found required $name-$version.jar in given file path : $arg1."
            else
                if cp "$arg1/$name-$version.jar" "$lib"; then
                    echo "$name JAR file copied successfully."
                else
                    echo "Error copying $name JAR file."
                fi
            fi
        else
            echo "Downloading required $name jar : $name-$version"
            if curl -f "$arg2/org/bouncycastle/$maven_artifact/$version/$maven_artifact-$version.jar" \
                -o "$lib/$name-$version.jar"; then
                local actual_checksum
                actual_checksum=$(sha1_checksum "$lib/$name-$version.jar")
                if [ "$expected_checksum" = "$actual_checksum" ]; then
                    echo "Checksum verified: The downloaded $name-$version.jar is valid."
                else
                    echo "Checksum verification failed: The downloaded $name-$version.jar may be corrupted."
                    rm "$lib/$name-$version.jar"
                fi
            else
                echo "Failed to download $name-$version.jar."
                rm -f "$lib/$name-$version.jar"
            fi
        fi
    fi
}

# ---------------------------------------------------------------------------
# Helper: verify a FIPS jar is present and at the correct version in lib/
# ---------------------------------------------------------------------------
check_fips_jar() {
    local name="$1"
    local version="$2"

    if ls "$CARBON_HOME/repository/components/lib/$name"*.jar 1>/dev/null 2>&1; then
        if [ ! -f "$CARBON_HOME/repository/components/lib/$name-$version.jar" ]; then
            verify=false
            echo "There is an update for $name. Run the script again to get updates."
        fi
    else
        verify=false
        echo "Can not be found $name-$version.jar in components/lib folder. This jar should be added."
    fi
}

# ===========================================================================

if [ "$ARGUMENT" = "DISABLE" ] || [ "$ARGUMENT" = "disable" ]; then

    # Remove all FIPS jars from lib/ and dropins/
    remove_fips_lib_jar "bc-fips"     "bc_fips"     "$BC_FIPS_VERSION"
    remove_fips_lib_jar "bcpkix-fips" "bcpkix_fips" "$BCPKIX_FIPS_VERSION"
    remove_fips_lib_jar "bcutil-fips" "bcutil_fips" "$BCUTIL_FIPS_VERSION"
    remove_fips_lib_jar "bcpg-fips"   "bcpg_fips"   "$BCPG_FIPS_VERSION"
    remove_fips_lib_jar "bctls-fips"  "bctls_fips"  "$BCTLS_FIPS_VERSION"

    # Restore all non-FIPS jars from backup to plugins/
    restore_nonfips_jar "bcprov-jdk18on"  "bcprov"
    restore_nonfips_jar "bcpkix-jdk18on"  "bcpkix"
    restore_nonfips_jar "bcutil-jdk18on"  "bcutil"
    restore_nonfips_jar "bcpg-jdk18on"    "bcpg"
    restore_nonfips_jar "bctls-jdk18on"   "bctls"

    # Restore bundles.info entries for non-FIPS jars
    for entry in \
        "bcprov-jdk18on:${bcprov_version}:${bcprov_file_name}" \
        "bcpkix-jdk18on:${bcpkix_version}:${bcpkix_file_name}" \
        "bcutil-jdk18on:${bcutil_version}:${bcutil_file_name}" \
        "bcpg-jdk18on:${bcpg_version}:${bcpg_file_name}" \
        "bctls-jdk18on:${bctls_version}:${bctls_file_name}"
    do
        IFS=':' read -r jar_name jar_ver jar_file <<< "$entry"
        if [ -z "$jar_ver" ] || [ -z "$jar_file" ]; then
            echo "Skipping bundles.info entry for $jar_name: JAR was not restored from backup."
            continue
        fi
        text="$jar_name,$jar_ver,../plugins/$jar_file,4,true"
        if ! grep -q "$text" "$bundles_info"; then
            echo "$text" >> "$bundles_info"
            server_restart_required=true
        fi
    done

elif [ "$ARGUMENT" = "VERIFY" ] || [ "$ARGUMENT" = "verify" ]; then
    verify=true

    # Non-FIPS jars must NOT be in plugins/
    for pattern in "bcprov-jdk18on" "bcpkix-jdk18on" "bcutil-jdk18on" "bcpg-jdk18on" "bctls-jdk18on"; do
        if ls "$CARBON_HOME/repository/components/plugins/$pattern"*.jar 1>/dev/null 2>&1; then
            location=$(find "$CARBON_HOME/repository/components/plugins/" -type f -name "${pattern}*.jar" | head -1)
            verify=false
            echo "Found $(basename "$location") in plugins folder. This jar should be removed."
        fi
    done

    # Non-FIPS entries must NOT be in bundles.info
    for pattern in "bcprov-jdk18on" "bcpkix-jdk18on" "bcutil-jdk18on" "bcpg-jdk18on" "bctls-jdk18on"; do
        if grep -q "$pattern" "$bundles_info"; then
            verify=false
            echo "Found $pattern entry in bundles.info. This should be removed."
        fi
    done

    # FIPS jars must be present and at the correct version in lib/
    check_fips_jar "bc-fips"     "$BC_FIPS_VERSION"
    check_fips_jar "bcpkix-fips" "$BCPKIX_FIPS_VERSION"
    check_fips_jar "bcutil-fips" "$BCUTIL_FIPS_VERSION"
    check_fips_jar "bcpg-fips"   "$BCPG_FIPS_VERSION"
    check_fips_jar "bctls-fips"  "$BCTLS_FIPS_VERSION"

    if [ "$verify" = true ]; then
        echo "Verified : Product is FIPS compliant."
    else
        echo "Verification failed : Product is not FIPS compliant."
    fi

else
    while getopts "f:m:" opt; do
        case $opt in
            f) arg1=$OPTARG ;;
            m) arg2=$OPTARG ;;
            \?)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done

    if [ ! -d "$homeDir/.wso2-bc" ]; then
        mkdir "$homeDir/.wso2-bc"
    fi
    if [ ! -d "$homeDir/.wso2-bc/backup" ]; then
        mkdir "$homeDir/.wso2-bc/backup"
    fi

    # Move all non-FIPS jars from plugins/ to backup
    backup_nonfips_jar "bcprov-jdk18on"
    backup_nonfips_jar "bcpkix-jdk18on"
    backup_nonfips_jar "bcutil-jdk18on"
    backup_nonfips_jar "bcpg-jdk18on"
    backup_nonfips_jar "bctls-jdk18on"

    # Remove non-FIPS entries from bundles.info
    for pattern in "bcprov-jdk18on" "bcpkix-jdk18on" "bcutil-jdk18on" "bcpg-jdk18on" "bctls-jdk18on"; do
        if grep -q "$pattern" "$bundles_info"; then
            server_restart_required=true
            perl -i -ne "print unless /$pattern/" "$bundles_info"
        fi
    done

    # Ensure all FIPS jars are present and up to date in lib/
    ensure_fips_jar "bc-fips"     "$BC_FIPS_VERSION"     "$EXPECTED_BC_FIPS_CHECKSUM"     "bc-fips"     "$arg1" "$arg2"
    ensure_fips_jar "bcpkix-fips" "$BCPKIX_FIPS_VERSION" "$EXPECTED_BCPKIX_FIPS_CHECKSUM" "bcpkix-fips" "$arg1" "$arg2"
    ensure_fips_jar "bcutil-fips" "$BCUTIL_FIPS_VERSION" "$EXPECTED_BCUTIL_FIPS_CHECKSUM" "bcutil-fips" "$arg1" "$arg2"
    ensure_fips_jar "bcpg-fips"   "$BCPG_FIPS_VERSION"   "$EXPECTED_BCPG_FIPS_CHECKSUM"   "bcpg-fips"   "$arg1" "$arg2"
    ensure_fips_jar "bctls-fips"  "$BCTLS_FIPS_VERSION"  "$EXPECTED_BCTLS_FIPS_CHECKSUM"  "bctls-fips"  "$arg1" "$arg2"

fi

if [ "$server_restart_required" = true ]; then
    echo "Please restart the server."
fi

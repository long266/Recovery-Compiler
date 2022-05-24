#!/bin/bash

printf "\e[1;32m \u2730 Recovery Compiler\e[0m\n\n"

echo "::group::Free Space Checkup"
if [[ ! $(df / --output=avail | tail -1 | awk '{print $NF}') -ge 41943040 ]]; then
    printf "Please use 'slimhub_actions@main' Action prior to this Recovery Compiler Action to gain at least 40 GB space\n"
    exit 1
else
    printf "You have %s space available\n" "$(df -h / --output=avail | tail -1 | awk '{print $NF}')"
fi
echo "::endgroup::"

echo "::group::Mandatory Variables Checkup"
if [[ -z ${MANIFEST} ]]; then
    printf "Please Provide A Manifest URL with/without Branch\n"
    exit 1
fi
if [[ -z ${VENDOR} || -z ${CODENAME} ]]; then
    # Assume the workflow runs in the device tree
    # And the naming is exactly like android_device_vendor_codename(_split_codename)(-pbrp)
    # Optimized for PBRP Device Trees
	VenCode=$(echo ${GITHUB_REPOSITORY#*/} | sed 's/android_device_//;s/-pbrp//;s/-recovery//')
    export VENDOR=$(echo ${VenCode} | cut -d'_' -f1)
    export CODENAME=$(echo ${VenCode} | cut -d'_' -f2-)
	unset VenCode
fi
if [[ -z ${DT_LINK} ]]; then
    # Assume the workflow runs in the device tree with the current checked-out branch
    DT_BR=${GITHUB_REF##*/}
    export DT_LINK="https://github.com/${GITHUB_REPOSITORY} -b ${DT_BR}"
	unset DT_BR
fi
# Default TARGET will be recoveryimage if not provided
export TARGET=${TARGET:-recoveryimage}
# Default FLAVOR will be eng if not provided
export FLAVOR=${FLAVOR:-eng}
# Default TZ (Timezone) will be set as UTC if not provided
export TZ=${TZ:-UTC}
if [[ ! ${TZ} == "UTC" ]]; then
    sudo timedatectl set-timezone ${TZ}
fi
echo "::endgroup::"

printf "We are going to build ${FLAVOR}-flavored ${TARGET} for ${CODENAME} from the manufacturer ${VENDOR}\n"

echo "::group::Installation Of Recommended Programs"
export \
    DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    JAVA_OPTS=" -Xmx7G " JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
sudo apt-get -qqy update &>/dev/null
sudo apt-get -qqy install --no-install-recommends \
    lsb-core lsb-security patchutils bc \
    android-sdk-platform-tools adb fastboot \
    openjdk-8-jdk ca-certificates-java maven \
    python-is-python2 \
    lzip lzop xzdec pixz libzstd-dev lib32z1-dev \
    exfat-utils exfat-fuse \
    build-essential gcc gcc-multilib g++-multilib clang llvm lld cmake ninja-build \
    libxml2-utils xsltproc expat re2c libxml2-utils xsltproc expat re2c \
    libreadline-gplv2-dev libsdl1.2-dev libtinfo5 xterm rename schedtool bison gperf libb2-dev \
    pngcrush imagemagick optipng advancecomp ccache
printf "Cleaning Some Programs...\n"
sudo apt-get -qqy purge default-jre-headless openjdk-11-jre-headless python &>/dev/null
sudo apt-get -qy clean &>/dev/null && sudo apt-get -qy autoremove &>/dev/null
sudo rm -rf -- /var/lib/apt/lists/* /var/cache/apt/archives/* &>/dev/null
echo "::endgroup::"

echo "::group::Installation Of repo"
cd /home/runner || exit 1
printf "Adding latest stable repo...\n"
curl -sL https://storage.googleapis.com/git-repo-downloads/repo > repo
chmod a+rx ./repo && sudo mv ./repo /usr/local/bin/
echo "::endgroup::"

echo "::group::Doing Some Random Stuff"
if [ -e /lib/x86_64-linux-gnu/libncurses.so.6 ] && [ ! -e /usr/lib/x86_64-linux-gnu/libncurses.so.5 ]; then
    ln -s /lib/x86_64-linux-gnu/libncurses.so.6 /usr/lib/x86_64-linux-gnu/libncurses.so.5
fi
export \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    USE_CCACHE=1 CCACHE_COMPRESS=1 CCACHE_COMPRESSLEVEL=8 CCACHE_DIR=/opt/ccache \
    TERM=xterm-256color
. /home/runner/.bashrc 2>/dev/null
echo "::endgroup::"

echo "::group::Setting ccache"
mkdir -p /opt/ccache &>/dev/null
sudo chown runner:docker /opt/ccache
CCACHE_DIR=/opt/ccache ccache -M 5G &>/dev/null
printf "All Preparation Done.\nReady To Build Recoveries...\n"
echo "::endgroup::"

# cd To An Absolute Path
mkdir -p /home/runner/builder &>/dev/null
cd /home/runner/builder || exit 1

# Setup the Sync Branch
if [ -z "$SYNC_BRANCH" ]; then
    export SYNC_BRANCH=$(echo ${FOX_BRANCH} | cut -d_ -f2)
fi

echo "::group::Source Repo Sync"
printf "Initializing Repo\n"
python --version
python3 --version
python2 --version

if [ "$MANIFEST" = "fox_12.1" ]; then
    git clone ${MANIFEST} fox_sync || { printf "ERROR: Repo Initialization Failed.\n"; exit 1; }
    cd fox_sync
    chmod a+x orangefox_sync.sh
    ./orangefox_sync.sh --branch 12.1 --path /home/runner/builder/orangefox || { printf "ERROR: Failed to Sync OrangeFox Sources.\n"; exit 1; }
    cd /home/runner/builder/orangefox
elif [ "$MANIFEST" = "fox_11.0" ]; then
    git clone ${MANIFEST} fox_sync || { printf "ERROR: Repo Initialization Failed.\n"; exit 1; }
    cd fox_sync
    chmod a+x orangefox_sync.sh
    ./orangefox_sync.sh --branch 11.0 --path /home/runner/builder/orangefox || { printf "ERROR: Failed to Sync OrangeFox Sources.\n"; exit 1; }
    cd /home/runner/builder/orangefox
elif [ "$MANIFEST" = "fox_10.0" ]; then
    git clone ${MANIFEST} fox_sync || { printf "ERROR: Repo Initialization Failed.\n"; exit 1; }
    cd fox_sync
    chmod a+x orangefox_sync.sh
    ./orangefox_sync.sh --branch 10.0 --path /home/runner/builder/orangefox || { printf "ERROR: Failed to Sync OrangeFox Sources.\n"; exit 1; }
    cd /home/runner/builder/orangefox
elif [ "$MANIFEST" = "fox_9.0" ]; then
    git clone ${MANIFEST} fox_sync || { printf "ERROR: Repo Initialization Failed.\n"; exit 1; }
    cd fox_sync
    chmod a+x orangefox_sync.sh
    ./orangefox_sync.sh --branch 9.0 --path /home/runner/builder/orangefox || { printf "ERROR: Failed to Sync OrangeFox Sources.\n"; exit 1; }
    cd /home/runner/builder/orangefox
else
    mkdir -p /home/runner/builder/twrp
    cd /home/runner/builder/twrp
    repo init -u ${MANIFEST} -b ${BRANCH} || { printf "ERROR: Repo Initialization Failed.\n"; exit 1; }
    repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags || { printf "Git-Repo Sync Failed.\n"; exit 1; }
fi

echo "::endgroup::"

# Clone the theme if not already present
if [ ! -d bootable/recovery/gui/theme || "$MANIFEST" = "fox_*" ]; then
git clone https://gitlab.com/OrangeFox/misc/theme.git bootable/recovery/gui/theme || { printf "ERROR: Failed to Clone the OrangeFox Theme.\n"; exit 1; }
fi

echo "::group::Device and Kernel Tree Cloning"
printf "Cloning Device Tree\n"
git clone ${DT_LINK} --depth=1 device/${VENDOR}/${CODENAME}
# omni.dependencies file is a must inside DT, otherwise lunch fails
[[ ! -f device/${VENDOR}/${CODENAME}/omni.dependencies ]] && printf "[\n]\n" > device/${VENDOR}/${CODENAME}/omni.dependencies
if [[ ! -z "${KERNEL_LINK}" ]]; then
    printf "Using Manual Kernel Compilation\n"
    git clone ${KERNEL_LINK} --depth=1 kernel/${VENDOR}/${CODENAME}
else
    printf "Using Prebuilt Kernel For The Build.\n"
fi
echo "::endgroup::"

echo "::group::Extra Commands"
if [[ ! -z "$EXTRA_CMD" ]]; then
    printf "Executing Extra Commands\n"
    eval "${EXTRA_CMD}"
    cd /home/runner/builder || exit
fi
echo "::endgroup::"

echo "::group::Pre-Compilation"
printf "Compiling Recovery...\n"
export ALLOW_MISSING_DEPENDENCIES=true

# Only for (Unofficial) TWRP Building...
# If lunch throws error for roomservice, saying like `device tree not found` or `fetching device already present`,
# replace the `roomservice.py` with appropriate one according to platform version from here
# >> https://gist.github.com/rokibhasansagar/247ddd4ef00dcc9d3340397322051e6a/
# and then `source` and `lunch` again

# Set BRANCH_INT variable for future use
BRANCH_INT=$(echo $BRANCH | cut -d. -f1)

source build/envsetup.sh
# lunch the target
if [ "$BRANCH" = "twrp-12.1" ]; then
    lunch twrp_${CODENAME}-${FLAVOR} || { echo "ERROR: Failed to lunch the target!" && exit 1; }
else
    lunch omni_${CODENAME}-${FLAVOR} || { echo "ERROR: Failed to lunch the target!" && exit 1; }
fi
echo "::endgroup::"

echo "::group::Compilation"
make -j$(nproc + 1) ${TARGET} || { printf "ERROR: Compilation failed.\n"; exit 1; }
echo "::endgroup::"

# Export VENDOR, CODENAME and BuildPath for next steps
echo "VENDOR=${VENDOR}" >> ${GITHUB_ENV}
echo "CODENAME=${CODENAME}" >> ${GITHUB_ENV}
echo "BuildPath=/home/runner/builder" >> ${GITHUB_ENV}

# Add GitHub Release Script Here
cd out/target/product/${CODENAME}

# Download Transfer binary
curl -sL https://git.io/file-transfer | sh

# Set FILENAME var
FILENAME=$(echo $OUTPUT)

# Upload to oshi.at
TIMEOUT=80160

# Upload to WeTransfer
./transfer wet $FILENAME > link.txt || { echo "ERROR: Failed to Upload the Build!" && exit 1; }

# Mirror to oshi.at
curl -T $FILENAME https://oshi.at/${FILENAME}/${OUTPUT} > mirror.txt || { echo "WARNING: Failed to Mirror the Build!"; }

DL_LINK=$(cat link.txt | grep Download | cut -d\  -f3)
MIRROR_LINK=$(cat mirror.txt | grep Download | cut -d\  -f1)

# Show the Download Link
echo "=============================================="
echo "Download Link: ${DL_LINK}" || { echo "ERROR: Failed to Upload the Build!"; }
echo "Mirror: ${MIRROR_LINK}" || { echo "WARNING: Failed to Mirror the Build!"; }
echo "=============================================="

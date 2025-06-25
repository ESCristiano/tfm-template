#!/usr/bin/env bash
ROOT="$(realpath .)"
TFM="${ROOT}/../trusted-firmware-m"
NSPE_MSTP_APP=${ROOT}/../exp-m-step-eval-tfm
MSTP=${ROOT}/../m-step

# Default values
TARGET="STM32L5"
PROFILE="bare"

#-------------------------------------------------------------------------------
# Parse arguments
#-------------------------------------------------------------------------------
set -e

DEPLOY=false  # default

while [[ $# -gt 0 ]]; do
    case "$1" in
        -b|--build)
            BUILD_TYPE="$2"
            if [[   "$BUILD_TYPE" != "s"        && 
                    "$BUILD_TYPE" != "ns_costum" ]]; then
                echo "Error: Invalid build type '$BUILD_TYPE'. Supported values are 's', 'ns_costum'."
                exit 1
            fi
            shift 2
            ;;
        -c|--config)
            CONFIG_TYPE="$2"
            if [[ "$CONFIG_TYPE" != "s" && "$CONFIG_TYPE" != "ns_costum" ]]; then
                echo "Error: Invalid config type '$CONFIG_TYPE'. Supported values are 's' or 'ns_costum'."
                exit 1
            fi
            shift 2
            ;;
        -p|--profile)
            PROFILE="$2"
            if [[   "$PROFILE" != "mstp" 
                ]]; then
                echo "Error: Invalid profile '$PROFILE'."
                exit 1
            fi
            shift 2
            ;;
        -t|--target)
            TARGET="$2"
            shift 2
            ;;
        -d|--deploy)
            DEPLOY=true
            shift
            ;;
        *)
            echo "Unknown argument: $1"
            echo "Usage: $0 [-b|--build <s|ns_costum>] [-c|--config <s|ns_costum>] [-t|--target <BoardName>] [-d|--deploy] [-p|--profile <bare|crypto|mstp>]"
            exit 1
            ;;
    esac
done


#-------------------------------------------------------------------------------
# Decode target 
#-------------------------------------------------------------------------------
if [[ "${TARGET}" == *"L5"* ]]; then
        PLATFORM="nucleo_l552ze_q"
elif [[ "${TARGET}" == *"U5"* ]]; then
        PLATFORM="b_u585i_iot02a"
else
        echo "Unknown target: ${TARGET}"
        exit 1
fi

CONFIG="build/${PLATFORM}_${PROFILE}_${CONFIG_TYPE}"

#-------------------------------------------------------------------------------
# Configure SPE build system 
#-------------------------------------------------------------------------------
if [[ "${CONFIG_TYPE}" == "s" ]]; then

        # Out of tree Custom Secure Services Build
        # APPROT_TA=${MSTP}/mstp-victims/TAs/appRoT
        # PROT_CRYPTO_ATTACK_TA=${MSTP}/mstp-victims/TAs/PRoT_crypto_attack

        # PARTITION_PATHS="${APPROT_TA};${PROT_CRYPTO_ATTACK_TA}"
        # MANIFEST_LIST_FILE="${APPROT_TA}/appRoT_manifest_list.yaml;${PROT_CRYPTO_ATTACK_TA}/PRoT_crypto_attack_manifest_list.yaml"

        cmake   -S ${TFM}                                               \
                -B ${CONFIG}                                            \
                -C ${PLATFORM}-${PROFILE}-config.cmake
fi

BUILD="build/${PLATFORM}_${PROFILE}_${BUILD_TYPE}"

#-------------------------------------------------------------------------------
# Build SPE build system 
#-------------------------------------------------------------------------------
if [[ "${BUILD_TYPE}" == "s" ]]; then
        cmake --build ${BUILD} -- install
fi

#-------------------------------------------------------------------------------
# Build Costum NS
#-------------------------------------------------------------------------------
if [[ "${BUILD_TYPE}" == "ns_costum" ]]; then
        BUILD_S="build/${PLATFORM}_${PROFILE}_s"
            
        cmake --build ${NSPE_MSTP_APP}/build

        arm-none-eabi-objcopy -O binary \
        ${NSPE_MSTP_APP}/src/NonSecure/build/tfm_ns.elf \
        ${NSPE_MSTP_APP}/src/NonSecure/build/tfm_ns.bin

        imgtool sign \
          -k ${BUILD_S}/api_ns/image_signing/keys/image_ns_signing_private_key.pem \
          --public-key-format full \
          --align 1 \
          -v 0.0.0 \
          -s 1 \
          -H 1024 \
          --pad-header \
          -S 0x9000 \
          --pad \
          --boot-record boot \
          ${NSPE_MSTP_APP}/src/NonSecure/build/tfm_ns.bin \
          ${BUILD_S}/api_ns/image_signing/scripts/tfm_ns_signed.bin
fi

#-------------------------------------------------------------------------------
# Flash TFM
#-------------------------------------------------------------------------------
if $DEPLOY; then        
        BUILD_S="build/${PLATFORM}_${PROFILE}_s"
        TFM_SPE="$(realpath ${BUILD_S})"

        echo "Deploying for target ${TARGET} with profile ${TFM_SPE}"
        
        ${TFM_SPE}/api_ns/postbuild.sh
        # ${TFM_SPE}/api_ns/regression.sh
        ${TFM_SPE}/api_ns/TFM_UPDATE.sh      
fi

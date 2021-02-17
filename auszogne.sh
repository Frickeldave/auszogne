ASZ_SOURCEFOLDER=$(dirname "$(readlink -f "$0")")
ASZ_BASEFOLDER=/mnt/c/temp
ASZ_GIMPFILE=${ASZ_SOURCEFOLDER}/msg_v01.xcf
ASZ_DEBUG="false"
ASZ_WORKDIR="EMPTY"
ASZ_EXPORTCOUNT=0
ASZ_IMAGECOUNT=0
ASZ_STARTTIMESTRING=`date +%Y-%m-%d_%H:%M:%S`
ASZ_STARTTIME="$(date -u +%s)"

declare -a ASZ_LAYERS
declare -a ASZ_BACKLAYERS
declare -a ASZ_FRONTLAYERS

function main() {
    
    checkPrereqs
    createWorkdir    
    getGimpLayers
    writeImages
    showResultStatistics
}

function showResultStatistics() {
    
    local ASZ_ENDTIME="$(date -u +%s)"
    local ASZ_ENDTIMESTRING=`date +%Y-%m-%d_%H:%M:%S`
    local ASZ_ELAPSEDTIME="$(($ASZ_ENDTIME-$ASZ_STARTTIME))"
    
    printMessage "-------------------------------------------"
    printMessage "Images exported: $ASZ_EXPORTCOUNT"
    printMessage "Images created:  $ASZ_IMAGECOUNT"
    printMessage "Starttime:       $ASZ_STARTTIMESTRING"
    printMessage "Endtime:         $ASZ_ENDTIMESTRING"
    printMessage "Seconds elapsed: $ASZ_ELAPSEDTIME"
    printMessage "-------------------------------------------"
}

function writeImages() {
    
    printMessage "export images"
    
    for key in "${!ASZ_FRONTLAYERS[@]}"
    do
        local frontlayername=$(echo ${ASZ_FRONTLAYERS[key]} | cut -d'#' -f 2)
        local frontlayerbackindizes=$(echo ${ASZ_FRONTLAYERS[key]} | cut -d'#' -f 3)

        IFS=',' read -ra frontlayerbackindexarray <<< "$frontlayerbackindizes"

        printMessage "Try to export ${#frontlayerbackindexarray[@]} images for layer \"${frontlayername}\""

        for i in "${frontlayerbackindexarray[@]}"
        do
            local backlayername=$(echo ${ASZ_BACKLAYERS[${i}]} | cut -d'#' -f 2)

            if [ ! -d "${ASZ_WORKDIR}/${backlayername}" ]
            then
                mkdir "${ASZ_WORKDIR}/${backlayername}"
                if [ ! -d "${ASZ_WORKDIR}/${backlayername}" ]
                then
                    printError "Failed to create directory \"${ASZ_WORKDIR}/${backlayername}\""
                    exit 1
                fi
            fi
            printDebug "Export image \"${backlayername}_${frontlayername}.png\" with index composition from layers \"${i}\",\"${key}\""
            xcf2png "${ASZ_GIMPFILE}" "${ASZ_BACKLAYERS[${i}]}" "${ASZ_FRONTLAYERS[key]}" > "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}-2000.png"
            local imexpreturn=$?
            ASZ_EXPORTCOUNT=$((ASZ_EXPORTCOUNT+1))
            ASZ_IMAGECOUNT=$((ASZ_IMAGECOUNT+1))
            if [ ! "$imexpreturn" == "0" ]; then printError "Failed to convert image"; exit 1; fi
            
            createResizedCopy 512 "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}-2000.png" "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}"
            createResizedCopy 256 "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}-2000.png" "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}"
            createResizedCopy 128 "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}-2000.png" "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}"
            createResizedCopy 64 "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}-2000.png" "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}"
            createResizedCopy 48 "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}-2000.png" "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}"
            createResizedCopy 32 "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}-2000.png" "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}"
            createResizedCopy 16 "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}-2000.png" "${ASZ_WORKDIR}/${backlayername}/${backlayername}_${frontlayername}"

        done
    done
}

function createResizedCopy() {
    
    if [ ! "$1" == "512" ] && [ ! "$1" == "256" ] && [ ! "$1" == "128" ] && [ ! "$1" == "64" ] && [ ! "$1" == "48" ] && [ ! "$1" == "32" ] && [ ! "$1" == "16" ]; then printError "createResizedCopy: Got wrong input parameter \"$1\"."; return; fi
    if [ ! -f "$2" ]; then printError "createResizedCopy: Given sourcefile doesn't exist."; return; fi

    local _targetSize=$1
    local _sourceFile=$2
    local _targetFile=$3

    printDebug "createResizedCopy: Try to create a resized copy of image \"$_sourceFile\" with size \"${_targetSize}\"."

    convert "${_sourceFile}" -resize "${_targetSize}x${_targetSize}" "${_targetFile}-${_targetSize}.png"
    local _imresreturn=$?
    if [ ! "${_imresreturn}" == "0" ] || [ ! -f "${_targetFile}-${_targetSize}.png" ] ; then printError "createResizedCopy: Failed to convert image."; return; fi
    
    ASZ_IMAGECOUNT=$((ASZ_IMAGECOUNT+1))
    printDebug "createResizedCopy: Successful created resized copy of image."
}

function checkPrereqs() {
    
    if [ ! -d "${ASZ_BASEFOLDER}" ]; then printError "Failed to find basefolder \"${ASZ_BASEFOLDER}\"."; exit 1; fi
    if [ ! -f "${ASZ_GIMPFILE}" ]; then printError "Failed to find source GIMP file \"${ASZ_GIMPFILE}\"."; exit 1; fi
    if ! command -v xcfinfo &> /dev/null; then printError "Please install \"xcfinfo\" (probably part of package xcftools) to run programm"; exit 1; fi
    if ! command -v convert &> /dev/null; then printError "Please install \"convert\" (probably part of package imagemagick) to run programm"; exit 1; fi
}

function createWorkdir() {
    
    printMessage "Create working directory."

    if [ ! -d "${ASZ_BASEFOLDER}/exportfolder" ]
    then 
        printMessage "Create base workdir \"${ASZ_BASEFOLDER}/exportfolder\"."
        mkdir "${ASZ_BASEFOLDER}/exportfolder"
    fi

    ASZ_WORKDIRTIMESTAMP=`date +%H_%M_%S_%3N`
    ASZ_WORKDIR="${ASZ_BASEFOLDER}/exportfolder/export_${ASZ_WORKDIRTIMESTAMP}"

    if [ -d "${ASZ_WORKDIR}" ]
    then 
        printError "Workdir already exist. Exiting."
        exit 1
    else
        printMessage "Create workdir \"${ASZ_WORKDIR}\"."
        mkdir "${ASZ_WORKDIR}"
        if [ ! "$?" == "0" ]; then printError "Failed to create workdir. Exiting."; exit 1; fi
        if [ ! -d "${ASZ_WORKDIR}" ]; then printError "Failed to create workdir. Exiting."; exit 1; fi
    fi

    printMessage "Workdir successful created."
}

function getGimpLayers() {
    
    printMessage "Read out all gimp layers into local cache."

    local count=0
    # Count al layers
    while read -r layerinfo
    do
        count=$((count+1))
    done < <(xcfinfo $ASZ_GIMPFILE)

    printMessage "Found ${count} layers in source file."

    # Get all information from layers and store them into a local hash table
    while read -r layerinfo
    do
        count=$((count-1))
        
        if [[ ${layerinfo} == "Version 0"* ]]
        then
            printDebug "[${count}] skip line $layerinfo.";
        elif [[ ! ${layerinfo} == ??"2000x2000"* ]]
        then 
            printDebug "[${count}] Skip following layer because of wrong size: \"${layerinfo}\"."
        elif [[ ! ${layerinfo} == ???????????"+0+0"* ]]
        then 
            printDebug "[${count}] Skip following layer because of layer position: \"${layerinfo}\"."
        elif [[ ! ${layerinfo} == ????????????????"RGB-alpha"* ]]
        then 
            printDebug "[${count}] Skip following layer because of wrong color table: \"${layerinfo}\"."
        else
            ASZ_LAYERINFOSTRING=$(echo ${layerinfo} | cut -d' ' -f 5)
            if [[ ! ${ASZ_LAYERINFOSTRING} == "Front"* ]] && [[ ! ${ASZ_LAYERINFOSTRING} == "Back"* ]]
            then
                printDebug "[${count}] Skip following layer: Not declared as front or back layer: \"${layerinfo}\"."
            else
                printDebug "[${count}] Import ${layerinfo}."
                ASZ_LAYERS[count]=${ASZ_LAYERINFOSTRING}
            fi
        fi
    done < <(xcfinfo $ASZ_GIMPFILE)
    
    for key in "${!ASZ_LAYERS[@]}"
    do
        if [[ ${ASZ_LAYERS[$key]} == "Back"* ]]
        then
            printDebug "Set \"${key}\" - \"${ASZ_LAYERS[$key]}\" as background layer."
            ASZ_BACKLAYERS[key]=${ASZ_LAYERS[$key]}
        elif [[ ${ASZ_LAYERS[$key]} == "Front"* ]]
        then
            printDebug "Set \"${key}\" - \"${ASZ_LAYERS[$key]}\" as foreground layer."
            ASZ_FRONTLAYERS[key]=${ASZ_LAYERS[$key]}
        fi
    done

    printMessage "Successful imported ${#ASZ_LAYERS[@]} layers, devided into ${#ASZ_BACKLAYERS[@]} background layers and ${#ASZ_FRONTLAYERS[@]} foreground layers."
}

function printMessage() {
    local date=`date +%H:%M:%S.%3N`
    printf "\x1b[32m${date} INFO:    $1\x1b[0m\n"
}

function printError() {
    local date=`date +%H:%M:%S.%3N`
    printf "\x1b[31m${date} ERROR:   $1\x1b[0m\n"
}

function printWarning() {
    local date=`date +%H:%M:%S.%3N`
    printf "\x1b[33m${date} WARNING: $1\x1b[0m\n"
}

function printDebug() {
    if [ "${ASZ_DEBUG}" == "true" ]
    then
        local date=`date +%H:%M:%S.%3N`
        printf "${date} DEBUG:   $1\n"
    fi
}

main
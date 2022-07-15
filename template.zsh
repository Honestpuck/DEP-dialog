#!/bin/zsh

####################################################################################################
#
# DEP-dialog
#
# Purpose: Leverages swiftDialog v1.11.0.2758 (or later) (https://github.com/bartreardon/swiftDialog/releases) and 
# Jamf Pro Policy Custom Events to allow end-users to self-complete Mac setup post-enrollment
# via Jamf Pro's Self Service. (See Jamf Pro Known Issues PI100009 - PI-004775.)
#
# Inspired by: Rich Trouton (@rtrouton) and Bart Reardon (@bartreardon)
#
# Based on:
# - Adam Codega (@adamcodega)'s https://github.com/acodega/dialog-scripts/blob/main/MDMAppsDeploy.sh
# - James Smith (@smithjw)'s https://github.com/smithjw/speedy-prestage-pkg/tree/feature/swiftDialog
# - Dan K. Snelson (@dan-snelson)'s https://github.com/dan-snelson/dialog-scripts/tree/main/Setup%20Your%20Mac
#
####################################################################################################
#
# HISTORY
#
# Version 1.0.0, 30-Apr-2022, Dan K. Snelson (@dan-snelson)
#   First "official" release
#
# Version 1.1.0, 19-May-2022, Dan K. Snelson (@dan-snelson)
#   Added initial Splash screen with Asset Tag Capture and Debug Mode
#
# Version 1.2.0, 30-May-2022, Dan K. Snelson (@dan-snelson)
#   Changed `--infobuttontext` to `--infotext`
#   Added `regex` and `regexerror` for Asset Tag Capture
#   Replaced @adamcodega's `apps` with @smithjw's `policy_array`
#   Added progress update
#   Added filepath validation
#
# Version 1.2.1, 01-Jun-2022, Dan K. Snelson (@dan-snelson)
#   Made Asset Tag Capture optional (via Jamf Pro Script Paramter 5)
#
# Version 1.2.2, 07-Jun-2022, Dan K. Snelson (@dan-snelson)
#   Added "dark mode" for logo (thanks, @mm2270)
#   Added "compact" for `--liststyle`
#
# Version 2.0.0, 2022-07-14, Tony Williams (@tony.williams)
# Some major changes to make it more suited to my needs.
# Created a system for filling the policy array
# Changed so much that I'm changing the name so Dan gets no blame
# Defensive programming - I now have full paths for all tools
# Removed overlay icon for now
# Removed initial Splash screen with Asset Tag Capture
#
####################################################################################################

# Variables

scriptVersion="2.0.0"
debugMode="${4}"        # ( true | false, blank )
assetTagCapture="${5}"  # ( true | false, blank )

# For debugging from the command line
debugMode="true"

# Set Dialog path, Command Files, JAMF binary, log files and currently logged-in user
dialogApp="/usr/local/bin/dialog"
dialogCommandFile="/var/tmp/dialog.log"
loggedInUser=$( /bin/echo "show State:/Users/ConsoleUser" | /usr/sbin/scutil | /usr/bin/awk '/Name :/ { print $3 }' )
jamfBinary="/usr/local/bin/jamf"
logFolder="/var/log/"
logName="enrollment.log"

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# APPS TO BE INSTALLED
#
# For each configuration step, specify:
# - listitem: The text to be displayed in the list
# - icon: The hash of the icon to be displayed on the left
#   - See: https://rumble.com/v119x6y-harvesting-self-service-icons.html
# - progresstext: The text to be displayed below the progress bar 
# - trigger: The Jamf Pro Policy Custom Event Name
# - path: The filepath for validation
#
# To have the array filled automatically see snippets.py
# If you fill it automatically you have to leave in the last step as it simplifies handling the
# snippets - JSON doesn't like an extra comma at the end of the array.
#
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

policy_array=('
{
    "steps": [
        {
            "listitem": "FileVault Disk Encryption",
            "icon": "f9ba35bd55488783456d64ec73372f029560531ca10dfa0e8154a46d7732b913",
            "progresstext": "FileVault is built-in to macOS and provides full-disk encryption to help prevent unauthorized access to your Mac.",
            "trigger_list": [
                {
                    "trigger": "filevault",
                    "path": "/Library/Preferences/com.apple.fdesetup.plist"
                }
            ]
        },
        ###SNIPPETS###
        {
            "listitem": "Update Inventory",
            "icon": "90958d0e1f8f8287a86a1198d21cded84eeea44886df2b3357d909fe2e6f1296",
            "progresstext": "The listing of your computer’s installed apps and settings — its inventory — is automatically sent to the Jamf Pro server daily.",
            "trigger_list": [
                {
                    "trigger": "recon",
                    "path": ""
                }
            ]
        }
    ]
}
')


# Our dialog

title="Setting up your Mac"
message="Please wait while the following apps are installed …"

# Set initial icon based on whether the Mac is a desktop or laptop
hwType=$(/usr/sbin/system_profiler SPHardwareDataType | grep "Model Identifier" | grep "Book")  
if [ "$hwType" != "" ]; then
  icon="SF=laptopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
else
  icon="SF=desktopcomputer.and.arrow.down,weight=semibold,colour1=#ef9d51,colour2=#ef7951"
fi

# "Setting up your Mac" dialog call
dialogCMD="$dialogApp --ontop --title \"$title\" \
--message \"$message\" \
--icon \"$icon\" \
--progress $progress_total \
--button1text \"Quit\" \
--button1disabled \
--infotext \"v$scriptVersion\" \
--blurscreen \
--titlefont 'size=28' \
--messagefont 'size=14' \
--height '57%' \
--position 'centre' \
--liststyle 'compact' \
--quitkey k"

#------------------------------- Edits below this line are optional -------------------------------#

# JAMF display message (for fallback in case swiftDialog fails to install)
# If we are here then things are seriously broken and we need to bail out.
function jamfDisplayMessage() {
    echo "${1}"
    /usr/local/jamf/bin/jamf displayMessage -message "${1}" &
    exit 1
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Check for / install swiftDialog (thanks, Adam!)
# https://github.com/acodega/dialog-scripts/blob/main/dialogCheckFunction.sh
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
function dialogCheck(){
  # Get the URL of the latest PKG From the Dialog GitHub repo
  dialogURL=$(curl --silent --fail "https://api.github.com/repos/bartreardon/swiftDialog/releases/latest" | awk -F '"' "/browser_download_url/ && /pkg\"/ { print \$4; exit }")
  # Expected Team ID of the downloaded PKG
  expectedDialogTeamID="PWA5E9TQ59"

  # Check for Dialog and install if not found
  if [ ! -e "/Library/Application Support/Dialog/Dialog.app" ]; then
    echo "Dialog not found. Installing..."
    # Create temporary working directory
    workDirectory=$( /usr/bin/basename "$0" )
    tempDirectory=$( /usr/bin/mktemp -d "/private/tmp/$workDirectory.XXXXXX" )
    # Download the installer package
    /usr/bin/curl --location --silent "$dialogURL" -o "$tempDirectory/Dialog.pkg"
    # Verify the download
    teamID=$(/usr/sbin/spctl -a -vv -t install "$tempDirectory/Dialog.pkg" 2>&1 | awk '/origin=/ {print $NF }' | tr -d '()')
    # Install the package if Team ID validates
    if [ "$expectedDialogTeamID" = "$teamID" ] || [ "$expectedDialogTeamID" = "" ]; then
      /usr/sbin/installer -pkg "$tempDirectory/Dialog.pkg" -target /
    else
      jamfDisplayMessage "Dialog Team ID verification failed."
      exit 1
    fi
    # Remove the temporary working directory when done
    /bin/rm -Rf "$tempDirectory"  
  else
    echo_logger "DIALOG: version $(dialog --version) found; proceeding..."
  fi
}

# Execute a dialog command
function dialog_update() {
    echo_logger "DIALOG: $1"
    # shellcheck disable=2001
    echo "$1" >> "$dialogCommandFile"
}

# Finalise app installations
function finalise(){
  dialog_update "icon: SF=checkmark.circle.fill,weight=bold,colour1=#00ff44,colour2=#075c1e"
  dialog_update "progresstext: Complete! Please restart and enjoy your new Mac!"
  dialog_update "progress: complete"
  dialog_update "button1text: Quit"
  dialog_update "button1: enable"
  /bin/rm "$dialogCommandFile"
  exit 0
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
#  smithjw's Logging Function (with preferred date / timestamp)
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
function echo_logger() {
    logFolder="${logFolder:=/private/var/log}"
    logName="${logName:=log.log}"

    /bin/mkdir -p $logFolder

    echo -e "$(/bin/date +%Y-%m-%d\ %H:%M:%S)  $1" |  /usr/bin/tee -a $logFolder/$logName
}

# Parse JSON via osascript and JavaScript
function get_json_value() {
    JSON="$1" /usr/bin/osascript -l 'JavaScript' \
        -e 'const env = $.NSProcessInfo.processInfo.environment.objectForKey("JSON").js' \
        -e "JSON.parse(env).$2"
}

# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# smithjw's sweet function to execute Jamf Pro Policy Custom Events
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
function run_jamf_trigger() {
    trigger="$1"
    if [ "$debugMode" = true ]; then
        echo_logger "DIALOG: DEBUG MODE: $jamfBinary policy -event $trigger"
        /bin/sleep 10
    elif [ "$trigger" == "recon" ]; then
        echo_logger "DIALOG: RUNNING: $jamfBinary recon"
        "$jamfBinary" recon
    else
        echo_logger "DIALOG: RUNNING: $jamfBinary policy -event $trigger"
        "$jamfBinary" policy -event "$trigger"
    fi
}

# Confirm script is running as root
if [[ $(id -u) -ne 0 ]]; then
  echo "This script should be run as root"
  exit 1
fi

# Validate swiftDialog is installed
dialogCheck

# Run swiftDialog
eval "$dialogApp" "${dialogCMD[*]}" & sleep 0.3
if [[ ${debugMode} == "true" ]]; then
    dialog_update "title: DEBUG MODE | $title"
fi

dialog_update "progresstext: Initializing configuration …"

# set progress_total to the number of steps
progress_total=$(get_json_value "${policy_array[*]}" "steps.length")
echo_logger "DIALOG: progress_total=$progress_total"

# start
progress_index=0
dialog_update "progress: $progress_index"

# Iterate through policy_array JSON to construct the list for swiftDialog
dialog_step_length=$(get_json_value "${policy_array[*]}" "steps.length")
for (( i=0; i<dialog_step_length; i++ )); do
    listitem=$(get_json_value "${policy_array[*]}" "steps[$i].listitem")
    list_item_array+=("$listitem")
done

# The ${array_name[*]/%/,} expansion will combine all items within the array adding a "," character at the end
# To add a character to the start, use "/#/" instead of the "/%/"
list_item_string=${list_item_array[*]/%/,}
dialog_update "list: ${list_item_string%?}"
for (( i=0; i<dialog_step_length; i++ )); do
    dialog_update "listitem: index: $i, status: wait, statustext: Pending"
done

# Iterate over each distinct step in the policy_array array
for (( i=0; i<dialog_step_length; i++ )); do

    # Increment the progress bar
    dialog_update "progress: $(( i * ( 100 / progress_total ) ))"

    # Creating initial variables
    listitem=$(get_json_value "${policy_array[*]}" "steps[$i].listitem")
    icon=$(get_json_value "${policy_array[*]}" "steps[$i].icon")
    progresstext=$(get_json_value "${policy_array[*]}" "steps[$i].progresstext")

    trigger_list_length=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list.length")

    # If there's a value in the variable, update running swiftDialog
    if [[ -n "$listitem" ]]; then dialog_update "listitem: index: $i, status: pending, statustext: Installing"; fi
    if [[ -n "$icon" ]]; then dialog_update "icon: https://ics.services.jamfcloud.com/icon/hash_$icon"; fi
    if [[ -n "$progresstext" ]]; then dialog_update "progresstext: $progresstext"; fi
    if [[ -n "$trigger_list_length" ]]; then
        for (( j=0; j<trigger_list_length; j++ )); do

            # Setting variables within the trigger_list
            trigger=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list[$j].trigger")
            path=$(get_json_value "${policy_array[*]}" "steps[$i].trigger_list[$j].path")

            # If the path variable has a value, check if that path exists on disk
            if [[ -f "$path" ]]; then
                echo_logger "INFO: $path exists, moving on"
                 if [[ "$debugMode" = true ]]; then /bin/sleep 7; fi
            else
                run_jamf_trigger "$trigger"
            fi
        done
    fi

    # Validate the expected path exists
    echo_logger "DIALOG: Testing for \"$path\" …"
    if [[ -f "$path" ]] || [[ -z "$path" ]] || [[ $debugMode ]]; then
        dialog_update "listitem: index: $i, status: success"
    else
        dialog_update "listitem: index: $i, status: fail, statustext: Failed"
    fi
done

# Complete processing and enable the "Done" button
finalise

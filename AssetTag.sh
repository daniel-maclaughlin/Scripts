#!/bin/sh

# Set CocoaDialog Location

CD="/usr/local/bin/cocoaDialog.app/Contents/MacOS/CocoaDialog"

# Dialog to enter the computer name and the create $COMPUTERNAME variable
rv=($($CD standard-inputbox --title "Asset Tag" --no-newline --informative-text "Enter the asset tag you wish to set"))

ASSETTAG=${rv[1]}


if [ "$rv" == "1" ]; then
echo "User said OK"
elif [ "$rv" == "2" ]; then
echo "Canceling"
exit
fi


# Set Hostname using variable created above
/usr/sbin/jamf recon -assetTag $ASSETTAG

# Dialog to confirm that the asset tag was set to.
tb=`$CD ok-msgbox --text "Asset Tag has been set to " --informative-text "The asset tag has been set to $ASSETTAG" --no-newline --float`

if [ "$tb" == "1" ]; then
echo "User said OK"
elif [ "$tb" == "2" ]; then
echo "Canceling"
exit
fi


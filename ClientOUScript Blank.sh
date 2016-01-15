#!/bin/sh

# FQDN of the AD
ADFQDN="mycompany.net"

# LDAP Search Base
LDAPBASE="DC=mycompany,DC=net"

# Full DN of our LDAP service account
LDAPDN="CN=Administrator,OU=Users,OU=mycompany,DC=net"

# Password of our ldap service account
LDAPPWD="password"

# Where our JSS lives
JSSURL="jss.mycompany.com"
JSSPORT=8443

# JSS accpunt with correct API priviliges
JSSUSER="jssapi"

# JSS account password
JSSPWD="password"

# Locate the Network Utility
if [ -x "/System/Library/CoreServices/Applications/Network Utility.app/Contents/Resources/stroke" ]; then
	STROKE="/System/Library/CoreServices/Applications/Network Utility.app/Contents/Resources/stroke"
else
	STROKE="/Applications/Utilities/Network Utility.app/Contents/Resources/stroke"
fi

# See if we can talk to the AD via LDAP
if ! "${STROKE}" "${ADFQDN}" 389 389 | grep -q "Open TCP Port" ; then
	# Exit if there's only one or less results
	echo "AD connection unavailable, exiting."
	exit 0
fi

# See if we can talk to the JSS via HTTPS
if ! "${STROKE}" "${JSSURL}" ${JSSPORT} ${JSSPORT} | grep -q "Open TCP Port" ; then
	echo "JSS connection unavailable, exiting."
	exit 0
fi

echo "NULL" > /tmp/ADComputerGroups
ComputerName=`scutil --get ComputerName`

# Query AD Computer Group Membership
ldapsearch -H ldap://"${ADFQDN}":389 -b "${LDAPBASE}" -D "${LDAPDN}" -w "${LDAPPWD}" "(&(objectCategory=computer)(CN=${ComputerName}))" -LLL memberOf | grep memberOf: | cut -d ',' -f 1 | awk '{print $2}' | sed 's/$/\]/' | sed 's/CN=/\[/' >> /tmp/ADComputerGroups

if [ ! -e /var/db/ADComputerGroups ] ; then
	echo "NULL" > /var/db/ADComputerGroups
fi

if ! diff -q /tmp/ADComputerGroups /var/db/ADComputerGroups ; then
	mv -f /tmp/ADComputerGroups /var/db/ADComputerGroups
	XPOSTSTRING="<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\"?><computer><general><name>${ComputerName}</name></general><extension_attributes><attribute><name>AD Security Groups</name><value>$(cat /var/db/ADComputerGroups)</value></attribute></extension_attributes></computer>"
	echo "${XPOSTSTRING}" | xmllint --format - > /tmp/ADComputerGroups.xml
	curl --silent -k -u "${JSSUSER}":"${JSSPWD}" https://"${JSSURL}":${JSSPORT}/JSSResource/computers/name/"${ComputerName}" -T "/tmp/ADComputerGroups.xml" -X PUT &>/dev/null
	if [ ${?} -eq 0 ] ; then
		echo "Updated AD group membership successfully submitted to the JSS."
	fi
	rm /tmp/ADComputerGroups.xml
else
	rm /tmp/ADComputerGroups
	echo "No AD group changes found, exiting."
fi
echo

exit 0
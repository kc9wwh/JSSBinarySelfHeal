#!/bin/sh

#####################################################################################################
#
# Copyright (c) 2015, JAMF Software, LLC.  All rights reserved.
#
#
#       THIS SOFTWARE IS PROVIDED BY JAMF SOFTWARE, LLC "AS IS" AND ANY
#       EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
#       WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
#       DISCLAIMED. IN NO EVENT SHALL JAMF SOFTWARE, LLC BE LIABLE FOR ANY
#       DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
#       (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
#       LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
#       ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
#       (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
#       SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
#####################################################################################################
#
#       This script is designed to perform a self heal on the client.  If the client does not have
#	the JAMF Binary, a quickadd package is downloaded and installed.  If the client cannot
#	check in with the JSS, run a policy, or cannot log it's IP address, the client
#	will be enrolled via invitation.  If the MDM profile is not found on the device, the client
#       will get re-enrolled into MDM.  There is a log file that is created to work with the Self Heal
#	process.  The log is located in /Users/Shared/ and is called enrollLog.log.  Five archives are
#	created of this log and stored in /Users/Shared/log_archive.  Once five logs rollover and are 
#	archived, the oldest four logs are deleted and the most recent archive is kept.
#
#	This process will work on a 9.8+ JSS.  It will not work on any JSS version pre 9.8.
#
#####################################################################################################
#
#       version 2.0 by Lucas Vance
#	Added log rotation, log archiving and log clean up LCV 11-23-15
#	Modified variables for more consitent Self Heal checks LCV 11-23-15
#       Added jamf binary size check LCV 10-28-16
#		- Special thanks to novaksam
#
#####################################################################################################

####################### Variables ################################
jssUrl="" # ex. https://jamit.q.jamfsw.corp:8443 - Please include the port if used
enrollInv="" # Invitation ID from a quickadd package
logFile="/Users/Shared/enrollLog.log"
check=`/usr/local/bin/jamf checkJSSConnection | rev | cut -c 2- | rev | grep "The JSS is available"`
quickLocation="/tmp/quickadd.zip"
log=`/usr/local/bin/jamf log | rev | cut -c 5- | rev`
policy=`/usr/local/bin/jamf policy -event heal | grep "Script result: heal" | cut -d " " -f3`
mdmEnrollmentProfileID="00000000-0000-0000-A000-4A414D460003"
enrolled=`/usr/bin/profiles -P | /usr/bin/grep "$mdmEnrollmentProfileID"`

addDate(){
	while IFS= read -r line; do
		echo "$(date) $line"
	done
}

######################## Do Not Modify Below This Line ####################################

# Create enrollLog if it doesn't exisit
if [[ ! -f $logFile ]];
	then echo "Creating enrollLog.log ....." | addDate >> $logFile;
	touch $logFile | addDate >> $logFile;
	sleep 5;
else echo "enrollLog.log already exists ..." | addDate >> $logFile;
fi

# Log rotation on /Users/Shared/enrollLog.log - Removes logs that are over 14 days old
log_directory="/Users/Shared"
archive_directory="/Users/Shared/log_archive"
max_size="10000000"
file="enrollLog.log"
filesize=`find "$log_directory"/"$file" -type f -print0 | xargs -0 stat -f%z | awk '{b+=$1} END {print b}'`

if [ -d "$archive_directory" ]; then
	echo "$archive_directory already exists" | addDate >> $logFile;
else
	echo "Creating "$archive_directory" ......" | addDate >> $logFile;
	mkdir "$archive_directory";
fi

cd "$log_directory"

if [ $filesize -ge $max_size ]; then
	i=0
	while [ "1" ]
	do
		if [ -f "$archive_directory/$file.$i.gz" -o -f "$archive_directory/$file.$i" ]; then
			((i++))
		else
			break
		fi
	done

	mv -f "$file" "$archive_directory/$file.$i"
	gzip -f "$archive_directory/$file.$i"
fi

sleep 5

# Check to see if binary exists if not install it, if not, install the binary and eroll the client
# Check if the binary exists and get the size in 1K blocks (should be over 5K)
if [[ ! -f /usr/local/jamf/bin/jamf ]]; then
		echo "Downloading the quickadd package from the JSS ...." | addDate >> $logFile;
		echo "Downloading the quickadd package from the JSS ...." | addDate >> $logFile;
		curl -sk $jssUrl/quickadd.zip > $quickLocation | addDate >> $logFile;
		echo "Download is complete ... Unpacking the quickadd package installer to /tmp/" | addDate >> $logFile;
		unzip /tmp/quickadd.zip -d /tmp/ | addDate >> $logFile;
		echo "Unzip is complete, now installing the JSS Binary" | addDate >> $logFile;
		/usr/sbin/installer -dumplog -verbose -pkg /tmp/QuickAdd.pkg -target / | addDate >> $logFile;
		echo "Installation is complete, the client should now be enrolled into the JSS" | addDate >> $logFile;
		echo "Cleaning up quickadd package ....." | addDate >> $logFile;
		rm -f /tmp/quickadd.zip | addDate >> $logFile;
		rm -rf /tmp/QuickAdd.pkg | addDate >> $logFile;
		rm -rf /tmp/_* | addDate >> $logFile;
fi
# Checks the size of the jamf binary, and if it abnormally small, reinstall the binary and enroll the client
# Checks if the file is at least 1M in size
if [ $jamf_size -le 1000 ]; then
	 	jamf_size=$(du -ks /usr/local/jamf/bin/jamf | awk '{ print $1 }')
		echo "Jamf binary is $jamf_size bytes ...." | addDate >> $logFile;
		echo "Jamf binary is abnormally small. Reinstalling ...." | addDate >> $logFile;
        	echo "Downloading the quickadd package from the JSS ...." | addDate >> $logFile;
		curl -sk $jssUrl/quickadd.zip > $quickLocation | addDate >> $logFile;
		echo "Download is complete ... Unpacking the quickadd package installer to /tmp/" | addDate >> $logFile;
		unzip /tmp/quickadd.zip -d /tmp/ | addDate >> $logFile;
		echo "Unzip is complete, now installing the JSS Binary" | addDate >> $logFile;
		/usr/sbin/installer -dumplog -verbose -pkg /tmp/QuickAdd.pkg -target / | addDate >> $logFile;
		echo "Installation is complete, the client should now be enrolled into the JSS" | addDate >> $logFile;
		echo "Cleaning up quickadd package ....." | addDate >> $logFile;
		rm -f /tmp/quickadd.zip | addDate >> $logFile;
		rm -rf /tmp/QuickAdd.pkg | addDate >> $logFile;
		rm -rf /tmp/_* | addDate >> $logFile;
	else 
		echo "JAMF binary is installed .... nothing to do" | addDate >> $logFile;
fi

# Check to see if the client to check in with the JSS, if not, enroll the client
if [[ ${check} == "The JSS is available" ]]; then
		echo "Client can successfully check in with the JSS" | addDate >> $logFile;
	else 
		jamf createConf -k -url $jssUrl | addDate >> $logFile;
		/usr/local/bin/jamf enroll -invitation $enrollInv | addDate >> $logFile;
fi

# Can the client log it's IP address with the JSS, if not, enroll the client
if [[ ${log} == "Logging to $jssUrl" ]]; then
		echo "Client can log IP address with JSS" | addDate >> $logFile
	else 
		jamf createConf -k -url $jssUrl | addDate >> $logFile;
		/usr/local/bin/jamf enroll -invitation $enrollInv | addDate >> $logFile;
fi

# Can the client execute a policy, if not, enroll the client
if [[ ${policy} == "heal" ]]; then
		echo "Client can execute policies at this time" | addDate >> $logFile;
	else 
		jamf createConf -k -url $jssUrl | addDate >> $logFile;
		/usr/local/bin/jamf enroll -invitation $enrollInv | addDate >> $logFile;
fi

# Does the client have it's MDM profile, if not, issue it to the client
if [[ "$enrolled" != "" ]]; then
		echo "Client is enrolled with MDM" | addDate >> $logFile;
	else 
		echo "This client is not enrolled with MDM, enrolling now ....." | addDate >> $logFile;
		/usr/local/bin/jamf mdm | addDate >> $logFile;
fi

# Clean up archived logs when 10 rollovers occur
number=`ls /Users/Shared/log_archive/* | wc -l`

if [ ${number} -ge 5 ]; then
	echo "Deleting archived logs as we are now at 5" | addDate >> $logFile;
	ls -tq /Users/Shared/log_archive/* | tail -n+3 | xargs rm | addDate >> $logFile;
else
	echo "There are currently "${number}" archived logs on this client.  When we reach 5, the latest archive log will be kept as the rest will be deleted." | addDate >> $logFile;
fi

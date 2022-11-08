#!/bin/bash
# 
# This script check total uptime of Confluence service and based on condition, then
# check total time to connect and load Confluence page "https://cnfl.csin.cz/index.action" with cURL.
# If total time is under 15 sec nothing will execute and script ends.
# (else) if time is 15 sec or more, script will check connectivity two more times and possibly restart, 
# confluence service based on defined conditions.
#


# defines website to check
WEBSITE="https://cnfl.csin.cz"
# export and check uptime of confluence service
UPTIME=$(ps axf | grep confluence | grep -o -P '(?<=Sl).*(?=/srv/sasbin/prod/confluence/confluence/jdk/bin/java)' | head -n 1 | sed s/'\s'//g)
INT_UPTIME=${UPTIME%%:*}
echo "Confluence uptime: " $INT_UPTIME "min"
# if service running 30+ min check will happen else exit script
if [ $INT_UPTIME -lt 30 ]
then
	echo "Exiting script, uptime under 30 min"
	exit 1
else
	echo "Checking total connectivity with curl"
fi

# defined array for store curl connectivity checks
TOTAL_ARRAY=()
# check total time to connect with curl, save to TOTAL variable
TOTAL=$(curl --max-time 15 -o /dev/null -s -w "%{time_total}s\n" $WEBSITE)
INT_TOTAL=${TOTAL%%.*}
# if total time to connect is 15+ sec, for loop will execute and check connectivity with curl two more times, else script end
if [ $INT_TOTAL -ge 15 ]
then

	echo "Result: " $INT_TOTAL "sec or more"
	TOTAL_ARRAY+=("$INT_TOTAL")
	# check connectivity two more times with 30 sec delays, save results to TOTAL_ARRAY
	for ((i = 0 ; i < 2 ; i++)); do

		echo "Waiting 30 sec and try again"
		sleep 30
		echo "Now checking again"

		TOTAL=$(curl --max-time 15 -o /dev/null -s -w "%{time_total}s\n" $WEBSITE)
		INT_TOTAL=${TOTAL%%.*}
		echo "Result: " $INT_TOTAL "sec"
		TOTAL_ARRAY+=("${TOTAL%%.*}")
	done

	echo "Total time to load page is: " ${TOTAL_ARRAY[@]} "sec"

	# sum all 3 checks from array
	COUNT_OF_THREE=$((${TOTAL_ARRAY[0]} + ${TOTAL_ARRAY[1]} + ${TOTAL_ARRAY[2]}))

	echo "Count of three: " $COUNT_OF_THREE "sec"
	echo "3rd try: " ${TOTAL_ARRAY[2]} "sec"

	# if count of three curl checks is bigger then 20 and third check isnt bigger then 1 restart of service will happen
	# else it wont restart and end script
	if [ $COUNT_OF_THREE -ge 20 ] && [ ${TOTAL_ARRAY[2]} -gt 1 ]
	then
		echo "Restarting service"
	else
		echo "Not restarting"
	fi


else
	echo "Total time to load page is:" $INT_TOTAL "sec"
	echo "Not restarting"
fi


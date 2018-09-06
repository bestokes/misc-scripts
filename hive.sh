#!/bin/bash

graphiteHost="localhost"
graphitePort="2003"

function GetHiveSession() {
        echo "INFO Creating new session token"
        curl -s -H 'Content-Type: application/vnd.alertme.zoo-6.1+json' \
                -H 'Accept: application/vnd.alertme.zoo-6.1+json' \
                -H 'X-Omnia-Client: Hive Web Dashboard' \
                -d @/Users/bestokes/hive/credentials.json \
                -X POST https://api.prod.bgchprod.info:443/omnia/auth/sessions | json_pp > sessid.out
        if [ "$?" != "0" ]; then
                echo "FATAL Could not fetch session token"
                exit 1
        else
                hiveSession=$(grep sessionId sessid.out | awk -F'"' '{ print $4 }')
                echo $hiveSession > ./hiveSession
        fi
}

function GetNodeData() {
        echo "INFO Fetching nodes data"
        export hiveSession=$(cat ./hiveSession)
        export gotNodeData=False
        curl -s -H 'Content-Type: application/vnd.alertme.zoo-6.1+json' \
                -H 'Accept: application/vnd.alertme.zoo-6.1+json' \
                -H 'X-Omnia-Client: Hive Web Dashboard' \
                -H "X-Omnia-Access-Token: ${hiveSession}" \
                -X GET \
                https://api-prod.bgchprod.info/omnia/nodes/ | json_pp > nodes.out
        if [ "$?" != "0" ]; then
                echo "ERROR Could not fetch nodes (curl failed)"
        elif [ "$(grep -c NOT_AUTHORIZED nodes.out)" = '1' ]; then
                echo "ERROR Received http 403 from Hive API"
        else
                export gotNodeData=True
        fi
}

function GetOutsideTemperature() {
        openweathermapKey=$(cat ./openweathermapKey)
        outsideTemperature=$(curl -s "https://api.openweathermap.org/data/2.5/weather?lat=50.9243&lon=-0.1454&units=metric&appid=${openweathermapKey}" | grep -o -E'"temp":([0-9]+\.[0-9]+)' | awk -F: '{ print $2 }')
        if [ "$?" != "0" ]; then
                echo "ERROR API call failed to openweathermap.org"
        fi
        # I'm parsing this with grep because jq doesn't
        # like the start and end of the json
}

echo "INFO Script starting up"

if [ -f ~/hive/credentials.json ]; then
        echo "INFO Found credentials.json"
        if [ ! -f ~/hive/sessid.out ]; then
                echo "INFO No session token found"
                GetHiveSession
        else
                # start a new session if it is 110 minutes old
                # because api session tokens expire after 2 hours
                if [ -z "$(find "sessid.out" -mmin -110)" ]; then
                rm ./hiveSession ./sessid.out
                GetHiveSession
                fi
        fi
else
        echo "FATAL Could not find credentials.json"
        exit 1
fi


GetNodeData
if [ "${gotNodeData}" = "True" ]; then
        batteryLevel=$(cat nodes.out | jq '.nodes[2].attributes.batteryLevel.reportedValue')
        actualTemperature=$(cat nodes.out | jq '.nodes[4].attributes.temperature.reportedValue')
        targetTemperature=$(cat nodes.out | jq '.nodes[4].attributes.targetHeatTemperature.reportedValue')
else
        batteryLevel=Null
        actualTemperature=Null
        targetTemperature=Null
fi

GetOutsideTemperature # should really only need this hourly, or every 30 minutes

# if things aren't working, uncomment the echos to look at the values.
# echo "INFO Battery level: ${batteryLevel}%"
echo "thermie.batterylevel ${batteryLevel} $(date +%s)" | nc ${graphiteHost} ${graphitePort}
# echo "INFO Inside Temperature: ${actualTemperature}"
echo "thermie.insideTemperature ${actualTemperature} $(date +%s)" | nc ${graphiteHost} ${graphitePort}
# echo "INFO Target Temperature: ${targetTemperature}"
echo "thermie.targetTemperature ${targetTemperature} $(date +%s)" | nc localhost 2003
# echo "INFO Outside Temperature: ${outsideTemperature}"
echo "weather.outsideTemperature ${outsideTemperature} $(date +%s)" | nc localhost 2003

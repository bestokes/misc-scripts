#!/bin/bash

export graphiteHost="127.0.0.1"
export graphitePort="2003"
export scriptDir=/root/hive

function GetHiveSession() {
        echo "INFO $(date +%d-%m-%Y,%H:%M) Creating new Hive API session token"
        curl -s -H 'Content-Type: application/vnd.alertme.zoo-6.1+json' \
                -H 'Accept: application/vnd.alertme.zoo-6.1+json' \
                -H 'X-Omnia-Client: Hive Web Dashboard' \
                -d @${scriptDir}/credentials.json \
                -X POST https://api.prod.bgchprod.info:443/omnia/auth/sessions | json_pp > ${scriptDir}/sessid.out
        if [ "$?" != "0" ]; then
                echo "FATAL $(date +%d-%m-%Y,%H:%M) Curl failed fetching session token"
                exit 1
        else
                hiveSession=$(grep sessionId sessid.out | awk -F'"' '{ print $4 }')
                echo $hiveSession > ${scriptDir}/hiveSession
        fi
}

function GetNodeData() {
        echo "INFO $(date +%d-%m-%Y,%H:%M) Fetching nodes data"
        export hiveSession=$(cat ${scriptDir}/hiveSession)
        export gotNodeData=False
        curl -s -H 'Content-Type: application/vnd.alertme.zoo-6.1+json' \
                -H 'Accept: application/vnd.alertme.zoo-6.1+json' \
                -H 'X-Omnia-Client: Hive Web Dashboard' \
                -H "X-Omnia-Access-Token: ${hiveSession}" \
                -X GET \
                https://api-prod.bgchprod.info/omnia/nodes/ | json_pp > ${scriptDir}/nodes.out
        if [ "$?" != "0" ]; then
                echo "ERROR $(date +%d-%m-%Y,%H:%M) Could not fetch nodes (curl failed)"
        elif [ "$(grep -c NOT_AUTHORIZED nodes.out)" = '1' ]; then
                echo "ERROR $(date +%d-%m-%Y,%H:%M) Received http 403 from Hive API"
        else
                export gotNodeData=True
        fi
}

function PostToGraphite() {
        if [ "${gotNodeData}" = "True" ]; then
                batteryLevel=$(cat ${scriptDir}/nodes.out | jq '.nodes[2].attributes.batteryLevel.reportedValue')
                actualTemperature=$(cat ${scriptDir}/nodes.out | jq '.nodes[4].attributes.temperature.reportedValue')
                targetTemperature=$(cat ${scriptDir}/nodes.out | jq '.nodes[4].attributes.targetHeatTemperature.reportedValue')
                boostOnOff=$(cat ${scriptDir}/nodes.out | jq '.nodes[4].attributes.activeHeatCoolMode.reportedValue' | awk -F'"' '{ print $2 }')
                if [ "${boostOnOff}" = "OFF" ]; then
                        boost=0
                elif [ "${boost}" = "BOOST" ]; then
                        boost=1
                fi
        else
                batteryLevel=Null
                actualTemperature=Null
                targetTemperature=Null
                boost=Null
        fi
        echo "INFO $(date +%d-%m-%Y,%H:%M) Sending data to graphite"
        for metric in batterylevel insideTemperature targetTemperature boost; do
                echo "thermie.$metric $(date +%s)" | nc -w 2 ${graphiteHost} ${graphitePort}
                if [ "$?" != "0" ]; then
                        echo "ERROR $(date +%d-%m-%Y,%H:%M) Could not add metric thermie.$metric to graphite"
                fi
        done
}

function Login() {
        if [ -f ${scriptDir}/credentials.json ]; then
                if [ ! -f ${scriptDir}/sessid.out ]; then
                        echo "INFO $(date +%d-%m-%Y,%H:%M) No session token found"
                        GetHiveSession
                else
                        # start a new session if it is 110 minutes old
                        # because api session tokens expire after 2 hours
                        if [ -z "$(find "sessid.out" -mmin -110)" ]; then
                                echo "INFO $(date +%d-%m-%Y,%H:%M) Old session timed out, getting new token"
                                rm -r ${scriptDir}/hiveSession ${scriptDir}/sessid.out
                                GetHiveSession
                        fi
                fi
        else
                echo "FATAL $(date +%d-%m-%Y,%H:%M) Could not find credentials.json"
                exit 1
        fi
}

echo "INFO $(date +%d-%m-%Y,%H:%M) Script starting up"

Login
GetNodeData
PostToGraphite

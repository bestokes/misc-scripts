#!/bin/bash

export graphiteHost="127.0.0.1"
export graphitePort="2003"
export scriptDir=/root/hive


function GetOutsideTemperature() {
        export gotWeatherData=False
        openweathermapKey=$(cat ${scriptDir}/openweathermapKey)
        outsideTemperature=$(curl -s "https://api.openweathermap.org/data/2.5/weather?lat=50.9243&lon=-0.1454&units=metric&appid=${openweathermapKey}" | grep -o -E '"temp":([0-9]+\.[0-9]+)' | awk -F: '{ print $2 }')
        if [ "$?" != "0" ]; then
                echo "ERROR API call failed to openweathermap.org"
        else
                export gotWeatherData=True
        fi
        # I'm parsing this with grep because jq doesn't
        # like the start and end of the json

        if [ "${gotWeatherData}" = "True" ]; then
                actualTemperature=$(cat ${scriptDir}/nodes.out | jq '.nodes[4].attributes.temperature.reportedValue')
        else
                actualTemperature=Null
        fi
}

function PostToGraphite() {
        echo "INFO Sending weather data to graphite"
        echo "weather.outsideTemperature ${outsideTemperature} $(date +%s)" | nc -w 2 ${graphiteHost} ${graphitePort}
}


GetOutsideTemperature # only do this hourly, should change to GetWeatherData and include wind speed?

PostToGraphite

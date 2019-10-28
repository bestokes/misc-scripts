#!/bin/bash

export graphiteHost="127.0.0.1"
export graphitePort="2003"
export scriptDir=/home/ben/weather


function GetOutsideTemperature() {
        if [ -f "${scriptDir}/json.out" ]; then rm -f ${scriptDir}/json.out; fi 
        export gotWeatherData=False
        openweathermapKey=$(cat ${scriptDir}/openweathermapKey)
        curl -s "https://api.openweathermap.org/data/2.5/weather?lat=50.9243&lon=-0.1454&units=metric&appid=${openweathermapKey}" | json_pp > ${scriptDir}/json.out 
        outsideTemperature=$(cat ${scriptDir}/json.out | jq '.main.temp')
        windSpeed=$(cat ${scriptDir}/json.out | jq '.wind.speed')

        if [ "$?" != "0" ]; then
                echo "ERROR API call failed to openweathermap.org"
        else
                export gotWeatherData=True
        fi

}

function PostToGraphite() {
        echo "INFO Sending weather data to graphite"
        echo "weather.outsideTemperature ${outsideTemperature} $(date +%s)" | nc -w 2 ${graphiteHost} ${graphitePort}
        echo "weather.windSpeed ${windSpeed} $(date +%s)" | nc -w 2 ${graphiteHost} ${graphitePort}
}


GetOutsideTemperature # only do this hourly, should change to GetWeatherData and include wind speed?

PostToGraphite

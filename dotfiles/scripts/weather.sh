#!/usr/bin/env zsh

get_weather() {
    if [ -z "$AMAP_WEATHER_KEY" ] || ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        echo "未知"
        return
    fi
    city="${AMAP_CITY_ADCODE:-440300}"
    curl -fsS "https://restapi.amap.com/v3/weather/weatherInfo?key=${AMAP_WEATHER_KEY}&city=${city}&extensions=base&output=json" | jq -r '.lives[0].weather // "未知"'
}

get_temperature() {
    if [ -z "$AMAP_WEATHER_KEY" ] || ! command -v curl >/dev/null 2>&1 || ! command -v jq >/dev/null 2>&1; then
        echo "未知"
        return
    fi
    city="${AMAP_CITY_ADCODE:-440300}"
    temper=$(curl -fsS "https://restapi.amap.com/v3/weather/weatherInfo?key=${AMAP_WEATHER_KEY}&city=${city}&extensions=base&output=json" | jq -r '.lives[0].temperature // "未知"')
    echo "$temper C"
}

get_temper_tip() {
    echo "带上水，少开会。"
}

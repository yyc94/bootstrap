#!/usr/bin/env zsh

ITEM_FILE="$HOME/scripts/text/.item"
ITEM_FILE2="$HOME/scripts/text/.item2"
FOOD_FILE="$HOME/scripts/text/.food"
FORTUNE_FILE="$HOME/scripts/text/.fortune"
SUNDAY_FILE="$HOME/scripts/text/.sunday"
WEEK_DAY=$(date +%u)
LINE="================================================================================================================"

if [ -r "$HOME/scripts/weather.sh" ]; then
    source "$HOME/scripts/weather.sh"
fi

typeset -A RADIO_TABLE=(
    [1]="Mourning Radio"
    [2]="FM99.6 周九早现场"
    [3]="精神放生FM"
    [4]="希望诈骗电台"
    [5]="48小时假释"
    [6]="共犯者之声"
    [7]="刑场广播 周末特别版"
)

random_message_from_file() {
    local file="${1:-$HOME/scripts/text/.fortune}"
    if [ -f "$file" ]; then
        local count
        count=$(wc -l < "$file")
        [ "$count" -gt 0 ] && sed -n "$((RANDOM % count + 1))p" "$file"
    fi
}

print_hello_ascii() {
    cat <<'EOF'
================================================================================================================

 ARE YOU SOBER?

================================================================================================================
EOF
}

print_hello_ascii
if [ "$WEEK_DAY" -eq 7 ] && [ -f "$SUNDAY_FILE" ]; then
    WORD1=$(sed -n "1p" "$SUNDAY_FILE")
    WORD2=$(sed -n "2p" "$SUNDAY_FILE")
    FOOD=$(sed -n "3p" "$SUNDAY_FILE")
    FORTUNE=$(sed -n "4p" "$SUNDAY_FILE")
else
    WORD1=$(random_message_from_file "$ITEM_FILE")
    WORD2=$(random_message_from_file "$ITEM_FILE2")
    FOOD=$(random_message_from_file "$FOOD_FILE")
    FORTUNE=$(random_message_from_file "$FORTUNE_FILE")
fi

RADIO_NAME="${RADIO_TABLE[$WEEK_DAY]}"
echo ""
echo "\"${WORD1}! ${WORD2}! ${FOOD}!\" 欢迎收听《$RADIO_NAME》！"
echo ""
echo "新的一天！保持宿醉！今天天气, $(get_weather 2>/dev/null)！温度, $(get_temperature 2>/dev/null)！"
echo ""
echo "  $(get_temper_tip 2>/dev/null)"
echo ""
echo "无论何时何地，请务必记住："
echo ""
echo "   ${FORTUNE}"
echo ""
echo "$LINE"

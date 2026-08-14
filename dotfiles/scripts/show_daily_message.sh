DAILY_FILE="$HOME/.daily_check"
TODAY_DAY=$(date +%j)

show_daily_message() {
    if [ ! -f "$DAILY_FILE" ] || [ "$(cat "$DAILY_FILE")" != "$TODAY_DAY" ]; then
        echo "$TODAY_DAY" > "$DAILY_FILE"
        if [ -r "$HOME/scripts/daily_message.sh" ]; then
            source "$HOME/scripts/daily_message.sh"
        fi
    fi
}

show_daily_message

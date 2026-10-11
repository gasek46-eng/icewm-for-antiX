#!/usr/bin/env bash
# brightness-slider — окно с ползунком яркости экрана (antiX / IceWM).
# Двигайте ползунок — яркость меняется сразу. Закрыть: Esc или кнопка.
# Нужны пакеты: yad, brightnessctl (их ставит install-brightness-button.sh).

MIN=5   # ниже 5% экран почти гаснет — не даём уйти в полную темноту

# Не открывать второе окно, если первое уже открыто
LOCK="${XDG_RUNTIME_DIR:-/tmp}/brightness-slider.$USER.lock"
exec 9>"$LOCK"
if ! flock -n 9; then
    exit 0
fi

err() {
    if command -v yad >/dev/null 2>&1; then
        yad --error --title="Яркость" --text="$1" --button="OK:0" --center --width=360
    else
        echo "$1" >&2
    fi
    exit 1
}

command -v yad >/dev/null 2>&1 || err "Не установлен yad. Запустите install-brightness-button.sh"

ICON="$HOME/.local/share/icons/hicolor/48x48/apps/brightness-slider.png"
[ -f "$ICON" ] || ICON="display-brightness"

# --- Текущая яркость в процентах ---
get_percent() {
    if command -v brightnessctl >/dev/null 2>&1; then
        local cur max
        cur=$(brightnessctl get 2>/dev/null)
        max=$(brightnessctl max 2>/dev/null)
        [ -n "$cur" ] && [ -n "$max" ] && [ "$max" -gt 0 ] && { echo $(( cur * 100 / max )); return; }
    fi
    local d
    d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1)
    [ -n "$d" ] || return 1
    echo $(( $(cat "$d/brightness") * 100 / $(cat "$d/max_brightness") ))
}

# --- Установить яркость в процентах ---
set_percent() {
    local p="$1"
    [ "$p" -lt "$MIN" ] && p=$MIN
    [ "$p" -gt 100 ] && p=100
    if command -v brightnessctl >/dev/null 2>&1; then
        brightnessctl -q set "${p}%" 2>/dev/null && return 0
    fi
    local d max
    d=$(ls -d /sys/class/backlight/* 2>/dev/null | head -n1)
    [ -n "$d" ] && [ -w "$d/brightness" ] || return 1
    max=$(cat "$d/max_brightness")
    echo $(( max * p / 100 )) > "$d/brightness"
}

CUR=$(get_percent) || err "Не найдено управление подсветкой экрана (/sys/class/backlight пуст)."

# Проверка прав: пробуем выставить текущее значение
if ! set_percent "$CUR"; then
    err "Нет прав менять яркость.\n\nВыполните в терминале:\n<tt>sudo usermod -aG video $USER</tt>\nи войдите в систему заново."
fi

# --- Окно с ползунком ---
yad --scale \
    --title="Яркость" \
    --window-icon="$ICON" \
    --image="$ICON" \
    --text="<b>Яркость экрана</b>" \
    --min-value="$MIN" --max-value=100 --step=5 --value="$CUR" \
    --mark="50%":50 \
    --print-partial \
    --mouse --on-top --skip-taskbar --fixed --width=340 \
    --button="Готово:0" 2>/dev/null |
while read -r v; do
    v=${v%%.*}
    [[ "$v" =~ ^[0-9]+$ ]] && set_percent "$v"
done

exit 0

#!/usr/bin/env bash
# =====================================================================
#  install-brightness-button.sh — кнопка регулировки яркости для antiX.
#
#  Что появится:
#    • кнопка «Яркость» (значок солнца) на панели IceWM;
#    • такой же значок в доке Plank (если Plank установлен);
#    • пункт «Яркость» в меню приложений;
#    • клавиши Fn+F9 / Fn+F10 — темнее / ярче на 10%.
#  По нажатию на кнопку открывается окно с ползунком.
#
#  Запуск (из папки brightness, где лежат все файлы, БЕЗ sudo):
#      bash install-brightness-button.sh
#  Удаление:
#      bash install-brightness-button.sh --remove
# =====================================================================

set -u
HERE="$(cd "$(dirname "$0")" && pwd)"

ok()   { printf '  \033[32m[OK]\033[0m  %s\n' "$*"; }
info() { printf '  \033[36m[..]\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m[!!]\033[0m  %s\n' "$*"; }
die()  { printf '\n\033[31mОШИБКА:\033[0m %s\n' "$*"; exit 1; }
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

[ "$(id -u)" -eq 0 ] && die "Запускайте без sudo:  bash $0"

BIN="$HOME/.local/bin/brightness-slider"
DESKTOP="$HOME/.local/share/applications/brightness-slider.desktop"
PLANK_ITEM="$HOME/.config/plank/dock1/launchers/brightness-slider.dockitem"
TOOLBAR="$HOME/.icewm/toolbar"
KEYS="$HOME/.icewm/keys"
ICON="$HOME/.local/share/icons/hicolor/48x48/apps/brightness-slider.png"
MARK="# brightness-slider"

restart_icewm() {
    pgrep -x icewm >/dev/null 2>&1 && { icewm --restart >/dev/null 2>&1 & sleep 1; ok "IceWM перезапущен"; }
}

# ---------------------------------------------------------------------
if [ "${1:-}" = "--remove" ]; then
    step "Удаление кнопки яркости"
    rm -f "$BIN" "$DESKTOP" "$PLANK_ITEM" "$ICON"
    [ -f "$TOOLBAR" ] && sed -i "/^$MARK\$/,+1d" "$TOOLBAR"
    [ -f "$KEYS" ]    && sed -i "/^$MARK\$/,+2d" "$KEYS"
    ok "Удалено"
    restart_icewm
    exit 0
fi

[ -f "$HERE/brightness-slider.sh" ] || die "Рядом нет файла brightness-slider.sh (скачайте всю папку brightness)"

# ---------------------------------------------------------------------
step "1/5 Пакеты yad и brightnessctl"
NEED=""
command -v yad >/dev/null 2>&1           || NEED="$NEED yad"
command -v brightnessctl >/dev/null 2>&1 || NEED="$NEED brightnessctl"
if [ -n "$NEED" ]; then
    info "Устанавливаю:$NEED (нужен пароль)"
    sudo apt-get install -y $NEED >/dev/null || die "Не удалось установить:$NEED. Проверьте интернет."
fi
ok "yad и brightnessctl есть"

# ---------------------------------------------------------------------
step "2/5 Права на управление подсветкой"
ls /sys/class/backlight/* >/dev/null 2>&1 || warn "В /sys/class/backlight пусто — подсветка не найдена, кнопка может не работать"
RELOGIN=0
if id -nG "$USER" | tr ' ' '\n' | grep -qx video; then
    ok "Пользователь $USER уже в группе video"
else
    sudo usermod -aG video "$USER" && { ok "Добавил $USER в группу video"; RELOGIN=1; } \
        || warn "Не удалось добавить в группу video"
fi

# ---------------------------------------------------------------------
step "3/5 Программа и пункт меню"
mkdir -p "$(dirname "$BIN")" "$(dirname "$DESKTOP")"
install -m 755 "$HERE/brightness-slider.sh" "$BIN"
ok "Установлено: $BIN"
if [ -f "$HERE/brightness-slider.png" ]; then
    install -D -m 644 "$HERE/brightness-slider.png" "$ICON"
    ok "Значок солнца установлен"
else
    ICON="display-brightness"
    warn "Нет brightness-slider.png рядом со скриптом — беру значок из темы иконок"
fi

cat > "$DESKTOP" <<EOF
[Desktop Entry]
Type=Application
Name=Brightness
Name[ru]=Яркость
Comment=Screen brightness slider
Comment[ru]=Регулировка яркости экрана
Exec=$BIN
Icon=$ICON
Terminal=false
Categories=Settings;HardwareSettings;
StartupNotify=false
EOF
ok "Пункт меню «Яркость» создан"

# ---------------------------------------------------------------------
step "4/5 Кнопка на панели IceWM и клавиши"
mkdir -p "$HOME/.icewm"
if [ ! -f "$TOOLBAR" ]; then
    for src in /usr/share/icewm/toolbar /etc/icewm/toolbar; do
        [ -f "$src" ] && { cp "$src" "$TOOLBAR"; break; }
    done
    touch "$TOOLBAR"
fi
if grep -qx "$MARK" "$TOOLBAR"; then
    ok "Кнопка на панели уже есть"
else
    printf '%s\nprog "Яркость" %s %s\n' "$MARK" "$ICON" "$BIN" >> "$TOOLBAR"
    ok "Кнопка добавлена на панель IceWM"
fi

touch "$KEYS"
if grep -qx "$MARK" "$KEYS"; then
    ok "Клавиши уже настроены"
else
    cat >> "$KEYS" <<EOF
$MARK
key "XF86MonBrightnessUp"   brightnessctl -q set +10%
key "XF86MonBrightnessDown" brightnessctl -q set 10%-
EOF
    ok "Fn+F9 / Fn+F10 — темнее / ярче"
fi

# ---------------------------------------------------------------------
step "5/5 Значок в доке Plank"
if command -v plank >/dev/null 2>&1; then
    mkdir -p "$(dirname "$PLANK_ITEM")"
    printf '[PlankDockItemPreferences]\nLauncher=file://%s\n' "$DESKTOP" > "$PLANK_ITEM"
    ok "Значок добавлен в Plank (появится справа в доке)"
else
    info "Plank не установлен — пропускаю"
fi

restart_icewm

echo
echo "================================================================"
echo " ✅ Готово. Кнопка «Яркость» — значок солнца на верхней панели"
echo "    и в доке. Нажмите — появится ползунок."
echo "    Fn+F9 / Fn+F10 — темнее / ярче."
if [ "$RELOGIN" -eq 1 ]; then
    echo
    echo " ⚠  Выйдите из сеанса и войдите снова (или перезагрузитесь),"
    echo "    чтобы заработали права на изменение яркости."
fi
echo " Удалить:  bash $0 --remove"
echo "================================================================"

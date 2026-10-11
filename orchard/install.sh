#!/usr/bin/env bash
# =====================================================================
#  Orchard — оформление antiX (IceWM) в стиле macOS. Установщик.
#
#  bash install.sh                 установить (без sudo, пароль спросит сам)
#  bash install.sh --no-whitesur   без скачивания тем WhiteSur (GTK, иконки, курсоры)
#  bash install.sh --remove        удалить и вернуть всё как было
# =====================================================================
set -u
HERE="$(cd "$(dirname "$0")" && pwd)"
SHARE="$HOME/.local/share/orchard"
BIN="$HOME/.local/bin"
BK_ROOT="$HOME/.local/share/orchard-backup"
M1="# >>> orchard >>>"; M2="# <<< orchard <<<"

ok()   { printf '  \033[32m[OK]\033[0m  %s\n' "$*"; }
info() { printf '  \033[36m[..]\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m[!!]\033[0m  %s\n' "$*"; }
die()  { printf '\n\033[31mОШИБКА:\033[0m %s\n' "$*"; exit 1; }
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

[ "$(id -u)" -eq 0 ] && die "Запускайте без sudo:  bash $0"

# Файлы, которые тема меняет (для резервной копии и отката)
FILES=(
  .icewm/theme .icewm/prefoverride .icewm/keys .icewm/toolbar
  .desktop-session/startup .desktop-session/desktop-session.conf
  .desktop-session/wallpaper-list.conf .desktop-session/wallpaper.conf
  .config/gtk-3.0/settings.ini .gtkrc-2.0 .icons/default/index.theme .Xresources
  .config/fontconfig/fonts.conf .config/rofi/orchard.rasi .config/dunst/dunstrc
  .config/xsettingsd/xsettingsd.conf
)

strip_block() { [ -f "$1" ] && sed -i "/^$M1\$/,/^$M2\$/d" "$1"; }

# --------------------------------------------------------------------- удаление
if [ "${1:-}" = "--remove" ]; then
    step "Удаление Orchard"
    BK="$(ls -d "$BK_ROOT"/*/ 2>/dev/null | head -n1)"
    [ -n "$BK" ] || die "Резервная копия не найдена ($BK_ROOT)"
    pkill -x picom 2>/dev/null; pkill -x plank 2>/dev/null
    for f in "${FILES[@]}"; do
        if [ -f "$BK/home/$f" ]; then cp -a "$BK/home/$f" "$HOME/$f"
        elif grep -qx "$f" "$BK/created.txt" 2>/dev/null; then rm -f "$HOME/$f"; fi
    done
    [ -f "$BK/plank.dconf" ] && have dconf && dconf load /net/launchpad/plank/ < "$BK/plank.dconf" 2>/dev/null
    if [ -d "$BK/launchers" ]; then
        rm -rf "$HOME/.config/plank/dock1/launchers"; cp -a "$BK/launchers" "$HOME/.config/plank/dock1/launchers"
    fi
    rm -rf "$HOME/.icewm/themes/Orchard" "$HOME/.icewm/themes/Orchard-Dark" "$HOME/.local/share/plank/themes/Orchard" \
           "$HOME/.local/share/plank/themes/Orchard-Dark" "$HOME/.config/orchard" \
           "$BIN/orchard-ctl" "$BIN/orchard-settings" "$HOME/.local/share/applications/orchard-settings.desktop"
    rm -rf "$SHARE"
    (plank >/dev/null 2>&1 &)
    pgrep -x icewm >/dev/null && (icewm --restart >/dev/null 2>&1 &)
    ok "Orchard удалён, настройки возвращены из $BK"
    info "Темы WhiteSur остались (удалить: rm -rf ~/.themes/WhiteSur* ~/.local/share/icons/WhiteSur*)"
    echo "Перезайдите в сеанс, чтобы всё вернулось полностью."
    exit 0
fi

[ -d "$HERE/icewm/Orchard" ] || die "Запускайте install.sh из папки orchard (рядом должны быть icewm/, bin/ …)"
have icewm || die "IceWM не найден — тема рассчитана на antiX с IceWM"

# --------------------------------------------------------------------- 1
step "1/8 Пакеты (нужен пароль)"
PKGS="picom plank rofi dunst feh yad wmctrl xdotool scrot xsettingsd libnotify-bin x11-xserver-utils dconf-cli
      fonts-inter fonts-jetbrains-mono git sassc libglib2.0-dev-bin libxml2-utils"
sudo apt-get update -qq || warn "apt update с ошибкой — продолжаю"
for p in $PKGS; do
    dpkg -s "$p" >/dev/null 2>&1 && continue
    sudo apt-get install -y --no-install-recommends "$p" >/dev/null 2>&1 && ok "$p" || warn "$p — не установился, пропускаю"
done

# --------------------------------------------------------------------- 2
step "2/8 Резервная копия"
if ls -d "$BK_ROOT"/*/ >/dev/null 2>&1; then
    BK="$(ls -d "$BK_ROOT"/*/ | head -n1)"
    info "Копия уже есть ($BK) — сохраняю её, чтобы откат вернул исходное состояние"
else
    BK="$BK_ROOT/$(date +%Y-%m-%d_%H-%M-%S)/"; mkdir -p "$BK/home"; : > "$BK/created.txt"
    for f in "${FILES[@]}"; do
        if [ -f "$HOME/$f" ]; then mkdir -p "$BK/home/$(dirname "$f")"; cp -a "$HOME/$f" "$BK/home/$f"
        else echo "$f" >> "$BK/created.txt"; fi
    done
    have dconf && dconf dump /net/launchpad/plank/ > "$BK/plank.dconf" 2>/dev/null
    [ -d "$HOME/.config/plank/dock1/launchers" ] && cp -a "$HOME/.config/plank/dock1/launchers" "$BK/launchers"
    ok "Сохранено в $BK"
fi

# --------------------------------------------------------------------- 3
step "3/8 Файлы темы"
mkdir -p "$SHARE" "$BIN" "$HOME/.icewm/themes" "$HOME/.local/share/plank/themes"
rm -rf "$HOME/.icewm/themes/Orchard" "$HOME/.icewm/themes/Orchard-Dark"
cp -a "$HERE/icewm/Orchard" "$HERE/icewm/Orchard-Dark" "$HOME/.icewm/themes/"
cp -a "$HERE/plank/Orchard" "$HERE/plank/Orchard-Dark" "$HOME/.local/share/plank/themes/"
for d in wallpapers icons rofi dunst picom; do rm -rf "${SHARE:?}/$d"; cp -a "$HERE/$d" "$SHARE/"; done
cp -a "$HERE/install.sh" "$SHARE/install.sh"
mkdir -p "$SHARE/src"; cp -a "$HERE"/{icewm,plank,bin,fontconfig} "$SHARE/src/" 2>/dev/null
install -m 755 "$HERE/bin/orchard-ctl" "$BIN/orchard-ctl"
install -m 755 "$HERE/bin/orchard-settings" "$BIN/orchard-settings"
mkdir -p "$HOME/.local/share/applications"
cat > "$HOME/.local/share/applications/orchard-settings.desktop" <<E
[Desktop Entry]
Type=Application
Name=Orchard Settings
Name[ru]=Настройки Orchard
Comment[ru]=Оформление в стиле macOS: режим, обои, док, эффекты
Exec=$BIN/orchard-settings
Icon=$SHARE/icons/orchard-settings.png
Categories=Settings;DesktopSettings;
E
ok "Темы окна, дока, обои, значки, скрипты"

# --------------------------------------------------------------------- 4
step "4/8 Темы программ, иконки и курсоры WhiteSur"
if [ "${1:-}" = "--no-whitesur" ]; then
    info "Пропущено (--no-whitesur): будут стандартные темы GTK"
else
    TMP="$(mktemp -d)"
    for r in WhiteSur-gtk-theme WhiteSur-icon-theme WhiteSur-cursors; do
        if git clone -q --depth 1 "https://github.com/vinceliuice/$r" "$TMP/$r" 2>/dev/null; then
            case $r in
                WhiteSur-gtk-theme)  (cd "$TMP/$r" && ./install.sh -d "$HOME/.themes" -c light -c dark --silent-mode >/dev/null 2>&1 || ./install.sh -d "$HOME/.themes" >/dev/null 2>&1) ;;
                WhiteSur-icon-theme) (cd "$TMP/$r" && ./install.sh -d "$HOME/.local/share/icons" >/dev/null 2>&1) ;;
                WhiteSur-cursors)    mkdir -p "$HOME/.icons"; cp -a "$TMP/$r/dist" "$HOME/.icons/WhiteSur-cursors" 2>/dev/null || (cd "$TMP/$r" && ./install.sh >/dev/null 2>&1) ;;
            esac && ok "$r" || warn "$r — не установилась"
        else
            warn "$r — не скачалась (нет интернета?), будет стандартная тема"
        fi
    done
    rm -rf "$TMP"
fi

# --------------------------------------------------------------------- 5
step "5/8 Шрифты"
mkdir -p "$HOME/.config/fontconfig"
cp "$HERE/fontconfig/fonts.conf" "$HOME/.config/fontconfig/fonts.conf"
touch "$HOME/.Xresources"; strip_block "$HOME/.Xresources"
cat >> "$HOME/.Xresources" <<E
$M1
Xft.antialias: 1
Xft.hinting: 1
Xft.hintstyle: hintslight
Xft.rgba: rgb
Xft.lcdfilter: lcddefault
Xft.dpi: 96
Xcursor.theme: WhiteSur-cursors
Xcursor.size: 24
$M2
E
fc-cache -f >/dev/null 2>&1; xrdb -merge "$HOME/.Xresources" 2>/dev/null
ok "Inter для интерфейса, JetBrains Mono для терминала, чёткое сглаживание"

# --------------------------------------------------------------------- 6
step "6/8 Панель, окна и горячие клавиши IceWM"
mkdir -p "$HOME/.icewm"; touch "$HOME/.icewm/prefoverride" "$HOME/.icewm/keys"
strip_block "$HOME/.icewm/prefoverride"; strip_block "$HOME/.icewm/keys"
cat >> "$HOME/.icewm/prefoverride" <<E
$M1
# Верхняя панель как строка меню macOS: меню слева, трей и часы справа
TaskBarAtTop=1
TaskBarShowWindows=0
TaskBarShowWorkspaces=0
TaskBarShowWindowListMenu=0
TaskBarShowShowDesktopButton=0
TaskBarShowCPUStatus=0
TaskBarShowMEMStatus=0
TaskBarShowNetStatus=0
TaskBarShowMailboxStatus=0
TaskBarShowCollapseButton=0
ShowAddressBar=0
TaskBarShowAPMStatus=1
TaskBarShowAPMGraph=0
TaskBarShowAPMTime=0
TaskBarClockLeds=0
TimeFormat="%a %-d %b  %H:%M"
DateFormat="%A, %-d %B %Y"
# Окна
ClickToFocus=1
OpaqueMove=1
OpaqueResize=1
SmartPlacement=1
CenterTransientsOnOwner=1
TitleBarRollupButton=0
MenuMouseTracking=1
Win95Keys=1
# Alt+Tab — крупные значки в ряд, как в macOS
QuickSwitchHugeIcon=1
QuickSwitchVertical=0
QuickSwitchAllIcons=1
QuickSwitchTextFirst=0
$M2
E
C="$BIN/orchard-ctl"
cat >> "$HOME/.icewm/keys" <<E
$M1
key "Super+space"       $C spotlight
key "Super+comma"       $C settings
key "Super+Shift+d"     $C mode toggle
key "Super+q"           $C close
key "Super+m"           $C minimize
key "Super+e"           $C files
key "Super+t"           $C terminal
key "Super+l"           $C lock
key "Super+Shift+3"     $C screenshot full
key "Super+Shift+4"     $C screenshot area
key "Print"             $C screenshot full
$M2
E
# Строка меню без значков быстрого запуска — программы живут в доке
printf '# Orchard: значки быстрого запуска перенесены в док (Plank)\n' > "$HOME/.icewm/toolbar"
ok "Панель сверху, «светофор» слева, Super+Пробел — поиск, Super+, — настройки"

# --------------------------------------------------------------------- 7
step "7/8 Автозапуск, Conky и старый набор"
DS="$HOME/.desktop-session"; mkdir -p "$DS"; touch "$DS/startup"
strip_block "$DS/startup"
# отключаем чужие запуски picom/plank/conky (например, от antix-macos-look)
sed -i -E '/^[[:space:]]*#/!{/(^|[[:space:]\/])(picom|compton|plank|conky)([[:space:]&]|$)/s/^/# [orchard отключил] /}' "$DS/startup"
cat >> "$DS/startup" <<E
$M1
$C session &
$M2
E
if [ -f "$DS/desktop-session.conf" ]; then
    sed -i -E 's/^(LOAD_CONKY=).*/\1"false"/' "$DS/desktop-session.conf"
else
    [ -f /etc/desktop-session/desktop-session.conf ] && cp /etc/desktop-session/desktop-session.conf "$DS/" \
        && sed -i -E 's/^(LOAD_CONKY=).*/\1"false"/' "$DS/desktop-session.conf"
fi
pkill -x conky 2>/dev/null
ok "Orchard запускается при входе, Conky выключен"

# --------------------------------------------------------------------- 8
step "8/8 Док и применение темы"
L="$HOME/.config/plank/dock1/launchers"; rm -rf "$L"; mkdir -p "$L"
items=()
add_item() { # add_item ИМЯ путь/к/.desktop
    [ -f "$2" ] || return 1
    printf '[PlankDockItemPreferences]\nLauncher=file://%s\n' "$2" > "$L/$1.dockitem"; items+=("'$1.dockitem'")
}
A=/usr/share/applications
first() { local n=$1; shift; for d in "$@"; do add_item "$n" "$A/$d.desktop" && return; done; }
first files    zzzfm spacefm rox-filer pcmanfm thunar
first browser  firefox-esr firefox google-chrome chromium
first terminal roxterm org.gnome.Terminal xfce4-terminal lxterminal
first text     geany featherpad mousepad leafpad
add_item brightness "$HOME/.local/share/applications/brightness-slider.desktop"
add_item settings   "$HOME/.local/share/applications/orchard-settings.desktop"
if have gsettings; then
    list="[$(IFS=,; echo "${items[*]}")]"
    S="net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/"
    if [ -n "${DBUS_SESSION_BUS_ADDRESS:-}" ]; then gsettings set "$S" dock-items "$list" 2>/dev/null
    else dbus-launch gsettings set "$S" dock-items "$list" 2>/dev/null; fi
fi
ok "В доке: ${#items[@]} значков"

"$C" mode light >/dev/null 2>&1
pkill -x plank 2>/dev/null
("$C" session >/dev/null 2>&1 &)
ok "Тема применена"

echo
echo "================================================================"
echo " ✅ Orchard установлен."
echo
echo "  Super+Пробел   поиск программ (как Spotlight)"
echo "  Super+,        Настройки Orchard (режим, обои, док, эффекты)"
echo "  Super+Shift+D  светлый ↔ тёмный режим"
echo "  Super+Q / M    закрыть / свернуть окно"
echo "  Super+Shift+3 / 4   снимок экрана / области (в «Изображения»)"
echo "  Super+L        заблокировать экран"
echo
echo " Выйдите из сеанса и войдите снова — так всё применится полностью."
echo " Удалить и вернуть как было:  bash $SHARE/install.sh --remove"
echo "================================================================"

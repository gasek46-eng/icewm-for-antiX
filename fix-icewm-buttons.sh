#!/usr/bin/env bash
# =====================================================================
#  fix-icewm-buttons.sh — исправление «чёрной полосы» под кнопками окон
#  в теме IceWM в стиле macOS (antiX).
#
#  Причина проблемы: в IceWM каждая картинка кнопки заголовка (closeA.xpm,
#  maximizeA.xpm и т.д.) должна содержать ДВА состояния одно над другим —
#  обычное сверху и нажатое снизу, т.е. быть вдвое выше заголовка.
#  Если картинка одинарная, IceWM показывает только её верхнюю половину
#  (кружки обрезаны), а остаток заголовка остаётся чёрным.
#
#  Что делает скрипт:
#    1. Находит текущую тему IceWM (или берёт папку, указанную аргументом).
#    2. Делает резервную копию картинок кнопок.
#    3. Удваивает по высоте ТОЛЬКО одинарные картинки (повторный запуск
#       безопасен — уже исправленные файлы не трогаются).
#    4. Так же исправляет копию темы в наборе ~/Загрузки/antix-macos-look,
#       чтобы повторный install.sh не вернул проблему.
#    5. Перезапускает IceWM и picom (тени и скругления).
#
#  Запуск (от обычного пользователя, НЕ через sudo):
#      bash fix-icewm-buttons.sh
#      bash fix-icewm-buttons.sh /путь/к/папке/темы      # другая тема
#
#  Откат: картинки из резервной копии (путь будет показан в конце):
#      cp ~/knopki-backup/<дата>/*.xpm ~/.icewm/themes/<тема>/
#      icewm --restart &
# =====================================================================

set -u

ok()   { printf '  \033[32m[OK]\033[0m  %s\n' "$*"; }
info() { printf '  \033[36m[..]\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m[!!]\033[0m  %s\n' "$*"; }
die()  { printf '\n\033[31mОШИБКА:\033[0m %s\n' "$*"; exit 1; }
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

if [ "$(id -u)" -eq 0 ]; then
    die "Запускайте без sudo:  bash $0"
fi

# Шаблоны имён картинок кнопок заголовка IceWM
BUTTONS='close|maximize|minimize|restore|rollup|rolldown|hide|depth|menuButton'

# ---------------------------------------------------------------------
step "1/5 Проверка ImageMagick"
IM=""
if command -v magick >/dev/null 2>&1; then
    IM="magick"
elif command -v convert >/dev/null 2>&1; then
    IM="convert"
else
    info "ImageMagick не установлен — устанавливаю (нужен пароль)"
    sudo apt-get install -y imagemagick >/dev/null || die "Не удалось установить imagemagick. Проверьте интернет."
    command -v magick >/dev/null 2>&1 && IM="magick" || IM="convert"
fi
ok "Использую: $IM"

# Размеры картинки: "ширина высота"
img_size() {
    if [ "$IM" = "magick" ]; then
        magick identify -format '%w %h' "$1" 2>/dev/null
    else
        identify -format '%w %h' "$1" 2>/dev/null
    fi
}

# Высота заголовка из default.theme (по умолчанию — по большинству картинок)
title_height() {
    local f="$1/default.theme" v=""
    [ -f "$f" ] && v="$(grep -E '^[[:space:]]*TitleBarHeight[[:space:]]*=' "$f" | tail -n1 | sed -E 's/.*=[[:space:]]*"?([0-9]+).*/\1/')"
    echo "${v:-}"
}

# Исправить все картинки кнопок в одной папке.
# $1 — папка, $2 — подпись для вывода. Возвращает число исправленных файлов в FIXED.
FIXED=0
fix_dir() {
    local dir="$1" label="$2" tbh f name w h n=0 skipped=0
    tbh="$(title_height "$dir")"
    if [ -z "$tbh" ]; then
        warn "$label: TitleBarHeight не найден в default.theme — считаю одинарными картинки, у которых высота ≤ 32"
    else
        info "$label: высота заголовка TitleBarHeight=$tbh"
    fi

    shopt -s nullglob nocaseglob
    for f in "$dir"/*.xpm; do
        name="$(basename "$f")"
        echo "$name" | grep -qiE "^($BUTTONS)[AIO]?\.xpm$" || continue

        read -r w h <<<"$(img_size "$f")"
        if [ -z "${h:-}" ]; then
            warn "$name: не удалось прочитать размер — пропускаю"; continue
        fi

        local need=0
        if [ -n "$tbh" ]; then
            [ "$h" -eq "$tbh" ] && need=1
            [ "$h" -lt "$tbh" ] && need=1        # тоже одинарная, просто меньше заголовка
            [ "$h" -ge $((tbh * 2)) ] && need=0
        else
            [ "$h" -le 32 ] && need=1
        fi

        if [ "$need" -eq 1 ]; then
            if "$IM" "$f" "$f" -append "$f" 2>/dev/null; then
                read -r w h <<<"$(img_size "$f")"
                ok "$name → ${w}×${h} (удвоена)"
                n=$((n + 1))
            else
                warn "$name: ошибка при обработке"
            fi
        else
            skipped=$((skipped + 1))
        fi
    done
    shopt -u nullglob nocaseglob

    [ "$skipped" -gt 0 ] && info "$label: уже в порядке — $skipped файл(ов), не тронуты"
    [ "$n" -eq 0 ] && [ "$skipped" -eq 0 ] && warn "$label: картинок кнопок не найдено"
    FIXED=$((FIXED + n))
}

# ---------------------------------------------------------------------
step "2/5 Поиск темы IceWM"
THEME_DIR="${1:-}"
if [ -z "$THEME_DIR" ]; then
    THEME_NAME=""
    for cfg in "$HOME/.icewm/theme" "$HOME/.icewm/preferences"; do
        [ -f "$cfg" ] || continue
        THEME_NAME="$(grep -E '^[[:space:]]*Theme[[:space:]]*=' "$cfg" | tail -n1 | sed -E 's/.*=[[:space:]]*"?([^"/]+)\/.*/\1/')"
        [ -n "$THEME_NAME" ] && break
    done
    [ -n "$THEME_NAME" ] || die "Не удалось определить тему. Укажите папку темы:  bash $0 ~/.icewm/themes/ИМЯ"

    for base in "$HOME/.icewm/themes" "/usr/share/icewm/themes" "/usr/local/share/icewm/themes"; do
        if [ -d "$base/$THEME_NAME" ]; then THEME_DIR="$base/$THEME_NAME"; break; fi
    done
    [ -n "$THEME_DIR" ] || die "Папка темы «$THEME_NAME» не найдена."
fi
[ -d "$THEME_DIR" ] || die "Нет такой папки: $THEME_DIR"
[ -w "$THEME_DIR" ] || die "Нет прав на запись в $THEME_DIR (системная тема). Скопируйте её в ~/.icewm/themes/ и выберите заново."
ok "Тема: $THEME_DIR"

# ---------------------------------------------------------------------
step "3/5 Резервная копия"
BACKUP="$HOME/knopki-backup/$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$BACKUP"
cp -a "$THEME_DIR"/*.xpm "$BACKUP"/ 2>/dev/null && ok "Сохранено в $BACKUP" || warn "Картинок .xpm для копии не найдено"

# ---------------------------------------------------------------------
step "4/5 Исправление картинок кнопок"
fix_dir "$THEME_DIR" "Установленная тема"

# Копии темы в наборе antix-macos-look (чтобы install.sh не вернул проблему)
for kit in "$HOME/Загрузки/antix-macos-look" "$HOME/Downloads/antix-macos-look"; do
    [ -d "$kit" ] || continue
    while IFS= read -r d; do
        [ "$(cd "$d" && pwd)" = "$(cd "$THEME_DIR" && pwd)" ] && continue
        mkdir -p "$BACKUP/nabor"
        cp -a "$d"/*.xpm "$BACKUP/nabor"/ 2>/dev/null
        fix_dir "$d" "Набор ($d)"
    done < <(find "$kit" -type f -iname 'closeA.xpm' -printf '%h\n' 2>/dev/null | sort -u)
done

# ---------------------------------------------------------------------
step "5/5 Перезапуск IceWM и picom"
if pgrep -x icewm >/dev/null 2>&1; then
    icewm --restart >/dev/null 2>&1 &
    sleep 2
    ok "IceWM перезапущен"
else
    info "IceWM сейчас не запущен — изменения применятся при следующем входе"
fi

PICOM_CONF=""
for c in "$HOME/.config/picom/macos-look.conf" "$HOME/.config/picom/picom.conf" "$HOME/.config/picom.conf"; do
    [ -f "$c" ] && { PICOM_CONF="$c"; break; }
done
if command -v picom >/dev/null 2>&1 && [ -n "$PICOM_CONF" ]; then
    pkill -x picom 2>/dev/null; sleep 1
    if picom -b --config "$PICOM_CONF" >/dev/null 2>&1; then
        ok "picom запущен ($PICOM_CONF)"
    else
        warn "picom не запустился — тени и скругления выключены (на кнопки не влияет)"
    fi
fi

echo
echo "================================================================"
if [ "$FIXED" -gt 0 ]; then
    echo " ✅ Готово: исправлено картинок — $FIXED."
else
    echo " ✅ Исправлять нечего: все кнопки уже в порядке."
fi
echo " Резервная копия: $BACKUP"
echo " Откат:  cp \"$BACKUP\"/*.xpm \"$THEME_DIR\"/ && icewm --restart &"
echo "================================================================"

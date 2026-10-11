#!/usr/bin/env bash
# =====================================================================
#  install-zoom.sh — установка Zoom на antiX (64-бит).
#  Скачивает официальный пакет с zoom.us и ставит его через apt,
#  который сам доставит нужные зависимости.
#
#  Запуск (без sudo, пароль спросит сам):   bash install-zoom.sh
#  Удаление:                                 bash install-zoom.sh --remove
# =====================================================================
set -u

ok()   { printf '  \033[32m[OK]\033[0m  %s\n' "$*"; }
info() { printf '  \033[36m[..]\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m[!!]\033[0m  %s\n' "$*"; }
die()  { printf '\n\033[31mОШИБКА:\033[0m %s\n' "$*"; exit 1; }
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

[ "$(id -u)" -eq 0 ] && die "Запускайте без sudo:  bash $0"

if [ "${1:-}" = "--remove" ]; then
    step "Удаление Zoom"
    sudo apt-get remove -y zoom && ok "Zoom удалён" || die "Не удалось удалить (возможно, Zoom не установлен)"
    exit 0
fi

URL="https://zoom.us/client/latest/zoom_amd64.deb"

step "1/4 Проверка системы"
[ "$(uname -m)" = "x86_64" ] || die "Zoom для Linux есть только для 64-битных систем (x86_64). У вас: $(uname -m)"
ok "64-битная система"
FREE_MB=$(df -Pm /usr | awk 'NR==2{print $4}')
[ "${FREE_MB:-0}" -lt 1500 ] && warn "Свободно меньше 1,5 ГБ на системном разделе — может не хватить места"
if dpkg -s zoom >/dev/null 2>&1; then
    info "Zoom уже установлен ($(dpkg-query -W -f='${Version}' zoom)) — обновлю до последней версии"
fi

step "2/4 Скачивание Zoom (~200 МБ)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
DEB="$TMP/zoom_amd64.deb"
if command -v wget >/dev/null 2>&1; then
    wget -q --show-progress -O "$DEB" "$URL" || die "Не удалось скачать $URL. Проверьте интернет."
else
    curl -fL --progress-bar -o "$DEB" "$URL" || die "Не удалось скачать $URL. Проверьте интернет."
fi
dpkg-deb -I "$DEB" >/dev/null 2>&1 || die "Скачанный файл повреждён — запустите скрипт ещё раз."
ok "Скачано: версия $(dpkg-deb -f "$DEB" Version)"

step "3/4 Установка (нужен пароль)"
sudo apt-get update -qq || warn "apt update завершился с ошибкой — пробую ставить дальше"
# Копия в /tmp, чтобы служебный пользователь apt мог прочитать файл
cp "$DEB" /tmp/zoom_amd64.deb && chmod 644 /tmp/zoom_amd64.deb
if sudo apt-get install -y /tmp/zoom_amd64.deb; then
    ok "Zoom установлен"
else
    warn "Установка прервалась — пробую починить зависимости"
    sudo apt-get -f install -y && ok "Зависимости исправлены, Zoom установлен" || die "Не удалось установить Zoom. Пришлите вывод ошибки."
fi
rm -f /tmp/zoom_amd64.deb

step "4/4 Проверка звука"
if pgrep -x pipewire >/dev/null 2>&1 || pgrep -x pulseaudio >/dev/null 2>&1; then
    ok "Звуковой сервер работает (PipeWire/PulseAudio) — микрофон и звук в Zoom должны работать"
else
    warn "Не найден PipeWire/PulseAudio. Zoom рассчитан на них — без них может не быть звука."
    warn "Включите PipeWire: Центр управления antiX → Звук, либо: sudo apt install pipewire-pulse wireplumber"
fi

echo
echo "================================================================"
echo " ✅ Готово. Запуск: Меню → Интернет → Zoom, или команда  zoom"
echo
echo " Совет для слабого ноутбука: если Zoom тормозит, подключайтесь"
echo " к встречам через браузер — https://app.zoom.us/wc (легче)."
echo " Удалить:  bash $0 --remove"
echo "================================================================"

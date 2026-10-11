#!/usr/bin/env bash
# =====================================================================
#  install-throne.sh — установка Throne (клиент прокси, бывший Nekoray)
#  на antiX (64-бит). Берёт последнюю версию с GitHub:
#  https://github.com/throneproj/Throne
#
#  Запуск (без sudo, пароль спросит сам):   bash install-throne.sh
#  Конкретная версия:                        bash install-throne.sh 1.3.2
#  Удаление:                                 bash install-throne.sh --remove
# =====================================================================
set -u

ok()   { printf '  \033[32m[OK]\033[0m  %s\n' "$*"; }
info() { printf '  \033[36m[..]\033[0m  %s\n' "$*"; }
warn() { printf '  \033[33m[!!]\033[0m  %s\n' "$*"; }
die()  { printf '\n\033[31mОШИБКА:\033[0m %s\n' "$*"; exit 1; }
step() { printf '\n\033[1;36m==> %s\033[0m\n' "$*"; }

[ "$(id -u)" -eq 0 ] && die "Запускайте без sudo:  bash $0"

REPO="https://github.com/throneproj/Throne"
FALLBACK_VER="1.3.2"   # если не удастся узнать последнюю версию

find_pkg() { dpkg-query -W -f='${Package}\n' 2>/dev/null | grep -ix 'throne' | head -n1; }

if [ "${1:-}" = "--remove" ]; then
    step "Удаление Throne"
    PKG="$(find_pkg)"
    [ -n "$PKG" ] || die "Throne не установлен через пакет"
    sudo apt-get remove -y "$PKG" && ok "Throne удалён (настройки остались в ~/.config/Throne)"
    exit 0
fi

fetch() {  # fetch URL FILE
    if command -v wget >/dev/null 2>&1; then
        wget -q --show-progress -O "$2" "$1"
    else
        curl -fL --progress-bar -o "$2" "$1"
    fi
}

step "1/4 Проверка системы"
[ "$(uname -m)" = "x86_64" ] || die "Скрипт рассчитан на 64-битную систему (x86_64). У вас: $(uname -m)"
ok "64-битная система"

step "2/4 Определение версии"
VER="${1:-}"
if [ -z "$VER" ]; then
    # GitHub перенаправляет /releases/latest на /releases/tag/<версия>
    VER="$(curl -fsSIL -o /dev/null -w '%{url_effective}' "$REPO/releases/latest" 2>/dev/null | sed -E 's|.*/tag/v?||')"
    if ! [[ "$VER" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
        VER="$(curl -fsS https://api.github.com/repos/throneproj/Throne/releases/latest 2>/dev/null \
               | grep -m1 '"tag_name"' | sed -E 's/.*"v?([^"]+)".*/\1/')"
    fi
    if ! [[ "$VER" =~ ^[0-9]+(\.[0-9]+)+$ ]]; then
        warn "Не удалось узнать последнюю версию — беру $FALLBACK_VER"
        VER="$FALLBACK_VER"
    fi
fi
ok "Версия Throne: $VER"
CUR="$(find_pkg)"
[ -n "$CUR" ] && info "Сейчас установлена $(dpkg-query -W -f='${Version}' "$CUR") — обновлю"

step "3/4 Скачивание"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
# Пакет со встроенным Qt: больше по размеру, зато не зависит от версий Qt в системе
NAME="Throne-${VER}-debian-amd64.deb"
URL="$REPO/releases/download/${VER}/${NAME}"
fetch "$URL" "$TMP/$NAME" || die "Не удалось скачать $URL
Проверьте интернет или скачайте файл вручную со страницы $REPO/releases"
dpkg-deb -I "$TMP/$NAME" >/dev/null 2>&1 || die "Скачанный файл повреждён — запустите скрипт ещё раз."
ok "Скачано: $NAME"

step "4/4 Установка (нужен пароль)"
cp "$TMP/$NAME" "/tmp/$NAME" && chmod 644 "/tmp/$NAME"
sudo apt-get update -qq || warn "apt update завершился с ошибкой — пробую ставить дальше"
if sudo apt-get install -y "/tmp/$NAME"; then
    ok "Throne установлен"
else
    warn "Установка прервалась — пробую починить зависимости"
    sudo apt-get -f install -y && ok "Зависимости исправлены, Throne установлен" || die "Не удалось установить Throne. Пришлите вывод ошибки."
fi
rm -f "/tmp/$NAME"

BIN="/opt/Throne/Throne"
[ -x "$BIN" ] || BIN="$(dpkg -L throne 2>/dev/null | grep -E '/Throne$' | head -n1)"
DESK="/usr/share/applications/Throne.desktop"   # создаётся при установке пакета
[ -f "$DESK" ] || DESK=""

echo
echo "================================================================"
echo " ✅ Готово."
[ -n "$DESK" ] && echo " Запуск: Меню → Интернет (или Сеть) → Throne"
[ -n "$BIN" ]  && echo " Или командой:  $BIN -appdata &"
echo
echo " Первый запуск: добавьте сервер (Сервер → Добавить / вставьте ссылку"
echo " из буфера), затем включите «Системный прокси»."
echo " Режим TUN (весь трафик через VPN) требует прав администратора;"
echo " если он не включается — пользуйтесь режимом «Системный прокси»."
echo " Удалить:  bash $0 --remove"
echo "================================================================"

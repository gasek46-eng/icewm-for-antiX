# Установка программ на antiX

**Русский** | [English](README.en.md)

Запускайте без `sudo`, пароль скрипты спросят сами.

## Zoom — `install-zoom.sh`

```bash
bash install-zoom.sh            # установить или обновить
bash install-zoom.sh --remove   # удалить
```

Скачивает официальный пакет с zoom.us (около 200 МБ) и ставит его через apt.
В конце проверяет, работает ли PipeWire/PulseAudio: без них в Zoom может не быть звука.
На слабом ноутбуке встречи легче открывать в браузере: https://app.zoom.us/wc

## Throne — `install-throne.sh`

Клиент прокси (бывший Nekoray): https://github.com/throneproj/Throne

```bash
bash install-throne.sh          # последняя версия
bash install-throne.sh 1.3.2    # конкретная версия
bash install-throne.sh --remove # удалить
```

Ставится в `/opt/Throne`, ярлык появляется в меню. При первом запуске добавьте сервер
и включите «Системный прокси». Режим TUN требует прав администратора; если он не
включается, пользуйтесь «Системным прокси».

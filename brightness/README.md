# Яркость экрана в antiX

**Русский** | [English](README.en.md)

![Окно регулировки яркости](preview.png)

## Кнопка с ползунком

Установка (из этой папки, без `sudo`):

```bash
bash install-brightness-button.sh
```

Появится значок солнца на верхней панели IceWM и в доке Plank, пункт «Яркость» в меню
и клавиши **Fn+F9 / Fn+F10**. После первой установки **выйдите из сеанса и войдите
снова**: скрипт добавляет вас в группу `video`, и право менять яркость появляется
только после повторного входа.

Удаление:

```bash
bash install-brightness-button.sh --remove
```

## Клавишами

На HP EliteBook 820 солнышко нарисовано на клавишах **F9** (темнее) и **F10** (ярче).
Нажимайте их вместе с **Fn**.

## Командой

```bash
sudo apt install brightnessctl
sudo usermod -aG video $USER    # затем выйти из сеанса и войти снова

brightnessctl              # показать текущую яркость
brightnessctl set 100%     # максимум
brightnessctl set +10%     # ярче на 10%
brightnessctl set 10%-     # темнее на 10%
```

## Если клавиши Fn+F9 / Fn+F10 не работают

1. Привяжите их в IceWM (установщик кнопки делает это сам):

   ```bash
   printf 'key "XF86MonBrightnessUp"   brightnessctl set +10%%\nkey "XF86MonBrightnessDown" brightnessctl set 10%%-\n' >> ~/.icewm/keys
   icewm --restart &
   ```

2. Если не помогло, откройте `sudo nano /etc/default/grub` и допишите в строку
   `GRUB_CMDLINE_LINUX_DEFAULT` слово `acpi_backlight=native` (не стирая того, что там
   уже есть). Затем выполните `sudo update-grub` и перезагрузитесь.

## Если яркость уже на максимуме

Когда `brightnessctl` показывает 100%, ярче подсветку не сделать: это предел самого
экрана. Можно только визуально осветлить картинку программно:

```bash
xrandr --output eDP-1 --gamma 1.1:1.1:1.1   # светлее (цвета немного выцветут)
xrandr --output eDP-1 --gamma 1:1:1         # вернуть как было
```

Если `eDP-1` не подходит, точное имя экрана покажет `xrandr | grep connected`.

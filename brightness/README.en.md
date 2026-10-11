# Screen brightness on antiX

[Русский](README.md) | **English**

![Brightness window](preview.png)

## Slider button

Install (from this folder, without `sudo`):

```bash
bash install-brightness-button.sh
```

You get a sun icon on the IceWM top panel and in the Plank dock, a "Brightness" menu
entry, and **Fn+F9 / Fn+F10** keys. After the first install, **log out and back in**:
the script adds you to the `video` group, and the permission to change brightness only
takes effect after you log in again.

Remove:

```bash
bash install-brightness-button.sh --remove
```

## With the keys

On the HP EliteBook 820 the sun icon is on **F9** (darker) and **F10** (brighter).
Press them together with **Fn**.

## From the terminal

```bash
sudo apt install brightnessctl
sudo usermod -aG video $USER    # then log out and back in

brightnessctl              # show current brightness
brightnessctl set 100%     # maximum
brightnessctl set +10%     # 10% brighter
brightnessctl set 10%-     # 10% darker
```

## If Fn+F9 / Fn+F10 don't work

1. Bind them in IceWM (the button installer does this for you):

   ```bash
   printf 'key "XF86MonBrightnessUp"   brightnessctl set +10%%\nkey "XF86MonBrightnessDown" brightnessctl set 10%%-\n' >> ~/.icewm/keys
   icewm --restart &
   ```

2. If that doesn't help, open `sudo nano /etc/default/grub` and add `acpi_backlight=native`
   to the `GRUB_CMDLINE_LINUX_DEFAULT` line (keep what's already there). Then run
   `sudo update-grub` and reboot.

## If brightness is already at maximum

When `brightnessctl` shows 100%, the backlight can't go any higher: that's the limit of
the panel itself. You can only make the picture look lighter in software:

```bash
xrandr --output eDP-1 --gamma 1.1:1.1:1.1   # lighter (colors fade a little)
xrandr --output eDP-1 --gamma 1:1:1         # back to normal
```

If `eDP-1` doesn't work, `xrandr | grep connected` shows the exact screen name.

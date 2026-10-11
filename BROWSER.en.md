# A browser for a low-end laptop on antiX

[Русский](BROWSER.md) | **English**

There is no truly lightweight browser that also handles modern websites well:
YouTube, webmail and social networks use a lot of memory on their own. The best option
is a regular browser with the right settings.

## How much memory you have

```bash
free -h
```

- **about 4 GB** — use Firefox ESR with the settings below;
- **8 GB or more** — any browser will do, Chrome included.

## Recommended: Firefox ESR

```bash
sudo apt install firefox-esr
```

It usually uses less memory than Chrome and is easy to tune. Do three things:

1. **Install the uBlock Origin extension.** It blocks ads and trackers, which account
   for a noticeable share of memory use on many sites.
2. **Reduce the number of processes.** Type `about:config` in the address bar, find
   `dom.ipc.processCount` and set it to `2` (the default is 8). Each process uses memory,
   and two are enough on a low-end laptop.
3. **Keep fewer tabs open.** Firefox unloads old tabs on its own when memory runs low,
   but 5–10 open tabs is still better than 30.

## If you prefer Chrome

Turn on **Settings → Performance → Memory Saver**. Inactive tabs will then go to sleep.
Without it, Chrome is heavier than Firefox on a weak machine.

## Truly lightweight browsers

**Falkon**, **NetSurf** and **Dillo** use almost no memory, but many modern sites
(YouTube, government services, online banking) work poorly or not at all.
They are fine for reading simple pages and not much else.

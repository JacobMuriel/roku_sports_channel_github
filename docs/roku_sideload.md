# Roku Sideload Steps (Developer Mode)

## A) Enable Developer Mode on Roku

1. On Roku home screen, press:
   - `Home` 3x, `Up` 2x, `Right`, `Left`, `Right`, `Left`, `Right`
2. Enable developer mode and set a web installer password.
3. Roku reboots.

## B) Find Roku IP

1. Roku: `Settings > Network > About`
2. Note `IP address`.

## C) Zip the Channel

From project root:

```bash
cd /Users/jacobmuriel/Desktop/roku_sports_channel/roku
zip -r ../games.zip .
```

## D) Upload Channel

1. On laptop browser, open: `http://ROKU_IP`
2. Login with user `rokudev` and your dev password.
3. Upload `games.zip`.
4. Install.

## E) Verify

- Channel should appear as **Games**.
- Launch it and confirm rows load from your backend.
- If not, verify `roku/source/config.brs` uses your backend LAN IP and port.

# iOS Shortcut: Control Center Button to Launch Games Channel

This launches your Roku channel directly via Roku ECP. It does not switch TV inputs.

## Prerequisites

1. Roku and iPhone are on the same Wi-Fi/LAN.
2. Roku mobile control is enabled:
   - Roku: `Settings > System > Advanced system settings > Control by mobile apps`
   - Set to `Permissive` (or allow your device based on your security preference).
3. Know Roku IP:
   - Roku: `Settings > Network > About`
4. Know your sideloaded app ID:
   - In Roku dev installer page (`http://ROKU_IP`), app list shows the current dev app id.
   - Use that `<APP_ID>` value in launch URL.

## Build the Shortcut

1. Open **Shortcuts** app on iPhone.
2. Tap `+` to create a new shortcut.
3. Add action: **Get Contents of URL**.
4. Set:
   - URL: `http://ROKU_IP:8060/launch/<APP_ID>`
   - Method: `POST`
   - Request Body: none
5. Optional: add **Show Notification** action with text like `Launching Games on Roku`.
6. Name the shortcut (example: `Launch Games Roku`).

## Add to Control Center

1. iPhone: `Settings > Control Center`.
2. Add **Shortcuts** control.
3. Configure it to use `Launch Games Roku`.
4. Open Control Center and tap the shortcut control.

## Troubleshooting

- If it fails, test URL in Safari first:
  - `http://ROKU_IP:8060/query/apps`
- Confirm Roku IP has not changed (DHCP can change it).
- Recheck `Control by mobile apps` setting.

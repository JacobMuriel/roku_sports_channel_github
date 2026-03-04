# Games: Roku + ESPN Dashboard

This project includes:
- `backend/`: FastAPI service that fetches ESPN JSON and serves `GET /dashboard?tz=America/Chicago`
- `roku/`: Roku SceneGraph channel named **Games**
- `docs/`: setup and iOS Shortcut instructions

## Project Structure
- `/backend`
- `/roku`
- `/docs`

## 1) Run Backend Locally

```bash
cd /Users/jacobmuriel/Desktop/roku_sports_channel/backend
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
uvicorn main:app --host 0.0.0.0 --port 8787
```

Test:

```bash
curl "http://127.0.0.1:8787/dashboard?tz=America/Chicago"
```

## 2) Configure Roku App Backend URL

Edit:
- `roku/source/config.brs`

Set:
- `GetBackendBaseUrl()` to your backend LAN URL, for example `http://192.168.1.45:8787`

## 3) Sideload Roku App

Follow:
- `/Users/jacobmuriel/Desktop/roku_sports_channel/docs/roku_sideload.md`

## 4) Create iOS Control Center Shortcut

Follow:
- `/Users/jacobmuriel/Desktop/roku_sports_channel/docs/ios_shortcut.md`

## Notes
- This app only launches the Roku channel and stays within Roku; it does not change TV inputs.
- iPhone and Roku must be on the same LAN as the target endpoint(s).
- ESPN endpoints are unofficial and may change; backend includes URL fallbacks and ranking fallback behavior.

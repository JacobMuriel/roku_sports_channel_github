# Backend API

## Endpoint

`GET /dashboard?tz=America/Chicago`

## Response Schema

```json
{
  "generated_at": "ISO8601",
  "items": [
    {
      "sport": "NBA",
      "league": "nba",
      "event_id": "401705123",
      "start_time": "2026-02-27T19:00:00-06:00",
      "status": "pre",
      "display": {
        "title": "Rockets @ Lakers",
        "subtitle": "7:00 PM",
        "score": "",
        "network": "ESPN"
      },
      "priority": 0,
      "watch": {
        "type": "text_only",
        "hint": "Open ESPN app on Roku"
      }
    }
  ]
}
```

## Selection and Sorting

- NBA team priority map:
  - Rockets=0, Thunder=1, Spurs=2, Nuggets=3, Timberwolves=4, Lakers=5, Pistons=6, Cavaliers=7, 76ers=8, Hornets=9
- Include only NBA games involving the above teams.
- NCAAM section:
  - Prefer AP Top 25 from ESPN rankings endpoint.
  - If rankings endpoint fails/unavailable, fallback to rank fields in scoreboard JSON.
  - If still empty, include all NCAAM games.
- Final output order:
  - NBA preferred games first, then NCAAM eligible games.
  - Within each group:
    - `live` before `pre` before `final`
    - `live`: smaller score differential first
    - `pre`: earlier start time first
    - tie-break by title
- Total items capped at 30.

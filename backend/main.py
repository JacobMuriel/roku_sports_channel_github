from __future__ import annotations

from datetime import datetime, timezone
import os
import traceback
from typing import Any, Dict, List, Optional, Set
from zoneinfo import ZoneInfo

import requests
from fastapi import FastAPI, Query
from fastapi.responses import JSONResponse

app = FastAPI(title="Games Dashboard API", version="1.0.0")

NBA_TEAM_PRIORITY: Dict[str, int] = {
    "houston rockets": 0,
    "oklahoma city thunder": 1,
    "san antonio spurs": 2,
    "denver nuggets": 3,
    "minnesota timberwolves": 4,
    "los angeles lakers": 5,
    "detroit pistons": 6,
    "cleveland cavaliers": 7,
    "philadelphia 76ers": 8,
    "charlotte hornets": 9,
}

REQUEST_TIMEOUT = 8
MAX_ITEMS = 300
ALLOWED_INJURY_STATUSES = {"out", "doubtful", "game-time decision", "gtd"}

STAR_PLAYERS: Dict[str, List[str]] = {
    "SAS": ["Victor Wembanyama", "De'Aaron Fox", "Stephon Castle", "Dylan Harper Jr."],
    "OKC": ["Shai Gilgeous-Alexander", "Chet Holmgren", "Jalen Williams"],
    "DEN": ["Nikola Jokic", "Jamal Murray"],
    "MIN": ["Anthony Edwards", "Julius Randle", "Jaden McDaniels"],
    "LAL": ["Luka Doncic", "LeBron James", "Anthony Davis", "Austin Reaves"],
    "DET": ["Cade Cunningham", "Jalen Duren"],
    "CLE": ["Donovan Mitchell", "Evan Mobley", "Darius Garland"],
    "PHI": ["Tyrese Maxey", "Joel Embiid"],
    "CHA": ["LaMelo Ball", "Brandon Miller"],
    "HOU": ["Kevin Durant", "Alperen Sengun", "Amen Thompson", "Jabari Smith Jr.", "Reed Sheppard"],
    "NYK": ["Jalen Brunson", "Karl-Anthony Towns", "Mikal Bridges"],
    "BOS": ["Jayson Tatum", "Jaylen Brown"],
    "MIL": ["Giannis Antetokounmpo", "Damian Lillard"],
    "PHX": ["Devin Booker", "Bradley Beal"],
    "GSW": ["Stephen Curry", "Draymond Green"],
    "DAL": ["Kyrie Irving", "Anthony Davis"],
    "MIA": ["Tyler Herro", "Bam Adebayo"],
    "MEM": ["Ja Morant", "Jaren Jackson Jr."],
    "ORL": ["Paolo Banchero", "Franz Wagner"],
    "ATL": ["Trae Young", "Jalen Johnson"],
    "SAC": ["Domantas Sabonis", "DeMar DeRozan", "Zach LaVine"],
    "LAC": ["Kawhi Leonard", "James Harden"],
    "IND": ["Pascal Siakam", "Tyrese Haliburton"],
    "NOP": ["Zion Williamson", "Trey Murphy III"],
    "TOR": ["Scottie Barnes", "RJ Barrett", "Immanuel Quickley"],
    "UTA": ["Lauri Markkanen", "Keyonte George"],
    "CHI": ["Josh Giddey", "Coby White"],
    "POR": ["Anfernee Simons", "Jerami Grant"],
    "WAS": ["Jordan Poole", "Kyle Kuzma"],
    "BKN": [],
}

TEAM_ALIAS_FIXUPS: Dict[str, str] = {
    "NY": "NYK",
    "GS": "GSW",
    "NO": "NOP",
    "SA": "SAS",
    "UTH": "UTA",
}


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def parse_iso(value: str) -> Optional[datetime]:
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def normalize_team_name(name: str) -> str:
    return " ".join((name or "").strip().lower().split())


def canonical_team_alias(alias: str) -> str:
    a = (alias or "").strip().upper()
    if not a:
        return ""
    return TEAM_ALIAS_FIXUPS.get(a, a)


def normalize_person_name(name: str) -> str:
    cleaned = (name or "").strip().lower().replace(".", "").replace("-", " ")
    return " ".join(cleaned.split())


def normalize_networks(competition: Dict[str, Any]) -> List[str]:
    broadcasts = competition.get("broadcasts") or []
    names: List[str] = []
    for broadcast in broadcasts:
        if isinstance(broadcast, dict):
            bnames = broadcast.get("names") or []
            for n in bnames:
                if isinstance(n, str) and n.strip():
                    names.append(n.strip())
    unique = []
    for n in names:
        if n not in unique:
            unique.append(n)
    return unique


def status_bucket(event: Dict[str, Any]) -> str:
    status = ((event.get("status") or {}).get("type") or {})
    state = (status.get("state") or "").lower()
    completed = bool(status.get("completed"))
    if state == "in":
        return "live"
    if state == "post" or completed:
        return "final"
    return "pre"


def status_rank(status: str) -> int:
    return {"live": 0, "pre": 1, "final": 2}.get(status, 3)


def parse_score(comp: Dict[str, Any]) -> int:
    score_str = str(comp.get("score") or "")
    try:
        return int(score_str)
    except ValueError:
        return 0


def subtitle_for_event(status: str, event: Dict[str, Any], start_local: datetime) -> str:
    status_type = ((event.get("status") or {}).get("type") or {})
    if status == "live":
        return str(status_type.get("shortDetail") or status_type.get("detail") or "Live")
    if status == "final":
        return "Final"
    return start_local.strftime("%I:%M %p").lstrip("0")


def status_text(status: str) -> str:
    if status == "live":
        return "Live"
    if status == "final":
        return "Final"
    return "Scheduled"


def map_game_state(status: str) -> str:
    if status == "live":
        return "in"
    if status == "final":
        return "final"
    return "pre"


def watch_hint_for_network(network: str) -> str:
    if network and network != "N/A":
        return f"Open {network} app on Roku"
    return "Open your preferred sports app on Roku"


def extract_logo(team: Dict[str, Any]) -> str:
    logos = team.get("logos") or []
    if isinstance(logos, list) and logos:
        first = logos[0]
        if isinstance(first, dict):
            href = first.get("href")
            if isinstance(href, str):
                return href
    logo = team.get("logo")
    if isinstance(logo, str):
        return logo
    return ""


def extract_record(competitor: Dict[str, Any]) -> str:
    records = competitor.get("records") or []
    if not isinstance(records, list):
        return ""
    for rec in records:
        if not isinstance(rec, dict):
            continue
        rec_type = str(rec.get("type") or rec.get("name") or "").lower()
        summary = rec.get("summary")
        if isinstance(summary, str) and summary.strip():
            if rec_type in ("overall", "total", "all"):
                return summary.strip()
    for rec in records:
        if isinstance(rec, dict):
            summary = rec.get("summary")
            if isinstance(summary, str) and summary.strip():
                return summary.strip()
    return ""


def parse_period_clock(event: Dict[str, Any]) -> Dict[str, Any]:
    status_type = ((event.get("status") or {}).get("type") or {})
    short_detail = str(status_type.get("shortDetail") or status_type.get("detail") or "")
    period_number = status_type.get("period")
    if not isinstance(period_number, int):
        period_number = None

    clock = status_type.get("displayClock") or status_type.get("clock") or ""
    if not isinstance(clock, str):
        clock = str(clock)

    detail_lower = short_detail.lower()
    is_halftime = ("half" in detail_lower) or short_detail.strip().upper() in ("HT", "HALF")

    return {
        "period_number": period_number,
        "clock_string": clock.strip(),
        "is_halftime": is_halftime,
    }


def try_fetch_json(urls: List[str]) -> Optional[Dict[str, Any]]:
    headers = {
        "User-Agent": "Mozilla/5.0 (GamesDashboard/1.0)",
        "Accept": "application/json",
    }
    for url in urls:
        try:
            response = requests.get(url, timeout=REQUEST_TIMEOUT, headers=headers)
            if response.status_code == 200:
                data = response.json()
                if isinstance(data, dict):
                    return data
        except Exception:
            continue
    return None


def team_injury_urls(team_id: str) -> List[str]:
    sport_path = "basketball/nba"
    return [
        f"https://site.api.espn.com/apis/site/v2/sports/{sport_path}/teams/{team_id}/injuries",
        f"https://site.web.api.espn.com/apis/v2/sports/{sport_path}/teams/{team_id}/injuries",
        f"https://site.api.espn.com/apis/v2/sports/{sport_path}/teams/{team_id}/injuries",
    ]


def event_summary_urls(event_id: str) -> List[str]:
    sport_path = "basketball/nba"
    return [
        f"https://site.api.espn.com/apis/site/v2/sports/{sport_path}/summary?event={event_id}",
        f"https://site.web.api.espn.com/apis/v2/sports/{sport_path}/summary?event={event_id}",
        f"https://site.api.espn.com/apis/v2/sports/{sport_path}/summary?event={event_id}",
    ]


def league_injuries_urls() -> List[str]:
    sport_path = "basketball/nba"
    return [
        f"https://site.api.espn.com/apis/site/v2/sports/{sport_path}/injuries",
        f"https://site.web.api.espn.com/apis/v2/sports/{sport_path}/injuries",
        f"https://site.api.espn.com/apis/v2/sports/{sport_path}/injuries",
    ]


def scoreboard_urls(league: str, yyyymmdd: str) -> List[str]:
    if league == "nba":
        sport_path = "basketball/nba"
    else:
        sport_path = "basketball/mens-college-basketball"

    return [
        f"https://site.api.espn.com/apis/site/v2/sports/{sport_path}/scoreboard?dates={yyyymmdd}",
        f"https://site.web.api.espn.com/apis/v2/sports/{sport_path}/scoreboard?dates={yyyymmdd}",
        f"https://site.api.espn.com/apis/v2/sports/{sport_path}/scoreboard?dates={yyyymmdd}",
    ]


def rankings_urls() -> List[str]:
    sport_path = "basketball/mens-college-basketball"
    return [
        f"https://site.api.espn.com/apis/site/v2/sports/{sport_path}/rankings",
        f"https://site.web.api.espn.com/apis/v2/sports/{sport_path}/rankings",
        f"https://site.api.espn.com/apis/v2/sports/{sport_path}/rankings",
    ]


def extract_team_rank(comp: Dict[str, Any]) -> Optional[int]:
    rank_fields = [
        comp.get("curatedRank"),
        comp.get("rank"),
        comp.get("currentRank"),
    ]
    for field in rank_fields:
        if isinstance(field, int):
            return field
        if isinstance(field, dict):
            for key in ("current", "displayValue", "rank"):
                val = field.get(key)
                if isinstance(val, int):
                    return val
                if isinstance(val, str) and val.isdigit():
                    return int(val)
        if isinstance(field, str) and field.isdigit():
            return int(field)
    return None


def parse_injury_entries(injury_data: Optional[Dict[str, Any]]) -> List[Dict[str, str]]:
    if not injury_data:
        return []

    entries = injury_data.get("injuries") or injury_data.get("entries") or []
    if not isinstance(entries, list):
        entries = []

    # Some ESPN payloads nest injury entries in other keys; recursively gather candidates.
    candidates: List[Dict[str, Any]] = []
    stack: List[Any] = [injury_data]
    visited = 0
    while stack and visited < 50000:
        node = stack.pop()
        visited += 1
        if isinstance(node, dict):
            has_name = any(k in node for k in ("athlete", "name", "playerName", "displayName"))
            has_status = any(k in node for k in ("status", "type", "designation"))
            if has_name and has_status:
                candidates.append(node)
            for v in node.values():
                stack.append(v)
        elif isinstance(node, list):
            for v in node:
                stack.append(v)
    entries.extend(candidates)

    parsed: List[Dict[str, str]] = []
    for entry in entries:
        if not isinstance(entry, dict):
            continue

        athlete = entry.get("athlete") or {}
        if not isinstance(athlete, dict):
            athlete = {}
        status_obj = entry.get("status") or entry.get("type") or {}
        if not isinstance(status_obj, dict):
            status_obj = {}
        name = (
            athlete.get("displayName")
            or athlete.get("shortName")
            or entry.get("name")
            or entry.get("playerName")
            or ""
        )
        status = (
            status_obj.get("name")
            or status_obj.get("displayName")
            or status_obj.get("abbreviation")
            or entry.get("status")
            or ""
        )
        reason = (
            entry.get("details")
            or entry.get("description")
            or entry.get("shortComment")
            or entry.get("comment")
            or ""
        )

        if not isinstance(name, str) or not name.strip():
            continue
        if not isinstance(status, str):
            status = str(status)
        if not isinstance(reason, str):
            reason = str(reason)

        parsed.append(
            {
                "name": name.strip(),
                "status": status.strip(),
                "reason": reason.strip(),
            }
        )

    # Deduplicate
    seen = set()
    deduped: List[Dict[str, str]] = []
    for row in parsed:
        key = (
            normalize_person_name(row.get("name", "")),
            row.get("status", "").strip().lower(),
            row.get("reason", "").strip().lower(),
        )
        if key in seen:
            continue
        seen.add(key)
        deduped.append(row)
    return deduped


def parse_injury_entries_by_team(injury_data: Optional[Dict[str, Any]]) -> Dict[str, List[Dict[str, str]]]:
    by_team: Dict[str, List[Dict[str, str]]] = {}
    if not injury_data:
        return by_team

    stack: List[Any] = [injury_data]
    visited = 0
    while stack and visited < 50000:
        node = stack.pop()
        visited += 1
        if isinstance(node, dict):
            athlete = node.get("athlete") or {}
            if not isinstance(athlete, dict):
                athlete = {}
            status_obj = node.get("status") or node.get("type") or {}
            if not isinstance(status_obj, dict):
                status_obj = {}

            name = (
                athlete.get("displayName")
                or athlete.get("shortName")
                or node.get("name")
                or node.get("playerName")
                or ""
            )
            status = (
                status_obj.get("name")
                or status_obj.get("displayName")
                or status_obj.get("abbreviation")
                or node.get("status")
                or ""
            )
            reason = (
                node.get("details")
                or node.get("description")
                or node.get("shortComment")
                or node.get("comment")
                or ""
            )

            team_obj = athlete.get("team") or node.get("team") or {}
            if not isinstance(team_obj, dict):
                team_obj = {}
            team_alias = (
                team_obj.get("abbreviation")
                or team_obj.get("shortDisplayName")
                or team_obj.get("displayName")
                or ""
            )
            team_alias = canonical_team_alias(str(team_alias))

            if team_alias and isinstance(name, str) and name.strip() and isinstance(status, str) and status.strip():
                by_team.setdefault(team_alias, []).append(
                    {
                        "name": name.strip(),
                        "status": status.strip(),
                        "reason": str(reason).strip(),
                    }
                )

            for v in node.values():
                stack.append(v)
        elif isinstance(node, list):
            for v in node:
                stack.append(v)

    # Deduplicate per team
    for alias, entries in by_team.items():
        seen = set()
        clean: List[Dict[str, str]] = []
        for row in entries:
            key = (
                normalize_person_name(row.get("name", "")),
                row.get("status", "").strip().lower(),
                row.get("reason", "").strip().lower(),
            )
            if key in seen:
                continue
            seen.add(key)
            clean.append(row)
        by_team[alias] = clean

    return by_team


def is_allowed_injury_status(status: str) -> bool:
    s = (status or "").strip().lower()
    if not s:
        return False
    if s in ALLOWED_INJURY_STATUSES:
        return True
    if s in {"o", "d"}:
        return True
    if s.startswith("out"):
        return True
    if s.startswith("doubtful"):
        return True
    if "game-time decision" in s or "game time decision" in s or "gtd" in s:
        return True
    return False


def merge_injury_payload(primary: Optional[Dict[str, Any]], fallback_list: Optional[List[Any]]) -> Dict[str, Any]:
    merged: Dict[str, Any] = {}
    injuries: List[Any] = []

    if isinstance(primary, dict):
        base = primary.get("injuries") or primary.get("entries") or []
        if isinstance(base, list):
            injuries.extend(base)

    if isinstance(fallback_list, list):
        injuries.extend(fallback_list)

    merged["injuries"] = injuries
    return merged


def get_star_injuries(team_alias: str, injury_data: Optional[Dict[str, Any]]) -> List[Dict[str, str]]:
    team_alias = canonical_team_alias(team_alias)
    if not team_alias:
        return []

    stars = STAR_PLAYERS.get(team_alias.upper())
    if not stars:
        return []

    star_name_map = {normalize_person_name(star): star for star in stars}
    if not star_name_map:
        return []

    injuries = parse_injury_entries(injury_data)
    result: List[Dict[str, str]] = []
    for injury in injuries:
        normalized_name = normalize_person_name(injury.get("name", ""))
        matched_star = ""
        if normalized_name in star_name_map:
            matched_star = star_name_map[normalized_name]
        else:
            for norm_star, display_star in star_name_map.items():
                if normalized_name.startswith(norm_star + " ") or norm_star.startswith(normalized_name + " "):
                    matched_star = display_star
                    break
                if normalized_name.find(norm_star) >= 0 or norm_star.find(normalized_name) >= 0:
                    matched_star = display_star
                    break

        if matched_star == "":
            continue

        status = injury.get("status", "")
        if not is_allowed_injury_status(status):
            continue

        result.append(
            {
                "name": matched_star,
                "status": status.strip() or "Out",
                "reason": (injury.get("reason", "").strip() or "Undisclosed"),
            }
        )
    return result


def extract_ap_top25_names(rankings_data: Optional[Dict[str, Any]]) -> Set[str]:
    if not rankings_data:
        return set()

    result: Set[str] = set()

    ranking_groups = rankings_data.get("rankings")
    if not isinstance(ranking_groups, list):
        ranking_groups = []

    for group in ranking_groups:
        if not isinstance(group, dict):
            continue
        name_blob = " ".join(
            str(group.get(k) or "") for k in ("name", "displayName", "shortName", "abbreviation")
        ).lower()
        if "ap" not in name_blob:
            continue

        ranks = group.get("ranks") or group.get("entries") or []
        if not isinstance(ranks, list):
            continue

        for item in ranks:
            if not isinstance(item, dict):
                continue
            rank_value = item.get("current") or item.get("rank") or item.get("value")
            if isinstance(rank_value, str) and rank_value.isdigit():
                rank_value = int(rank_value)
            if not isinstance(rank_value, int) or rank_value < 1 or rank_value > 25:
                continue

            team = item.get("team") or {}
            for key in ("displayName", "shortDisplayName", "name", "abbreviation"):
                team_name = team.get(key)
                if isinstance(team_name, str) and team_name.strip():
                    result.add(normalize_team_name(team_name))

    return result


def extract_ap_rank_map(rankings_data: Optional[Dict[str, Any]]) -> Dict[str, int]:
    if not rankings_data:
        return {}

    rank_map: Dict[str, int] = {}
    ranking_groups = rankings_data.get("rankings")
    if not isinstance(ranking_groups, list):
        return {}

    for group in ranking_groups:
        if not isinstance(group, dict):
            continue
        name_blob = " ".join(
            str(group.get(k) or "") for k in ("name", "displayName", "shortName", "abbreviation")
        ).lower()
        if "ap" not in name_blob:
            continue

        ranks = group.get("ranks") or group.get("entries") or []
        if not isinstance(ranks, list):
            continue

        for item in ranks:
            if not isinstance(item, dict):
                continue
            rank_value = item.get("current") or item.get("rank") or item.get("value")
            if isinstance(rank_value, str) and rank_value.isdigit():
                rank_value = int(rank_value)
            if not isinstance(rank_value, int) or rank_value < 1 or rank_value > 25:
                continue

            team = item.get("team") or {}
            for key in ("displayName", "shortDisplayName", "name", "abbreviation"):
                team_name = team.get(key)
                if isinstance(team_name, str) and team_name.strip():
                    rank_map[normalize_team_name(team_name)] = rank_value

    return rank_map


def team_name_variants(team: Dict[str, Any]) -> Set[str]:
    variants: Set[str] = set()
    for key in ("displayName", "shortDisplayName", "name", "abbreviation"):
        val = team.get(key)
        if isinstance(val, str) and val.strip():
            variants.add(normalize_team_name(val))
    return variants


def normalize_event(
    event: Dict[str, Any],
    sport: str,
    league: str,
    tz: ZoneInfo,
) -> Optional[Dict[str, Any]]:
    competitions = event.get("competitions") or []
    if not competitions:
        return None
    competition = competitions[0]
    competitors = competition.get("competitors") or []
    if len(competitors) < 2:
        return None

    home = next((c for c in competitors if c.get("homeAway") == "home"), competitors[0])
    away = next((c for c in competitors if c.get("homeAway") == "away"), competitors[1])

    home_team = home.get("team") or {}
    away_team = away.get("team") or {}

    start_utc = parse_iso(str(event.get("date") or ""))
    if not start_utc:
        return None
    start_local = start_utc.astimezone(tz)

    state = status_bucket(event)
    state_mapped = map_game_state(state)
    period_clock_data = parse_period_clock(event)
    networks = normalize_networks(competition)
    network_label = " / ".join(networks) if networks else ("League Pass" if league == "nba" else "N/A")
    home_score = parse_score(home)
    away_score = parse_score(away)

    title = f"{away_team.get('shortDisplayName', away_team.get('displayName', 'Away'))} @ {home_team.get('shortDisplayName', home_team.get('displayName', 'Home'))}"
    score = "" if state == "pre" else f"{away_score}\u2013{home_score}"

    item = {
        "sport": sport,
        "league": league,
        "event_id": str(event.get("id") or ""),
        "start_time": start_local.isoformat(),
        "start_time_epoch": int(start_local.timestamp()),
        "status": {"live": "live", "pre": "pre", "final": "final"}.get(state, "pre"),
        "game_state": state_mapped,
        "status_text": status_text(state),
        "away_team": away_team.get("shortDisplayName", away_team.get("displayName", "Away")),
        "home_team": home_team.get("shortDisplayName", home_team.get("displayName", "Home")),
        "away_alias": (away_team.get("abbreviation") or "").upper(),
        "home_alias": (home_team.get("abbreviation") or "").upper(),
        "away_logo": extract_logo(away_team),
        "home_logo": extract_logo(home_team),
        "away_record": extract_record(away),
        "home_record": extract_record(home),
        "away_team_id": str(away_team.get("id") or ""),
        "home_team_id": str(home_team.get("id") or ""),
        "away_competitor_injuries": away.get("injuries") or [],
        "home_competitor_injuries": home.get("injuries") or [],
        "away_score": away_score,
        "home_score": home_score,
        "away_rank": extract_team_rank(away),
        "home_rank": extract_team_rank(home),
        "period_clock": str(
            ((event.get("status") or {}).get("type") or {}).get("shortDetail")
            or ((event.get("status") or {}).get("type") or {}).get("detail")
            or ""
        ),
        "period_number": period_clock_data["period_number"],
        "clock_string": period_clock_data["clock_string"],
        "is_halftime": period_clock_data["is_halftime"],
        "networks": networks,
        "is_my_team": False,
        "display": {
            "title": title,
            "subtitle": subtitle_for_event(state, event, start_local),
            "score": score,
            "network": network_label,
        },
        "priority": 9999,
        "watch": {
            "type": "text_only",
            "hint": watch_hint_for_network(network_label),
        },
        "_sort": {
            "status_rank": status_rank(state),
            "score_diff": abs(away_score - home_score),
            "start_ts": start_local.timestamp(),
            "title": title.lower(),
        },
        "_teams": {
            "home": team_name_variants(home_team),
            "away": team_name_variants(away_team),
        },
        "_team_ranks": {
            "home": extract_team_rank(home),
            "away": extract_team_rank(away),
        },
    }
    return item


def ranking_fallback_from_scoreboard(ncaam_items: List[Dict[str, Any]]) -> Set[str]:
    ranked: Set[str] = set()
    for item in ncaam_items:
        home_rank = item.get("_team_ranks", {}).get("home")
        away_rank = item.get("_team_ranks", {}).get("away")
        if isinstance(home_rank, int) and 1 <= home_rank <= 25:
            ranked.update(item.get("_teams", {}).get("home", set()))
        if isinstance(away_rank, int) and 1 <= away_rank <= 25:
            ranked.update(item.get("_teams", {}).get("away", set()))
    return ranked


def first_valid_rank(value: Any) -> Optional[int]:
    if isinstance(value, int) and 1 <= value <= 25:
        return value
    return None


def find_rank_from_variants(variants: Set[str], rank_map: Dict[str, int]) -> Optional[int]:
    for variant in variants:
        rank = rank_map.get(variant)
        if isinstance(rank, int) and 1 <= rank <= 25:
            return rank
    return None


def format_star_injury_strip(away_alias: str, home_alias: str, injury_data: Dict[str, List[Dict[str, str]]]) -> str:
    def format_team(alias: str) -> str:
        rows = injury_data.get(alias, []) if isinstance(injury_data, dict) else []
        if not rows:
            return ""
        parts: List[str] = []
        for row in rows:
            name = str(row.get("name") or "").strip()
            status = str(row.get("status") or "").strip()
            reason = str(row.get("reason") or "").strip()
            if not name or not status:
                continue
            if reason:
                parts.append(f"{name} ({status} - {reason})")
            else:
                parts.append(f"{name} ({status})")
        if not parts:
            return ""
        return f"{alias}: " + ", ".join(parts)

    away = format_team(away_alias)
    home = format_team(home_alias)
    blocks = [b for b in (away, home) if b]
    if not blocks:
        return ""
    return "Stars Out: " + " | ".join(blocks)


def status_short(status: str) -> str:
    s = (status or "").strip().lower()
    if s.startswith("out") or s == "o":
        return "OUT"
    if s.startswith("doubtful") or s == "d":
        return "D"
    if "game-time decision" in s or "game time decision" in s or "gtd" in s:
        return "GTD"
    if s.startswith("question"):
        return "Q"
    return (status or "").strip().upper()


def build_dashboard(tz_name: str) -> Dict[str, Any]:
    try:
        tz = ZoneInfo(tz_name)
    except Exception:
        tz = ZoneInfo("America/Chicago")

    today = now_utc().astimezone(tz).strftime("%Y%m%d")

    nba_data = try_fetch_json(scoreboard_urls("nba", today)) or {}
    ncaam_data = try_fetch_json(scoreboard_urls("ncaam", today)) or {}
    rankings_data = try_fetch_json(rankings_urls())
    league_injuries_data = try_fetch_json(league_injuries_urls()) or {}
    league_injuries_by_team = parse_injury_entries_by_team(league_injuries_data)
    ap_rank_map = extract_ap_rank_map(rankings_data)

    nba_events = nba_data.get("events") or []
    ncaam_events = ncaam_data.get("events") or []

    nba_items: List[Dict[str, Any]] = []
    team_injury_cache: Dict[str, Dict[str, Any]] = {}
    event_injury_cache: Dict[str, Dict[str, Any]] = {}
    for event in nba_events:
        item = normalize_event(event, "NBA", "nba", tz)
        if item:
            away_id = item.get("away_team_id", "")
            home_id = item.get("home_team_id", "")
            away_alias = canonical_team_alias(item.get("away_alias", ""))
            home_alias = canonical_team_alias(item.get("home_alias", ""))
            event_id = item.get("event_id", "")

            away_injuries = team_injury_cache.get(away_id, {}) if away_id else {}
            if away_id and away_id not in team_injury_cache:
                away_injuries = try_fetch_json(team_injury_urls(away_id)) or {}
                team_injury_cache[away_id] = away_injuries

            home_injuries = team_injury_cache.get(home_id, {}) if home_id else {}
            if home_id and home_id not in team_injury_cache:
                home_injuries = try_fetch_json(team_injury_urls(home_id)) or {}
                team_injury_cache[home_id] = home_injuries

            away_payload = merge_injury_payload(
                away_injuries,
                item.get("away_competitor_injuries") if isinstance(item.get("away_competitor_injuries"), list) else [],
            )
            home_payload = merge_injury_payload(
                home_injuries,
                item.get("home_competitor_injuries") if isinstance(item.get("home_competitor_injuries"), list) else [],
            )

            away_star = get_star_injuries(away_alias, away_payload)
            home_star = get_star_injuries(home_alias, home_payload)

            # Fallback: game summary injuries (often richer than team endpoint)
            if (not away_star or not home_star) and event_id:
                summary = event_injury_cache.get(event_id)
                if summary is None:
                    summary = try_fetch_json(event_summary_urls(event_id)) or {}
                    event_injury_cache[event_id] = summary
                by_team = parse_injury_entries_by_team(summary)

                if not away_star and away_alias in by_team:
                    away_star = get_star_injuries(away_alias, {"injuries": by_team.get(away_alias, [])})
                if not home_star and home_alias in by_team:
                    home_star = get_star_injuries(home_alias, {"injuries": by_team.get(home_alias, [])})

            # Final fallback: league-wide injuries endpoint
            if not away_star and away_alias in league_injuries_by_team:
                away_star = get_star_injuries(away_alias, {"injuries": league_injuries_by_team.get(away_alias, [])})
            if not home_star and home_alias in league_injuries_by_team:
                home_star = get_star_injuries(home_alias, {"injuries": league_injuries_by_team.get(home_alias, [])})

            item["injury_data"] = {
                away_alias: away_star,
                home_alias: home_star,
            }
            item["injury_strip"] = format_star_injury_strip(away_alias, home_alias, item["injury_data"])
            item["injuries_home"] = [
                {"playerName": x.get("name", ""), "statusShort": status_short(x.get("status", ""))}
                for x in home_star
            ]
            item["injuries_away"] = [
                {"playerName": x.get("name", ""), "statusShort": status_short(x.get("status", ""))}
                for x in away_star
            ]
            item["injury_debug"] = {
                "away_alias": away_alias,
                "home_alias": home_alias,
                "league_raw_count_away": len(league_injuries_by_team.get(away_alias, [])),
                "league_raw_count_home": len(league_injuries_by_team.get(home_alias, [])),
                "star_count_away": len(away_star),
                "star_count_home": len(home_star),
            }
            nba_items.append(item)

    ncaam_items: List[Dict[str, Any]] = []
    for event in ncaam_events:
        item = normalize_event(event, "NCAAM", "ncaam", tz)
        if item:
            teams = item.get("_teams", {})
            home_variants = set(teams.get("home", set()))
            away_variants = set(teams.get("away", set()))

            home_rank = first_valid_rank(item.get("home_rank"))
            away_rank = first_valid_rank(item.get("away_rank"))

            if home_rank is None:
                home_rank = find_rank_from_variants(home_variants, ap_rank_map)
            if away_rank is None:
                away_rank = find_rank_from_variants(away_variants, ap_rank_map)

            item["home_rank"] = home_rank
            item["away_rank"] = away_rank

            away_name = item.get("away_team") or "Away"
            home_name = item.get("home_team") or "Home"
            away_label = f"{away_name} ({away_rank})" if isinstance(away_rank, int) else away_name
            home_label = f"{home_name} ({home_rank})" if isinstance(home_rank, int) else home_name
            item["display"]["title"] = f"{away_label} @ {home_label}"
            ncaam_items.append(item)

    prioritized_nba: List[Dict[str, Any]] = []
    for item in nba_items:
        teams = item.get("_teams", {})
        all_variants = set(teams.get("home", set())) | set(teams.get("away", set()))

        matched_priorities = [NBA_TEAM_PRIORITY[t] for t in all_variants if t in NBA_TEAM_PRIORITY]
        p = min(matched_priorities) if matched_priorities else 999
        item["is_my_team"] = bool(matched_priorities)
        item["priority"] = p
        sort = item["_sort"]

        is_live = 0 if sort["status_rank"] == 0 else 1
        is_pre = 0 if sort["status_rank"] == 1 else 1
        is_final = 0 if sort["status_rank"] == 2 else 1
        my_team_live = 0 if (sort["status_rank"] == 0 and item["is_my_team"]) else 1
        pre_start = sort["start_ts"] if sort["status_rank"] == 1 else float("inf")
        final_recent = -sort["start_ts"] if sort["status_rank"] == 2 else float("inf")

        item["_final_sort"] = (
            0,
            is_live,
            my_team_live,
            is_pre,
            is_final,
            pre_start,
            final_recent,
            p,
            sort["title"],
        )
        prioritized_nba.append(item)

    prioritized_ncaam: List[Dict[str, Any]] = []
    for item in ncaam_items:
        sort = item["_sort"]
        is_live = 0 if sort["status_rank"] == 0 else 1
        is_pre = 0 if sort["status_rank"] == 1 else 1
        is_final = 0 if sort["status_rank"] == 2 else 1
        pre_start = sort["start_ts"] if sort["status_rank"] == 1 else float("inf")
        final_recent = -sort["start_ts"] if sort["status_rank"] == 2 else float("inf")

        item["priority"] = 100
        item["_final_sort"] = (
            1,
            is_live,
            is_pre,
            is_final,
            pre_start,
            final_recent,
            sort["title"],
        )
        prioritized_ncaam.append(item)

    combined = prioritized_nba + prioritized_ncaam
    combined.sort(key=lambda x: x["_final_sort"])

    items: List[Dict[str, Any]] = []
    for item in combined[:MAX_ITEMS]:
        clean_item = {
            "sport": item["sport"],
            "league": item["league"],
            "event_id": item["event_id"],
            "start_time": item["start_time"],
            "start_time_epoch": item["start_time_epoch"],
            "status": item["status"],
            "gameState": item.get("game_state", "pre"),
            "status_text": item["status_text"],
            "awayTeam": item["away_team"],
            "homeTeam": item["home_team"],
            "awayTeamName": item["away_team"],
            "homeTeamName": item["home_team"],
            "awayAlias": item.get("away_alias", ""),
            "homeAlias": item.get("home_alias", ""),
            "awayTeamLogoUri": item.get("away_logo", ""),
            "homeTeamLogoUri": item.get("home_logo", ""),
            "awayRecord": item.get("away_record", ""),
            "homeRecord": item.get("home_record", ""),
            "awayScore": item["away_score"],
            "homeScore": item["home_score"],
            "startTimeLocalString": datetime.fromisoformat(item["start_time"]).strftime("%I:%M %p").lstrip("0"),
            "periodNumber": item.get("period_number"),
            "clockString": item.get("clock_string", ""),
            "isHalftime": item.get("is_halftime", False),
            "broadcasts": item.get("networks", []),
            "awayRank": item["away_rank"],
            "homeRank": item["home_rank"],
            "periodClock": item["period_clock"],
            "networks": item["networks"],
            "isMyTeam": item["is_my_team"],
            "injuryData": item.get("injury_data", {}),
            "injuryStrip": item.get("injury_strip", ""),
            "injuriesHome": item.get("injuries_home", []),
            "injuriesAway": item.get("injuries_away", []),
            "injuryDebug": item.get("injury_debug", {}),
            "display": item["display"],
            "priority": item["priority"],
            "watch": item["watch"],
        }
        items.append(clean_item)

    return {
        "generated_at": now_utc().isoformat(),
        "items": items,
    }


@app.get("/dashboard")
def dashboard(tz: str = Query(default="America/Chicago")) -> JSONResponse:
    try:
        data = build_dashboard(tz)
        return JSONResponse(content=data, media_type="application/json; charset=utf-8")
    except Exception as exc:
        traceback.print_exc()
        return JSONResponse(
            content={
                "generated_at": now_utc().isoformat(),
                "items": [],
                "error": f"{type(exc).__name__}: {exc}",
            },
            media_type="application/json; charset=utf-8",
            status_code=200,
        )


@app.get("/health")
def health() -> Dict[str, str]:
    return {"status": "ok"}


if __name__ == "__main__":
    import uvicorn

    port = int(os.getenv("PORT", "8787"))
    uvicorn.run("main:app", host="0.0.0.0", port=port)

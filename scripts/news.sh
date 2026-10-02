#!/usr/bin/env bash
# Fetch headlines for the news module and cache them as JSON.
# Usage: news.sh [topic]   (auto | world | tech | nepal | custom, default auto)
#
# "custom" reads ~/.config/omarchy/notch-island-feeds.txt (one URL per line,
# # comments allowed). The other topics use built-in feeds. "auto" pulls from
# every pool at once and reshuffles, so it surfaces stories you would not get
# from a single source.
#
# Each topic writes its own cache: ~/.local/state/notch-island/news-<topic>.json
# Safe to run offline: a failed fetch keeps the previous cache.
set -u
TOPIC="${1:-auto}"
case "$TOPIC" in
  auto|world|tech|nepal|business|science|sport|custom) ;;
  *) TOPIC="auto" ;;
esac

FEEDS_FILE="${HOME}/.config/omarchy/notch-island-feeds.txt"
STATE_DIR="${HOME}/.local/state/notch-island"
mkdir -p "$STATE_DIR"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

# --- feed pools -------------------------------------------------------------
world=(   "https://feeds.bbci.co.uk/news/world/rss.xml"
          "https://www.aljazeera.com/xml/rss/all.xml"
          "https://rss.dw.com/rdf/rss-en-world" )
tech=(    "https://hnrss.org/frontpage"
          "https://arstechnica.com/feed/"
          "https://feeds.bbci.co.uk/news/technology/rss.xml"
          "https://www.theverge.com/rss/index.xml" )
business=( "https://feeds.bbci.co.uk/news/business/rss.xml"
          "https://www.cnbc.com/id/100003114/device/rss/rss.html" )
science=( "https://feeds.bbci.co.uk/news/science_and_environment/rss.xml" )
sport=(   "https://feeds.bbci.co.uk/sport/rss.xml"
          "https://www.espn.com/espn/rss/news" )
health=(  "https://feeds.bbci.co.uk/news/health/rss.xml" )
nepal=(   "https://kathmandupost.com/rss"
          "https://english.onlinekhabar.com/feed" )

# custom feeds first, so an explicit file always wins
feeds=()
if [[ "$TOPIC" == "custom" && -f "$FEEDS_FILE" ]]; then
  while IFS= read -r line; do
    line="${line%%#*}"
    line="$(echo "$line" | tr -d '[:space:]')"
    [[ -n "$line" ]] && feeds+=("$line")
  done < "$FEEDS_FILE"
fi

if [[ ${#feeds[@]} -eq 0 ]]; then
  case "$TOPIC" in
    world)    feeds=("${world[@]}") ;;
    tech)     feeds=("${tech[@]}") ;;
    business) feeds=("${business[@]}") ;;
    science)  feeds=("${science[@]}") ;;
    sport)    feeds=("${sport[@]}") ;;
    nepal)    feeds=("${nepal[@]}") ;;
    custom)   # no feeds file: fall back to auto rather than a single source
              TOPIC="auto"; feeds=("${world[@]}" "${tech[@]}" "${business[@]}"
                                   "${science[@]}" "${sport[@]}" "${health[@]}") ;;
    auto)     feeds=("${world[@]}" "${tech[@]}" "${business[@]}"
                     "${science[@]}" "${sport[@]}" "${health[@]}" "${nepal[@]}") ;;
  esac
fi

echo "{\"fetching\":[$(printf '"%s",' "${feeds[@]}" | sed 's/,$//')]}" > "$tmp/manifest.json"

i=0
for url in "${feeds[@]}"; do
  curl -sS -m 20 -A "notch-island/1.0" "$url" -o "$tmp/feed-$i.xml" 2>/dev/null || true
  i=$((i+1))
done

python3 - "$tmp" "$STATE_DIR" "$TOPIC" <<'PY'
import email.utils
import glob
import json
import os
import random
import re
import sys
import time
import xml.etree.ElementTree as ET

srcdir, statedir, topic = sys.argv[1], sys.argv[2], sys.argv[3]
cache = os.path.join(statedir, "news-%s.json" % topic)

NS = {
    "atom": "http://www.w3.org/2005/Atom",
    "dc":   "http://purl.org/dc/elements/1.1/",
    "content": "http://purl.org/rss/1.0/modules/content/",
}


def clean(text):
    text = re.sub(r"<[^>]+>", " ", text or "")
    return re.sub(r"\s+", " ", text).strip()


def published_of(item):
    raw = (item.findtext("pubDate") or item.findtext("published")
           or item.findtext("updated") or item.findtext("{%s}date" % NS["dc"]) or "")
    raw = raw.strip()
    if not raw:
        return 0.0
    try:
        return email.utils.parsedate_to_datetime(raw).timestamp()
    except Exception:
        pass
    for fmt in ("%Y-%m-%dT%H:%M:%S%z", "%Y-%m-%dT%H:%M:%SZ", "%Y-%m-%d %H:%M:%S"):
        try:
            import datetime
            dt = datetime.datetime.strptime(raw.replace("Z", "+0000"), fmt)
            if dt.tzinfo is None:
                dt = dt.replace(tzinfo=datetime.timezone.utc)
            return dt.timestamp()
        except Exception:
            continue
    return 0.0


rows = []
for path in sorted(glob.glob(os.path.join(srcdir, "feed-*.xml"))):
    try:
        root = ET.parse(path).getroot()
    except Exception:
        continue

    channel = root.find("channel")
    if channel is not None:
        feed_title = clean(channel.findtext("title") or "News")
        items = channel.findall("item")
    else:                                    # Atom
        feed_title = clean(root.findtext("atom:title", namespaces=NS)
                           or root.findtext("{%s}title" % NS["atom"]) or "News")
        items = root.findall("atom:entry", NS) or root.findall("{%s}entry" % NS["atom"])

    for item in items:
        title = clean(item.findtext("title") or item.findtext("{%s}title" % NS["atom"]))
        if not title:
            continue
        link = (item.findtext("link") or "").strip()
        if not link:
            # Atom links live in an attribute
            for candidate in item.findall("atom:link", NS) or item.findall("{%s}link" % NS["atom"]):
                if candidate.get("rel") in (None, "alternate"):
                    link = candidate.get("href") or ""
                    if link:
                        break
        rows.append({
            "title": title,
            "link": link.strip(),
            "source": feed_title,
            "published": published_of(item),
        })

if not rows:
    sys.exit(0)                             # keep the previous cache

# De-duplicate on a normalised title so syndicated stories appear once.
seen, unique = set(), []
for row in rows:
    key = re.sub(r"[^a-z0-9]+", "", row["title"].lower())[:70]
    if not key or key in seen:
        continue
    seen.add(key)
    unique.append(row)

now = time.time()
limit = 12 if topic != "auto" else 24

if topic == "auto":
    # Fresh first, then a shuffle among the rest, seeded on the hour. The seed
    # keeps the list stable within an hour (no flicker on refresh) but lets a
    # new mix appear over time, and every source gets a fair share.
    fresh = [r for r in unique if r["published"] and now - r["published"] < 36 * 3600]
    stale = [r for r in unique if r not in fresh]
    rng = random.Random(int(now // 3600))
    rng.shuffle(fresh)
    rng.shuffle(stale)
    picked = (fresh + stale)[:limit]
else:
    picked = sorted(unique, key=lambda r: r["published"], reverse=True)[:limit]

picked = [{
    "title": r["title"],
    "link": r["link"],
    "source": r["source"],
    "published": int(r["published"]),
} for r in picked]

with open(cache + ".new", "w") as f:
    json.dump({"updated": int(now), "topic": topic, "items": picked}, f)
os.replace(cache + ".new", cache)
PY

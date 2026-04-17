#!/usr/bin/env bash
# Weekly upstream sync for anthropic-skills-trimmed.
# Intended to run on mac-mini via launchd. Emits ntfy notifications on conflict,
# push failure, or successful merge.
#
# Deliberately does NOT use `set -e` — we need to inspect non-zero exit codes
# ourselves and notify on each failure class.
set -u

REPO=~/Projects/anthropic-skills-trimmed
LOG=~/Library/Logs/anthropic-skills-trimmed-sync.log
NTFY_TOPIC="alex-alerts"
# Token file is optional. If present: push uses an embedded x-access-token URL
# (one-shot; never written to git config). If absent: push uses whatever
# credentials the machine has (sagan uses the alex-edv gh CLI token).
TOKEN_FILE="$HOME/.config/anthropic-skills-trimmed-sync/token"

# Guard: upstream must never introduce a new skill we haven't explicitly
# decided to keep. Update this allowlist when we add skills intentionally.
ALLOWED_SKILLS=(claude-api docx pdf pptx xlsx)

exec >>"$LOG" 2>&1
echo "===== $(date -u +%FT%TZ) sync start ====="

cd "$REPO" || { echo "repo missing at $REPO"; exit 2; }

git fetch origin main --quiet
git checkout main --quiet
git reset --hard origin/main --quiet

git fetch upstream main --quiet
UPSTREAM_AHEAD=$(git rev-list --count main..upstream/main)
if [[ "$UPSTREAM_AHEAD" -eq 0 ]]; then
    echo "no upstream changes — nothing to do"
    exit 0
fi

echo "upstream is $UPSTREAM_AHEAD commits ahead — merging"
if ! git merge upstream/main --no-edit --quiet; then
    echo "MERGE CONFLICT — leaving worktree dirty for manual resolution"
    curl -sS -H "Priority: urgent" -H "Tags: warning" \
         -d "anthropic-skills-trimmed: upstream merge conflict on mac-mini. Resolve manually: cd $REPO && git status." \
         "https://ntfy.sh/$NTFY_TOPIC" || true
    exit 3
fi

# Sanity: refuse to push if upstream snuck in a new skill directory
for dir in skills/*/; do
    name=$(basename "$dir")
    allowed=0
    for a in "${ALLOWED_SKILLS[@]}"; do
        [[ "$name" == "$a" ]] && allowed=1 && break
    done
    if [[ $allowed -eq 0 ]]; then
        echo "GUARD TRIPPED — unexpected skill dir after merge: $name"
        curl -sS -H "Priority: urgent" -H "Tags: warning" \
             -d "anthropic-skills-trimmed: upstream added new skill '$name'. Review manually before syncing: cd $REPO." \
             "https://ntfy.sh/$NTFY_TOPIC" || true
        exit 5
    fi
done

push_ok=0
if [[ -r "$TOKEN_FILE" ]]; then
    TOKEN=$(cat "$TOKEN_FILE")
    # Push to a URL with the token embedded. The URL stays out of git config
    # (no `remote set-url`) so the token never persists anywhere on disk
    # beyond $TOKEN_FILE.
    git push "https://x-access-token:${TOKEN}@github.com/edv-io/anthropic-skills-trimmed.git" main --quiet && push_ok=1
    unset TOKEN
else
    git push origin main --quiet && push_ok=1
fi

if [[ $push_ok -eq 0 ]]; then
    echo "PUSH FAILED"
    curl -sS -H "Priority: urgent" -H "Tags: warning" \
         -d "anthropic-skills-trimmed: push to origin failed on mac-mini. Check $LOG." \
         "https://ntfy.sh/$NTFY_TOPIC" || true
    exit 4
fi

echo "synced $UPSTREAM_AHEAD upstream commits and pushed to origin/main"
curl -sS -H "Tags: white_check_mark" \
     -d "anthropic-skills-trimmed: synced $UPSTREAM_AHEAD upstream commits." \
     "https://ntfy.sh/$NTFY_TOPIC" || true

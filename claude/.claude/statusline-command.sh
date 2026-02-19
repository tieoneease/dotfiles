#!/usr/bin/env bash
set -euo pipefail

# --- ANSI Colors ---
RST='\033[0m'
BOLD='\033[1m'
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
BLUE='\033[34m'
MAGENTA='\033[35m'
CYAN='\033[36m'

# --- Read stdin + extract fields in one jq call ---
input=$(cat)
IFS=$'\t' read -r model_name model_id context_remaining project_dir transcript_path <<< "$(
    echo "$input" | jq -r '[
        (.model.display_name // .model.id // "unknown"),
        (.model.id // "unknown"),
        (.context_window.remaining_percentage // "null"),
        (.workspace.project_dir // .workspace.current_dir // "unknown"),
        (.transcript_path // "")
    ] | @tsv'
)"

user=$(whoami)
host=$(hostname -s)
project_name=$(basename "$project_dir")

# --- Git branch ---
branch=""
if [ -d "$project_dir/.git" ]; then
    cd "$project_dir" 2>/dev/null || true
    git_info=$(git -c core.useBuiltinFSMonitor=false config --get-regexp 'core.bare|core.worktree' 2>/dev/null || true)
    if echo "$git_info" | grep -q "core.bare true"; then
        branch="(bare)"
    elif echo "$git_info" | grep -q "core.worktree"; then
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "(worktree)")
        [ -n "$branch" ] && branch="worktree:$branch"
    else
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null || echo "(no branch)")
    fi
fi

# --- Model color ---
color_model() {
    local id="$1" name="$2"
    case "$id" in
        *opus*)   printf '%b%s%b' "$MAGENTA" "$name" "$RST" ;;
        *sonnet*) printf '%b%s%b' "$CYAN" "$name" "$RST" ;;
        *haiku*)  printf '%b%s%b' "$BLUE" "$name" "$RST" ;;
        *)        printf '%s' "$name" ;;
    esac
}

# --- Context color ---
color_context() {
    local pct="$1"
    local color="$GREEN"
    if (( pct < 25 )); then
        color="$RED"
    elif (( pct < 50 )); then
        color="$YELLOW"
    fi
    printf '%b%d%% left%b' "$color" "$pct" "$RST"
}

# --- Usage color (with optional countdown) ---
color_usage() {
    local label="$1" pct="$2" reset_at="$3" always_countdown="${4:-0}"
    local color="$GREEN"
    if (( pct >= 80 )); then
        color="$RED"
    elif (( pct >= 60 )); then
        color="$YELLOW"
    fi

    local countdown=""
    if (( always_countdown || pct >= 60 )) && [ -n "$reset_at" ] && [ "$reset_at" != "null" ]; then
        countdown=$(format_countdown "$reset_at")
        [ -n "$countdown" ] && countdown=" ($countdown)"
    fi

    printf '%s: %b%d%%%b%s' "$label" "$color" "$pct" "$RST" "$countdown"
}

# --- Countdown formatter ---
format_countdown() {
    local reset_at="$1"
    local reset_epoch now_epoch diff_s

    # Parse ISO8601 timestamp
    reset_epoch=$(date -d "$reset_at" +%s 2>/dev/null) || return 0
    now_epoch=$(date +%s)
    diff_s=$(( reset_epoch - now_epoch ))
    (( diff_s <= 0 )) && return 0

    local days=$(( diff_s / 86400 ))
    local hours=$(( (diff_s % 86400) / 3600 ))
    local minutes=$(( (diff_s % 3600) / 60 ))

    if (( days > 0 )); then
        printf '%dd%02dh%02dm' "$days" "$hours" "$minutes"
    elif (( hours > 0 )); then
        printf '%dh%02dm' "$hours" "$minutes"
    else
        printf '%dm' "$minutes"
    fi
}

# --- Parse running subagents from transcript ---
parse_running_agents() {
    local transcript="$1"
    [ -n "$transcript" ] && [ -f "$transcript" ] || return 0
    local now_epoch
    now_epoch=$(date +%s)

    # Read last 512KB, skip first (potentially truncated) line
    tail -c 524288 "$transcript" 2>/dev/null | sed '1d' | jq -s -r --argjson now "$now_epoch" '
        # Collect Task tool_use entries (started agents)
        [.[] | select(.type == "assistant") |
            . as $line |
            .message.content[]? |
            select(.type == "tool_use" and (.name == "Task" or .name == "proxy_Task")) |
            {
                id: .id,
                model: (.input.model // "unknown"),
                subagent_type: (.input.subagent_type // "unknown"),
                description: (.input.description // ""),
                timestamp: $line.timestamp
            }
        ] as $started |
        # Collect completed tool_result IDs
        [.[] | select(.type == "user") |
            .message.content[]? |
            select(.type == "tool_result") |
            .tool_use_id
        ] as $completed |
        # Filter to running (started but not completed), exclude stale (>30 min)
        [$started[] | select(
            (.id as $id | $completed | index($id) | not) and
            ((.timestamp // null) as $ts |
                if $ts then
                    (($ts | sub("\\.[0-9]+Z$"; "Z") | fromdate) as $epoch |
                    ($now - $epoch) < 1800)
                else true end)
        )] |
        # Take up to 5, output TSV: model, subagent_type, description, elapsed_seconds
        .[:5][] |
        ((.timestamp // null) as $ts |
            if $ts then
                (($ts | sub("\\.[0-9]+Z$"; "Z") | fromdate) as $epoch | ($now - $epoch))
            else 0 end) as $elapsed |
        [.model, .subagent_type, .description, ($elapsed | tostring)] | @tsv
    ' 2>/dev/null || true
}

# --- Format agent tree display ---
format_agent_tree() {
    local agents="$1"
    [ -z "$agents" ] && return 0
    local count=0 total
    total=$(echo "$agents" | wc -l)

    while IFS=$'\t' read -r model subagent_type description elapsed_s; do
        count=$((count + 1))
        # Model badge with color
        local badge
        case "$model" in
            *opus*)   badge="${MAGENTA}O${RST}" ;;
            *sonnet*) badge="${CYAN}s${RST}" ;;
            *haiku*)  badge="${GREEN}h${RST}" ;;
            *)        badge="?" ;;
        esac

        # Elapsed time formatted
        local mins=$(( elapsed_s / 60 ))
        local secs=$(( elapsed_s % 60 ))
        local elapsed_fmt="${mins}m${secs}s"

        # Truncate description
        [ ${#description} -gt 40 ] && description="${description:0:37}..."

        # Tree connector
        local connector="├─"
        [ "$count" -eq "$total" ] && connector="└─"

        printf '  %s %b %-14s %-7s %s\n' "$connector" "$badge" "$subagent_type" "$elapsed_fmt" "$description"
    done <<< "$agents"
}

# --- Fetch usage (cached) ---
CACHE_DIR="$HOME/.claude/hud"
CACHE_FILE="$CACHE_DIR/.usage-cache.json"
CREDS_FILE="$HOME/.claude/.credentials.json"
CACHE_MAX_AGE=60

fetch_usage() {
    # No credentials → no usage data
    [ -f "$CREDS_FILE" ] || return 1
    local token
    token=$(jq -r '.claudeAiOauth.accessToken // empty' "$CREDS_FILE" 2>/dev/null) || return 1
    [ -n "$token" ] || return 1

    # Check cache freshness
    if [ -f "$CACHE_FILE" ]; then
        local now file_mtime age
        now=$(date +%s)
        # Cross-platform stat: Linux vs macOS
        if stat --version &>/dev/null; then
            file_mtime=$(stat -c %Y "$CACHE_FILE" 2>/dev/null) || file_mtime=0
        else
            file_mtime=$(stat -f %m "$CACHE_FILE" 2>/dev/null) || file_mtime=0
        fi
        age=$(( now - file_mtime ))
        if (( age < CACHE_MAX_AGE )); then
            cat "$CACHE_FILE"
            return 0
        fi
    fi

    # Fetch from API
    mkdir -p "$CACHE_DIR"
    local tmp_file response
    tmp_file=$(mktemp "${CACHE_DIR}/.usage-tmp.XXXXXX")

    response=$(curl -s --connect-timeout 3 --max-time 5 \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        -H "User-Agent: claude-code/2.0.32" \
        -H "anthropic-beta: oauth-2025-04-20" \
        "https://api.anthropic.com/api/oauth/usage" 2>/dev/null) || true

    # Validate response has expected fields
    if [ -n "$response" ] && echo "$response" | jq -e '.five_hour.utilization' &>/dev/null; then
        echo "$response" > "$tmp_file"
        mv -f "$tmp_file" "$CACHE_FILE"
        echo "$response"
        return 0
    fi

    rm -f "$tmp_file"

    # Fall back to stale cache
    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
        return 0
    fi

    return 1
}

# --- Build status line ---
status="${BOLD}[$RST"
status+="$user@$host $project_name"

if [ -n "$branch" ]; then
    status+=" ($branch)"
fi

status+=" | $(color_model "$model_id" "$model_name")"

# Context remaining
if [ "$context_remaining" != "null" ] && [ -n "$context_remaining" ]; then
    context_int=$(printf "%.0f" "$context_remaining" 2>/dev/null || echo "$context_remaining")
    status+=" | $(color_context "$context_int")"
fi

# Usage limits
usage_json=$(fetch_usage 2>/dev/null) || usage_json=""

if [ -n "$usage_json" ]; then
    read -r five_pct five_reset seven_pct seven_reset <<< "$(
        echo "$usage_json" | jq -r '[
            (.five_hour.utilization // 0 | floor),
            (.five_hour.resets_at // "null"),
            (.seven_day.utilization // 0 | floor),
            (.seven_day.resets_at // "null")
        ] | @tsv'
    )"

    status+=" | $(color_usage "5h" "$five_pct" "$five_reset" 0)"
    status+=" | $(color_usage "7d" "$seven_pct" "$seven_reset" 1)"
elif [ -f "$CREDS_FILE" ]; then
    # Have credentials but API failed and no cache
    status+=" | 5h: -- | 7d: --"
fi

# Running agents
agent_lines=""
if [ -n "${transcript_path:-}" ] && [ -f "${transcript_path:-}" ]; then
    agent_lines=$(parse_running_agents "$transcript_path")
fi

agent_count=0
if [ -n "$agent_lines" ]; then
    agent_count=$(echo "$agent_lines" | wc -l)
    status+=" | $agent_count agent"
    (( agent_count > 1 )) && status+="s"
fi

status+="${BOLD}]$RST"

echo -e "$status"

if [ -n "$agent_lines" ]; then
    format_agent_tree "$agent_lines"
fi

#!/bin/bash
# Verbose Claude Code status line.
#
# Base segment converted from the colored PS1 found in ~/.bashrc:
#   PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
#
# Mapping:
#   \u          -> $(whoami)
#   \h          -> $(hostname -s)
#   \w          -> current dir, with $HOME shown as ~ (bash's \w behavior)
#   debian_chroot prefix -> included only if $debian_chroot is set
#   trailing "\$ " (prompt terminator) -> dropped, per statusline conventions
#
# On top of that base segment, this "verbose" variant adds (each optional,
# shown only when available): git branch + dirty marker, the active model,
# output style (when not "default"), vim mode, and context-window usage.
#
# Colors are preserved via printf; the terminal renders them dimmed as part
# of the status line.

input=$(cat)

cwd=$(printf '%s' "$input" | jq -r '.workspace.current_dir // .cwd // empty')
[ -n "$cwd" ] || cwd=$(pwd)

user=$(whoami)
host=$(hostname -s)

# --- Directory: replicate bash's \w, showing $HOME as ~ ---
if [ "$cwd" = "$HOME" ]; then
  dir_display="~"
elif [ "${cwd#"$HOME"/}" != "$cwd" ]; then
  dir_display="~${cwd#"$HOME"}"
else
  dir_display="$cwd"
fi

# --- Optional debian_chroot prefix, as in the original PS1 ---
chroot_prefix=""
[ -n "$debian_chroot" ] && chroot_prefix="($debian_chroot)"

GREEN='\033[01;32m'
BLUE='\033[01;34m'
YELLOW='\033[01;33m'
CYAN='\033[01;36m'
MAGENTA='\033[01;35m'
RESET='\033[00m'

out=$(printf "%s${GREEN}%s@%s${RESET}:${BLUE}%s${RESET}" "$chroot_prefix" "$user" "$host" "$dir_display")

# --- Git branch + dirty marker (skip optional locks; safe in any repo state) ---
# The status line runs in whatever folder Claude is open in, including untrusted
# clones, so neutralise repo config that would run commands (fsmonitor, external
# diff, textconv) on every refresh.
safe_git() {
  git -C "$cwd" --no-optional-locks -c core.fsmonitor= -c diff.external= -c core.hooksPath=/dev/null "$@"
}
if safe_git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  branch=$(safe_git symbolic-ref --short HEAD 2>/dev/null \
    || safe_git rev-parse --short HEAD 2>/dev/null)
  if [ -n "$branch" ]; then
    dirty=""
    # Content filters (filter.<name>.clean/process) can't be switched off by name, so
    # skip the dirty check when the repo's own config defines any. Filters from your
    # global or system config (e.g. git-lfs) are yours and still apply.
    # Fail closed: run diff only when git config answers cleanly (1 = no filters at all,
    # 0 = filters, all from global/system). Any error (e.g. git < 2.26) skips the check.
    filters=$(safe_git config --show-scope --includes --get-regexp '^filter\.' 2>/dev/null)
    rc=$?
    if [ $rc -eq 1 ] || { [ $rc -eq 0 ] && [ -z "$(printf '%s\n' "$filters" | grep -Ev '^(global|system|command)[[:space:]]')" ]; }; then
      safe_git diff --no-ext-diff --no-textconv --quiet --ignore-submodules -- 2>/dev/null || dirty="*"
    fi
    git_seg=$(printf "${YELLOW} (%s%s)${RESET}" "$branch" "$dirty")
    out="${out}${git_seg}"
  fi
fi

# --- Model ---
model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
[ -n "$model" ] && out="${out} | $(printf "${CYAN}%s${RESET}" "$model")"

# --- Output style, only when non-default ---
style=$(printf '%s' "$input" | jq -r '.output_style.name // empty')
[ -n "$style" ] && [ "$style" != "default" ] && out="${out} [${style}]"

# --- Vim mode, when enabled ---
vim_mode=$(printf '%s' "$input" | jq -r '.vim.mode // empty')
[ -n "$vim_mode" ] && out="${out} ${MAGENTA}${vim_mode}${RESET}"

# --- Context window usage ---
used=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
if [ -n "$used" ]; then
  used_fmt=$(printf '%.0f' "$used")
  out="${out} | Ctx: ${used_fmt}%"
fi

printf '%s' "$out"

#!/bin/zsh

set -u

project_root="/Volumes/DuXC_PhD_OS/04_PAPERS_论文发表/04_GUT_ED_MR_REBUILD_20260710"
stdout_log="$HOME/Library/Logs/gut-ed-mechanistic-download.stdout.log"
stderr_log="$HOME/Library/Logs/gut-ed-mechanistic-download.stderr.log"

cd "$project_root" || exit 1
exec >>"$stdout_log" 2>>"$stderr_log"

echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') supervisor started"
while true; do
  /usr/bin/caffeinate -ims \
    /opt/homebrew/bin/Rscript \
    "$project_root/scripts/16_download_mechanistic_sources.R"
  exit_code=$?
  if [[ $exit_code -eq 0 ]]; then
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') all downloads verified"
    exit 0
  fi
  echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') downloader exited $exit_code; retrying in 30 seconds" >&2
  sleep 30
done

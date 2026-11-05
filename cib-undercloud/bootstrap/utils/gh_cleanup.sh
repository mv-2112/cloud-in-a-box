#!/usr/bin/env bash

# Define color codes
# Bold Red: \033[1;31m | Reset: \033[0m
RED='\033[1;31m'
NC='\033[0m' # No Color

# Check if the terminal supports color; if not, clear the variables
if [ -t 1 ]; then
    ncolors=$(tput colors 2>/dev/null || echo 0)
    if [ -z "$ncolors" ] || [ "$ncolors" -lt 8 ]; then
        RED=''
        NC=''
    fi
else
    RED=''
    NC=''
fi

GH_ORG=$1

# Basic validation
if [ -z "$GH_ORG" ]; then
  echo "Usage: $0 <github-org-name>"
  exit 1
fi

# 1. Warning message
echo -e "${RED}CAUTION - This will delete the following repositories in organization: $GH_ORG${NC}"
gh repo list "$GH_ORG" --json nameWithOwner --jq ".[].nameWithOwner"

# 2. Confirmation before starting the loop
read -p "Are you sure you want to proceed with deletion? (y/N): " main_confirm
if [[ ! "$main_confirm" =~ ^[Yy]$ ]]; then
  echo "Aborting."
  exit 0
fi

# 3. Individual confirmation loop
for each_repo in $(gh repo list "$GH_ORG" --json nameWithOwner --jq ".[].nameWithOwner")
do
  echo -e "Preparing to delete: ${RED}$each_repo${NC}"
  read -p "Confirm deletion of $each_repo? (y/N): " repo_confirm
  
  if [[ "$repo_confirm" =~ ^[Yy]$ ]]; then
    # Use --yes to skip the gh cli's internal confirmation if we already asked
    gh repo delete "$each_repo" --confirm 2>/dev/null || gh repo delete "$each_repo" --yes
  else
    echo "Skipping $each_repo."
  fi
done

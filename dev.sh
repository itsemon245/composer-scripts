#!/bin/bash

# Define colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Define the path to composer.json
COMPOSER_FILE="composer.json"

# Check if composer.json exists
if [ ! -f "$COMPOSER_FILE" ]; then
  echo -e "${RED}[ERROR] ${COMPOSER_FILE} not found.${RESET}"
  exit 1
fi

# Check if npm is installed
if ! command -v npm >/dev/null 2>&1; then
  echo -e "${RED}[ERROR] npm is not installed. Please install npm and try again.${RESET}"
  exit 1
fi

# Check if composer is installed
if ! command -v composer >/dev/null 2>&1; then
  echo -e "${RED}[ERROR] composer is not installed. Please install composer and try again.${RESET}"
  exit 1
fi

# Check if jq is installed
if ! command -v jq >/dev/null 2>&1; then
  echo -e "${RED}[ERROR] jq is required but not installed. Please install jq and try again.${RESET}"
  exit 1
fi

# Define the new script to be added
NEW_SCRIPT_KEY="dev"
NEW_SCRIPT_VALUE="[
  \"Composer\\Config::disableProcessTimeout\",
  \"npx concurrently -c '#93c5fd,#c4b5fd,#fb7185,#fdba74' 'php artisan serve' 'php artisan queue:listen --tries=1' 'echo Logs are available at http://localhost:8000/log-viewer' 'npm run dev' --names=server,queue,logs,vite\"
]"

# Backup the original composer.json
cp "$COMPOSER_FILE" "$COMPOSER_FILE.bak"
echo -e "${BLUE}[INFO] Backup created: $COMPOSER_FILE.bak${RESET}"

# Check if log-viewer is already required
if jq -e '.require["opcodesio/log-viewer"]' "$COMPOSER_FILE" >/dev/null; then
  echo -e "${YELLOW}[INFO] log-viewer is already installed. Skipping installation.${RESET}"
else
  # Add log-viewer package
  composer require opcodesio/log-viewer
  if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR] Failed to install log-viewer.${RESET}"
    exit 1
  fi
  php artisan log-viewer:publish
  if [ $? -ne 0 ]; then
    echo -e "${RED}[ERROR] Failed to publish log-viewer files${RESET}"
    exit 1
  fi
fi

# Check if the dev script already exists
if jq -e ".scripts.$NEW_SCRIPT_KEY" "$COMPOSER_FILE" >/dev/null; then
  echo -e "${YELLOW}[INFO] The dev script already exists in $COMPOSER_FILE. No changes made.${RESET}"
else
  # Add the dev script
  jq ".scripts.$NEW_SCRIPT_KEY = $NEW_SCRIPT_VALUE" "$COMPOSER_FILE" > "$COMPOSER_FILE.tmp" && mv "$COMPOSER_FILE.tmp" "$COMPOSER_FILE"
  echo -e "${GREEN}[SUCCESS] Successfully added the dev script to $COMPOSER_FILE. A backup has been created as $COMPOSER_FILE.bak.${RESET}"
fi

# Install the required npm package
npm i -D concurrently
if [ $? -ne 0 ]; then
  echo -e "${RED}[ERROR] Failed to install npm dependencies.${RESET}"
  exit 1
fi

# Run composer update
composer update
if [ $? -ne 0 ]; then
  echo -e "${RED}[ERROR] Failed to run composer update.${RESET}"
  exit 1
fi

echo -e "${GREEN}[SUCCESS] All tasks completed successfully.${RESET}"

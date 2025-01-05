#!/bin/bash

# Define the path to composer.json
COMPOSER_FILE="composer.json"
ROUTES_FILE="routes/web.php"

# Check if composer.json exists
if [ ! -f "$COMPOSER_FILE" ]; then
  echo "Error: $COMPOSER_FILE not found."
  exit 1
fi

# Check if routes/web.php exists
if [ ! -f "$ROUTES_FILE" ]; then
  echo "Error: $ROUTES_FILE not found."
  exit 1
fi

# Check if npm is installed
if ! command -v npm >/dev/null 2>&1; then
  echo "Error: npm is not installed. Please install npm and try again."
  exit 1
fi

# Check if composer is installed
if ! command -v composer >/dev/null 2>&1; then
  echo "Error: composer is not installed. Please install composer and try again."
  exit 1
fi

# Check if jq is installed
if ! command -v jq >/dev/null 2>&1; then
  echo "Error: jq is required but not installed. Please install jq and try again."
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

# Check if log-viewer is already required
if jq -e '.require["opcodesio/log-viewer"]' "$COMPOSER_FILE" >/dev/null; then
  echo "log-viewer is already installed. Skipping installation."
else
  # Add log-viewer package
  composer require opcodesio/log-viewer
  if [ $? -ne 0 ]; then
    echo "Error: Failed to install log-viewer."
    exit 1
  fi

  # Add log-viewer route to routes/web.php
  if ! grep -q "LogViewer::routes()" "$ROUTES_FILE"; then
    echo "\n\App\LogViewer\LogViewer::routes();" >> "$ROUTES_FILE"
    echo "Added log-viewer route to $ROUTES_FILE."
  else
    echo "LogViewer route already exists in $ROUTES_FILE."
  fi
fi

# Check if the dev script already exists
if jq -e ".scripts.$NEW_SCRIPT_KEY" "$COMPOSER_FILE" >/dev/null; then
  echo "The dev script already exists in $COMPOSER_FILE. No changes made."
else
  # Add the dev script
  jq ".scripts.$NEW_SCRIPT_KEY = $NEW_SCRIPT_VALUE" "$COMPOSER_FILE" > "$COMPOSER_FILE.tmp" && mv "$COMPOSER_FILE.tmp" "$COMPOSER_FILE"
  echo "Successfully added the dev script to $COMPOSER_FILE. A backup has been created as $COMPOSER_FILE.bak."
fi

# Install the required npm package
npm i -D concurrently
if [ $? -ne 0 ]; then
  echo "Error: Failed to install npm dependencies."
  exit 1
fi

# Run composer update
composer update
if [ $? -ne 0 ]; then
  echo "Error: Failed to run composer update."
  exit 1
fi

echo "All tasks completed successfully."

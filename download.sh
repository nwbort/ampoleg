#!/usr/bin/env bash
#
# download - Simple downloader that always constructs the filename from the URL
# Usage: ./download.sh URL

set -e

# Function to detect MIME type and return appropriate extension
get_file_extension() {
  local file_path="$1"
  local mime_type=$(file --mime-type -b "$file_path")
  local extension=""
  
  case "$mime_type" in
    text/html)                extension=".html" ;;
    application/json)         extension=".json" ;;
    text/plain)               extension=".txt" ;;
    application/javascript)   extension=".js" ;;
    application/xml|text/xml) extension=".xml" ;;
    application/pdf)          extension=".pdf" ;;
    image/jpeg)               extension=".jpg" ;;
    image/png)                extension=".png" ;;
    image/gif)                extension=".gif" ;;
    image/svg+xml)            extension=".svg" ;;
    application/zip)          extension=".zip" ;;
    application/gzip)         extension=".gz" ;;
    application/x-tar)        extension=".tar" ;;
    application/x-bzip2)      extension=".bz2" ;;
    *)                        extension=".html" ;; # Default to HTML if unknown
  esac
  
  echo "$extension"
}

# Check if URL provided
if [ $# -ne 1 ]; then
  echo "Usage: $0 URL"
  exit 1
fi

URL="$1"

# Validate URL format (must start with http:// or https://)
if [[ ! "$URL" =~ ^https?:// ]]; then
  echo "Error: URL must start with http:// or https://"
  exit 1
fi

# Create temporary file
TEMP_FILE=$(mktemp)

# Download the file
echo "Downloading $URL"
curl -s -L "$URL" -o "$TEMP_FILE" || {
  echo "Error: Failed to download $URL"
  rm -f "$TEMP_FILE"
  exit 1
}

# Get file extension based on MIME type
EXTENSION=$(get_file_extension "$TEMP_FILE")

# Always construct filename from the URL, replacing slashes with hyphens
FILENAME=$(echo "$URL" | sed -E 's|^https?://||' | sed -E 's|^www\.||' | sed 's|/$||' | sed 's|/|-|g')

# Add extension to the filename
FILENAME="${FILENAME}${EXTENSION}"

# Make sure we don't end up with just an extension
if [ "$FILENAME" = "${EXTENSION}" ]; then
  FILENAME="index${EXTENSION}"
fi

# Get the current directory to ensure we save to this location
CURRENT_DIR="$(pwd)"
FULL_PATH="${CURRENT_DIR}/${FILENAME}"

# Clean dynamic content from HTML file
clean_html_file() {
  local file="$1"

  sed -i -E \
    -e 's/js-view-dom-id-[a-f0-9]{64}/js-view-dom-id-STATIC/g' \
    -e 's/(id="edit-submit-accc-search-site--)[^"]+"/\1STATIC"/g' \
    -e 's/(css\/css_)[^.]+\.css/\1STATIC.css/g' \
    -e 's/(js\/js_)[^.]+\.js/\1STATIC.js/g' \
    -e 's/("libraries":")[^"]+"/\1STATIC_LIBRARIES"/g' \
    -e 's/("permissionsHash":")[^"]+"/\1STATIC_HASH"/g' \
    -e 's/("view_dom_id":")[a-f0-9]{64}/\1STATIC"/g' \
    -e 's/(views_dom_id:)[a-f0-9]{64}/\1STATIC/g' \
    -e 's/include=[^"&>]+/include=STATIC/g' \
    -e 's/href="https:\/\/app\.readspeaker\.com\/[^"]+"/href="STATIC_READSPEAKER_URL"/g' \
    -e 's/(icons\.svg\?t)[^#]+#/\1STATIC#/g' \
    -e 's/(\?t)[^">]+/\1STATIC/g' \
    -e 's/("css_js_query_string":")[^"]+"/\1STATIC"/g' \
    "$file"

  sed -i -E -e ':a;N;$!ba;s#(<a[^>]*class="[^"]*megamenu-page-link-level-3[^"]*"[^>]*href=")[^"]*("[^>]*>[[:space:]]*<span>)[^<]*(</span>)#\1STATIC_HREF\2STATIC_TEXT\3#g' "$file"

  local temp_file
  temp_file=$(mktemp)
  cat -s "$file" > "$temp_file" && mv "$temp_file" "$file"
}

# Pretty-print JSON if applicable
if [ "$EXTENSION" = ".json" ]; then
  # Create another temporary file for the pretty-printed version
  PRETTY_TEMP=$(mktemp)
  # Try to pretty-print with jq, but don't fail if jq fails
  if command -v jq &> /dev/null; then
    if jq . "$TEMP_FILE" > "$PRETTY_TEMP" 2>/dev/null; then
      mv "$PRETTY_TEMP" "$TEMP_FILE"
    else
      rm -f "$PRETTY_TEMP"
    fi
  else
    rm -f "$PRETTY_TEMP"
  fi
fi

# Move to final destination
mv "$TEMP_FILE" "$FULL_PATH"

# Clean dynamic content from HTML files
if [ "$EXTENSION" = ".html" ]; then
  clean_html_file "$FULL_PATH"
fi

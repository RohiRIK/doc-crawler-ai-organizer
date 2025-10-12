#!/bin/bash

# Advanced Firecrawl Documentation Scraper with AI-Ready Post-Processing
# Usage: ./scrape_and_organize.sh <domain_url> [max_pages] [output_dir]

set -e

# ==================== CONFIGURATION ====================
FIRECRAWL_API_URL="${FIRECRAWL_API_URL:-http://localhost:3002}"
FIRECRAWL_API_KEY="${FIRECRAWL_API_KEY:-your-api-key}"
DOMAIN_URL="${1:-https://docs.n8n.io}"
MAX_PAGES="${2:-1000}"
BASE_OUTPUT_DIR="${3:-./docs_output}"
POLL_INTERVAL=5

# Derived paths
RAW_DIR="${BASE_OUTPUT_DIR}/raw"
PROCESSED_DIR="${BASE_OUTPUT_DIR}/processed"
CATEGORIZED_DIR="${BASE_OUTPUT_DIR}/categorized"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# ==================== HELPER FUNCTIONS ====================

log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Extract domain name for categorization
get_domain_name() {
  echo "$DOMAIN_URL" | sed 's|https\?://||' | sed 's|/.*||' | sed 's|docs\.||' | sed 's|www\.||'
}

# Generate safe filename from URL
sanitize_filename() {
  local url="$1"
  echo "$url" | sed 's|https\?://||' | sed 's|[/:]|_|g' | sed 's|_$||' | sed 's|__*|_|g'
}

# Extract metadata from content
extract_title() {
  local content="$1"
  # Get first H1 or filename as fallback
  echo "$content" | grep -m 1 '^# ' | sed 's/^# //' || echo "Untitled"
}

# Categorize based on URL patterns
categorize_url() {
  local url="$1"

  # Common documentation patterns
  if echo "$url" | grep -qi 'getting.started\|quickstart\|intro\|installation'; then
    echo "getting_started"
  elif echo "$url" | grep -qi 'api\|reference\|endpoint'; then
    echo "api_reference"
  elif echo "$url" | grep -qi 'tutorial\|guide\|how.to'; then
    echo "tutorials"
  elif echo "$url" | grep -qi 'example\|workflow\|template'; then
    echo "examples"
  elif echo "$url" | grep -qi 'node\|integration\|connector'; then
    echo "nodes"
  elif echo "$url" | grep -qi 'advanced\|expert'; then
    echo "advanced"
  elif echo "$url" | grep -qi 'troubleshoot\|faq\|error'; then
    echo "troubleshooting"
  else
    echo "general"
  fi
}

# Extract keywords from content
extract_keywords() {
  local content="$1"
  local title="$2"

  # Extract common technical terms and create tags
  local keywords=""

  # Add title words as keywords
  keywords="$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g')"

  # Add category-specific keywords
  if echo "$content" | grep -qi "trigger"; then
    keywords="$keywords, trigger"
  fi
  if echo "$content" | grep -qi "webhook"; then
    keywords="$keywords, webhook"
  fi
  if echo "$content" | grep -qi "api"; then
    keywords="$keywords, api"
  fi

  echo "$keywords" | sed 's/^ *, *//'
}

# Add metadata header to markdown file
add_metadata_header() {
  local filepath="$1"
  local url="$2"
  local category="$3"
  local title="$4"
  local keywords="$5"
  local domain="$(get_domain_name)"
  local timestamp="$(date -u +"%Y-%m-%d")"

  # Create temp file with metadata
  local temp_file="${filepath}.tmp"

  cat >"$temp_file" <<EOF
---
title: ${title}
source_url: ${url}
domain: ${domain}
category: ${category}
tags: ${keywords}
scraped_date: ${timestamp}
---

EOF

  # Append original content
  cat "$filepath" >>"$temp_file"
  mv "$temp_file" "$filepath"
}

# Split markdown by H2 headers
split_by_headers() {
  local input_file="$1"
  local output_dir="$2"

  log_info "Splitting ${input_file} by H2 headers..."

  # Use awk to split by ## headers
  awk '
    BEGIN { 
        file_count = 0
        current_file = ""
        header_name = ""
    }
    /^## / { 
        if (current_file != "") close(current_file)
        header_name = $0
        gsub(/^## /, "", header_name)
        gsub(/[^a-zA-Z0-9_-]/, "_", header_name)
        gsub(/__+/, "_", header_name)
        gsub(/^_|_$/, "", header_name)
        current_file = sprintf("'"$output_dir"'/%03d_%s.md", ++file_count, tolower(header_name))
        print "Processing section: " header_name > "/dev/stderr"
    }
    { 
        if (current_file != "") print > current_file
        else print > sprintf("'"$output_dir"'/000_header.md")
    }
    END { 
        if (current_file != "") close(current_file)
    }
    ' "$input_file"
}

# Create index file
create_index() {
  local output_dir="$1"
  local domain="$(get_domain_name)"
  local index_file="${output_dir}/INDEX.md"

  log_info "Creating master INDEX.md..."

  cat >"$index_file" <<EOF
# ${domain} Documentation Index

**Generated:** $(date)
**Source:** ${DOMAIN_URL}
**Total Documents:** $(find "$CATEGORIZED_DIR" -name "*.md" | wc -l)

## Documentation Categories

EOF

  # Add category sections
  for category_dir in "$CATEGORIZED_DIR"/*; do
    if [ -d "$category_dir" ]; then
      local category="$(basename "$category_dir")"
      local count=$(find "$category_dir" -name "*.md" | wc -l)

      echo "### ${category//_/ } (${count} documents)" >>"$index_file"
      echo "" >>"$index_file"

      # List files in category
      find "$category_dir" -name "*.md" -exec basename {} .md \; | sort | while read -r filename; do
        echo "- [${filename}](categorized/${category}/${filename}.md)" >>"$index_file"
      done

      echo "" >>"$index_file"
    fi
  done

  log_success "INDEX.md created at ${index_file}"
}

# Create category summary
create_category_summaries() {
  local categorized_dir="$1"

  for category_dir in "$categorized_dir"/*; do
    if [ -d "$category_dir" ]; then
      local category="$(basename "$category_dir")"
      local summary_file="${category_dir}/_SUMMARY.md"

      cat >"$summary_file" <<EOF
# ${category//_/ } Summary

This directory contains documentation related to ${category//_/ }.

## Documents in this category:

EOF

      find "$category_dir" -name "*.md" ! -name "_SUMMARY.md" -exec basename {} .md \; | sort | while read -r filename; do
        # Extract title from first line if it's an H1
        local filepath="${category_dir}/${filename}.md"
        local title=$(grep -m 1 '^# ' "$filepath" | sed 's/^# //' || echo "$filename")
        echo "- **${filename}**: ${title}" >>"$summary_file"
      done

      log_success "Created summary for ${category}"
    fi
  done
}

# ==================== MAIN SCRIPT ====================

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}AI-Ready Documentation Scraper${NC}"
echo -e "${BLUE}========================================${NC}"
log_info "Domain: $DOMAIN_URL"
log_info "Max Pages: $MAX_PAGES"
log_info "Output Directory: $BASE_OUTPUT_DIR"
echo -e "${BLUE}========================================${NC}\n"

# Create directory structure
mkdir -p "$RAW_DIR" "$PROCESSED_DIR" "$CATEGORIZED_DIR"

# ==================== STEP 1: CRAWL ====================
log_info "Starting Firecrawl job..."

CRAWL_RESPONSE=$(curl -s -X POST "${FIRECRAWL_API_URL}/v2/crawl" \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer ${FIRECRAWL_API_KEY}" \
  -d "{
    \"url\": \"${DOMAIN_URL}\",
    \"limit\": ${MAX_PAGES},
    \"scrapeOptions\": {
      \"formats\": [\"markdown\"],
      \"onlyMainContent\": true,
      \"waitFor\": 1000
    }
  }")

JOB_ID=$(echo "$CRAWL_RESPONSE" | grep -o '"id":"[^"]*' | cut -d'"' -f4)

if [ -z "$JOB_ID" ]; then
  log_error "Failed to start crawl job"
  echo "$CRAWL_RESPONSE"
  exit 1
fi

log_success "Crawl job started with ID: $JOB_ID"

# Monitor progress
while true; do
  STATUS_RESPONSE=$(curl -s -X GET "${FIRECRAWL_API_URL}/v2/crawl/${JOB_ID}" \
    -H "Authorization: Bearer ${FIRECRAWL_API_KEY}")

  STATUS=$(echo "$STATUS_RESPONSE" | grep -o '"status":"[^"]*' | cut -d'"' -f4)
  COMPLETED=$(echo "$STATUS_RESPONSE" | grep -o '"completed":[0-9]*' | cut -d':' -f2)
  TOTAL=$(echo "$STATUS_RESPONSE" | grep -o '"total":[0-9]*' | cut -d':' -f2)

  log_info "Status: $STATUS | Progress: $COMPLETED/$TOTAL pages"

  if [ "$STATUS" = "completed" ]; then
    log_success "Crawl completed!"
    break
  elif [ "$STATUS" = "failed" ]; then
    log_error "Crawl failed!"
    exit 1
  fi

  sleep $POLL_INTERVAL
done

# ==================== STEP 2: DOWNLOAD & PROCESS ====================
log_info "Fetching and processing results..."

SKIP=0
PAGE_COUNT=0

while true; do
  RESULTS=$(curl -s -X GET "${FIRECRAWL_API_URL}/v2/crawl/${JOB_ID}?skip=${SKIP}" \
    -H "Authorization: Bearer ${FIRECRAWL_API_KEY}")

  NEXT_URL=$(echo "$RESULTS" | grep -o '"next":"[^"]*' | cut -d'"' -f4)

  # Process each page
  echo "$RESULTS" | jq -r '.data[] | @json' | while read -r page; do
    URL=$(echo "$page" | jq -r '.metadata.sourceURL // .metadata.url')
    MARKDOWN=$(echo "$page" | jq -r '.markdown // ""')

    if [ -n "$MARKDOWN" ] && [ "$MARKDOWN" != "null" ]; then
      # Save raw markdown
      FILENAME=$(sanitize_filename "$URL")
      RAW_FILE="${RAW_DIR}/${FILENAME}.md"
      echo "$MARKDOWN" >"$RAW_FILE"

      # Extract metadata
      TITLE=$(extract_title "$MARKDOWN")
      CATEGORY=$(categorize_url "$URL")
      KEYWORDS=$(extract_keywords "$MARKDOWN" "$TITLE")

      # Create processed version with metadata
      PROCESSED_FILE="${PROCESSED_DIR}/${FILENAME}.md"
      cp "$RAW_FILE" "$PROCESSED_FILE"
      add_metadata_header "$PROCESSED_FILE" "$URL" "$CATEGORY" "$TITLE" "$KEYWORDS"

      # Categorize into folders
      CATEGORY_DIR="${CATEGORIZED_DIR}/${CATEGORY}"
      mkdir -p "$CATEGORY_DIR"
      cp "$PROCESSED_FILE" "${CATEGORY_DIR}/${FILENAME}.md"

      PAGE_COUNT=$((PAGE_COUNT + 1))
      log_success "Processed: ${TITLE} → ${CATEGORY}"
    fi
  done

  if [ -z "$NEXT_URL" ] || [ "$NEXT_URL" = "null" ]; then
    break
  fi

  SKIP=$((SKIP + 10))
done

# ==================== STEP 3: POST-PROCESSING ====================
log_info "Creating organizational files..."

# Create combined file per category
for category_dir in "$CATEGORIZED_DIR"/*; do
  if [ -d "$category_dir" ]; then
    category="$(basename "$category_dir")"
    combined_file="${category_dir}/_COMBINED_${category}.md"
    cat "${category_dir}"/*.md >"$combined_file" 2>/dev/null || true
    log_success "Combined ${category} documents"
  fi
done

# Create master combined file
ALL_COMBINED="${BASE_OUTPUT_DIR}/ALL_DOCS_COMBINED.md"
cat "${PROCESSED_DIR}"/*.md >"$ALL_COMBINED" 2>/dev/null || true

# Create index and summaries
create_index "$BASE_OUTPUT_DIR"
create_category_summaries "$CATEGORIZED_DIR"

# ==================== STEP 4: STATISTICS ====================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}Processing Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
log_success "Total pages scraped: $PAGE_COUNT"
log_success "Raw files: ${RAW_DIR}"
log_success "Processed files: ${PROCESSED_DIR}"
log_success "Categorized files: ${CATEGORIZED_DIR}"
log_success "Master index: ${BASE_OUTPUT_DIR}/INDEX.md"
log_success "Combined file: ${ALL_COMBINED}"

echo ""
log_info "Directory structure:"
find "$CATEGORIZED_DIR" -type d | while read -r dir; do
  count=$(find "$dir" -maxdepth 1 -name "*.md" ! -name "_*" 2>/dev/null | wc -l)
  if [ $count -gt 0 ]; then
    echo "  📁 $(basename "$dir"): $count documents"
  fi
done

echo -e "${GREEN}========================================${NC}"

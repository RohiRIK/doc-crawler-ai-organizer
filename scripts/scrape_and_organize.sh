#!/bin/bash

# Advanced Firecrawl Documentation Scraper with AI-Ready Post-Processing
# Usage: ./scrape_and_organize.sh <domain_url> [max_pages] [output_dir]

set -e

# ==================== DEPENDENCY CHECKS ====================
check_dependencies() {
  local missing=0
  for cmd in curl jq; do
    if ! command -v "$cmd" &> /dev/null; then
      log_error "Dependency missing: $cmd is not installed."
      missing=1
    fi
  done
  if [ $missing -eq 1 ]; then
    log_error "Please install missing dependencies and try again."
    exit 1
  fi
}


# ==================== CONFIGURATION ====================

source "$(dirname "$0")/config.sh"

DOMAIN_URL="${1:-https://docs.n8n.io}"
MAX_PAGES="${2:-1000}"
BASE_OUTPUT_DIR="${3:-./ai_knowledge_base}"
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

source "$(dirname "$0")/functions.sh"

# ==================== MAIN SCRIPT ====================

check_dependencies


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

if [ -z "$CRAWL_RESPONSE" ]; then
  log_error "Failed to get a response from the Firecrawl API. Please check if the API is running and accessible."
  exit 1
fi


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

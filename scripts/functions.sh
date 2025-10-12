#!/bin/bash

# Helper functions for the Advanced Firecrawl Documentation Scraper

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

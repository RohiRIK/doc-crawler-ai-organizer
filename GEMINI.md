# GEMINI.md

## Project Overview

This project is an AI-Ready Documentation Scraper. Its primary purpose is to crawl and scrape documentation websites, process the content into a structured format, and enrich it with metadata to make it suitable for consumption by AI agents, such as those in multi-agent systems.

The core of the project is a sophisticated bash script, `scrape_and_organize.sh`, which orchestrates the entire process. It uses the Firecrawl API to perform the web scraping and then applies a series of processing and organization steps to the scraped content.

The main technologies used are:
*   **Bash:** For the main scripting and orchestration.
*   **Firecrawl:** For web scraping.
*   **curl:** For making API requests to Firecrawl.
*   **jq:** For parsing JSON responses from the API.

The architecture is based on a pipeline of operations:
1.  **Crawl:** Initiate a crawl job on a target domain.
2.  **Download & Process:** Fetch the scraped content, add metadata, and save it.
3.  **Categorize:** Organize the processed files into a logical directory structure based on URL patterns.
4.  **Post-process:** Generate summary files, indexes, and combined markdown files for easy use by AI models.

## Building and Running

There is no formal "build" process for this project, as it is a shell script.

### Prerequisites

*   **bash:** The script is designed to be run in a bash environment.
*   **curl:** Used for making API calls.
*   **jq:** Used for parsing JSON.
*   **Firecrawl API:** A running instance of the Firecrawl API is required. The script is configured to connect to `http://localhost:3002` by default.

### Running the Scraper

To run the scraper, execute the `scrape_and_organize.sh` script with the target domain as an argument:

```bash
./scripts/scrape_and_organize.sh <domain_url> [max_pages] [output_dir]
```

*   `<domain_url>`: **(Required)** The URL of the documentation website to scrape (e.g., `https://docs.n8n.io`).
*   `[max_pages]`: (Optional) The maximum number of pages to crawl. Defaults to `1000`.
*   `[output_dir]`: (Optional) The directory to save the output files. Defaults to `./docs_output`.

### Environment Variables

The script can be configured using the following environment variables:

*   `FIRECRAWL_API_URL`: The URL of the Firecrawl API. Defaults to `http://localhost:3002`.
*   `FIRECRAWL_API_KEY`: Your Firecrawl API key. Defaults to `your-api-key`.

## Development Conventions

*   **Shell Scripting:** The project follows standard shell scripting practices.
*   **Error Handling:** The script uses `set -e` to exit immediately if a command fails.
*   **Logging:** The script includes logging functions (`log_info`, `log_success`, `log_warning`, `log_error`) to provide clear output during execution.
*   **Categorization:** The `categorize_url` function in the script contains the logic for categorizing documents. This can be customized to suit different documentation structures.
*   **Metadata:** The `add_metadata_header` function defines the metadata that is added to each document. This can be extended with additional fields as needed.

# AI-Ready Documentation Scraper

## Project Overview

This project is an AI-Ready Documentation Scraper. Its primary purpose is to crawl and scrape documentation websites, process the content into a structured format, and enrich it with metadata to make it suitable for consumption by AI agents, such as those in multi-agent systems.

The core of the project is a sophisticated bash script, `scrape_and_organize.sh`, which orchestrates the entire process. It uses the Firecrawl API to perform the web scraping and then applies a series of processing and organization steps to the scraped content.

The main technologies used are:
*   **Bash:** For the main scripting and orchestration.
*   **Firecrawl:** For web scraping.
*   **curl:** For making API requests to Firecrawl.
*   **jq:** For parsing JSON responses from the API.
*   **Docker:** For containerizing the application and its dependencies.

## Features

*   **Intelligent Categorization:** Automatically categorizes scraped documents based on URL patterns.
*   **Metadata Generation:** Enriches documents with metadata such as title, source URL, category, and tags.
*   **AI-Optimized Structure:** Organizes content in a way that is easy for AI agents to parse and understand.
*   **Modular and Configurable:** The script is broken down into functions and uses a separate configuration file for easy customization.
*   **Containerized:** A Dockerfile is included for easy deployment and portability.

## Getting Started

### Prerequisites

*   **bash:** The script is designed to be run in a bash environment.
*   **curl:** Used for making API calls.
*   **jq:** Used for parsing JSON.
*   **Docker:** (Optional) For running the scraper in a container.
*   **Firecrawl API:** A running instance of the Firecrawl API is required.

### Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/RohiRIK/doc-crawler-ai-organizer.git
    cd doc-crawler-ai-organizer
    ```

2.  Configure the script:
    *   Copy the example configuration file:
        ```bash
        cp scripts/config.sh.example scripts/config.sh
        ```
    *   Edit `scripts/config.sh` and set your `FIRECRAWL_API_KEY` and, if necessary, the `FIRECRAWL_API_URL`.

### Running the Scraper

There are two ways to run the scraper:

**1. Directly with Bash:**

```bash
./scripts/scrape_and_organize.sh <domain_url> [max_pages] [output_dir]
```

*   `<domain_url>`: **(Required)** The URL of the documentation website to scrape (e.g., `https://docs.n8n.io`).
*   `[max_pages]`: (Optional) The maximum number of pages to crawl. Defaults to `1000`.
*   `[output_dir]`: (Optional) The directory to save the output files. Defaults to `./ai_knowledge_base`.

**2. Using Docker:**

*   Build the Docker image:
    ```bash
    docker build -t doc-scraper .
    ```

*   Run the scraper in a container:
    ```bash
    docker run -v $(pwd)/ai_knowledge_base:/app/ai_knowledge_base doc-scraper <domain_url> [max_pages]
    ```
    *   The `-v $(pwd)/ai_knowledge_base:/app/ai_knowledge_base` flag mounts the output directory on your host machine so you can access the scraped files.

## Development Conventions

*   **Shell Scripting:** The project follows standard shell scripting practices.
*   **Modularity:** The main script `scrape_and_organize.sh` sources helper functions from `scripts/functions.sh` and configuration from `scripts/config.sh`.
*   **Error Handling:** The script uses `set -e` to exit immediately if a command fails. It also includes dependency checks and error handling for API calls.
*   **Logging:** The script includes logging functions (`log_info`, `log_success`, `log_warning`, `log_error`) to provide clear output during execution.

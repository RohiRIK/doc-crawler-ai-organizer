# Use a lightweight base image
FROM alpine:latest

# Install dependencies
RUN apk --no-cache add bash curl jq

# Set the working directory
WORKDIR /app

# Copy the scripts directory into the container
COPY scripts/ .

# Make the main script executable
RUN chmod +x scrape_and_organize.sh

# Set the entrypoint
ENTRYPOINT ["./scrape_and_organize.sh"]

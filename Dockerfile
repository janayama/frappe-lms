FROM frappe/bench:latest

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/bin/bash

# Install additional system dependencies
USER root
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    default-mysql-client \
    redis-server \
    && rm -rf /var/lib/apt/lists/*

# Switch back to frappe user
USER frappe
WORKDIR /home/frappe

# Copy the initialization script
COPY entrypoint.sh /home/frappe/entrypoint.sh

# Make the script executable
USER root
RUN chmod +x /home/frappe/entrypoint.sh
USER frappe

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=120s --retries=3 \
    CMD curl -f http://localhost:8000/api/method/ping || exit 1

# Use entrypoint script
ENTRYPOINT ["/home/frappe/entrypoint.sh"] 
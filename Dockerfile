FROM frappe/bench:latest

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/bin/bash

# Install system dependencies for Railway deployment
USER root
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    default-mysql-client \
    redis-server \
    procps \
    && pip3 install --no-cache-dir gunicorn \
    && rm -rf /var/lib/apt/lists/*

# Switch back to frappe user
USER frappe
WORKDIR /home/frappe

# Copy the initialization script and health check
COPY entrypoint.sh /home/frappe/entrypoint.sh
COPY healthcheck.sh /home/frappe/healthcheck.sh

# Make the scripts executable
USER root
RUN chmod +x /home/frappe/entrypoint.sh /home/frappe/healthcheck.sh
USER frappe

# Expose port
EXPOSE 8000

# Health check - Railway optimized
HEALTHCHECK --interval=60s --timeout=30s --start-period=180s --retries=3 \
    CMD /home/frappe/healthcheck.sh

# Use entrypoint script
ENTRYPOINT ["/home/frappe/entrypoint.sh"] 
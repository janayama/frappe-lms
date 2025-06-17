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
COPY entrypoint.sh /home/frappe/frappe-bench/
COPY healthcheck.sh /home/frappe/frappe-bench/
COPY init_frappe.py /home/frappe/frappe-bench/
COPY static_server.py /home/frappe/frappe-bench/

# Make the scripts executable
RUN chmod +x /home/frappe/frappe-bench/entrypoint.sh && \
    chmod +x /home/frappe/frappe-bench/healthcheck.sh && \
    chmod +x /home/frappe/frappe-bench/init_frappe.py

# Set the working directory
WORKDIR /home/frappe/frappe-bench

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=300s --retries=3 \
    CMD ./healthcheck.sh

# Set entrypoint
ENTRYPOINT ["./entrypoint.sh"] 
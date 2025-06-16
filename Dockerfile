FROM frappe/frappe_docker:latest

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV DEBIAN_FRONTEND=noninteractive

# Install additional system dependencies
USER root
RUN apt-get update && apt-get install -y \
    wget \
    curl \
    git \
    default-mysql-client \
    && rm -rf /var/lib/apt/lists/*

# Switch back to frappe user
USER frappe
WORKDIR /home/frappe/frappe-bench

# Copy apps.json for LMS
COPY apps.json /tmp/apps.json

# Get LMS app
RUN bench get-app lms https://github.com/frappe/lms.git --branch develop

# Create common site config template
RUN mkdir -p sites && \
    echo '{}' > sites/common_site_config.json

# Build assets
RUN bench build --app lms

# Create entrypoint script
COPY entrypoint.sh /home/frappe/entrypoint.sh
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
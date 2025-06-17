FROM frappe/bench:latest

# Switch to root for installation
USER root

# Install system dependencies and Python packages in one layer
RUN apt-get update && apt-get install -y \
    git \
    curl \
    redis-server \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --no-cache-dir gunicorn

# Switch back to frappe user
USER frappe

# Set working directory
WORKDIR /home/frappe

# Copy application files
COPY --chown=frappe:frappe entrypoint.sh ./
COPY --chown=frappe:frappe static_server.py ./

# Make entrypoint executable
RUN chmod +x entrypoint.sh

# Expose port
EXPOSE 8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/health || exit 1

# Start the application
CMD ["./entrypoint.sh"] 
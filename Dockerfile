FROM frappe/bench:latest

# Switch to root to install system dependencies
USER root

# Install redis-server for caching. Gunicorn is already included in the base image.
RUN apt-get update && apt-get install -y redis-server --no-install-recommends \
    && rm -rf /var/lib/apt/lists/*

# Switch back to frappe user
USER frappe

# Set working directory
WORKDIR /home/frappe

# Copy the initialization script
COPY --chown=frappe:frappe init-railway.sh ./
RUN chmod +x ./init-railway.sh

# Expose the port Frappe will run on
EXPOSE 8000

# Health check will point to Gunicorn. Increased start-period for first setup.
HEALTHCHECK --interval=30s --timeout=10s --start-period=600s --retries=5 \
    CMD curl -f http://localhost:8000/api/method/ping || exit 1

# Run the initialization script which will end by executing gunicorn
CMD ["./init-railway.sh"] 
FROM frappe/bench:latest

# Set working directory
WORKDIR /home/frappe

# Copy the initialization script
COPY --chown=frappe:frappe init-railway.sh /home/frappe/
RUN chmod +x /home/frappe/init-railway.sh

# Expose port
EXPOSE 8000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=300s --retries=3 \
    CMD curl -f http://localhost:8000 || exit 1

# Run the initialization script
CMD ["./init-railway.sh"] 
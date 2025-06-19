FROM frappe/bench:latest as frappe-lms-app

# Frappe's bench image is based on Debian. We need to install NodeJS and Yarn.
USER root
RUN apt-get update && \
    apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g yarn && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Copy scripts to a standard executable path and make them executable
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
COPY run_migrate.py /usr/local/bin/run_migrate.py
RUN chmod +x /usr/local/bin/run_migrate.py

USER frappe

# Set the working directory to the user's home
WORKDIR /home/frappe

# Initialize a new bench. This creates the directory structure and installs Frappe framework.
# We skip redis config generation because we will provide it via environment variables.
RUN bench init --skip-redis-config-generation frappe-bench

# Set the working directory to the newly created bench
WORKDIR /home/frappe/frappe-bench

# Switch to root to copy app files directly into the bench directory.
# This avoids all 'mv' permission errors.
USER root
COPY --chown=frappe:frappe ./lms ./apps/lms
COPY --chown=frappe:frappe ./frontend ./apps/lms/frontend
COPY --chown=frappe:frappe ./pyproject.toml ./apps/lms/pyproject.toml
RUN touch ./apps/lms/README.md && chown frappe:frappe ./apps/lms/README.md

# Switch back to the frappe user for all subsequent build steps.
USER frappe

# Install Python dependencies
RUN bench setup requirements --python && \
    pip install -e ./apps/lms

# Install Node.js dependencies
RUN bench setup requirements --node

# Build the frontend assets
RUN PYTHONPATH=$(pwd)/apps:$PYTHONPATH bench build --app lms

# Final setup for the container
EXPOSE 8000
# Run the entrypoint as root to have permission to create site configs.
USER root
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["-"] 
FROM frappe/bench:latest as frappe-lms-app

# Frappe's bench image is based on Debian. We need to install NodeJS and Yarn.
USER root
RUN apt-get update && \
    apt-get install -y curl && \
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    npm install -g yarn && \
    apt-get install -y --no-install-recommends mariadb-client redis-tools vim-tiny && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user 'frappe'
RUN useradd -m -s /bin/bash frappe

# Copy scripts to a standard executable path and make them executable
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

# --- Switch to non-root user for the rest of the build and for runtime ---
USER frappe
WORKDIR /home/frappe

# Set path for python packages and the bench environment
ENV PATH="/home/frappe/.local/bin:/home/frappe/frappe-bench/env/bin:$PATH"

# Install bench and initialize the bench directory in a single layer
RUN pip3 install frappe-bench && \
    bench init --skip-redis-config-generation --frappe-branch version-15 frappe-bench

# Set the working directory to the bench directory
WORKDIR /home/frappe/frappe-bench

# Install the custom 'lms' app and build assets
COPY --chown=frappe:frappe . /home/frappe/frappe-bench/apps/lms
RUN bench get-app lms && \
    bench build

# Final setup for the container
EXPOSE 8000
# Run the entrypoint as the application user.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["-"] 
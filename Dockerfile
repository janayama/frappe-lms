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

# Copy the entrypoint script and make it executable
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER frappe

# Set the working directory to the user's home
WORKDIR /home/frappe

# Initialize a new bench. This creates the directory structure and installs Frappe framework.
# We skip redis config generation because we will provide it via environment variables.
RUN bench init --skip-redis-config-generation frappe-bench

# Set the working directory to the newly created bench
WORKDIR /home/frappe/frappe-bench

# Copy your local app code into a temporary directory inside the container
COPY --chown=frappe:frappe . /app_source

# Move the 'lms' python app and its 'frontend' code into the bench's apps directory.
# This makes your app available to the bench.
RUN mv /app_source/lms ./apps/
RUN mv /app_source/frontend ./apps/lms/frontend
RUN mv /app_source/pyproject.toml ./apps/lms/

# Install the LMS app's Python dependencies from its pyproject.toml
RUN bench setup requirements --python && \
    pip install -e ./apps/lms

# Install the LMS app's Node.js dependencies and build the frontend assets.
# `bench build` is the standard Frappe command to compile and place assets correctly.
RUN bench setup requirements --node && \
    bench build --app lms

# Expose the port Frappe runs on
EXPOSE 8000

# Set the entrypoint to our custom script
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["-"] 
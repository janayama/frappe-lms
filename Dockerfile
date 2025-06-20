# Use a specific version of the official Python image for reproducibility
# We lock this to Bullseye to ensure compatibility with wkhtmltopdf
FROM python:3.11-slim-bullseye

# Set environment variables to prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV BENCH_DEVELOPER=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/home/frappe/.local/bin:$PATH"

# Install all system dependencies in a single, atomic RUN command.
# This includes:
# - Common utilities (git, curl, etc.)
# - MariaDB client and dev headers for the python connector
# - A complete, modern Node.js environment using the official NodeSource script
# - A full set of dependencies for wkhtmltopdf to prevent recurring build failures
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    cron \
    git \
    libmariadb-dev \
    pkg-config \
    redis-tools \
    vim-tiny \
    # Full dependency list for wkhtmltopdf on Debian Bullseye
    xvfb \
    libfontconfig1 \
    fontconfig \
    libxrender1 \
    libxext6 \
    xfonts-base \
    xfonts-75dpi \
    libssl1.1 && \
    # Use the official NodeSource script to install Node.js 18
    curl -fsSL https://deb.nodesource.com/setup_18.x | bash - && \
    apt-get install -y --no-install-recommends nodejs && \
    # Install yarn globally via npm
    npm install -g yarn && \
    # Download and install wkhtmltopdf in the same layer
    curl -L https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.bullseye_amd64.deb -o wkhtmltopdf.deb && \
    apt-get install -y ./wkhtmltopdf.deb && \
    # Clean up downloaded files and apt cache
    rm wkhtmltopdf.deb && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user 'frappe' to run the application
RUN useradd -ms /bin/bash frappe
USER frappe
WORKDIR /home/frappe

# Install frappe-bench using pip
RUN pip install --no-cache-dir frappe-bench

# Initialize the Frappe bench environment.
# This is the standard procedure that creates the virtualenv and installs Frappe.
# We use the --frappe-branch flag to ensure we get a compatible version.
RUN bench init --skip-redis-config-generation --frappe-branch version-15 frappe-bench

# Set the working directory to the newly created bench
WORKDIR /home/frappe/frappe-bench

# Copy the local 'lms' app source code into the apps directory of the bench
COPY --chown=frappe:frappe . /home/frappe/frappe-bench/apps/lms

# Initialize a git repository in the app directory, as bench expects this.
# This is necessary because the COPY command does not include the .git directory.
RUN cd /home/frappe/frappe-bench/apps/lms && \
    git config --global user.name "Docker Build" && \
    git config --global user.email "docker@example.com" && \
    git init && \
    git add . && \
    git commit -m "Initial commit for build"

# Install the 'lms' app's dependencies and build its assets.
# We do NOT use `get-app` because the app is already local.
# `setup requirements` installs python/js deps, and `build` creates assets.
RUN bench setup requirements && \
    bench build

# Copy the runtime entrypoint script and make it executable
COPY --chown=frappe:frappe entrypoint.sh /home/frappe/entrypoint.sh
RUN chmod +x /home/frappe/entrypoint.sh

# Expose the port Frappe runs on
EXPOSE 8000

# Set the entrypoint to our script. The application will be started by this script.
ENTRYPOINT ["/home/frappe/entrypoint.sh"] 
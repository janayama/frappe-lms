# Use a specific version of the official Python image for reproducibility
# We lock this to Bullseye to ensure compatibility with wkhtmltopdf
FROM python:3.11-slim-bullseye

# Set environment variables to prevent interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive
ENV BENCH_DEVELOPER=1
ENV PYTHONUNBUFFERED=1
ENV PATH="/home/frappe/.local/bin:$PATH"

# Install system dependencies required by Frappe and LMS
# This includes git, curl, mariadb client and dev headers, nodejs, yarn, and wkhtmltopdf dependencies
RUN apt-get update && \
    apt-get install -y \
    curl \
    git \
    libmariadb-dev \
    nodejs \
    npm \
    pkg-config \
    redis-tools \
    vim-tiny \
    xvfb \
    fontconfig \
    xfonts-75dpi \
    libssl1.1 \
    && npm install -g yarn \
    && rm -rf /var/lib/apt/lists/*

# Install wkhtmltopdf for PDF generation, a crucial Frappe dependency
# We use the version for Bullseye to match our base image
RUN curl -L https://github.com/wkhtmltopdf/packaging/releases/download/0.12.6.1-2/wkhtmltox_0.12.6.1-2.bullseye_amd64.deb -o wkhtmltopdf.deb && \
    apt-get install -y ./wkhtmltopdf.deb && \
    rm wkhtmltopdf.deb

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

# Install the 'lms' app into the bench.
# This command handles dependencies and site registration.
RUN bench get-app lms && \
    bench setup requirements && \
    bench build

# Copy the runtime entrypoint script and make it executable
COPY --chown=frappe:frappe entrypoint.sh /home/frappe/entrypoint.sh
RUN chmod +x /home/frappe/entrypoint.sh

# Expose the port Frappe runs on
EXPOSE 8000

# Set the entrypoint to our script. The application will be started by this script.
ENTRYPOINT ["/home/frappe/entrypoint.sh"] 
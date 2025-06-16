# Frappe LMS Railway Deployment Guide

This guide will help you deploy Frappe LMS on Railway using Docker with MySQL.

## Quick Setup (If you already have MySQL on Railway)

If you already have a MySQL database service on Railway, you only need to set 2 environment variables:

1. `SITE_NAME=your-app-name.railway.app` (replace with your actual Railway domain)
2. `ADMIN_PASSWORD=your-secure-password`

The MySQL connection variables are automatically available from your Railway MySQL service.

## Full Setup Instructions

### Step 1: Prepare Your Repository

1. Fork or clone the Frappe LMS repository
2. Add the Railway deployment files to your repository (these should already be present)

### Step 2: Create Railway Project

1. Go to [Railway](https://railway.app)
2. Click "New Project"
3. Choose "Deploy from GitHub repo"
4. Select your Frappe LMS repository

### Step 3: Add MySQL Database

1. In your Railway project, click "New Service"
2. Choose "Database" → "Add MySQL"
3. Wait for the database to be provisioned

### Step 4: Configure Environment Variables

Set these environment variables in your Railway project:

**Required:**
- `SITE_NAME` - Your Railway app domain (e.g., `your-app.railway.app`)
- `ADMIN_PASSWORD` - Strong password for the Administrator account

**Optional (MySQL variables are auto-configured):**
- `MYSQLHOST` - Database host (auto-set by Railway)
- `MYSQLPORT` | Database port (auto-set by Railway)
- `MYSQLDATABASE` | Database name (auto-set by Railway)
- `MYSQLUSER` | Database username (auto-set by Railway)
- `MYSQLPASSWORD` | Database password (auto-set by Railway)

### Step 5: Deploy

1. Railway will automatically start building and deploying your application
2. The initial deployment may take 5-10 minutes as it:
   - Builds the Docker image
   - Initializes the Frappe bench
   - Downloads and installs the LMS app
   - Creates the site and database
   - Starts the application

### Step 6: Access Your LMS

1. Once deployed, click on your service in Railway
2. Go to the "Settings" tab and find your public URL
3. Visit your LMS at that URL
4. Login with:
   - **Username:** Administrator
   - **Password:** The password you set in `ADMIN_PASSWORD`

## Health Checks

The application includes comprehensive health checks:
- **Start Period:** 5 minutes (allows time for initial setup)
- **Check Interval:** 60 seconds
- **Timeout:** 30 seconds per check
- **Retries:** 5 attempts before marking as unhealthy

The health check endpoint is `/api/method/ping` which verifies that the Frappe application is running and responding.

## Troubleshooting

### Deployment Takes Long Time
- Initial deployment can take 5-10 minutes
- Check the build logs in Railway dashboard
- Health checks allow 5 minutes for startup

### Database Connection Issues
- Ensure MySQL service is running in Railway
- Check that environment variables are properly set
- Verify database credentials in Railway dashboard

### Application Won't Start
- Check the application logs in Railway
- Ensure `SITE_NAME` matches your Railway domain
- Verify `ADMIN_PASSWORD` is set

### Health Check Failures
- Health checks now allow 5 minutes for startup
- Check if the application is responding at `/api/method/ping`
- Review application logs for startup errors

## Architecture

- **Base Image:** `frappe/bench:latest` (official Frappe Docker image)
- **Database:** Railway MySQL service
- **Redis:** Built into the container (not external service)
- **Web Server:** Gunicorn (production-ready WSGI server)
- **Application:** Frappe LMS with automatic site creation

## Environment Variables Reference

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `SITE_NAME` | Your Railway app domain | `lms.localhost` | Yes |
| `ADMIN_PASSWORD` | Administrator password | `admin` | Yes |
| `MYSQLHOST` | Database host | Auto-set by Railway | No |
| `MYSQLPORT` | Database port | Auto-set by Railway | No |
| `MYSQLDATABASE` | Database name | Auto-set by Railway | No |
| `MYSQLUSER` | Database username | Auto-set by Railway | No |
| `MYSQLPASSWORD` | Database password | Auto-set by Railway | No |
| `PORT` | Application port | `8000` | No |

## Support

If you encounter issues:
1. Check Railway deployment logs
2. Verify environment variables are set correctly
3. Ensure MySQL service is running
4. Review the troubleshooting section above 
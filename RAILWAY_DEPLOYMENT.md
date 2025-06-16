# Frappe LMS Railway Deployment Guide

This guide will help you deploy Frappe LMS on Railway with MySQL database.

## Prerequisites

- Railway account connected to your GitHub account
- This repository forked to your GitHub account

## Step 1: Set Up Railway Project

1. **Create a new Railway project**
   - Go to [Railway Dashboard](https://railway.app/dashboard)
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose your forked Frappe LMS repository

2. **Use Existing MySQL Database (Recommended)**
   - If you already have a MySQL database in your Railway project, you can use it
   - The Frappe LMS service will automatically connect using the existing MySQL environment variables
   - No additional database setup required!

3. **Add MySQL Database (If you don't have one)**
   - In your Railway project dashboard
   - Click "+ New" 
   - Select "Database" → "MySQL"
   - Railway will automatically provision a MySQL instance

## Step 2: Configure Environment Variables

In your Frappe LMS service settings, add these environment variables:

### Database Variables (Automatic if using existing MySQL)
If you're using an existing MySQL database in the same Railway project, these variables are automatically available and **you don't need to set them manually**:
- `MYSQLHOST` - Automatically provided by Railway
- `MYSQLPORT` - Automatically provided by Railway  
- `MYSQLDATABASE` - Automatically provided by Railway
- `MYSQLUSER` - Automatically provided by Railway
- `MYSQLPASSWORD` - Automatically provided by Railway

### Manual Database Variables (Only if using external database)
```
MYSQLHOST=your-external-mysql-host
MYSQLPORT=3306
MYSQLDATABASE=your-database-name
MYSQLUSER=your-mysql-user
MYSQLPASSWORD=your-mysql-password
```

### Required Application Variables
```
SITE_NAME=your-app-name.railway.app
ADMIN_PASSWORD=your-secure-admin-password
PORT=8000
```

### Optional Variables
```
ENCRYPTION_KEY=your-32-character-encryption-key
SECRET_KEY=your-secret-key
```

## Step 3: Deploy

1. **Push changes to GitHub**
   - Commit all changes to your repository
   - Push to the main/master branch
   - Railway will automatically trigger deployment

2. **Monitor deployment**
   - Check Railway deployment logs
   - Initial deployment may take 10-15 minutes
   - Wait for "Starting Frappe LMS on port 8000..." message

3. **Access your application**
   - Railway will provide a public URL
   - Access your Frappe LMS instance
   - Default login: Administrator / [your-admin-password]

## Step 4: Post-Deployment Configuration

### Set up Custom Domain (Optional)
1. Go to your service settings in Railway
2. Click "Domains" tab
3. Add your custom domain
4. Update DNS records as instructed

### Configure SSL
- Railway automatically provides SSL certificates
- No additional configuration needed

## Troubleshooting

### Common Issues

1. **Database Connection Failed**
   - Verify all MySQL environment variables are set correctly
   - Ensure MySQL service is running before Frappe service

2. **Build Timeout**
   - Increase build timeout in Railway settings
   - Consider using a more powerful Railway plan

3. **Memory Issues**
   - Upgrade to a Railway plan with more memory (minimum 1GB recommended)
   - Monitor resource usage in Railway dashboard

4. **Site Creation Failed**
   - Check deployment logs for specific error messages
   - Verify database credentials and connectivity

### Viewing Logs
```bash
# In Railway dashboard, go to your service and click "Logs"
# Or use Railway CLI:
railway logs
```

### Connecting to Database
```bash
# Use Railway CLI to connect to your MySQL database:
railway connect MySQL
```

## Important Notes

- **Build Time**: Initial deployment takes 10-15 minutes due to Frappe's build process
- **Memory Requirements**: Minimum 1GB RAM recommended
- **Database**: Uses Railway's managed MySQL service
- **Persistence**: Site data is stored in the database and persists across deployments
- **Scaling**: Railway handles scaling automatically based on your plan

## Support

For issues specific to this deployment:
1. Check Railway deployment logs
2. Verify environment variables
3. Ensure MySQL service is healthy
4. Review Frappe LMS documentation

For Railway-specific issues, consult [Railway Documentation](https://docs.railway.app/). 
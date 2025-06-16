# Quick Railway Setup (Existing MySQL Database)

If you already have a MySQL database configured in your Railway project, follow these simplified steps:

## Step 1: Deploy Frappe LMS Service

1. In your Railway project dashboard, click **"+ New"**
2. Select **"GitHub Repo"**
3. Choose your forked Frappe LMS repository
4. Railway will automatically start building and deploying

## Step 2: Configure Required Variables

You only need to set these **2 required variables** in your Frappe LMS service:

```
SITE_NAME=your-app-name.railway.app
ADMIN_PASSWORD=your-secure-admin-password
```

**That's it!** The database variables are automatically available from your existing MySQL service.

## Step 3: Wait for Deployment

- Initial deployment takes 10-15 minutes
- Monitor the logs for "Starting Frappe LMS on port 8000..."
- Railway will provide a public URL once ready

## Step 4: Access Your LMS

- Click on the Railway-provided URL
- Login with:
  - **Username**: Administrator
  - **Password**: [your-admin-password]

## Optional Variables

You can also set these for additional customization:

```
PORT=8000                    # Default port (usually not needed)
ENCRYPTION_KEY=your-key      # For additional security
SECRET_KEY=your-secret       # For additional security
```

## Database Connection

The system automatically uses these variables from your existing MySQL service:
- ✅ `MYSQLHOST` - Auto-detected
- ✅ `MYSQLPORT` - Auto-detected  
- ✅ `MYSQLDATABASE` - Auto-detected
- ✅ `MYSQLUSER` - Auto-detected
- ✅ `MYSQLPASSWORD` - Auto-detected

## Troubleshooting

If deployment fails:

1. **Check MySQL service is running**: Ensure your MySQL database service is healthy
2. **Verify variables**: Make sure `SITE_NAME` and `ADMIN_PASSWORD` are set
3. **Check logs**: Look for database connection errors in the deployment logs
4. **Memory**: Ensure you have at least 1GB RAM allocated

## Next Steps

Once deployed:
- Create your first course
- Set up user accounts
- Configure your learning platform
- Add custom domain (optional)

For detailed configuration options, see [RAILWAY_DEPLOYMENT.md](RAILWAY_DEPLOYMENT.md). 
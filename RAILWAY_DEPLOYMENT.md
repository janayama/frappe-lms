# Frappe LMS Railway Deployment Guide

This guide provides a **Railway-optimized** deployment of Frappe LMS using Docker with MySQL.

## 🚀 Quick Setup (Recommended)

If you already have a MySQL database service on Railway:

1. **Set Environment Variables:**
   ```
   SITE_NAME=your-app-name.railway.app
   ADMIN_PASSWORD=your-secure-password
   ```

2. **Deploy:** The MySQL connection variables are automatically available from Railway's MySQL service.

## 📋 Complete Setup Guide

### Step 1: Prerequisites

- Railway account
- GitHub repository with this code
- MySQL database service on Railway (recommended)

### Step 2: Environment Variables

#### Required Variables:
- `SITE_NAME` - Your Railway app domain (e.g., `myapp.railway.app`)
- `ADMIN_PASSWORD` - Admin password for your LMS site

#### MySQL Variables (Auto-configured from Railway MySQL service):
- `MYSQLHOST` - Database host
- `MYSQLPORT` - Database port (usually 3306)
- `MYSQLDATABASE` - Database name
- `MYSQLUSER` - Database username
- `MYSQLPASSWORD` - Database password

### Step 3: Deploy to Railway

1. **Connect Repository:**
   - Go to Railway dashboard
   - Click "New Project"
   - Select "Deploy from GitHub repo"
   - Choose your repository

2. **Add MySQL Service:**
   - Click "Add Service"
   - Select "Database" → "MySQL"
   - Railway will automatically configure connection variables

3. **Configure Environment Variables:**
   - Go to your app service
   - Navigate to "Variables" tab
   - Add the required variables listed above

4. **Deploy:**
   - Railway will automatically build and deploy your application
   - Wait for the build to complete (usually 5-10 minutes)

### Step 4: Access Your LMS

Once deployed, your LMS will be available at your Railway-provided domain.

**Default Login:**
- Username: `Administrator`
- Password: Your `ADMIN_PASSWORD`

## 🔧 Architecture Details

### Railway-Optimized Design

This deployment is specifically optimized for Railway's architecture:

- **Single Process:** Uses Gunicorn as the main web server
- **Embedded Redis:** Redis runs as a background process within the container
- **Production Configuration:** Optimized for Railway's resource constraints
- **Health Checks:** Simple, reliable health monitoring

### Resource Configuration

- **Workers:** 2 Gunicorn workers (optimized for Railway's CPU limits)
- **Memory:** Redis limited to 256MB
- **Timeouts:** 120s request timeout
- **Connections:** 1000 worker connections

## 🚨 Troubleshooting

### Common Issues

1. **Health Check Failures:**
   - Wait 3-5 minutes for initial startup
   - Check logs for database connection issues
   - Verify MySQL service is running

2. **Database Connection Issues:**
   - Ensure MySQL service is in the same Railway project
   - Check that environment variables are properly set
   - Verify database credentials

3. **Build Failures:**
   - Check Docker build logs
   - Ensure all files are committed to repository
   - Verify Dockerfile syntax

### Logs and Monitoring

- **Application Logs:** Available in Railway dashboard
- **Health Check:** `/api/method/ping` endpoint
- **Database Status:** Check MySQL service logs

## 📈 Performance Optimization

### For Production Use:

1. **Scale Resources:**
   - Upgrade Railway plan for more CPU/memory
   - Consider increasing Gunicorn workers

2. **Database Optimization:**
   - Use Railway's MySQL Pro for better performance
   - Consider connection pooling for high traffic

3. **Caching:**
   - Redis is already configured for caching
   - Consider external Redis for scaling

## 🔒 Security Considerations

1. **Environment Variables:**
   - Never commit sensitive data to repository
   - Use Railway's environment variable management

2. **Database Security:**
   - Use strong passwords
   - Limit database access to Railway network

3. **Application Security:**
   - Keep Frappe/LMS updated
   - Monitor security advisories

## 📚 Additional Resources

- [Railway Documentation](https://docs.railway.app/)
- [Frappe LMS Documentation](https://github.com/frappe/lms)
- [Frappe Framework Documentation](https://frappeframework.com/docs)

## 🆘 Support

If you encounter issues:

1. Check Railway deployment logs
2. Review this documentation
3. Check Frappe LMS GitHub issues
4. Contact Railway support for platform-specific issues

---

**Note:** This deployment is optimized for Railway's architecture and may not work on other platforms without modifications. 
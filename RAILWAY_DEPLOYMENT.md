# Frappe LMS Production Deployment on Railway

This guide provides a **production-ready** deployment of Frappe LMS on Railway using Docker with MySQL.

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
- MySQL database service on Railway (recommended) or external MySQL

### Step 2: Environment Variables

#### Required Variables:
- `SITE_NAME` - Your Railway app domain (e.g., `myapp.railway.app`)
- `ADMIN_PASSWORD` - Secure password for the Administrator account

#### Optional Variables (if using external MySQL):
- `MYSQLHOST` - MySQL host
- `MYSQLPORT` - MySQL port (default: 3306)
- `MYSQLDATABASE` - Database name
- `MYSQLUSER` - MySQL username
- `MYSQLPASSWORD` - MySQL password

### Step 3: Deploy to Railway

1. **Connect Repository:**
   - Go to [Railway](https://railway.app)
   - Create new project from GitHub repository
   - Select this repository

2. **Configure Environment:**
   - Add the required environment variables
   - Ensure MySQL service is running

3. **Deploy:**
   - Railway will automatically build and deploy using the Dockerfile
   - Initial deployment may take 5-10 minutes

## 🏗️ Architecture Overview

### Production Features:
- **Gunicorn WSGI Server** - Production-grade Python web server
- **Multi-worker Configuration** - 4 workers for better performance
- **Redis Caching** - In-memory caching for improved speed
- **Asset Building** - Optimized static assets for production
- **Health Monitoring** - Comprehensive health checks
- **Graceful Error Handling** - Robust error recovery

### Process Management:
- **Web Server:** Gunicorn with 4 workers
- **Background Workers:** Frappe task queue processing
- **Scheduler:** Automated task scheduling
- **Redis:** In-memory data structure store

## 🔧 Configuration Details

### Health Checks:
- **Startup Period:** 5 minutes (300 seconds)
- **Check Interval:** 60 seconds
- **Timeout:** 30 seconds per check
- **Retries:** 5 attempts before marking as unhealthy

### Performance Settings:
- **Workers:** 4 Gunicorn workers
- **Timeout:** 120 seconds per request
- **Max Requests:** 5000 per worker (with jitter)
- **Keep-alive:** 5 seconds

## 🐛 Troubleshooting

### Common Issues:

#### 1. Health Check Failures
**Symptoms:** "Service unavailable" errors, deployment fails
**Solutions:**
- Check logs for startup errors
- Verify database connection
- Ensure environment variables are set correctly
- Wait for full startup (can take 5+ minutes)

#### 2. Database Connection Issues
**Symptoms:** "Can't connect to MySQL server"
**Solutions:**
- Verify MySQL service is running
- Check MYSQL* environment variables
- Ensure database exists and user has permissions

#### 3. Site Creation Failures
**Symptoms:** "Site already exists" or database errors
**Solutions:**
- Check if site directory exists in logs
- Verify database permissions
- Try with a different SITE_NAME

#### 4. Asset Building Errors
**Symptoms:** Missing CSS/JS, styling issues
**Solutions:**
- Check build logs for Node.js errors
- Verify all dependencies are installed
- Clear cache and rebuild

### Debugging Commands:

If you have SSH access to the container:
```bash
# Check application status
ps aux | grep gunicorn

# Check Redis status
redis-cli ping

# Check database connection
mysql -h$MYSQLHOST -u$MYSQLUSER -p$MYSQLPASSWORD -e "SELECT 1"

# Check site status
cd /home/frappe/frappe-bench
bench --site $SITE_NAME doctor

# View logs
tail -f logs/web.log
tail -f logs/worker.log
```

## 📊 Monitoring

### Application Logs:
- **Access Logs:** HTTP request logging
- **Error Logs:** Application error tracking
- **Worker Logs:** Background task processing
- **Scheduler Logs:** Automated task execution

### Health Endpoints:
- `/` - Basic application health
- `/api/method/ping` - API health check
- `/api/method/frappe.ping` - Framework health check

## 🔒 Security Considerations

### Production Security:
- **Developer Mode:** Disabled
- **Debug Mode:** Disabled
- **Server Scripts:** Enabled (configurable)
- **Maintenance Mode:** Disabled
- **Test Mode:** Disabled

### Recommended Settings:
- Use strong `ADMIN_PASSWORD`
- Enable HTTPS (Railway provides this automatically)
- Regular database backups
- Monitor access logs

## 🚀 Performance Optimization

### For High Traffic:
1. **Scale Workers:** Increase Gunicorn workers
2. **Database Optimization:** Use connection pooling
3. **Caching:** Implement Redis clustering
4. **CDN:** Use Railway's edge caching
5. **Monitoring:** Set up application monitoring

### Resource Requirements:
- **Minimum:** 1GB RAM, 1 CPU
- **Recommended:** 2GB RAM, 2 CPU
- **High Traffic:** 4GB+ RAM, 4+ CPU

## 📝 Maintenance

### Regular Tasks:
- **Database Backups:** Use Railway's backup features
- **Log Rotation:** Monitor log file sizes
- **Security Updates:** Keep base image updated
- **Performance Monitoring:** Track response times

### Update Process:
1. Test changes in development
2. Create backup of production data
3. Deploy new version
4. Monitor health checks
5. Rollback if issues occur

## 🆘 Support

### Getting Help:
- **Railway Docs:** [railway.app/docs](https://railway.app/docs)
- **Frappe Community:** [discuss.frappe.io](https://discuss.frappe.io)
- **LMS Documentation:** [github.com/frappe/lms](https://github.com/frappe/lms)

### Reporting Issues:
Include the following information:
- Railway deployment logs
- Environment variables (without sensitive data)
- Error messages
- Steps to reproduce

---

## 🎉 Success!

Once deployed successfully, you should be able to:
- Access your LMS at `https://your-app-name.railway.app`
- Login with Administrator and your `ADMIN_PASSWORD`
- Create courses and manage content
- Monitor performance through Railway dashboard

**Note:** Initial setup may take 5-10 minutes. The application will be available once health checks pass. 
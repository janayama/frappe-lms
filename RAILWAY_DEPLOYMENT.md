# Frappe LMS Deployment on Railway

This guide helps you deploy Frappe LMS on Railway with MySQL.

## ⚡ Quick Deploy (Optimized)

### Prerequisites
- Railway account
- Existing MySQL service in Railway (optional - we can create one)

### 1. Fork and Connect Repository
1. Fork this repository to your GitHub account
2. Connect your Railway account to GitHub
3. Create a new Railway project from your forked repository

### 2. Environment Variables
Set these environment variables in Railway:

**Required:**
```bash
SITE_NAME=your-app-name.railway.app
ADMIN_PASSWORD=your-secure-password
```

**If using existing MySQL service:**
Your MySQL variables should already be available (MYSQLHOST, MYSQLPORT, etc.)

**If creating new MySQL:**
Add a MySQL service to your Railway project - variables will be auto-configured.

### 3. Deploy
Railway will automatically build and deploy. The initial deployment takes ~10-15 minutes due to:
- Cloning Frappe framework and LMS
- Installing Python dependencies
- Setting up the database
- Starting the application

## 🔧 Optimizations Made

### Build Performance
- **Shallow Git Clones**: Uses `--depth 1 --single-branch` for faster cloning
- **Dependency Resolution**: Fixed cairocffi version conflict (LMS requires 1.6.1)
- **Docker Layer Optimization**: Combined RUN commands to reduce layers
- **Efficient Caching**: Better Docker layer caching strategy

### Runtime Performance
- **Simple WSGI Server**: Direct Python server instead of Gunicorn for simpler deployment
- **Fast Health Checks**: Ultra-simple `/health` endpoint that returns immediately
- **Reduced Memory Usage**: Optimized Redis configuration (256MB limit)
- **Threading Support**: ThreadingWSGIServer for better concurrent request handling

### Reliability Improvements
- **Extended Timeouts**: Health check timeout increased to 10 minutes
- **Better Error Handling**: Comprehensive error logging and fallback responses
- **Dependency Compatibility**: Resolved cairocffi version conflicts between Frappe and LMS
- **Simplified Site Setup**: Streamlined site creation process

## 🚀 Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Railway       │    │  Frappe LMS      │    │  MySQL Service  │
│   (Port 8080)   │───▶│  Application     │───▶│  (External)     │
│                 │    │                  │    │                 │
│  Health Check   │    │  - Frappe Core   │    │  - User Data    │
│  /health        │    │  - LMS App       │    │  - System Data  │
│                 │    │  - Redis (local) │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

### Key Components
- **Base Image**: `frappe/bench:latest` (official Frappe Docker image)
- **Web Server**: Python WSGI server with threading support
- **Database**: Railway MySQL service (external)
- **Cache**: Local Redis server (embedded in container)
- **Static Files**: Served through WSGI middleware

## 📊 Performance Expectations

### Build Time
- **First Deploy**: ~10-15 minutes (includes framework installation)
- **Subsequent Deploys**: ~5-8 minutes (cached dependencies)

### Startup Time
- **Cold Start**: ~2-3 minutes (database connection + site initialization)
- **Health Check**: ~30 seconds (simple endpoint)

### Resource Usage
- **Memory**: ~512MB-1GB (depending on usage)
- **CPU**: Low (single-threaded Python application)
- **Storage**: ~2GB (framework + dependencies)

## 🐛 Common Issues & Solutions

### 1. Health Check Timeouts
**Issue**: "1/1 replicas never became healthy!"
**Solution**: The app takes time to start. Health check timeout is set to 10 minutes.

### 2. Dependency Conflicts
**Issue**: "lms 2.31.0 requires cairocffi~=1.6.1, but you have cairocffi 1.5.1"
**Solution**: Uses smart dependency resolution - installs packages without strict dependency checking, then manually resolves cairocffi version compatibility.

**How it works**:
1. Installs Frappe and LMS with `--no-deps` to avoid conflicts
2. Manually installs all required dependencies
3. Tests cairocffi 1.6.1 compatibility with both apps
4. Falls back to cairocffi 1.5.1 if needed
5. Ensures both applications can import successfully

### 3. Database Connection
**Issue**: "Service mariadb is not running"
**Solution**: Using external MySQL instead of local MariaDB.

### 4. Site Not Found
**Issue**: "404 Not Found: your-site.railway.app does not exist"
**Solution**: Proper site registration in Frappe's site system.

## 🔍 Debugging

### Check Application Logs
```bash
# In Railway dashboard, go to your service and check "Logs" tab
# Look for these key messages:
# - "Starting Frappe LMS application..."
# - "Server started successfully"
# - "Frappe initialized successfully"
```

### Test Health Check
```bash
curl https://your-app.railway.app/health
# Should return: OK
```

### Verify Database Connection
Check logs for successful database connection messages.

## 🚀 Production Considerations

### Scaling
- Railway handles horizontal scaling automatically
- For high traffic, consider upgrading to Railway Pro
- Monitor memory usage and upgrade plan if needed

### Security
- Change default admin password immediately
- Use strong database passwords
- Enable HTTPS (Railway provides this automatically)

### Backups
- Set up regular MySQL backups in Railway
- Consider exporting site data periodically

### Monitoring
- Use Railway's built-in monitoring
- Set up alerts for application errors
- Monitor resource usage trends

## 📝 Environment Variables Reference

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `SITE_NAME` | Your Railway app domain | Yes | - |
| `ADMIN_PASSWORD` | Frappe admin password | Yes | - |
| `MYSQLHOST` | MySQL host | Auto | From Railway MySQL |
| `MYSQLPORT` | MySQL port | Auto | From Railway MySQL |
| `MYSQLDATABASE` | MySQL database name | Auto | From Railway MySQL |
| `MYSQLUSER` | MySQL username | Auto | From Railway MySQL |
| `MYSQLPASSWORD` | MySQL password | Auto | From Railway MySQL |
| `PORT` | Application port | Auto | 8080 |

## 📞 Support

If you encounter issues:

1. **Check Railway Logs**: Most issues are visible in the deployment logs
2. **Verify Environment Variables**: Ensure SITE_NAME and ADMIN_PASSWORD are set
3. **Database Connection**: Verify MySQL service is running and accessible
4. **Health Checks**: Wait for the full startup process (up to 10 minutes)

## 🎯 Next Steps

After successful deployment:

1. **Access Admin Panel**: `https://your-app.railway.app/app`
2. **Login**: Use "Administrator" and your ADMIN_PASSWORD
3. **Configure LMS**: Set up courses, users, and content
4. **Customize**: Modify themes and settings as needed

The application is now ready for production use! 🎉 
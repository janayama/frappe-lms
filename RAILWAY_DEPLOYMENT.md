# Frappe LMS on Railway - Simplified Official Setup

This deployment uses the **official Frappe LMS Docker approach** adapted for Railway with MySQL.

## 🚀 Quick Deploy

### Prerequisites
- Railway account
- MySQL service in Railway (or create a new one)

### 1. Environment Variables
Set these in your Railway service:

```bash
# Required
SITE_NAME=your-app-name.railway.app
ADMIN_PASSWORD=your-secure-password

# MySQL (auto-configured if using Railway MySQL service)
MYSQLHOST=mysql.railway.internal
MYSQLPORT=3306
MYSQLDATABASE=railway
MYSQLUSER=root
MYSQLPASSWORD=your-mysql-password
```

### 2. Deploy
Railway will automatically:
1. Build the Docker image using `frappe/bench:latest`
2. Run the initialization script
3. Create the Frappe bench
4. Install the LMS app
5. Create your site
6. Start the application on port 8000

**Initial deployment takes ~5-10 minutes.**

## 🏗️ How It Works

This setup follows the **official Frappe LMS Docker approach**:

1. **Uses Official Image**: `frappe/bench:latest` (same as official docs)
2. **Official Commands**: Uses `bench init`, `bench get-app lms`, `bench new-site`
3. **Standard Setup**: Follows the exact same steps as the official documentation
4. **Railway Adapted**: Modified only for Railway's MySQL service instead of MariaDB containers

## 📋 Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Railway       │    │  Frappe Bench    │    │  MySQL Service  │
│   (Port 8000)   │───▶│  - Frappe Core   │───▶│  (Railway)      │
│                 │    │  - LMS App       │    │                 │
│                 │    │  - Redis (local) │    │                 │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 🔧 What's Different from Official Setup

**Official Setup:**
```bash
# Uses MariaDB container
bench set-mariadb-host mariadb

# Uses Redis container  
bench set-redis-cache-host redis://redis:6379
```

**Railway Setup:**
```bash
# Uses Railway MySQL service
bench set-config -g db_host $MYSQLHOST

# Uses local Redis
bench set-redis-cache-host redis://localhost:6379
```

## ⚡ Performance

- **Build Time**: ~5-10 minutes (official Frappe setup)
- **Startup Time**: ~2-3 minutes (bench initialization)
- **Memory Usage**: ~512MB-1GB
- **Port**: 8000 (standard Frappe port)

## 🐛 Troubleshooting

### Health Check Failures
The app takes 2-3 minutes to fully start. Health check timeout is set to 5 minutes.

### Database Connection Issues
Ensure your MySQL service is running and environment variables are correct:
```bash
MYSQLHOST=mysql.railway.internal
MYSQLPORT=3306
MYSQLDATABASE=railway
MYSQLUSER=root
MYSQLPASSWORD=your-password
```

### Site Access
After deployment, access your LMS at:
- **URL**: `https://your-app-name.railway.app`
- **Admin Panel**: `https://your-app-name.railway.app/app`
- **Username**: `Administrator`
- **Password**: Your `ADMIN_PASSWORD`

## 🎯 Why This Approach is Better

1. **Official**: Uses the exact same setup as Frappe's documentation
2. **Simple**: No complex dependency management
3. **Reliable**: Proven approach used by thousands of Frappe deployments
4. **Maintainable**: Easy to update and debug
5. **Standard**: Follows Frappe best practices

## 📚 Official References

- [Frappe LMS Docker Setup](https://github.com/frappe/lms#docker)
- [Frappe Bench Documentation](https://frappeframework.com/docs/user/en/bench)
- [Railway Deployment Guide](https://docs.railway.app/deploy/dockerfiles)

## 🎉 Next Steps

1. **Access your LMS**: `https://your-app-name.railway.app`
2. **Login as Administrator** with your admin password
3. **Create courses** and start using your LMS!

---

**Note**: This is the **official Frappe LMS setup** adapted for Railway. It's much simpler and more reliable than custom solutions. 
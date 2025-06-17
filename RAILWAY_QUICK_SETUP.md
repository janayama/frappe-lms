# Quick Railway Setup - Frappe LMS

## 🚀 3-Step Setup

### 1. Environment Variables
Set these 2 variables in Railway:
```bash
SITE_NAME=your-app-name.railway.app
ADMIN_PASSWORD=your-secure-password
```

### 2. Deploy
- Railway will automatically detect the Dockerfile
- Build takes ~5-10 minutes
- Uses official `frappe/bench:latest` image

### 3. Access
- **URL**: `https://your-app-name.railway.app`
- **Username**: `Administrator`  
- **Password**: Your `ADMIN_PASSWORD`

## ✅ What This Setup Does

1. **Uses Official Frappe Approach**: Same as `frappe/lms` documentation
2. **Automatic Setup**: Runs `bench init`, `bench get-app lms`, `bench new-site`
3. **Railway MySQL**: Connects to your existing MySQL service
4. **Standard Port**: Runs on port 8000 (Frappe default)

## 🔧 Files Used

- `Dockerfile`: Uses `frappe/bench:latest`
- `init-railway.sh`: Official setup adapted for Railway
- `railway.json`: Railway configuration

## 📝 MySQL Variables (Auto-configured)

If you have Railway MySQL service, these are automatically available:
- `MYSQLHOST`
- `MYSQLPORT` 
- `MYSQLDATABASE`
- `MYSQLUSER`
- `MYSQLPASSWORD`

## ⏱️ Timeline

- **Build**: 5-10 minutes
- **Startup**: 2-3 minutes  
- **Total**: ~8-13 minutes

Much simpler than the previous complex approach! 🎉

## Optional Variables

You can also set these for additional customization:

```
PORT=8000                    # Default port (usually not needed)
ENCRYPTION_KEY=your-key      # For additional security
SECRET_KEY=your-secret       # For additional security
```

## Built-in Services

The container includes:
- ✅ **Redis** - Built-in for caching and queues
- ✅ **MySQL Client** - For database connectivity
- ✅ **Frappe Framework** - Complete LMS platform

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
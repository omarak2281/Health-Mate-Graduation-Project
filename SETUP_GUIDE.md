# External Services Setup Guide

This document provides step-by-step instructions for setting up external services required by Health Mate.

## 📸 Cloudflare Images (Required for Profile Pictures)

Cloudflare Images provides fast, secure image storage and delivery with automatic optimization.

### Step 1: Create Cloudflare Account

1. Go to [cloudflare.com](https://cloudflare.com)
2. Click **Sign Up** (top-right)
3. Enter your email and create a password
4. Verify your email address

### Step 2: Enable Cloudflare Images

1. Log in to Cloudflare Dashboard
2. Click on your account name (top-left)
3. Go to **Images** in the left sidebar
4. Click **Purchase Images** or **Enable Images**
5. Choose a plan:
   - **Free**: 100,000 images, $1/month after
   - **Pro**: Unlimited storage, $5/month
6. Click **Subscribe**

### Step 3: Get API Credentials

1. In Cloudflare Dashboard, go to **Images**
2. Click **API Tokens** tab
3. You'll see your **Account ID** - copy this
4. Click **Create Token**
5. Template: Select **Edit Cloudflare Images**
6. Permissions should include:
   - `Account` → `Cloudflare Images` → `Edit`
7. Click **Continue to Summary**
8. Click **Create Token**
9. **IMPORTANT**: Copy the API token immediately (shown only once)

### Step 4: Add to Health Mate

1. Open `Back-end/.env` file
2. Add your credentials:
```env
CLOUDFLARE_ACCOUNT_ID=your_account_id_here
CLOUDFLARE_API_TOKEN=your_api_token_here
```
3. Save the file
4. Restart the backend server

### Step 5: Test Upload

```bash
# Upload profile picture
curl -X POST "http://localhost:8000/api/v1/upload/profile-picture" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -F "file=@/path/to/image.jpg"
```

Expected response:
```json
{
  "message": "Profile picture uploaded successfully",
  "image_url": "https://imagedelivery.net/...",
  "image_id": "abc123..."
}
```

---

## 🔔 Firebase Cloud Messaging (Optional - For Push Notifications)

Firebase FCM enables push notifications to mobile devices.

### Step 1: Create Firebase Project

1. Go to [firebase.google.com](https://firebase.google.com)
2. Click **Get Started**
3. Click **Add Project**
4. Enter project name: `health-mate`
5. Disable Google Analytics (optional for this project)
6. Click **Create Project**
7. Wait for project creation (~30 seconds)
8. Click **Continue**

### Step 2: Add Android App (for Flutter)

1. In Firebase Console, click the Android icon
2. **Android package name**: `com.healthmate.app` (must match Flutter app)
3. **App nickname**: `Health Mate`
4. Click **Register App**
5. Download `google-services.json`
6. Save to: `Front-end/health_mate_app/android/app/google-services.json`
7. Click **Next** → **Next** → **Continue to Console**

### Step 3: Add iOS App (for Flutter)

1. Click the iOS icon
2. **Bundle ID**: `com.healthmate.app`
3. **App nickname**: `Health Mate`
4. Click **Register App**
5. Download `GoogleService-Info.plist`
6. Save to: `Front-end/health_mate_app/ios/Runner/GoogleService-Info.plist`
7. Click **Next** → **Next** → **Continue to Console**

### Step 4: Get Server Key

1. In Firebase Console, click the gear icon (⚙️) → **Project Settings**
2. Go to **Cloud Messaging** tab
3. Scroll to **Cloud Messaging API (Legacy)**
4. If disabled, click **Enable**
5. Copy the **Server Key**

### Step 5: Get Service Account JSON

1. In Project Settings, go to **Service Accounts** tab
2. Click **Generate New Private Key**
3. Click **Generate Key**
4. Save the JSON file securely
5. Copy the contents

### Step 6: Add to Health Mate

1. Open `Back-end/.env` file
2. Add Firebase credentials:
```env
FIREBASE_PROJECT_ID=health-mate-xxxxx
FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\nMIIE...rest_of_key...\n-----END PRIVATE KEY-----\n
```
3. Escape newlines in the private key (replace actual newlines with `\n`)
4. Save the file

---

## 🗄️ PostgreSQL Database (Required)

### Option 1: Using Docker (Recommended - Already done!)

Docker Compose automatically sets up PostgreSQL. Just run:
```bash
docker-compose up -d
```

### Option 2: Local Installation

#### Windows:
1. Download PostgreSQL from [postgresql.org/download/windows](https://www.postgresql.org/download/windows/)
2. Run the installer
3. Set password: `healthmate123`
4. Keep default port: `5432`
5. Complete installation

#### Create Database:
```bash
psql -U postgres
CREATE USER healthmate WITH PASSWORD 'healthmate123';
CREATE DATABASE healthmate_db OWNER healthmate;
\q
```

---

## 📦 Redis Cache (Required)

### Option 1: Using Docker (Recommended - Already done!)

Docker Compose automatically sets up Redis. Just run:
```bash
docker-compose up -d
```

### Option 2: Local Installation

#### Windows:
1. Download Redis from [github.com/microsoftarchive/redis/releases](https://github.com/microsoftarchive/redis/releases)
2. Download `Redis-x64-xxx.zip`
3. Extract to `C:\Redis`
4. Run `redis-server.exe`

---

## ✅ Quick Verification Checklist

After setup, verify all services:

### 1. Check `.env` file has:
```env
✅ DATABASE_URL=postgresql://...
✅ REDIS_URL=redis://localhost:6379/0
✅ JWT_SECRET=long-random-string
✅ CLOUDFLARE_ACCOUNT_ID=xxx
✅ CLOUDFLARE_API_TOKEN=xxx
✅ FIREBASE_PROJECT_ID=xxx (optional)
✅ FIREBASE_PRIVATE_KEY=xxx (optional)
```

### 2. Start Services:
```bash
# Using Docker
docker-compose up -d

# Check logs
docker-compose logs -f api
```

### 3. Test API:
```bash
# Health check
curl http://localhost:8000/health

# API docs
open http://localhost:8000/docs
```

### 4. Test Image Upload:
1. Register a user via `/api/v1/auth/register`
2. Login via `/api/v1/auth/login` (get JWT token)
3. Upload profile picture via `/api/v1/upload/profile-picture`
4. Check user profile - `profile_image_url` should have Cloudflare URL

---

## 🆘 Troubleshooting

### Cloudflare Upload Fails
**Error**: "Image upload service not configured"
- **Fix**: Add `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` to `.env`

**Error**: "Invalid API token"
- **Fix**: Regenerate token in Cloudflare Dashboard with correct permissions

### Database Connection Fails
**Error**: "could not connect to server"
- **Fix**: Ensure PostgreSQL is running (`docker-compose ps`)
- **Fix**: Check `DATABASE_URL` in `.env` matches your setup

### Redis Connection Fails
**Error**: "Connection refused"
- **Fix**: Ensure Redis is running (`docker-compose ps`)
- **Fix**: Check `REDIS_URL` in `.env`

---

## 📞 Need Help?

- **Cloudflare Docs**: [developers.cloudflare.com/images](https://developers.cloudflare.com/images/)
- **Firebase Docs**: [firebase.google.com/docs/cloud-messaging](https://firebase.google.com/docs/cloud-messaging)
- **PostgreSQL Docs**: [postgresql.org/docs](https://www.postgresql.org/docs/)

---

*Last Updated: 2026-01-06*

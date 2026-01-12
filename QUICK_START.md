# 🚀 QUICK START GUIDE

## 🎯 Get Health Mate Running in 5 Minutes

---

## 📋 Prerequisites

- ✅ Docker Desktop installed and running
- ✅ Flutter SDK installed (3.9.2+)
- ✅ Code editor (VS Code recommended)

---

## 🔧 STEP 1: Start Backend (2 minutes)

```bash
# Navigate to backend
cd "d:\Projects\Graduation Project\Health_Mate_v4\Back-end"

# Start all services (PostgreSQL + Redis + API)
docker-compose up -d

# Check status
docker-compose ps

# View logs (optional)
docker-compose logs -f api
```

**Expected Output:**
```
✅ Database tables created
✅ Environment: development
✅ IoT Mode: mock
✅ Redis connected successfully
```

**API URLs:**
- 📍 API: http://localhost:8000
- 📍 Docs: http://localhost:8000/docs
- 📍 Health: http://localhost:8000/health

---

## 📱 STEP 2: Start Flutter App (3 minutes)

```bash
# Navigate to Flutter project
cd "d:\Projects\Graduation Project\Health_Mate_v4\Front-end\health_mate_app"

# Get dependencies
flutter pub get

# Run app (recommended: Chrome for testing)
flutter run -d chrome

# Or run on Android emulator
flutter run -d android

# Or run on physical device
flutter run
```

**First Launch:**
1. App shows splash screen
2. Loads → No auth → Redirects to Login
3. Click "Register" → Create account
4. Choose role: Patient or Caregiver
5. Login → Redirected to dashboard

---

## ✅ STEP 3: Test the System

### Test Backend API

1. Open: http://localhost:8000/docs
2. Click **"Authorize"** button (top right)
3. Click **"Try it out"** on `/api/v1/auth/register`
4. Create a Patient account:
   ```json
   {
     "email": "patient@test.com",
     "password": "Test1234",
     "full_name": "John Patient",
     "role": "patient"
   }
   ```
5. Click **Execute**
6. Copy the `access_token` from response
7. Click **"Authorize"** → Paste token → Authorize
8. Test `/api/v1/vitals/bp` - Create BP reading:
   ```json
   {
     "systolic": 120,
     "diastolic": 80,
     "source": "manual"
   }
   ```

### Test Flutter App

1. **Register**: Create account (patient or caregiver)
2. **Login**: Use credentials
3. **Patient Dashboard**:
   - View welcome card
   - Click "Add Reading" → Enter BP values
   - View BP card with risk color
   - Check medications tab
4. **Caregiver Dashboard**:
   - View linked patients placeholder
   - View alerts section

---

## 🎨 Test Localization

### Switch Language

```dart
// In any screen
context.setLocale(Locale('ar')); // Switch to Arabic
context.setLocale(Locale('en')); // Switch to English
```

**Test:**
- App text switches
- Layout flips to RTL for Arabic
- All UI updates automatically

---

## 🔍 Verify Features

### ✅ Backend Features
- [x] User registration
- [x] Login with JWT
- [x] BP readings CRUD
- [x] Medications CRUD
- [x] Emergency alerts (HIGH/CRITICAL BP)
- [x] Notifications
- [x] IoT mock endpoints
- [x] AI Symptom Checker

### ✅ Flutter Features
- [x] Authentication flow
- [x] Patient dashboard
- [x] Caregiver dashboard
- [x] BP card with risk colors
- [x] Add BP reading
- [x] Medications list
- [x] Add medication
- [x] Offline caching
- [x] Arabic + English support
- [x] Dark/Light theme

---

## 🐛 Troubleshooting

### Backend Won't Start
```bash
# Check Docker status
docker --version
docker ps

# Check ports
netstat -ano | findstr :8000
netstat -ano | findstr :5432
netstat -ano | findstr :6379

# Restart containers
docker-compose down
docker-compose up -d
```

### Flutter Errors
```bash
# Clean and rebuild
flutter clean
flutter pub get
flutter run

# Check device connection
flutter devices

# See detailed logs
flutter run -v
```

### Database Issues
```bash
# Reset database
docker-compose down -v  # Warning: Deletes data!
docker-compose up -d

# View database logs
docker-compose logs postgres
```

---

## 📊 Monitor System

### Backend Logs
```bash
docker-compose logs -f api      # API logs
docker-compose logs -f postgres # Database logs
docker-compose logs -f redis    # Redis logs
```

### Flutter Logs
- Check terminal where `flutter run` is running
- Errors shown in red
- Network requests logged

---

## 🎯 Development Workflow

### 1. Start Day
```bash
# Start backend
cd Back-end
docker-compose up -d

# Start Flutter
cd ../Front-end/health_mate_app
flutter run
```

### 2. Make Changes
- Edit Dart files → Hot reload (press `r`)
- Edit backend → Restart: `docker-compose restart api`

### 3. End Day
```bash
# Stop backend (data preserved)
docker-compose stop

# Or stop and remove (clean slate next time)
docker-compose down
```

---

## 📚 Useful Commands

### Backend
```bash
# Rebuild after code changes
docker-compose build

# Check API health
curl http://localhost:8000/health

# Access PostgreSQL
docker exec -it healthmate_db psql -U healthmate -d healthmate_db

# Access Redis
docker exec -it healthmate_redis redis-cli
```

### Flutter
```bash
# Hot reload
r  # (press in terminal)

# Hot restart
R  # (press in terminal)

# Quit
q  # (press in terminal)

# Run tests
flutter test

# Build APK
flutter build apk

# Format code
flutter format .
```

---

## 🚀 Ready for Development!

**You now have:**
- ✅ Backend running on http://localhost:8000
- ✅ Flutter app running
- ✅ Full authentication working
- ✅ BP + Medications features
- ✅ Offline support
- ✅ Bilingual support

**Next Steps:**
- Add more features (see task.md)
- Test end-to-end flows
- Configure Cloudflare (SETUP_GUIDE.md)
- Build remaining screens

---

**Need Help?**
- Backend API Docs: http://localhost:8000/docs
- Project Status: `PROJECT_STATUS.md`
- Setup Guide: `SETUP_GUIDE.md`
- Localization: `LOCALIZATION.md`

**Happy Coding! 🎉**

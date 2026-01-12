# 🎯 MANUAL SETUP STEPS - ACTION REQUIRED

This guide lists **all manual steps** you need to complete to fully configure Health Mate.

---

## 📋 STEP 1: Setup Cloudflare Images (CRITICAL - For Profile Pictures)

**Why**: Profile pictures and medication images require secure cloud storage.

### Actions:
1. Go to [cloudflare.com](https://cloudflare.com) → Sign Up (free account)
2. Enable **Cloudflare Images** in dashboard
3. Copy your **Account ID** and create an **API Token**
4. Add to `Back-end/.env`:
   ```env
   CLOUDFLARE_ACCOUNT_ID=your_account_id_here
   CLOUDFLARE_API_TOKEN=your_token_here
   ```

**Detailed Guide**: See `SETUP_GUIDE.md` → Cloudflare Images section

**Status**: ✅ Backend code ready, ⏳ Awaiting your credentials

---

## 📋 STEP 2: Setup Firebase (Optional - For Push Notifications)

**Why**: Mobile push notifications for emergency alerts and medication reminders.

### Actions:
1. Go to [firebase.google.com](https://firebase.google.com) → Create project
2. Add Android app with package: `com.healthmate.app`
3. Add iOS app with bundle ID: `com.healthmate.app`
4. Download `google-services.json` and `GoogleService-Info.plist`
5. Get Service Account JSON for backend
6. Add to `Back-end/.env`:
   ```env
   FIREBASE_PROJECT_ID=health-mate-xxxxx
   FIREBASE_PRIVATE_KEY=-----BEGIN PRIVATE KEY-----\n...
   ```

**Detailed Guide**: See `SETUP_GUIDE.md` → Firebase section

**Status**: ⏳ Optional but recommended for production

---

## 📋 STEP 3: Install and Run Backend

**Why**: Start the FastAPI server to test endpoints.

### Option A: Using Docker (RECOMMENDED - No manual DB setup needed)

```bash
cd "d:\Projects\Graduation Project\Health_Mate_v4\Back-end"
docker-compose up -d
```

**Check status:**
```bash
docker-compose ps
docker-compose logs -f api
```

**Access API**:
- API: http://localhost:8000
- Docs: http://localhost:8000/docs

### Option B: Manual Setup (If Docker unavailable)

1. Install PostgreSQL and Redis locally
2. Create database:
   ```sql
   CREATE USER healthmate WITH PASSWORD 'healthmate123';
   CREATE DATABASE healthmate_db OWNER healthmate;
   ```
3. Install Python dependencies:
   ```bash
   cd Back-end
   python -m venv venv
   venv\Scripts\activate
   pip install -r requirements.txt
   ```
4. Run server:
   ```bash
   uvicorn app.main:app --reload
   ```

**Status**: ⏳ Awaiting you to run backend

---

## 📋 STEP 4: Test Backend APIs

**Why**: Verify everything works before starting Flutter.

### Test Checklist:

1. **Health Check**: http://localhost:8000/health
2. **API Docs**: http://localhost:8000/docs
3. **Register User**:
   - Go to `/api/v1/auth/register` in docs
   - Create a Patient account
   - Create a Caregiver account
4. **Test Image Upload**:
   - Login as Patient → get JWT token
   - Upload profile picture via `/api/v1/upload/profile-picture`
   - Verify image URL returned
5. **Test BP Reading**:
   - Create BP reading via `/api/v1/vitals/bp`
   - Use high values (systolic: 180, diastolic: 120)
   - Check notifications created for caregivers
6. **Link Patient-Caregiver**:
   - Use `/api/v1/users/link/{user_id}` to link accounts

**Status**: ⏳ Awaiting you to test

---

## 📋 STEP 5: Review Backend Code

**What's Built:**
- ✅ 9 Database models (User, VitalSign, Medication, CallSession, etc.)
- ✅ 7 API routers (Auth, Users, Vitals, Meds, IoT, Upload, Notifications)
- ✅ 3 Services (IoT Mock, Cloudflare Upload, Notifications)
- ✅ Docker setup
- ✅ Emergency BP alerts system
- ✅ Cloudflare image upload
- ✅ Role-based access control

**What's NOT Built Yet:**
- ⏳ Communication/WebRTC endpoints (for video calls)
- ⏳ AI integration (Symptom Checker, BP Prediction)
- ⏳ Redis caching layer
- ⏳ Background workers (Celery for reminders)
- ⏳ Flutter mobile app (entire frontend)

---

## 📋 STEP 6: Decide Next Steps

**Option A: Continue Backend-First**
- Complete Communication module (WebRTC)
- Integrate AI models
- Add Redis caching
- Then start Flutter

**Timeline**: ~2-3 more sessions for complete backend

**Option B: Start Flutter Now**
- Begin building Flutter app with existing APIs
- Continue backend in parallel
- Implement Communication/AI later

**Timeline**: Can see UI progress sooner

**Option C: Test Current Backend Thoroughly**
- Use Postman/curl to test all endpoints
- Document any bugs or issues
- Then decide: continue backend or start Flutter

**Recommended**: Choose based on your priority:
- Want video calls? → Option A
- Want to see app UI? → Option B
- Want stable foundation? → Option C

---

## ✅ QUICK REFERENCE

### Environment Variables Needed:
```env
# Database (auto-configured by Docker)
DATABASE_URL=postgresql://healthmate:healthmate123@localhost:5432/healthmate_db

# Redis (auto-configured by Docker)
REDIS_URL=redis://localhost:6379/0

# JWT (auto-generated, can keep default for development)
JWT_SECRET=dev-secret-key-replace-in-production-with-secure-random-string

# Cloudflare (⚠️ YOU MUST ADD THIS)
CLOUDFLARE_ACCOUNT_ID=
CLOUDFLARE_API_TOKEN=

# Firebase (Optional)
FIREBASE_PROJECT_ID=
FIREBASE_PRIVATE_KEY=
```

### Files You Need to Review:
- `PROGRESS.md` - Detailed progress report
- `SETUP_GUIDE.md` - Step-by-step service setup
- `Back-end/README.md` - Backend documentation 
- `Back-end/docker-compose.yml` - Docker configuration
- `Back-end/.env` - Environment variables

---

## 🆘 Troubleshooting

### Backend won't start
- Check Docker is running: `docker --version`
- Check ports not in use: 5432 (PostgreSQL), 6379 (Redis), 8000 (API)
- Check `.env` file exists in `Back-end/` directory

### Image upload fails
- Error: "Image upload service not configured"
  - **Fix**: Add `CLOUDFLARE_ACCOUNT_ID` and `CLOUDFLARE_API_TOKEN` to `.env`
- Error: "Invalid file type"
  - **Fix**: Only JPG, PNG, WebP allowed (max 10MB)

### Can't link patient-caregiver
- Ensure you have one Patient account and one Caregiver account
- Note their user IDs from login response
- Use correct user ID in link endpoint

---

## 📞 Next Session Plan

Based on task.md, next major items are:
1. **Phase 7**: Communication Module (WebRTC video calls)
2. **Phase 4**: AI/ML Integration (Symptom Checker)
3. **Phase 5**: Flutter Frontend (Major phase - 50+ hours)

**Let me know which you want to prioritize!**

---

*Last Updated: 2026-01-06 17:30*

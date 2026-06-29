# Health Mate Backend API

Medical-grade healthcare monitoring system with FastAPI.

## Features

✅ **Authentication**: JWT-based auth with role-based access control (Patient/Caregiver)  
✅ **Vitals Management**: Blood pressure monitoring with automatic risk calculation  
✅ **Medications**: Medicine tracking with medicine box integration  
✅ **IoT Integration**: Mock layer for development, production-ready architecture  
✅ **Patient-Caregiver Linking**: Many-to-many relationship management  
✅ **Audit Logging**: Complete event tracking for compliance  

## Quick Start

### Using Docker Compose (Recommended)

```bash
# Start all services
docker-compose up -d

# Check logs
docker-compose logs -f api

# Stop services
docker-compose down
```

API will be available at: `http://localhost:8000`  
API Documentation: `http://localhost:8000/docs`

### Manual Setup

1. Create Python virtual environment:
```bash
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Set up environment:
```bash
cp .env.example .env
# Edit .env with your configuration
```

4. Start PostgreSQL and Redis

5. Run the API:
```bash
uvicorn app.main:app --reload
```

## API Endpoints

### Authentication
- `POST /api/v1/auth/register` - Register new user
- `POST /api/v1/auth/login` - Login
- `POST /api/v1/auth/refresh` - Refresh token

### Users
- `GET /api/v1/users/me` - Get current user profile
- `PUT /api/v1/users/me` - Update profile
- `PUT /api/v1/users/me/password` - Change password
- `GET /api/v1/users/linked` - Get linked users
- `POST /api/v1/users/link/{user_id}` - Link with user

### Vitals
- `POST /api/v1/vitals/bp` - Create BP reading
- `GET /api/v1/vitals/bp/current` - Get current BP
- `GET /api/v1/vitals/bp/history` - Get BP history
- `GET /api/v1/vitals/bp/stats` - Get BP statistics

### Medications
- `POST /api/v1/medications` - Create medication
- `GET /api/v1/medications` - List medications
- `GET /api/v1/medications/{id}` - Get medication
- `PUT /api/v1/medications/{id}` - Update medication
- `DELETE /api/v1/medications/{id}` - Delete medication

### IoT Devices
- `GET /api/v1/iot/sensors/status` - Get sensors status
- `GET /api/v1/iot/sensors/data` - Get sensor readings
- `GET /api/v1/iot/medicine-box/drawers` - Get all drawers
- `POST /api/v1/iot/medicine-box/drawer/{num}/activate` - Activate drawer

## Environment Variables

See `.env.example` for all configuration options.

Key variables:
- `DATABASE_URL` - PostgreSQL connection string
- `REDIS_URL` - Redis connection string
- `JWT_SECRET` - Secret key for JWT tokens
- `IOT_MODE` - `mock` or `production`

## Project Structure

```
app/
├── api/
│   ├── dependencies.py     # Auth dependencies
│   └── v1/                 # API v1 routes
│       ├── auth.py
│       ├── users.py
│       ├── vitals.py
│       ├── medications.py
│       └── iot.py
├── core/
│   ├── config.py           # Settings
│   ├── database.py         # DB session
│   └── security.py         # JWT & hashing
├── models/                 # SQLAlchemy models
├── schemas/                # Pydantic schemas
├── services/               # Business logic
│   └── iot_mock.py
└── main.py                 # FastAPI app
```

## Development

### Run tests
```bash
pytest tests/ -v
```

### Code quality
```bash
black app/
flake8 app/
mypy app/
```

## Production Deployment

1. Set `ENVIRONMENT=production` in `.env`
2. Set strong `JWT_SECRET`
3. Use managed PostgreSQL and Redis
4. Set `IOT_MODE=production` and connect real hardware
5. Configure CORS origins properly
6. Enable HTTPS

## License

Proprietary - Health Mate Project 2026

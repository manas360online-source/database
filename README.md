# Manas360 Database Schema

Comprehensive database schema and visualization dashboard for the Manas360 platform (Sprint 9).

## Contents
- **`manas360 db.sql`**: Full PostgreSQL schema including 17+ tables, views, functions, and RLS policies.
- **`seed_data.sql`**: Comprehensive test data set for validation and development.
- **`preview.html`**: Interactive database explorer dashboard with glassmorphism UI.

## Features
- **Doctor Referral System**: Complete tracking of patient referrals, doctor credits, and rewards.
- **Analytics Ready**: Includes dimension/fact tables for tracking marketing campaigns and QR scans.
- **Premium Visualization**: Built-in frontend dashboard to explore table structures and sample data.

## Getting Started
### Database Setup
Run the following commands in your PostgreSQL environment:
```sql
\i "manas360 db.sql"
\i "seed_data.sql"
```

### Preview Dashboard
Simply open `preview.html` in any modern web browser to view the interactive dashboard.

---
*Created during Sprint 9 Database Extension.*

# University Timetable & Exam Scheduling — Backend

This repository contains the backend for a University Timetable & Exam Scheduling system. It demonstrates advanced database design, automated scheduling logic, and clean API integration.

---

## Table of Contents

1. [Project Overview](#project-overview)
2. [Features](#features)
3. [System Architecture](#system-architecture)
4. [Database Schema](#database-schema)
5. [Backend API](#backend-api)
6. [Connecting to the Database](#connecting-to-the-database)
7. [Testing the API](#testing-the-api)
8. [Sample Queries and Views](#sample-queries-and-views)
9. [Security and Best Practices](#security-and-best-practices)
10. [Troubleshooting](#troubleshooting)

---

## Project Overview

This project provides a comprehensive backend for managing university timetables and exam scheduling. It features:

- A fully normalized PostgreSQL schema with constraints, triggers, and stored procedures to ensure data integrity.
- Automated, clash-free exam scheduling that resolves student conflicts and enforces room capacity.
- A FastAPI-powered REST API for secure and efficient database interaction.
- Deployment on Neon for read-only access to the schema and sample data.

---

## Features

### Database (PostgreSQL)

- Normalized tables: Terms, Rooms, Courses, Instructors, Offerings, Timeslots, ClassMeetings, Students, Enrollments, ExamSlots, ExamSittings.
- Constraints & Triggers: Prevent double-bookings, enforce room capacities, and eliminate student exam clashes.
- Stored Procedures: Automatically generate clash-free exam schedules.

### Backend API (FastAPI)

- REST endpoints to list courses, manage enrollments, view timetables, and generate/view exam schedules.
- Project structure with configuration via environment variables.
- Error handling and validation, leveraging database triggers and constraints.

### Dev & Portfolio Tools

- Postman Collection for API testing.
- DBeaver / TablePlus integration for database visualization and read-only queries.
- Cloud deployment via Neon for easy sharing.

---

## System Architecture

The architecture is organized into three main layers:

1. **PostgreSQL (Neon):**  
    - Central data store with integrity enforced at the database level.
2. **FastAPI Backend:**  
    - Connects to PostgreSQL using SQLAlchemy Core.
    - Exposes REST endpoints for all interactions.
3. **Clients / Testing Tools:**  
    - Postman for API requests.
    - DBeaver/TablePlus for schema exploration.

---

## Database Schema

- **Terms:** Academic periods (e.g., 2025-SPR).
- **Rooms:** Physical rooms with capacity and type (Lecture, Lab, Exam Hall, Seminar).
- **Instructors:** Teaching staff metadata.
- **Courses:** Course catalog.
- **Course Offerings:** Term-specific course instances with sections and instructors.
- **Timeslots & Class Meetings:** Weekly schedule blocks and room assignments.
- **Students & Enrollments:** Student registration and course enrollment.
- **Exam Slots & Exam Sittings:** Scheduled exam times and room assignments, with clash-free logic.

The schema uses indexes, constraints, and triggers to ensure data integrity and conflict-free scheduling.

---

## Backend API

Key endpoints:

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/healthz` | GET | Health check |
| `/courses` | GET | List all courses |
| `/enrollments` | POST | Add student enrollment (with integrity validation) |
| `/timetable/{term_code}` | GET | View weekly timetable for a term |
| `/exams/schedule` | POST | Generate clash-free exam schedule |
| `/exams/schedule/{term_code}` | GET | View scheduled exams |

**Postman Collection:**  
Located at `postman/postman_collection.json`—import and replace `{{baseUrl}}` with your API URL for testing.

---

## Connecting to the Database

**Read-only access:**

```
postgres://uni_readonly:PostgreUniDbPass@ep-rough-moon-agnj9mm7-pooler.c-2.eu-central-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require
```

**Recommended clients:**
- **DBeaver / TablePlus:** Paste the URL and connect.
- **psql CLI:**
  ```bash
  psql "postgres://uni_readonly:PostgreUniDbPass@ep-rough-moon-agnj9mm7-pooler.c-2.eu-central-1.aws.neon.tech/neondb?sslmode=require&channel_binding=require"
  ```

---

## Testing the API

1. **Run the backend locally:**
    ```bash
    uvicorn app.main:app --reload
    ```
2. **Open Postman → Import Collection:**  
    `postman/postman_collection.json`
3. **Set Base URL:**  
    ```
    http://127.0.0.1:8000
    ```
4. **Test endpoints interactively:**  
    - List courses  
    - Add enrollments  
    - Generate and view exam schedule

API responses include constraint validations to ensure realistic and conflict-free data.

---

## Sample Queries and Views

- **Weekly timetable:**  
  `SELECT * FROM v_timetable;`
- **Exam schedule:**  
  `SELECT * FROM v_exam_schedule;`
- **Underutilized rooms:**  
  Calculate % of weekly timeslots used.

These views provide a human-readable representation of the normalized schema.

---

## Security and Best Practices

- Do not expose superuser credentials—only share the read-only role.
- Keep passwords out of version control; use placeholders in SQL scripts.
- Business rules are enforced via constraints, triggers, and procedures for data integrity.
- The API exposes controlled interactions; direct data modifications must follow database rules.

---

## Troubleshooting

- **Cannot connect to Neon:** Check DSN, Neon project status, and SSL mode.
- **Trigger exceptions on API inserts:** Indicates constraint enforcement.
- **Incorrect API URL in Postman:** Update `{{baseUrl}}` to your backend URL.
- **Port conflicts:** Ensure FastAPI runs on a free port (default: 8000).

---

## Conclusion

This project demonstrates:

- Professional-grade database design with constraints, triggers, and automated scheduling logic.
- Clean API design exposing secure endpoints.
- Deployment via Neon with read-only access.
- Documentation and testing tools (Postman, DBeaver) for evaluation.
"""
FastAPI application exposing REST endpoints for:
- Listing courses
- Adding enrollments (real insert via API)
- Viewing weekly timetable
- Scheduling and viewing exams

Using the database schema & procedures defined in sql/*.sql.
"""

from fastapi import FastAPI, Depends, HTTPException
from sqlalchemy.orm import Session
from sqlalchemy import text
from app.dp import SessionLocal, fetch_all

app = FastAPI(title="University Timetable MVP")

def get_db():
    """
    Dependency that yields a transactional DB session.
    Ensures clean open/close per request.
    """
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

@app.get("/healthz")
def healthz():
    """
    Simple health check endpoint for monitoring/CI.
    """
    return {"status": "ok"}

# -------------------- Courses --------------------
@app.get("/courses")
def list_courses(db: Session = Depends(get_db)):
    """
    Return the list of all courses in the catalog.
    """
    rows = fetch_all(db, "SELECT code, title, credits FROM course ORDER BY code")
    return {"courses": rows}

# ------------------- Enrollments ------------------
@app.post("/enrollments", status_code=201)
def add_enrollment(payload: dict, db: Session = Depends(get_db)):
    """
    Insert a new enrollment using the API (real-world flow).
    DB constraints and triggers will enforce business rules.
    Expected JSON body: {"student_id": int, "offering_id": int}
    """
    try:
        db.execute(
            text("INSERT INTO enrollment (student_id, offering_id) VALUES (:s, :o)"),
            {"s": payload["student_id"], "o": payload["offering_id"]},
        )
        db.commit()
        return {"message": "Enrollment added"}
    except Exception as e:
        db.rollback()
        # Any violations (FK, uniqueness, trigger exceptions) will surface here
        raise HTTPException(status_code=400, detail=str(e))

# --------------------- Timetable ------------------
@app.get("/timetable/{term_code}")
def get_timetable(term_code: str, db: Session = Depends(get_db)):
    """
    Return the weekly timetable for a given term code (e.g., '2025-SPR').
    """
    sql = """
    SELECT tm.code AS term, r.code AS room, c.code AS course, co.section,
           i.full_name AS instructor, ts.day_of_week, ts.start_time, ts.end_time
    FROM class_meeting cm
    JOIN course_offering co USING (offering_id)
    JOIN course c ON c.course_id = co.course_id
    JOIN instructor i ON i.instructor_id = co.instructor_id
    JOIN room r ON r.room_id = cm.room_id
    JOIN timeslot ts ON ts.timeslot_id = cm.timeslot_id
    JOIN term tm ON tm.term_id = ts.term_id
    WHERE tm.code = :term
    ORDER BY ts.day_of_week, ts.start_time, r.code;
    """
    rows = fetch_all(db, sql, {"term": term_code})
    return {"items": rows}

# ----------------------- Exams --------------------
@app.post("/exams/schedule")
def schedule_exams(payload: dict, db: Session = Depends(get_db)):
    """
    Generate a clash-free exam schedule for a given term by calling the stored
    procedure schedule_exams_clash_free(term_code). The procedure:
      1) Builds a conflict graph from shared-student enrollments
      2) Greedily colors offerings into exam slots (no clashes)
      3) Packs rooms by smallest-fitting capacity
      4) Inserts rows into exam_sitting
    Expected JSON body: {"term_code": "2025-SPR"}
    """
    try:
        rows = fetch_all(db, "SELECT * FROM schedule_exams_clash_free(:t)", {"t": payload["term_code"]})
        db.commit()
        return {"scheduled": rows}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=str(e))

@app.get("/exams/schedule/{term_code}")
def view_exam_schedule(term_code: str, db: Session = Depends(get_db)):
    """
    View the scheduled exams for a term (after running the scheduler).
    """
    sql = """
    SELECT tm.code AS term, c.code AS course, co.section, r.code AS room,
           es.exam_date, es.start_time, es.end_time
    FROM exam_sitting s
    JOIN exam_slot es ON es.exam_slot_id = s.exam_slot_id
    JOIN term tm ON tm.term_id = es.term_id
    JOIN course_offering co ON co.offering_id = s.offering_id
    JOIN course c ON c.course_id = co.course_id
    JOIN room r ON r.room_id = s.room_id
    WHERE tm.code = :term
    ORDER BY es.exam_date, es.start_time, room;
    """
    return fetch_all(db, sql, {"term": term_code})
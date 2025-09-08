-- ===============================
-- 01_schema.sql
-- Core schema for timetable/exams
-- ===============================

-- Terms define the academic period (e.g., 2025-SPR)
CREATE TABLE term (
  term_id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,            -- e.g., '2025-SPR'
  start_date DATE NOT NULL,
  end_date DATE NOT NULL,
  teaching_weeks INT NOT NULL CHECK (teaching_weeks BETWEEN 1 AND 30),
  CHECK (start_date < end_date)
);

-- Room categories to differentiate spaces
CREATE TYPE room_type AS ENUM ('LECTURE','LAB','EXAM_HALL','SEMINAR');

-- Physical rooms on campus
CREATE TABLE room (
  room_id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,            -- e.g., 'A101'
  building TEXT NOT NULL,
  capacity INT NOT NULL CHECK (capacity > 0),
  type room_type NOT NULL DEFAULT 'LECTURE'
);

-- Teaching staff
CREATE TABLE instructor (
  instructor_id SERIAL PRIMARY KEY,
  full_name TEXT NOT NULL,
  email TEXT UNIQUE
);

-- Course catalog entries (not specific to term)
CREATE TABLE course (
  course_id SERIAL PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,            -- e.g., 'CS205'
  title TEXT NOT NULL,
  credits NUMERIC(3,1) NOT NULL CHECK (credits > 0)
);

-- A concrete instance of a course in a term, taught by an instructor
CREATE TABLE course_offering (
  offering_id SERIAL PRIMARY KEY,
  course_id INT NOT NULL REFERENCES course(course_id) ON DELETE CASCADE,
  term_id INT NOT NULL REFERENCES term(term_id) ON DELETE CASCADE,
  section TEXT NOT NULL,                -- e.g., 'A'
  instructor_id INT NOT NULL REFERENCES instructor(instructor_id),
  max_enrollment INT NOT NULL CHECK (max_enrollment > 0),
  UNIQUE (course_id, term_id, section)  -- prevents duplicate offerings in a term
);

-- Reusable weekly time blocks within a term (e.g., Mon 09:00–10:30)
CREATE TABLE timeslot (
  timeslot_id SERIAL PRIMARY KEY,
  term_id INT NOT NULL REFERENCES term(term_id) ON DELETE CASCADE,
  day_of_week INT NOT NULL CHECK (day_of_week BETWEEN 1 AND 7), -- 1=Mon..7=Sun
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  CHECK (start_time < end_time),
  UNIQUE (term_id, day_of_week, start_time, end_time) -- canonical slot
);

-- Weekly class meeting = offering + room + timeslot
CREATE TABLE class_meeting (
  class_meeting_id SERIAL PRIMARY KEY,
  offering_id INT NOT NULL REFERENCES course_offering(offering_id) ON DELETE CASCADE,
  room_id INT NOT NULL REFERENCES room(room_id),
  timeslot_id INT NOT NULL REFERENCES timeslot(timeslot_id),

  -- Business rules (prevent double-bookings):
  UNIQUE (room_id, timeslot_id),      -- a room can't host two classes in same slot
  UNIQUE (timeslot_id, offering_id)   -- offering appears once per slot
);

-- Students and their enrollments
CREATE TABLE student (
  student_id SERIAL PRIMARY KEY,
  reg_no TEXT NOT NULL UNIQUE,         -- e.g., 'U2025-0001'
  full_name TEXT NOT NULL,
  email TEXT UNIQUE
);

CREATE TABLE enrollment (
  student_id INT NOT NULL REFERENCES student(student_id) ON DELETE CASCADE,
  offering_id INT NOT NULL REFERENCES course_offering(offering_id) ON DELETE CASCADE,
  PRIMARY KEY (student_id, offering_id) -- prevents duplicates
);

-- Exam windows and specific scheduled exam sittings
CREATE TABLE exam_slot (
  exam_slot_id SERIAL PRIMARY KEY,
  term_id INT NOT NULL REFERENCES term(term_id) ON DELETE CASCADE,
  exam_date DATE NOT NULL,
  start_time TIME NOT NULL,
  end_time TIME NOT NULL,
  CHECK (start_time < end_time),
  UNIQUE (term_id, exam_date, start_time, end_time) -- canonical exam slots
);

CREATE TABLE exam_sitting (
  exam_sitting_id SERIAL PRIMARY KEY,
  offering_id INT NOT NULL REFERENCES course_offering(offering_id) ON DELETE CASCADE,
  room_id INT NOT NULL REFERENCES room(room_id),
  exam_slot_id INT NOT NULL REFERENCES exam_slot(exam_slot_id) ON DELETE CASCADE,

  -- Business rules (prevent double-book):
  UNIQUE (offering_id, exam_slot_id),  -- offering sits once per slot
  UNIQUE (room_id, exam_slot_id)       -- room can't host multiple exams same slot
);

-- Helpful indexes (improve query performance)
CREATE INDEX idx_meeting_room ON class_meeting(room_id);
CREATE INDEX idx_enroll_offering ON enrollment(offering_id);
CREATE INDEX idx_exam_slot ON exam_sitting(exam_slot_id);
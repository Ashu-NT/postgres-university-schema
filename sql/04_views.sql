-- ===============================
-- 04_views.sql
-- Human-friendly reporting views
-- ===============================

-- Weekly class timetable view
CREATE OR REPLACE VIEW v_timetable AS
SELECT tm.code AS term, r.code AS room, c.code AS course, co.section,
       i.full_name AS instructor, ts.day_of_week, ts.start_time, ts.end_time
FROM class_meeting cm
JOIN course_offering co USING (offering_id)
JOIN course c ON c.course_id = co.course_id
JOIN instructor i ON i.instructor_id = co.instructor_id
JOIN room r ON r.room_id = cm.room_id
JOIN timeslot ts ON ts.timeslot_id = cm.timeslot_id
JOIN term tm ON tm.term_id = ts.term_id;

-- Exam schedule view
CREATE OR REPLACE VIEW v_exam_schedule AS
SELECT tm.code AS term, c.code AS course, co.section, r.code AS room,
       es.exam_date, es.start_time, es.end_time
FROM exam_sitting s
JOIN exam_slot es ON es.exam_slot_id = s.exam_slot_id
JOIN term tm ON tm.term_id = es.term_id
JOIN course_offering co ON co.offering_id = s.offering_id
JOIN course c ON c.course_id = co.course_id
JOIN room r ON r.room_id = s.room_id;
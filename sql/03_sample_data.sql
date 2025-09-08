-- ===============================
-- 03_sample_data.sql
-- Seed a small realistic dataset
-- ===============================

-- 1) Term
INSERT INTO term (code, start_date, end_date, teaching_weeks)
VALUES ('2025-SPR','2025-02-10','2025-06-15',14);

-- 2) Rooms
INSERT INTO room (code, building, capacity, type) VALUES
('A101','Alpha',120,'LECTURE'),
('B201','Beta', 40,'SEMINAR'),
('C301','Gamma',80,'EXAM_HALL');

-- 3) Instructors
INSERT INTO instructor (full_name, email) VALUES
('Dr. Lina Torres','lina.torres@uni.edu'),
('Prof. Mark Chen','mark.chen@uni.edu');

-- 4) Courses
INSERT INTO course (code, title, credits) VALUES
('CS205','Data Structures',4.0),
('MA110','Calculus I',5.0);

-- 5) Offerings (course+term+section+instructor)
INSERT INTO course_offering (course_id, term_id, section, instructor_id, max_enrollment)
VALUES
((SELECT course_id FROM course WHERE code='CS205'),
 (SELECT term_id FROM term WHERE code='2025-SPR'),'A',
 (SELECT instructor_id FROM instructor WHERE full_name='Dr. Lina Torres'),80),
((SELECT course_id FROM course WHERE code='MA110'),
 (SELECT term_id FROM term WHERE code='2025-SPR'),'B',
 (SELECT instructor_id FROM instructor WHERE full_name='Prof. Mark Chen'),120);

-- 6) Timeslots (Mon 09:00–10:30, Tue 11:00–12:30)
INSERT INTO timeslot (term_id, day_of_week, start_time, end_time)
SELECT term_id, 1, '09:00'::time ,'10:30'::time  FROM term WHERE code='2025-SPR' UNION ALL
SELECT term_id, 2, '11:00'::time ,'12:30'::time  FROM term WHERE code='2025-SPR';

-- 7) Class meetings (assign room+slot to offerings)
INSERT INTO class_meeting (offering_id, room_id, timeslot_id)
VALUES
((SELECT offering_id FROM course_offering co JOIN course c USING(course_id)
  WHERE c.code='CS205' AND section='A' AND term_id=(SELECT term_id FROM term WHERE code='2025-SPR')),
 (SELECT room_id FROM room WHERE code='A101'),
 (SELECT timeslot_id FROM timeslot t JOIN term tm ON t.term_id=tm.term_id
  WHERE tm.code='2025-SPR' AND day_of_week=1 AND start_time='09:00'::time));

((SELECT offering_id FROM course_offering co JOIN course c USING(course_id)
  WHERE c.code='MA110' AND section='B' AND term_id=(SELECT term_id FROM term WHERE code='2025-SPR')),
 (SELECT room_id FROM room WHERE code='B201'),
 (SELECT timeslot_id FROM timeslot t JOIN term tm ON t.term_id=tm.term_id
  WHERE tm.code='2025-SPR' AND day_of_week=2 AND start_time='11:00'::time));

-- 8) Students
INSERT INTO student (reg_no, full_name, email) VALUES
('U2025-0001','Amara Singh','amara@uni.edu'),
('U2025-0002','Jonas Weber','jonas@uni.edu'),
('U2025-0003','Sara Ali','sara@uni.edu');

-- 9) Enrollments
INSERT INTO enrollment (student_id, offering_id)
SELECT s.student_id, o.offering_id
FROM student s
JOIN course_offering o ON o.term_id=(SELECT term_id FROM term WHERE code='2025-SPR')
JOIN course c ON c.course_id=o.course_id
WHERE (s.reg_no IN ('U2025-0001','U2025-0002') AND c.code='CS205')
   OR (s.reg_no IN ('U2025-0002','U2025-0003') AND c.code='MA110');

-- 10) Exam slots (two slots on same day)
INSERT INTO exam_slot (term_id, exam_date, start_time, end_time)
SELECT term_id, '2025-06-01'::date,'09:00'::time,'12:00'::time FROM term WHERE code='2025-SPR' UNION ALL
SELECT term_id, '2025-06-01'::date,'13:00'::time,'16:00'::time FROM term WHERE code='2025-SPR';
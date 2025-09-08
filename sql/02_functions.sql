-- ===============================
-- 02_functions.sql
-- Triggers & Scheduling procedure
-- ===============================

-- Helper: count enrolled students for an offering
CREATE OR REPLACE FUNCTION f_offering_enrollment_count(p_offering INT)
RETURNS INT LANGUAGE SQL AS $$
  SELECT COUNT(*) FROM enrollment WHERE offering_id = p_offering;
$$;

-- Trigger: exam room capacity must fit enrolled headcount
CREATE OR REPLACE FUNCTION trg_exam_capacity_check()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE
  enrolled INT; cap INT;
BEGIN
  SELECT COUNT(*) INTO enrolled FROM enrollment WHERE offering_id = NEW.offering_id;
  SELECT capacity INTO cap FROM room WHERE room_id = NEW.room_id;
  IF enrolled > cap THEN
    RAISE EXCEPTION 'Exam room capacity % < enrolled % for offering %', cap, enrolled, NEW.offering_id;
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER exam_capacity_check
BEFORE INSERT OR UPDATE ON exam_sitting
FOR EACH ROW EXECUTE FUNCTION trg_exam_capacity_check();

-- Trigger: prevent student exam clashes (two exams same slot)
CREATE OR REPLACE FUNCTION trg_student_exam_clash()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM enrollment e
    JOIN exam_sitting es2 ON es2.offering_id = e.offering_id
    WHERE e.student_id IN (
      SELECT e2.student_id FROM enrollment e2 WHERE e2.offering_id = NEW.offering_id
    )
    AND es2.exam_slot_id = NEW.exam_slot_id
  ) THEN
    RAISE EXCEPTION 'Student clash: some enrolled students already have an exam in this slot';
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER student_exam_clash
BEFORE INSERT ON exam_sitting
FOR EACH ROW EXECUTE FUNCTION trg_student_exam_clash();

-- ===============================================
-- Stored Procedure: schedule_exams_clash_free(term)
-- Greedy graph coloring + smallest-fitting-room pack
-- ===============================================
CREATE OR REPLACE FUNCTION schedule_exams_clash_free(p_term_code TEXT)
RETURNS TABLE(offering_id INT, exam_slot_id INT, room_id INT)
LANGUAGE plpgsql AS $$
DECLARE
  v_term_id INT;
  v_missing INT;
BEGIN
  -- Resolve the term code -> term_id
  SELECT term_id INTO v_term_id FROM term WHERE code = p_term_code;
  IF v_term_id IS NULL THEN
    RAISE EXCEPTION 'Unknown term code %', p_term_code;
  END IF;

  -- Offerings and enrollment sizes for the term
  CREATE TEMP TABLE t_offering_size ON COMMIT DROP AS
  SELECT o.offering_id, COUNT(e.student_id)::INT AS size
  FROM course_offering o
  LEFT JOIN enrollment e ON e.offering_id = o.offering_id
  WHERE o.term_id = v_term_id
  GROUP BY o.offering_id;

  -- Conflict edges: offerings sharing at least one student
  CREATE TEMP TABLE t_conflict(offering_a INT, offering_b INT) ON COMMIT DROP;
  INSERT INTO t_conflict
  SELECT LEAST(e1.offering_id, e2.offering_id),
         GREATEST(e1.offering_id, e2.offering_id)
  FROM enrollment e1
  JOIN enrollment e2
    ON e1.student_id = e2.student_id
   AND e1.offering_id < e2.offering_id
  WHERE e1.offering_id IN (SELECT offering_id FROM t_offering_size)
    AND e2.offering_id IN (SELECT offering_id FROM t_offering_size)
  GROUP BY 1,2;

  -- Available exam slots in the term (ordered)
  CREATE TEMP TABLE t_slots ON COMMIT DROP AS
  SELECT exam_slot_id
  FROM exam_slot
  WHERE term_id = v_term_id
  ORDER BY exam_date, start_time;

  IF (SELECT COUNT(*) FROM t_slots) = 0 THEN
    RAISE EXCEPTION 'No exam slots for term %', p_term_code;
  END IF;

  -- Greedy coloring: highest degree & size first
  CREATE TEMP TABLE t_assignment(offering_id INT PRIMARY KEY, exam_slot_id INT) ON COMMIT DROP;

  FOR offering_id IN
    SELECT s.offering_id
    FROM t_offering_size s
    LEFT JOIN (
      SELECT offering_a AS offering_id, COUNT(*) AS deg FROM t_conflict GROUP BY 1
      UNION ALL
      SELECT offering_b AS offering_id, COUNT(*) AS deg FROM t_conflict GROUP BY 1
    ) d USING (offering_id)
    ORDER BY COALESCE(d.deg,0) DESC, s.size DESC
  LOOP
    -- Choose first slot that doesn't conflict with already colored neighbors
    INSERT INTO t_assignment(offering_id, exam_slot_id)
    SELECT offering_id, ts.exam_slot_id
    FROM t_slots ts
    WHERE NOT EXISTS (
      SELECT 1
      FROM t_conflict c
      JOIN t_assignment a
        ON (c.offering_a = offering_id AND c.offering_b = a.offering_id)
        OR (c.offering_b = offering_id AND c.offering_a = a.offering_id)
      WHERE a.exam_slot_id = ts.exam_slot_id
    )
    LIMIT 1;

    IF NOT FOUND THEN
      RAISE EXCEPTION 'Insufficient exam slots to avoid clashes for offering %', offering_id;
    END IF;
  END LOOP;

  -- Assign rooms per slot: pack largest classes first into smallest-fitting rooms
  CREATE TEMP TABLE t_room_assign(offering_id INT PRIMARY KEY, exam_slot_id INT, room_id INT) ON COMMIT DROP;

  FOR exam_slot_id IN SELECT exam_slot_id FROM t_slots LOOP
    INSERT INTO t_room_assign(offering_id, exam_slot_id, room_id)
    SELECT a.offering_id, a.exam_slot_id, r.room_id
    FROM (
      SELECT a.offering_id, a.exam_slot_id, s.size
      FROM t_assignment a JOIN t_offering_size s USING (offering_id)
      WHERE a.exam_slot_id = exam_slot_id
      ORDER BY s.size DESC
    ) a
    JOIN LATERAL (
      SELECT room_id
      FROM room
      WHERE capacity >= (SELECT size FROM t_offering_size WHERE offering_id = a.offering_id)
        AND room_id NOT IN (SELECT room_id FROM t_room_assign WHERE exam_slot_id = a.exam_slot_id)
      ORDER BY capacity ASC   -- smallest that fits
      LIMIT 1
    ) r ON true;

    -- Validate: did everyone get a room?
    SELECT COUNT(*) INTO v_missing FROM t_room_assign WHERE exam_slot_id = exam_slot_id;
    IF v_missing < (SELECT COUNT(*) FROM t_assignment WHERE exam_slot_id = exam_slot_id) THEN
      RAISE EXCEPTION 'Insufficient room capacity for slot %', exam_slot_id;
    END IF;
  END LOOP;

  -- Persist into exam_sitting (idempotent on reruns)
  INSERT INTO exam_sitting (offering_id, room_id, exam_slot_id)
  SELECT offering_id, room_id, exam_slot_id FROM t_room_assign
  ON CONFLICT (offering_id, exam_slot_id) DO NOTHING;

  -- Return the assignment summary
  RETURN QUERY
  SELECT offering_id, exam_slot_id, room_id FROM t_room_assign ORDER BY exam_slot_id;
END;
$$;
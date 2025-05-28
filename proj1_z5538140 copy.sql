-------------------------
-- Project 1 Solution Template
-- COMP9311 24T3
-- Name: DiKan
-- zID: z5538140
-------------------------


-- Q1 all good
DROP VIEW IF EXISTS Q1 CASCADE;
CREATE or REPLACE VIEW Q1(count) AS
SELECT COUNT(DISTINCT CE.student) AS count 
FROM COURSES C
JOIN COURSE_ENROLMENTS CE ON CE.course = C.id 
JOIN SUBJECTS S ON S.id = C.subject
WHERE CE.mark > 85 
AND S.code LIKE 'COMP%'
;




-- Q2 all good
DROP VIEW IF EXISTS Q2 CASCADE;
CREATE or REPLACE VIEW Q2(count) AS
SELECT COUNT(*) AS count
FROM (
    SELECT ce.student
    FROM COURSE_ENROLMENTS ce
    JOIN COURSES c ON ce.course = c.id
    JOIN SUBJECTS s ON c.subject = s.id
    WHERE s.code LIKE 'COMP%'
    AND ce.mark IS NOT NULL
    GROUP BY ce.student
    HAVING AVG(ce.mark) > 85
) AS t1;




-- Q3 all good
DROP VIEW IF EXISTS Q3 CASCADE;
CREATE or REPLACE VIEW Q3(unswid,name) AS
SELECT p.unswid, p.name
FROM people p
JOIN course_enrolments ce ON p.id = ce.student
JOIN courses c ON ce.course = c.id
JOIN subjects s ON c.subject = s.id
WHERE s.code LIKE 'COMP%'
AND ce.mark IS NOT NULL 
GROUP BY p.unswid, p.name
HAVING AVG(ce.mark) > 85 AND COUNT(ce.course) >= 6
;

-- Q4 
DROP VIEW IF EXISTS Q4 CASCADE;
CREATE or REPLACE VIEW Q4(unswid,name) AS
SELECT p.unswid, p.name
FROM people p
JOIN(
    SELECT ce.student,ce.course,ce.mark,s.id AS subject_id,s.uoc,
    ROW_NUMBER() OVER (PARTITION BY ce.student,s.id ORDER BY ce.mark DESC) AS rank
    FROM course_enrolments ce
    JOIN courses c ON ce.course = c.id
    JOIN subjects s ON c.subject = s.id
    WHERE s.code LIKE 'COMP%' AND ce.mark IS NOT NULL
) AS highest_marks ON p.id = highest_marks.student
WHERE highest_marks.rank = 1
GROUP BY p.unswid, p.name
HAVING COUNT(DISTINCT highest_marks.subject_id) >= 6 
AND CAST(SUM(highest_marks.mark * highest_marks.uoc) AS DOUBLE PRECISION) / CAST(SUM(highest_marks.uoc) AS DOUBLE PRECISION) > 85
;

-- Q5
DROP VIEW IF EXISTS Q5 CASCADE;
CREATE or REPLACE VIEW Q5(count) AS
SELECT COUNT(DISTINCT s.id) AS count
FROM subjects s
JOIN courses c ON c.subject = s.id
JOIN semesters sem ON c.semester = sem.id
JOIN orgunits o ON s.offeredby = o.id
WHERE o.longname = 'School of Computer Science and Engineering'
AND sem.year = 2012
;


-- Q6 
DROP VIEW IF EXISTS Q6 CASCADE;
CREATE or REPLACE VIEW Q6(count) AS
SELECT COUNT(DISTINCT cs.staff) AS count
FROM course_staff cs
JOIN staff_roles sr ON cs.role = sr.id
JOIN courses c ON cs.course = c.id
JOIN semesters sem ON c.semester = sem.id
JOIN affiliations aff ON cs.staff = aff.staff
JOIN orgunits o ON aff.orgunit = o.id
WHERE sr.name = 'Course Lecturer'
AND sem.year = 2012
AND o.longname = 'School of Computer Science and Engineering'
;

-- Q7
DROP VIEW IF EXISTS Q7 CASCADE;
CREATE or REPLACE VIEW Q7(course_id,unswid) AS
SELECT c.id AS course_id, p.unswid            
FROM courses c
JOIN subjects s ON c.subject = s.id
JOIN orgunits o ON s.offeredby = o.id
JOIN course_staff cs ON cs.course = c.id
JOIN staff_roles sr ON sr.id = cs.role
JOIN people p ON cs.staff = p.id
JOIN affiliations a ON a.staff = p.id
JOIN semesters sem ON c.semester = sem.id
WHERE o.longname = 'School of Computer Science and Engineering'   
AND sem.year = 2012                                         
AND sr.name = 'Course Lecturer'                          
AND a.orgunit = o.id                                        
GROUP BY  c.id, p.unswid
HAVING COUNT(DISTINCT cs.role) = 1;                               





-- Q8
DROP VIEW IF EXISTS Q8 CASCADE;
CREATE or REPLACE VIEW Q8(course_id,unswid) AS
SELECT c.id AS course_id, p.unswid            
FROM courses c
JOIN subjects s ON c.subject = s.id
JOIN orgunits o ON s.offeredby = o.id
JOIN course_staff cs ON cs.course = c.id
JOIN staff_roles sr ON sr.id = cs.role
JOIN people p ON cs.staff = p.id
JOIN affiliations a ON a.staff = p.id
JOIN semesters sem ON c.semester = sem.id
WHERE o.longname = 'School of Computer Science and Engineering'   
AND sem.year = 2012                                         
AND sr.name = 'Course Lecturer'                          
AND a.orgunit = o.id                                        
GROUP BY c.id, p.unswid
HAVING COUNT(DISTINCT cs.role) = 1;



-- Q9
DROP FUNCTION IF EXISTS Q9 CASCADE;
CREATE OR REPLACE FUNCTION Q9(subject1 integer, subject2 integer) 
RETURNS text AS $$
DECLARE
    subject1_code TEXT;
    subject2_prereq TEXT;
BEGIN
    -- 获取 subject1 的代码
    SELECT code INTO subject1_code
    FROM subjects
    WHERE id = subject1;

    -- 检查 subject1 是否存在
    IF NOT FOUND THEN
        RETURN 'Subject1 does not exist.';
    END IF;

    -- 获取 subject2 的先修课程信息
    SELECT _prereq INTO subject2_prereq
    FROM subjects
    WHERE id = subject2;

    -- 检查 subject2 是否存在
    IF NOT FOUND THEN
        RETURN 'Subject2 does not exist.';
    END IF;

    -- 检查 subject1_code 是否是 subject2_prereq 的子串
    IF subject2_prereq ILIKE '%' || subject1_code || '%' THEN
        RETURN subject1 || ' is a direct prerequisite of ' || subject2 || '.';
    ELSE
        RETURN subject1 || ' is not a direct prerequisite of ' || subject2 || '.';
    END IF;
END;
$$ LANGUAGE plpgsql;


-- Q10
DROP FUNCTION IF EXISTS Q10 CASCADE;
CREATE OR REPLACE FUNCTION Q10(subject1 integer, subject2 integer) 
RETURNS text AS $$
DECLARE
    subject1_code TEXT;
    subject2_code TEXT;
    course TEXT;
    prereq_courses TEXT[];  -- 用于存储匹配的课程代码
    subject_queue TEXT[] := '{}';  -- 初始化空队列
    flag BOOLEAN := FALSE;  -- 初始化标志
    current_subject TEXT;    -- 当前处理的课程代码
BEGIN
    -- 获取 subject1 的代码
    SELECT code INTO subject1_code
    FROM subjects
    WHERE id = subject1;

   
    IF NOT FOUND THEN
        RETURN 'Subject1 does not exist.';
    END IF;

    
    SELECT code INTO subject2_code
    FROM subjects
    WHERE id = subject2;

   
    IF NOT FOUND THEN
        RETURN 'Subject2 does not exist.';
    END IF;

    
    subject_queue := array_append(subject_queue, subject2_code);

    
    WHILE NOT flag AND array_length(subject_queue, 1) > 0 LOOP
        
        current_subject := subject_queue[array_length(subject_queue, 1)];
        subject_queue := subject_queue[1:array_length(subject_queue, 1) - 1];  

        
        DECLARE
            subject_prereq TEXT;
        BEGIN
            SELECT _prereq INTO subject_prereq
            FROM subjects
            WHERE code = current_subject;
            IF NOT FOUND THEN
                CONTINUE;  
            END IF;

            
            IF subject_prereq ILIKE '%' || subject1_code || '%' THEN
                flag := TRUE;  
            ELSE
                
                SELECT array_agg(match) INTO prereq_courses
                FROM regexp_matches(subject_prereq, '([A-Z]{4}[0-9]{4})', 'g') AS match;

                
                IF prereq_courses IS NOT NULL THEN
                    FOREACH course IN ARRAY prereq_courses
                    LOOP
                        subject_queue := array_append(subject_queue, TRIM(course));
                    END LOOP;
                END IF;
            END IF;
        END;
    END LOOP;

    -- 返回结果
    IF flag THEN
        RETURN subject1 || ' is a prerequisite of ' || subject2 || '.';
    ELSE
        RETURN subject1 || ' is not a prerequisite of ' || subject2 || '.';
    END IF;
END;
$$ LANGUAGE plpgsql;





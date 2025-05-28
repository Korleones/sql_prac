----------------------------------------------------------
--		COMP9311 24T3 Project 1
-- 		Project AutoTest File
-- 		MyMyUNSW Check
----------------------------------------------------------

SET client_min_messages TO WARNING;

-- check if a table exists, return true or false
create or replace function
	proj1_table_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_class
	where relname=tname and relkind='r';
	return (_check = 1);
end;
$$ language plpgsql;

-- check if a view exists, return true or false
create or replace function
	proj1_view_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_class
	where relname=tname and relkind='v';
	return (_check = 1);
end;
$$ language plpgsql;

-- check if a function exists, return true or false
create or replace function
	proj1_function_exists(tname text) returns boolean
as $$
declare
	_check integer := 0;
begin
	select count(*) into _check from pg_proc
	where proname=tname;
	return (_check > 0);
end;
$$ language plpgsql;

--------------------------------------------------------------
-- show warning if the tests are not run on the course server
---------------------------------------------------------------
DROP FUNCTION IF EXISTS version_warning_msg;
CREATE OR REPLACE FUNCTION version_warning_msg() RETURNS text AS $$
DECLARE
    version_info TEXT;
	warn_msg text;
BEGIN
    SELECT version() INTO version_info;
	warn_msg := '';
    IF position('PostgreSQL 13.14' IN version_info) = 0 THEN
        warn_msg := ' (Warning: Your PostgreSQL version may not be compatible with that of course server, please run this check on vxdb before submission.)';
		warn_msg := '';
	END IF;
	RETURN warn_msg;
END;
$$ LANGUAGE plpgsql;

--------------------------------------------------------------
-- proj1_check_result:
-- determines appropriate message, based on count of
-- excess and missing tuples in user output vs expected output
--------------------------------------------------------------

create or replace function
	proj1_check_result(_res text,nexcess integer, nmissing integer) returns text
as $$
begin
	if (nexcess = 0 and nmissing = 0) then
		return _res || ': correct.';
	elsif (nexcess > 0 and nmissing = 0) then
		return _res || ': too many tuples.';
	elsif (nexcess = 0 and nmissing > 0) then
		return _res || ': missing tuples.';
	elsif (nexcess > 0 and nmissing > 0) then
		return _res || ': incorrect.';
	end if;
end;
$$ language plpgsql;

--------------------------------------------------------------
-- proj1_check:
-- * compares output of user view/function against expected output
-- * returns string (text message) containing analysis of results
--  _type: 'view' or 'function'
--  _name: view or function name defined by student
--	_res: table name containing expected results, e.g. 'q1_expected'
--	_query: query string to be executed on student solution, e.g. $$select * from q1$$
-- Example: select proj1_check('view','q1','q1_expected',$$select * from q1$$)
--------------------------------------------------------------

create or replace function
	proj1_check(_type text, _name text, _res text, _query text) returns text
as $$
declare
	nexcess integer;
	nmissing integer;
	excessQ text;
	missingQ text;
	return_msg text;
begin
	return_msg := '';
	if (_type = 'view' and not proj1_view_exists(_name)) then
		return_msg := 'No '||_name||' view; did it load correctly?';
	elsif (_type = 'function' and not proj1_function_exists(_name)) then
		return_msg := 'No '||_name||' function; did it load correctly?';
	elsif (not proj1_table_exists(_res)) then
		return_msg := _res||': No expected results!';
	else
		excessQ := 'select count(*) '||
				 'from (('||_query||') except '||
				 '(select * from '||_res||')) as X';
		-- raise notice 'Q: %',excessQ;
		execute excessQ into nexcess;
		missingQ := 'select count(*) '||
					'from ((select * from '||_res||') '||
					'except ('||_query||')) as X';
		-- raise notice 'Q: %',missingQ;
		execute missingQ into nmissing;
		return_msg := proj1_check_result(regexp_replace(_res, '_expected$', ''),nexcess,nmissing);
	end if;
	return return_msg || version_warning_msg();
end;
$$ language plpgsql;



--------------------------------------------------------------
-- proj1_rescheck:
-- * compares output of user function against expected result
-- * returns string (text message) containing analysis of results
--------------------------------------------------------------

create or replace function
	proj1_rescheck(_type text, _name text, _res text, _query text) returns text
as $$
declare
	_sql text;
	_chk boolean;
begin
	if (_type = 'function' and not proj1_function_exists(_name)) then
		return 'No '||_name||' function; did it load correctly?';
	elsif (_res is null) then
		_sql := 'select ('||_query||') is null';
		-- raise notice 'SQL: %',_sql;
		execute _sql into _chk;
		-- raise notice 'CHK: %',_chk;
	else
		_sql := 'select ('||_query||') = '||quote_literal(_res);
		-- raise notice 'SQL: %',_sql;
		execute _sql into _chk;
		-- raise notice 'CHK: %',_chk;
	end if;
	if (_chk) then
		return 'correct';
	else
		return 'incorrect result';
	end if;
end;
$$ language plpgsql;

--------------------------------------------------------------
-- check_all:
-- * run all of the checks and return a table of results
--------------------------------------------------------------

drop type if exists TestingResult cascade;
create type TestingResult as (test text, result text);

create or replace function
	check_all() returns setof TestingResult
as $$
declare
	i int;
	testQ text;
	result text;
	out TestingResult;
	tests text[] := array['q1', 'q2', 'q3', 'q4', 'q5', 'q6', 'q7', 'q8', 'q9a', 'q9b', 'q9c', 'q9d', 'q9e', 'q9f', 'q10a', 'q10b', 'q10c', 'q10d', 'q10e', 'q10f'];
begin
	for i in array_lower(tests,1) .. array_upper(tests,1)
	loop
		testQ := 'select check_'||tests[i]||'()';
		execute testQ into result;
		out := (tests[i],result);
		return next out;
	end loop;
	return;
end;
$$ language plpgsql;


-----------------------Q1----------------

create or replace function check_q1() returns text as $chk$
select proj1_check('view','q1','q1_expected', $$select * from q1$$)
$chk$ language sql;

drop table if exists q1_expected;
create table q1_expected (
	count INTEGER
);

COPY q1_expected (count) FROM stdin;
794
\.
;

-- SELECT check_q1();

-----------------------Q2----------------

create or replace function check_q2() returns text as $chk$
select proj1_check('view','q2','q2_expected', $$select * from q2$$)
$chk$ language sql;

drop table if exists q2_expected;
create table q2_expected (
	count INTEGER
);

COPY q2_expected (count) FROM stdin;
282
\.
;

-- SELECT check_q2();




-----------------------q3----------------

create or replace function check_q3() returns text as $chk$
select proj1_check('view','q3','q3_expected', $$select * from q3$$)
$chk$ language sql;

drop table if exists q3_expected;
create table q3_expected (
	unswid INTEGER,
	name VARCHAR(128)
);

COPY q3_expected (unswid,name) FROM stdin;
3066859	Murphy Lok
3032240	Sarah Bitar
3144015	Ayako Kao
3003813	Helena Holmberg
3013980	Nicolas Courtot
3171417	David Rodway
3244504	Adam Shiao
3232152	Cosimo Mottey
3231195	Benjamin Barrington
3269260	Einat Rosenberg
3254031	Hong Nguyen Van
3279389	Kyung-Chuel Sun
3234675	Tomas Beer
3250411	Andrew Tan
3294545	Haysam Boag
3201489	Marco Murr
3270049	Brooke Kwai
3209070	Anthony Amos
3207247	Terri Hackett
3209249	Amanda Nesbitt
3278144	Robert McElroy
3329009	Nathania Sunandar Ng
3372638	Bryan Snudden
3356955	Karen Kerr
3380439	Seoh Ho
3320447	Susannah Jones
3386050	Marta Seruga
3378141	Damien Mc Phan
3334567	Christine Duan Linglan
3345244	Sophie King
3332547	Thamar Crossley
3354047	Jacqueline Pring
\.
;

-- SELECT check_q3();


-----------------------q4----------------

create or replace function check_q4() returns text as $chk$
select proj1_check('view','q4','q4_expected', $$select * from q4$$)
$chk$ language sql;

drop table if exists q4_expected;
create table q4_expected (
	unswid INTEGER,
	name VARCHAR(128)
);

COPY q4_expected (unswid,name) FROM stdin;
3332547	Thamar Crossley
3378141	Damien Mc Phan
3329009	Nathania Sunandar Ng
3372638	Bryan Snudden
3386050	Marta Seruga
3356955	Karen Kerr
3144015	Ayako Kao
3294545	Haysam Boag
3269260	Einat Rosenberg
3232152	Cosimo Mottey
3066859	Murphy Lok
3209070	Anthony Amos
3032240	Sarah Bitar
3254031	Hong Nguyen Van
3334567	Christine Duan Linglan
3244504	Adam Shiao
3279389	Kyung-Chuel Sun
3234675	Tomas Beer
3201489	Marco Murr
3354047	Jacqueline Pring
3209249	Amanda Nesbitt
3207247	Terri Hackett
3250411	Andrew Tan
3345244	Sophie King
3231195	Benjamin Barrington
3278144	Robert McElroy
3372020	Mark Kelleher
3171417	David Rodway
3003813	Helena Holmberg
3013980	Nicolas Courtot
3380439	Seoh Ho
3320447	Susannah Jones
3270049	Brooke Kwai
\.
;

-- SELECT check_q4();



-----------------------q5----------------

create or replace function check_q5() returns text as $chk$
select proj1_check('view','q5','q5_expected', $$select * from q5$$)
$chk$ language sql;

drop table if exists q5_expected;
create table q5_expected (
	count INTEGER
);

COPY q5_expected (count) FROM stdin;
114
\.
;

-- SELECT * from q5;
-- SELECT check_q5();


-----------------------q6----------------

create or replace function check_q6() returns text as $chk$
select proj1_check('view','q6','q6_expected', $$select * from q6$$)
$chk$ language sql;

drop table if exists q6_expected;
create table q6_expected (
	count INTEGER
);

COPY q6_expected (count) FROM stdin;
15
\.
;

-- SELECT check_q6();


-----------------------q7----------------

create or replace function check_q7() returns text as $chk$
select proj1_check('view','q7','q7_expected', $$select * from q7$$)
$chk$ language sql;

drop table if exists q7_expected;
create table q7_expected (
	course_id INTEGER,
	unswid INTEGER
);

COPY q7_expected (course_id,unswid) FROM stdin;
61475	9481907
61478	9481907
61694	9067316
61695	9707258
61696	9989352
61705	3018428
61737	3018428
61740	9794093
61749	9640108
62021	8959668
63712	8124783
63712	9640108
64971	9907698
64982	3340192
64985	3353841
64985	9607046
64991	9640108
65004	9178344
\.
;


-- SELECT check_q7();


-----------------------q8----------------

create or replace function check_q8() returns text as $chk$
select proj1_check('view','q8','q8_expected', $$select * from q8$$)
$chk$ language sql;

drop table if exists q8_expected;
create table q8_expected (
	course_id   INTEGER,
	unswid INTEGER
);

COPY q8_expected (course_id,unswid) FROM stdin;
61749	9640108
61740	9794093
61695	9707258
61694	9067316
61478	9481907
61737	3018428
61705	3018428
61475	9481907
64982	3340192
63712	8124783
63712	9640108
65004	9178344
64971	9907698
62021	8959668
61696	9989352
64991	9640108
64985	9607046
64985	3353841
\.
;

-- SELECT * from q8;
-- SELECT check_q8();



-----------------------q9a----------------

create or replace function check_q9a() returns text as $chk$
select proj1_check('function','q9','q9a_expected', $$select Q9(1891,1915)$$)
$chk$ language sql;

drop table if exists q9a_expected;
create table q9a_expected (
	q9 text
);

COPY q9a_expected (q9) FROM stdin;
1891 is a direct prerequisite of 1915.
\.
;

-- SELECT check_q9a();


-----------------------q9b----------------

create or replace function check_q9b() returns text as $chk$
select proj1_check('function','q9','q9b_expected', $$select Q9(1893,1915)$$)
$chk$ language sql;

drop table if exists q9b_expected;
create table q9b_expected (
	q9 text
);

COPY q9b_expected (q9) FROM stdin;
1893 is not a direct prerequisite of 1915.
\.
;

-- SELECT check_q9b();

-----------------------q9c----------------

create or replace function check_q9c() returns text as $chk$
select proj1_check('function','q9','q9c_expected', $$select q9(1318,1332)$$)
$chk$ language sql;

drop table if exists q9c_expected;
create table q9c_expected (
	q9 text
);

COPY q9c_expected (q9) FROM stdin;
1318 is a direct prerequisite of 1332.
\.
;

-- SELECT * from q9;
-- SELECT check_q9c();

-----------------------q9d----------------

create or replace function check_q9d() returns text as $chk$
select proj1_check('function','q9','q9d_expected', $$select q9(2220,1332)$$)
$chk$ language sql;

drop table if exists q9d_expected;
create table q9d_expected (
	q9 text
);

COPY q9d_expected (q9) FROM stdin;
2220 is not a direct prerequisite of 1332.
\.
;

-- SELECT check_q9d();



-----------------------q9e----------------

create or replace function check_q9e() returns text as $chk$
select proj1_check('function','q9','q9e_expected', $$select q9(1318,1339)$$)
$chk$ language sql;

drop table if exists q9e_expected;
create table q9e_expected (
	q9 text
);

COPY q9e_expected (q9) FROM stdin;
1318 is a direct prerequisite of 1339.
\.
;

-- SELECT check_q9e();




-----------------------q9f----------------

create or replace function check_q9f() returns text as $chk$
select proj1_check('function','q9','q9f_expected', $$select q9(1881,1339)$$)
$chk$ language sql;

drop table if exists q9f_expected;
create table q9f_expected (
	q9 text
);

COPY q9f_expected (q9) FROM stdin;
1881 is not a direct prerequisite of 1339.
\.
;

-- SELECT check_q9f();


-----------------------q10a----------------

create or replace function check_q10a() returns text as $chk$
select proj1_check('function','q10','q10a_expected', $$select q10(1863,1915)$$)
$chk$ language sql;

drop table if exists q10a_expected;
create table q10a_expected (
	q10 text
);

COPY q10a_expected (q10) FROM stdin;
1863 is a prerequisite of 1915.
\.
;

-- SELECT * from q10;
-- SELECT check_q10a();


-----------------------q10b----------------

create or replace function check_q10b() returns text as $chk$
select proj1_check('function','q10','q10b_expected', $$select q10(1867,1915)$$)
$chk$ language sql;

drop table if exists q10b_expected;
create table q10b_expected (
	q10 text
);

COPY q10b_expected (q10) FROM stdin;
1867 is a prerequisite of 1915.
\.
;

-- SELECT q10('COMP4601');
-- SELECT check_q10b();

-----------------------q10c----------------

create or replace function check_q10c() returns text as $chk$
select proj1_check('function','q10','q10c_expected', $$select q10(4897,1915)$$)
$chk$ language sql;

drop table if exists q10c_expected;
create table q10c_expected (
	q10 text
);

COPY q10c_expected (q10) FROM stdin;
4897 is not a prerequisite of 1915.
\.
;

-- SELECT * from q10;
-- SELECT check_q10c();

-----------------------q10d----------------

create or replace function check_q10d() returns text as $chk$
select proj1_check('function','q10','q10d_expected', $$select q10(1254,1339)$$)
$chk$ language sql;

drop table if exists q10d_expected;
create table q10d_expected (
	q10 text
);

COPY q10d_expected (q10) FROM stdin;
1254 is a prerequisite of 1339.
\.
;


-- SELECT check_q10d();

-----------------------q10e----------------

create or replace function check_q10e() returns text as $chk$
select proj1_check('function','q10','q10e_expected', $$select q10(1339,1339)$$)
$chk$ language sql;

drop table if exists q10e_expected;
create table q10e_expected (
	q10 text
);

COPY q10e_expected (q10) FROM stdin;
1339 is not a prerequisite of 1339.
\.
;

-- SELECT check_q10e();


-----------------------q10f----------------

create or replace function check_q10f() returns text as $chk$
select proj1_check('function','q10','q10f_expected', $$select q10(1862,1339)$$)
$chk$ language sql;

drop table if exists q10f_expected;
create table q10f_expected (
	q10 text
);

COPY q10f_expected (q10) FROM stdin;
1862 is not a prerequisite of 1339.
\.
;

-- SELECT * from q10;
-- SELECT check_q10f();


-- select CHECK_ALL();

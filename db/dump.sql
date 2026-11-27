--
-- PostgreSQL database dump
--


-- Dumped from database version 16.14 (Debian 16.14-1.pgdg13+1)
-- Dumped by pg_dump version 16.14 (Debian 16.14-1.pgdg13+1)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

ALTER TABLE IF EXISTS ONLY public.track DROP CONSTRAINT IF EXISTS track_coordinator_id_fkey;
ALTER TABLE IF EXISTS ONLY public.track DROP CONSTRAINT IF EXISTS track_conference_id_fkey;
ALTER TABLE IF EXISTS ONLY public.reviewer DROP CONSTRAINT IF EXISTS reviewer_reviewer_id_fkey;
ALTER TABLE IF EXISTS ONLY public.reviewer_expertise DROP CONSTRAINT IF EXISTS reviewer_expertise_reviewer_id_fkey;
ALTER TABLE IF EXISTS ONLY public.review DROP CONSTRAINT IF EXISTS review_reviewer_id_fkey;
ALTER TABLE IF EXISTS ONLY public.review DROP CONSTRAINT IF EXISTS review_paper_id_fkey;
ALTER TABLE IF EXISTS ONLY public.paper_version DROP CONSTRAINT IF EXISTS paper_version_paper_id_fkey;
ALTER TABLE IF EXISTS ONLY public.paper DROP CONSTRAINT IF EXISTS paper_track_id_fkey;
ALTER TABLE IF EXISTS ONLY public.paper DROP CONSTRAINT IF EXISTS paper_session_id_fkey;
ALTER TABLE IF EXISTS ONLY public.paper_keyword DROP CONSTRAINT IF EXISTS paper_keyword_paper_id_fkey;
ALTER TABLE IF EXISTS ONLY public.paper_author DROP CONSTRAINT IF EXISTS paper_author_paper_id_fkey;
ALTER TABLE IF EXISTS ONLY public.paper_author DROP CONSTRAINT IF EXISTS paper_author_author_id_fkey;
ALTER TABLE IF EXISTS ONLY public.conference_session DROP CONSTRAINT IF EXISTS conference_session_conference_id_fkey;
ALTER TABLE IF EXISTS ONLY public.conference_session DROP CONSTRAINT IF EXISTS conference_session_chair_id_fkey;
ALTER TABLE IF EXISTS ONLY public.conference_reviewer DROP CONSTRAINT IF EXISTS conference_reviewer_reviewer_id_fkey;
ALTER TABLE IF EXISTS ONLY public.conference_reviewer DROP CONSTRAINT IF EXISTS conference_reviewer_conference_id_fkey;
ALTER TABLE IF EXISTS ONLY public.conference_host DROP CONSTRAINT IF EXISTS conference_host_conference_id_fkey;
ALTER TABLE IF EXISTS ONLY public.author_research_area DROP CONSTRAINT IF EXISTS author_research_area_author_id_fkey;
ALTER TABLE IF EXISTS ONLY public.author DROP CONSTRAINT IF EXISTS author_author_id_fkey;
DROP INDEX IF EXISTS public.one_corresponding_author_per_paper;
ALTER TABLE IF EXISTS ONLY public.track DROP CONSTRAINT IF EXISTS track_pkey;
ALTER TABLE IF EXISTS ONLY public.track DROP CONSTRAINT IF EXISTS track_conference_id_name_key;
ALTER TABLE IF EXISTS ONLY public.reviewer DROP CONSTRAINT IF EXISTS reviewer_pkey;
ALTER TABLE IF EXISTS ONLY public.reviewer_expertise DROP CONSTRAINT IF EXISTS reviewer_expertise_pkey;
ALTER TABLE IF EXISTS ONLY public.review DROP CONSTRAINT IF EXISTS review_pkey;
ALTER TABLE IF EXISTS ONLY public.review DROP CONSTRAINT IF EXISTS review_paper_id_reviewer_id_key;
ALTER TABLE IF EXISTS ONLY public.paper_version DROP CONSTRAINT IF EXISTS paper_version_pkey;
ALTER TABLE IF EXISTS ONLY public.paper DROP CONSTRAINT IF EXISTS paper_pkey;
ALTER TABLE IF EXISTS ONLY public.paper_keyword DROP CONSTRAINT IF EXISTS paper_keyword_pkey;
ALTER TABLE IF EXISTS ONLY public.paper_author DROP CONSTRAINT IF EXISTS paper_author_pkey;
ALTER TABLE IF EXISTS ONLY public.paper_author DROP CONSTRAINT IF EXISTS paper_author_paper_id_author_position_key;
ALTER TABLE IF EXISTS ONLY public.conference_session DROP CONSTRAINT IF EXISTS conference_session_pkey;
ALTER TABLE IF EXISTS ONLY public.conference_reviewer DROP CONSTRAINT IF EXISTS conference_reviewer_pkey;
ALTER TABLE IF EXISTS ONLY public.conference DROP CONSTRAINT IF EXISTS conference_pkey;
ALTER TABLE IF EXISTS ONLY public.conference_host DROP CONSTRAINT IF EXISTS conference_host_pkey;
ALTER TABLE IF EXISTS ONLY public.author_research_area DROP CONSTRAINT IF EXISTS author_research_area_pkey;
ALTER TABLE IF EXISTS ONLY public.author DROP CONSTRAINT IF EXISTS author_pkey;
ALTER TABLE IF EXISTS ONLY public.author DROP CONSTRAINT IF EXISTS author_orcid_key;
ALTER TABLE IF EXISTS ONLY public.app_user DROP CONSTRAINT IF EXISTS app_user_pkey;
ALTER TABLE IF EXISTS ONLY public.app_user DROP CONSTRAINT IF EXISTS app_user_email_key;
DROP TABLE IF EXISTS public.reviewer_expertise;
DROP TABLE IF EXISTS public.reviewer;
DROP TABLE IF EXISTS public.review;
DROP TABLE IF EXISTS public.paper_version;
DROP TABLE IF EXISTS public.paper_keyword;
DROP TABLE IF EXISTS public.conference_reviewer;
DROP TABLE IF EXISTS public.conference_host;
DROP TABLE IF EXISTS public.author_research_area;
DROP TABLE IF EXISTS public.author;
DROP VIEW IF EXISTS public.accepted_paper_schedule;
DROP TABLE IF EXISTS public.track;
DROP TABLE IF EXISTS public.paper_author;
DROP TABLE IF EXISTS public.paper;
DROP TABLE IF EXISTS public.conference_session;
DROP TABLE IF EXISTS public.conference;
DROP TABLE IF EXISTS public.app_user;
SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: app_user; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.app_user (
    user_id integer NOT NULL,
    name character varying(100) NOT NULL,
    surname character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    affiliation character varying(200) NOT NULL,
    country character varying(100) NOT NULL,
    phone character varying(30) NOT NULL
);


--
-- Name: conference; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conference (
    conference_id integer NOT NULL,
    name character varying(200) NOT NULL,
    acronym character varying(30) NOT NULL,
    description text NOT NULL,
    city character varying(100) NOT NULL,
    country character varying(100) NOT NULL,
    start_date date NOT NULL,
    end_date date NOT NULL,
    submission_deadline date NOT NULL,
    review_deadline date NOT NULL,
    CONSTRAINT conference_check CHECK ((end_date >= start_date))
);


--
-- Name: conference_session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conference_session (
    session_id integer NOT NULL,
    conference_id integer NOT NULL,
    title character varying(200) NOT NULL,
    session_date date NOT NULL,
    start_time time without time zone NOT NULL,
    end_time time without time zone NOT NULL,
    room_label character varying(50) NOT NULL,
    chair_id integer NOT NULL,
    CONSTRAINT conference_session_check CHECK ((end_time > start_time))
);


--
-- Name: paper; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paper (
    paper_id integer NOT NULL,
    track_id integer NOT NULL,
    title character varying(300) NOT NULL,
    abstract text NOT NULL,
    submission_date date DEFAULT CURRENT_DATE NOT NULL,
    status character varying(20) DEFAULT 'submitted'::character varying NOT NULL,
    session_id integer,
    CONSTRAINT paper_status_check CHECK (((status)::text = ANY ((ARRAY['submitted'::character varying, 'under review'::character varying, 'accepted'::character varying, 'rejected'::character varying, 'withdrawn'::character varying])::text[])))
);


--
-- Name: paper_author; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paper_author (
    paper_id integer NOT NULL,
    author_id integer NOT NULL,
    author_position integer NOT NULL,
    is_corresponding boolean DEFAULT false NOT NULL,
    CONSTRAINT paper_author_author_position_check CHECK ((author_position > 0))
);


--
-- Name: track; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.track (
    track_id integer NOT NULL,
    conference_id integer NOT NULL,
    name character varying(200) NOT NULL,
    description text,
    research_area character varying(100) NOT NULL,
    coordinator_id integer NOT NULL
);


--
-- Name: accepted_paper_schedule; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.accepted_paper_schedule AS
 SELECT p.paper_id,
    p.title AS paper_title,
    c.conference_id,
    c.acronym,
    t.name AS track_name,
    s.session_id,
    s.title AS session_title,
    s.session_date,
    s.start_time,
    s.end_time,
    s.room_label,
    (((chair.name)::text || ' '::text) || (chair.surname)::text) AS chair_name,
    (((ca.name)::text || ' '::text) || (ca.surname)::text) AS corresponding_author_name,
    ca.email AS corresponding_author_email
   FROM ((((((public.paper p
     JOIN public.track t ON ((t.track_id = p.track_id)))
     JOIN public.conference_session s ON ((s.session_id = p.session_id)))
     JOIN public.conference c ON ((c.conference_id = s.conference_id)))
     JOIN public.app_user chair ON ((chair.user_id = s.chair_id)))
     JOIN public.paper_author pa ON (((pa.paper_id = p.paper_id) AND pa.is_corresponding)))
     JOIN public.app_user ca ON ((ca.user_id = pa.author_id)));


--
-- Name: app_user_user_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.app_user ALTER COLUMN user_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.app_user_user_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: author; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.author (
    author_id integer NOT NULL,
    orcid character varying(19)
);


--
-- Name: author_research_area; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.author_research_area (
    author_id integer NOT NULL,
    area_label character varying(100) NOT NULL
);


--
-- Name: conference_conference_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.conference ALTER COLUMN conference_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.conference_conference_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: conference_host; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conference_host (
    conference_id integer NOT NULL,
    host_name character varying(200) NOT NULL
);


--
-- Name: conference_reviewer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.conference_reviewer (
    conference_id integer NOT NULL,
    reviewer_id integer NOT NULL
);


--
-- Name: conference_session_session_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.conference_session ALTER COLUMN session_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.conference_session_session_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: paper_keyword; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paper_keyword (
    paper_id integer NOT NULL,
    keyword character varying(100) NOT NULL
);


--
-- Name: paper_paper_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.paper ALTER COLUMN paper_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.paper_paper_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: paper_version; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.paper_version (
    paper_id integer NOT NULL,
    version_no integer NOT NULL,
    file_location character varying(500) NOT NULL,
    uploaded_at timestamp without time zone DEFAULT CURRENT_TIMESTAMP NOT NULL,
    change_note text,
    CONSTRAINT paper_version_version_no_check CHECK ((version_no > 0))
);


--
-- Name: review; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.review (
    review_id integer NOT NULL,
    paper_id integer NOT NULL,
    reviewer_id integer NOT NULL,
    overall_score integer NOT NULL,
    recommendation character varying(10) NOT NULL,
    comments_for_authors text NOT NULL,
    confidential_comments text,
    review_submission_date date DEFAULT CURRENT_DATE NOT NULL,
    CONSTRAINT review_overall_score_check CHECK (((overall_score >= 1) AND (overall_score <= 5))),
    CONSTRAINT review_recommendation_check CHECK (((recommendation)::text = ANY ((ARRAY['accept'::character varying, 'reject'::character varying])::text[])))
);


--
-- Name: review_review_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.review ALTER COLUMN review_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.review_review_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Name: reviewer; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviewer (
    reviewer_id integer NOT NULL,
    years_experience integer NOT NULL,
    CONSTRAINT reviewer_years_experience_check CHECK ((years_experience >= 0))
);


--
-- Name: reviewer_expertise; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reviewer_expertise (
    reviewer_id integer NOT NULL,
    area_label character varying(100) NOT NULL
);


--
-- Name: track_track_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

ALTER TABLE public.track ALTER COLUMN track_id ADD GENERATED BY DEFAULT AS IDENTITY (
    SEQUENCE NAME public.track_track_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);


--
-- Data for Name: app_user; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.app_user (user_id, name, surname, email, affiliation, country, phone) VALUES (1, 'Arman', 'Armanov', 'arman.armanov@example.com', 'Nazarbayev University', 'Kazakhstan', '+77001112233');
INSERT INTO public.app_user (user_id, name, surname, email, affiliation, country, phone) VALUES (2, 'Amina', 'Aminova', 'amina.aminova@example.com', 'KBTU', 'Kazakhstan', '+77015556677');
INSERT INTO public.app_user (user_id, name, surname, email, affiliation, country, phone) VALUES (3, 'Daniyar', 'Sarsenov', 'daniyar.sarsenov@example.com', 'Astana IT University', 'Kazakhstan', '+12025550103');
INSERT INTO public.app_user (user_id, name, surname, email, affiliation, country, phone) VALUES (4, 'Aigerim', 'Nurlanova', 'aigerim.nurlanova@example.com', 'SDU University', 'Kazakhstan', '+77025553344');
INSERT INTO public.app_user (user_id, name, surname, email, affiliation, country, phone) VALUES (5, 'Timur', 'Bekov', 'timur.bekov@example.com', 'TU Berlin', 'Germany', '+4915112345678');
INSERT INTO public.app_user (user_id, name, surname, email, affiliation, country, phone) VALUES (6, 'Madina', 'Omarova', 'madina.omarova@example.com', 'Nazarbayev University', 'Kazakhstan', '+12025550106');
INSERT INTO public.app_user (user_id, name, surname, email, affiliation, country, phone) VALUES (7, 'Yerlan', 'Kassym', 'yerlan.kassym@example.com', 'Al-Farabi University', 'Kazakhstan', '+12025550107');
INSERT INTO public.app_user (user_id, name, surname, email, affiliation, country, phone) VALUES (8, 'Dana', 'Serik', 'dana.serik@example.com', 'Astana IT University', 'Kazakhstan', '+77019998877');
INSERT INTO public.app_user (user_id, name, surname, email, affiliation, country, phone) VALUES (9, 'Ivan', 'Petrov', 'ivan.petrov@example.com', 'MIPT', 'Russia', '+12025550109');
INSERT INTO public.app_user (user_id, name, surname, email, affiliation, country, phone) VALUES (10, 'Sofia', 'Rossi', 'sofia.rossi@example.com', 'Politecnico di Milano', 'Italy', '+393331234567');
INSERT INTO public.app_user (user_id, name, surname, email, affiliation, country, phone) VALUES (11, 'Wei', 'Chen', 'wei.chen@example.com', 'Tsinghua University', 'China', '+12025550111');
INSERT INTO public.app_user (user_id, name, surname, email, affiliation, country, phone) VALUES (12, 'Laura', 'Smith', 'laura.smith@example.com', 'University of Leeds', 'United Kingdom', '+447700900123');


--
-- Data for Name: author; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.author (author_id, orcid) VALUES (1, '0000-0001-1111-0001');
INSERT INTO public.author (author_id, orcid) VALUES (2, '0000-0001-1111-0002');
INSERT INTO public.author (author_id, orcid) VALUES (3, NULL);
INSERT INTO public.author (author_id, orcid) VALUES (4, '0000-0001-1111-0004');
INSERT INTO public.author (author_id, orcid) VALUES (5, NULL);
INSERT INTO public.author (author_id, orcid) VALUES (9, '0000-0001-1111-0009');
INSERT INTO public.author (author_id, orcid) VALUES (11, '0000-0001-1111-0011');
INSERT INTO public.author (author_id, orcid) VALUES (12, NULL);


--
-- Data for Name: author_research_area; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.author_research_area (author_id, area_label) VALUES (1, 'Databases');
INSERT INTO public.author_research_area (author_id, area_label) VALUES (2, 'Software Engineering');
INSERT INTO public.author_research_area (author_id, area_label) VALUES (2, 'Security');
INSERT INTO public.author_research_area (author_id, area_label) VALUES (3, 'Machine Learning');
INSERT INTO public.author_research_area (author_id, area_label) VALUES (4, 'Machine Learning');
INSERT INTO public.author_research_area (author_id, area_label) VALUES (4, 'NLP');
INSERT INTO public.author_research_area (author_id, area_label) VALUES (5, 'Databases');
INSERT INTO public.author_research_area (author_id, area_label) VALUES (9, 'Databases');
INSERT INTO public.author_research_area (author_id, area_label) VALUES (11, 'Machine Learning');
INSERT INTO public.author_research_area (author_id, area_label) VALUES (12, 'Software Engineering');


--
-- Data for Name: conference; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.conference (conference_id, name, acronym, description, city, country, start_date, end_date, submission_deadline, review_deadline) VALUES (1, 'Astana International Conference on Data Science', 'ASDS 2026', 'Data science, machine learning and databases.', 'Astana', 'Kazakhstan', '2026-09-10', '2026-09-12', '2026-05-01', '2026-06-15');
INSERT INTO public.conference (conference_id, name, acronym, description, city, country, start_date, end_date, submission_deadline, review_deadline) VALUES (2, 'Berlin Symposium on Software Systems', 'BSSS 2026', 'Software engineering and distributed systems.', 'Berlin', 'Germany', '2026-10-20', '2026-10-22', '2026-06-01', '2026-07-20');
INSERT INTO public.conference (conference_id, name, acronym, description, city, country, start_date, end_date, submission_deadline, review_deadline) VALUES (3, 'Almaty Workshop on Wireless Networks', 'AWN 2026', 'Research on wireless networking, mobile systems and communications.', 'Almaty', 'Kazakhstan', '2026-11-05', '2026-11-06', '2026-07-15', '2026-09-01');


--
-- Data for Name: conference_host; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.conference_host (conference_id, host_name) VALUES (1, 'Nazarbayev University');
INSERT INTO public.conference_host (conference_id, host_name) VALUES (1, 'Astana IT University');
INSERT INTO public.conference_host (conference_id, host_name) VALUES (2, 'TU Berlin');
INSERT INTO public.conference_host (conference_id, host_name) VALUES (3, 'Almaty Technical University');


--
-- Data for Name: conference_reviewer; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (1, 1);
INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (1, 5);
INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (1, 6);
INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (1, 7);
INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (1, 8);
INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (1, 11);
INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (2, 5);
INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (2, 6);
INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (2, 7);
INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (2, 10);
INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (2, 11);
INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (3, 6);
INSERT INTO public.conference_reviewer (conference_id, reviewer_id) VALUES (3, 10);


--
-- Data for Name: conference_session; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.conference_session (session_id, conference_id, title, session_date, start_time, end_time, room_label, chair_id) VALUES (1, 1, 'Machine Learning Applications', '2026-09-10', '09:00:00', '10:30:00', 'Room A101', 6);
INSERT INTO public.conference_session (session_id, conference_id, title, session_date, start_time, end_time, room_label, chair_id) VALUES (2, 1, 'Data Management Trends', '2026-09-10', '11:00:00', '12:30:00', 'Room A102', 1);
INSERT INTO public.conference_session (session_id, conference_id, title, session_date, start_time, end_time, room_label, chair_id) VALUES (3, 1, 'Poster Discussion', '2026-09-11', '14:00:00', '15:00:00', 'Hall B', 11);
INSERT INTO public.conference_session (session_id, conference_id, title, session_date, start_time, end_time, room_label, chair_id) VALUES (4, 2, 'Software Quality', '2026-10-20', '10:00:00', '11:30:00', 'Room B1', 5);
INSERT INTO public.conference_session (session_id, conference_id, title, session_date, start_time, end_time, room_label, chair_id) VALUES (5, 2, 'Closing Session', '2026-10-22', '15:00:00', '16:00:00', 'Room B2', 7);


--
-- Data for Name: paper; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (1, 1, 'Deep Learning for Cashier Behavior Analysis', 'We apply machine learning to detect cashier actions in store video.', '2026-04-10', 'accepted', 1);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (2, 1, 'Transformer Models for Kazakh Text Classification', 'A study of Machine Learning methods for low-resource language classification.', '2026-04-12', 'accepted', 1);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (3, 2, 'Query Optimization in Distributed Databases', 'We propose a cost model for joins across distributed nodes.', '2026-04-14', 'accepted', 2);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (4, 2, 'Indexing Strategies for Time-Series Data', 'We compare index structures for sensor data workloads.', '2026-04-15', 'accepted', NULL);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (5, 1, 'Federated Learning under Limited Bandwidth', 'This paper studies machine learning when clients have little bandwidth.', '2026-04-18', 'under review', NULL);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (6, 2, 'Schema Evolution in NoSQL Systems', 'We analyze how schemas change over time in document stores.', '2026-04-20', 'submitted', NULL);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (7, 1, 'Bias in Automated Resume Screening', 'We measure bias in learning machines used for hiring.', '2026-04-22', 'rejected', NULL);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (8, 4, 'Static Analysis for Python Type Errors', 'We present a checker that finds type errors without running code.', '2026-05-05', 'accepted', 4);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (9, 4, 'Mutation Testing at Scale', 'Mutation testing techniques for large code bases.', '2026-05-08', 'accepted', NULL);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (10, 5, 'Congestion Control in Data Centers', 'We evaluate congestion control algorithms in data center networks.', '2026-05-10', 'rejected', NULL);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (11, 5, 'Edge Caching with Learned Policies', 'Learned cache replacement policies for edge servers.', '2026-05-12', 'under review', NULL);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (12, 4, 'Continuous Integration Practices in Startups', 'A survey of CI pipelines in early-stage companies.', '2026-05-14', 'withdrawn', NULL);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (13, 2, 'Privacy-Preserving Query Processing', 'Answering queries over encrypted data.', '2026-04-25', 'withdrawn', NULL);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (14, 2, 'Data Lake Governance Frameworks', 'We review governance practices for data lakes.', '2026-04-26', 'withdrawn', NULL);
INSERT INTO public.paper (paper_id, track_id, title, abstract, submission_date, status, session_id) VALUES (15, 2, 'Benchmarking Graph Databases', 'A benchmark of graph database engines.', '2026-04-28', 'submitted', NULL);


--
-- Data for Name: paper_author; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (1, 3, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (1, 4, 2, false);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (2, 4, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (2, 9, 2, false);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (3, 5, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (3, 12, 2, false);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (4, 9, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (5, 11, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (5, 3, 2, false);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (6, 12, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (7, 9, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (7, 4, 2, false);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (8, 12, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (8, 1, 2, false);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (9, 11, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (10, 3, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (10, 5, 2, false);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (11, 4, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (12, 2, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (12, 12, 2, false);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (13, 2, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (13, 9, 2, false);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (14, 9, 1, true);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (14, 2, 2, false);
INSERT INTO public.paper_author (paper_id, author_id, author_position, is_corresponding) VALUES (15, 2, 1, true);


--
-- Data for Name: paper_keyword; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (1, 'deep learning');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (1, 'video analysis');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (2, 'transformers');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (2, 'text classification');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (3, 'query optimization');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (3, 'distributed systems');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (4, 'indexing');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (4, 'time series');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (5, 'federated learning');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (5, 'bandwidth');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (6, 'schema evolution');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (6, 'NoSQL');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (7, 'bias');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (7, 'hiring');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (8, 'static analysis');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (8, 'Python');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (9, 'mutation testing');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (9, 'software quality');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (10, 'congestion control');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (10, 'data centers');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (11, 'edge caching');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (11, 'learned policies');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (12, 'continuous integration');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (12, 'startups');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (13, 'privacy');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (13, 'encrypted queries');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (14, 'data lakes');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (14, 'governance');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (15, 'graph databases');
INSERT INTO public.paper_keyword (paper_id, keyword) VALUES (15, 'benchmarks');


--
-- Data for Name: paper_version; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (1, 1, 'papers/p1/v1.pdf', '2026-04-10 10:00:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (1, 2, 'papers/p1/v2.pdf', '2026-04-20 11:30:00', 'Fixed figures');
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (1, 4, 'papers/p1/v4.pdf', '2026-05-25 09:15:00', 'Camera-ready version');
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (2, 1, 'papers/p2/v1.pdf', '2026-04-12 12:00:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (2, 2, 'papers/p2/v2.pdf', '2026-05-02 16:45:00', 'Added experiments');
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (3, 1, 'papers/p3/v1.pdf', '2026-04-14 09:00:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (4, 1, 'papers/p4/v1.pdf', '2026-04-15 14:00:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (4, 3, 'papers/p4/v3.pdf', '2026-05-30 10:10:00', 'Camera-ready version');
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (5, 1, 'papers/p5/v1.pdf', '2026-04-18 08:30:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (6, 1, 'papers/p6/v1.pdf', '2026-04-20 17:00:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (7, 1, 'papers/p7/v1.pdf', '2026-04-22 13:20:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (7, 2, 'papers/p7/v2.pdf', '2026-05-01 10:00:00', 'Responded to feedback');
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (8, 1, 'papers/p8/v1.pdf', '2026-05-05 09:45:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (8, 2, 'papers/p8/v2.pdf', '2026-06-20 15:00:00', 'Camera-ready version');
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (9, 1, 'papers/p9/v1.pdf', '2026-05-08 11:00:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (10, 1, 'papers/p10/v1.pdf', '2026-05-10 10:30:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (11, 1, 'papers/p11/v1.pdf', '2026-05-12 12:30:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (12, 1, 'papers/p12/v1.pdf', '2026-05-14 09:00:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (13, 1, 'papers/p13/v1.pdf', '2026-04-25 09:30:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (13, 2, 'papers/p13/v2.pdf', '2026-05-05 14:30:00', 'Shortened');
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (14, 1, 'papers/p14/v1.pdf', '2026-04-26 10:00:00', NULL);
INSERT INTO public.paper_version (paper_id, version_no, file_location, uploaded_at, change_note) VALUES (15, 1, 'papers/p15/v1.pdf', '2026-04-28 16:00:00', NULL);


--
-- Data for Name: review; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (1, 1, 6, 5, 'accept', 'Strong results and clear writing.', NULL, '2026-05-20');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (2, 1, 1, 4, 'accept', 'Good paper, minor typos.', 'Solid work.', '2026-05-22');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (3, 1, 11, 4, 'accept', 'Convincing evaluation.', NULL, '2026-05-24');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (4, 2, 6, 4, 'accept', 'Interesting dataset.', NULL, '2026-05-21');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (5, 2, 1, 3, 'accept', 'Needs more baselines.', 'Borderline but fine.', '2026-05-23');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (6, 3, 6, 5, 'accept', 'Excellent cost model.', NULL, '2026-05-26');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (7, 3, 11, 4, 'accept', 'Clear contribution.', NULL, '2026-05-27');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (8, 4, 1, 4, 'accept', 'Useful comparison.', NULL, '2026-05-28');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (9, 7, 6, 2, 'reject', 'Weak methodology.', 'Not ready.', '2026-05-29');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (10, 7, 11, 1, 'reject', 'Conclusions are not supported.', NULL, '2026-05-30');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (11, 5, 1, 3, 'accept', 'Promising but incomplete.', NULL, '2026-06-02');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (12, 8, 5, 5, 'accept', 'Very practical tool.', NULL, '2026-06-25');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (13, 8, 7, 4, 'accept', 'Well evaluated.', NULL, '2026-06-26');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (14, 9, 6, 4, 'accept', 'Solid engineering.', NULL, '2026-06-28');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (15, 10, 7, 2, 'reject', 'Old baselines.', 'Weak novelty.', '2026-07-01');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (16, 10, 10, 2, 'reject', 'Results not reproducible.', NULL, '2026-07-02');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (17, 13, 7, 2, 'reject', 'Threat model is unclear.', NULL, '2026-05-18');
INSERT INTO public.review (review_id, paper_id, reviewer_id, overall_score, recommendation, comments_for_authors, confidential_comments, review_submission_date) VALUES (18, 11, 10, 3, 'accept', 'Needs a larger evaluation.', NULL, '2026-07-05');


--
-- Data for Name: reviewer; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.reviewer (reviewer_id, years_experience) VALUES (1, 6);
INSERT INTO public.reviewer (reviewer_id, years_experience) VALUES (5, 4);
INSERT INTO public.reviewer (reviewer_id, years_experience) VALUES (6, 8);
INSERT INTO public.reviewer (reviewer_id, years_experience) VALUES (7, 2);
INSERT INTO public.reviewer (reviewer_id, years_experience) VALUES (8, 5);
INSERT INTO public.reviewer (reviewer_id, years_experience) VALUES (10, 3);
INSERT INTO public.reviewer (reviewer_id, years_experience) VALUES (11, 7);


--
-- Data for Name: reviewer_expertise; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (1, 'Databases');
INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (1, 'Machine Learning');
INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (5, 'Databases');
INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (5, 'Networks');
INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (6, 'Machine Learning');
INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (6, 'NLP');
INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (7, 'Databases');
INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (8, 'Databases');
INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (8, 'Security');
INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (10, 'Networks');
INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (10, 'Security');
INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (11, 'Machine Learning');
INSERT INTO public.reviewer_expertise (reviewer_id, area_label) VALUES (11, 'Databases');


--
-- Data for Name: track; Type: TABLE DATA; Schema: public; Owner: -
--

INSERT INTO public.track (track_id, conference_id, name, description, research_area, coordinator_id) VALUES (1, 1, 'Machine Learning', 'Learning methods and applications.', 'Machine Learning', 6);
INSERT INTO public.track (track_id, conference_id, name, description, research_area, coordinator_id) VALUES (2, 1, 'Databases and Data Engineering', 'Storage, queries and pipelines.', 'Databases', 1);
INSERT INTO public.track (track_id, conference_id, name, description, research_area, coordinator_id) VALUES (3, 1, 'Security and Privacy', 'Empty track.', 'Security', 11);
INSERT INTO public.track (track_id, conference_id, name, description, research_area, coordinator_id) VALUES (4, 2, 'Software Engineering', 'Testing and analysis.', 'Software Engineering', 5);
INSERT INTO public.track (track_id, conference_id, name, description, research_area, coordinator_id) VALUES (5, 2, 'Networks and Systems', 'Networking and systems.', 'Networks', 10);
INSERT INTO public.track (track_id, conference_id, name, description, research_area, coordinator_id) VALUES (6, 3, 'Wireless Networks', 'Conference without papers.', 'Networks', 6);


--
-- Name: app_user_user_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.app_user_user_id_seq', 12, true);


--
-- Name: conference_conference_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.conference_conference_id_seq', 3, true);


--
-- Name: conference_session_session_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.conference_session_session_id_seq', 5, true);


--
-- Name: paper_paper_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.paper_paper_id_seq', 15, true);


--
-- Name: review_review_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.review_review_id_seq', 18, true);


--
-- Name: track_track_id_seq; Type: SEQUENCE SET; Schema: public; Owner: -
--

SELECT pg_catalog.setval('public.track_track_id_seq', 6, true);


--
-- Name: app_user app_user_email_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_email_key UNIQUE (email);


--
-- Name: app_user app_user_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.app_user
    ADD CONSTRAINT app_user_pkey PRIMARY KEY (user_id);


--
-- Name: author author_orcid_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.author
    ADD CONSTRAINT author_orcid_key UNIQUE (orcid);


--
-- Name: author author_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.author
    ADD CONSTRAINT author_pkey PRIMARY KEY (author_id);


--
-- Name: author_research_area author_research_area_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.author_research_area
    ADD CONSTRAINT author_research_area_pkey PRIMARY KEY (author_id, area_label);


--
-- Name: conference_host conference_host_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conference_host
    ADD CONSTRAINT conference_host_pkey PRIMARY KEY (conference_id, host_name);


--
-- Name: conference conference_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conference
    ADD CONSTRAINT conference_pkey PRIMARY KEY (conference_id);


--
-- Name: conference_reviewer conference_reviewer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conference_reviewer
    ADD CONSTRAINT conference_reviewer_pkey PRIMARY KEY (conference_id, reviewer_id);


--
-- Name: conference_session conference_session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conference_session
    ADD CONSTRAINT conference_session_pkey PRIMARY KEY (session_id);


--
-- Name: paper_author paper_author_paper_id_author_position_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paper_author
    ADD CONSTRAINT paper_author_paper_id_author_position_key UNIQUE (paper_id, author_position);


--
-- Name: paper_author paper_author_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paper_author
    ADD CONSTRAINT paper_author_pkey PRIMARY KEY (paper_id, author_id);


--
-- Name: paper_keyword paper_keyword_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paper_keyword
    ADD CONSTRAINT paper_keyword_pkey PRIMARY KEY (paper_id, keyword);


--
-- Name: paper paper_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paper
    ADD CONSTRAINT paper_pkey PRIMARY KEY (paper_id);


--
-- Name: paper_version paper_version_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paper_version
    ADD CONSTRAINT paper_version_pkey PRIMARY KEY (paper_id, version_no);


--
-- Name: review review_paper_id_reviewer_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review
    ADD CONSTRAINT review_paper_id_reviewer_id_key UNIQUE (paper_id, reviewer_id);


--
-- Name: review review_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review
    ADD CONSTRAINT review_pkey PRIMARY KEY (review_id);


--
-- Name: reviewer_expertise reviewer_expertise_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewer_expertise
    ADD CONSTRAINT reviewer_expertise_pkey PRIMARY KEY (reviewer_id, area_label);


--
-- Name: reviewer reviewer_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewer
    ADD CONSTRAINT reviewer_pkey PRIMARY KEY (reviewer_id);


--
-- Name: track track_conference_id_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.track
    ADD CONSTRAINT track_conference_id_name_key UNIQUE (conference_id, name);


--
-- Name: track track_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.track
    ADD CONSTRAINT track_pkey PRIMARY KEY (track_id);


--
-- Name: one_corresponding_author_per_paper; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX one_corresponding_author_per_paper ON public.paper_author USING btree (paper_id) WHERE is_corresponding;


--
-- Name: author author_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.author
    ADD CONSTRAINT author_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.app_user(user_id) ON DELETE CASCADE;


--
-- Name: author_research_area author_research_area_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.author_research_area
    ADD CONSTRAINT author_research_area_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.author(author_id) ON DELETE CASCADE;


--
-- Name: conference_host conference_host_conference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conference_host
    ADD CONSTRAINT conference_host_conference_id_fkey FOREIGN KEY (conference_id) REFERENCES public.conference(conference_id) ON DELETE CASCADE;


--
-- Name: conference_reviewer conference_reviewer_conference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conference_reviewer
    ADD CONSTRAINT conference_reviewer_conference_id_fkey FOREIGN KEY (conference_id) REFERENCES public.conference(conference_id) ON DELETE CASCADE;


--
-- Name: conference_reviewer conference_reviewer_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conference_reviewer
    ADD CONSTRAINT conference_reviewer_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.reviewer(reviewer_id) ON DELETE CASCADE;


--
-- Name: conference_session conference_session_chair_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conference_session
    ADD CONSTRAINT conference_session_chair_id_fkey FOREIGN KEY (chair_id) REFERENCES public.reviewer(reviewer_id) ON DELETE RESTRICT;


--
-- Name: conference_session conference_session_conference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.conference_session
    ADD CONSTRAINT conference_session_conference_id_fkey FOREIGN KEY (conference_id) REFERENCES public.conference(conference_id) ON DELETE CASCADE;


--
-- Name: paper_author paper_author_author_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paper_author
    ADD CONSTRAINT paper_author_author_id_fkey FOREIGN KEY (author_id) REFERENCES public.author(author_id) ON DELETE RESTRICT;


--
-- Name: paper_author paper_author_paper_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paper_author
    ADD CONSTRAINT paper_author_paper_id_fkey FOREIGN KEY (paper_id) REFERENCES public.paper(paper_id) ON DELETE CASCADE;


--
-- Name: paper_keyword paper_keyword_paper_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paper_keyword
    ADD CONSTRAINT paper_keyword_paper_id_fkey FOREIGN KEY (paper_id) REFERENCES public.paper(paper_id) ON DELETE CASCADE;


--
-- Name: paper paper_session_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paper
    ADD CONSTRAINT paper_session_id_fkey FOREIGN KEY (session_id) REFERENCES public.conference_session(session_id) ON DELETE SET NULL;


--
-- Name: paper paper_track_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paper
    ADD CONSTRAINT paper_track_id_fkey FOREIGN KEY (track_id) REFERENCES public.track(track_id) ON DELETE RESTRICT;


--
-- Name: paper_version paper_version_paper_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.paper_version
    ADD CONSTRAINT paper_version_paper_id_fkey FOREIGN KEY (paper_id) REFERENCES public.paper(paper_id) ON DELETE CASCADE;


--
-- Name: review review_paper_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review
    ADD CONSTRAINT review_paper_id_fkey FOREIGN KEY (paper_id) REFERENCES public.paper(paper_id) ON DELETE CASCADE;


--
-- Name: review review_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.review
    ADD CONSTRAINT review_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.reviewer(reviewer_id) ON DELETE RESTRICT;


--
-- Name: reviewer_expertise reviewer_expertise_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewer_expertise
    ADD CONSTRAINT reviewer_expertise_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.reviewer(reviewer_id) ON DELETE CASCADE;


--
-- Name: reviewer reviewer_reviewer_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reviewer
    ADD CONSTRAINT reviewer_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.app_user(user_id) ON DELETE CASCADE;


--
-- Name: track track_conference_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.track
    ADD CONSTRAINT track_conference_id_fkey FOREIGN KEY (conference_id) REFERENCES public.conference(conference_id) ON DELETE CASCADE;


--
-- Name: track track_coordinator_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.track
    ADD CONSTRAINT track_coordinator_id_fkey FOREIGN KEY (coordinator_id) REFERENCES public.reviewer(reviewer_id) ON DELETE RESTRICT;


--
-- PostgreSQL database dump complete
--



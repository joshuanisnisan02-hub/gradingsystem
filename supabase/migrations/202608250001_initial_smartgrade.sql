create extension if not exists pgcrypto;

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  role text not null default 'teacher' check (role in ('teacher','administrator','viewer')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.school_years (
  id uuid primary key default gen_random_uuid(),
  label text not null unique,
  is_active boolean not null default false,
  archived_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.terms (
  id uuid primary key default gen_random_uuid(),
  school_year_id uuid not null references public.school_years(id),
  name text not null check (name in ('First Semester','Second Semester','Summer')),
  is_active boolean not null default false,
  archived_at timestamptz,
  unique (school_year_id, name)
);

create table public.classes (
  id uuid primary key default gen_random_uuid(),
  teacher_id uuid not null references public.profiles(id),
  term_id uuid references public.terms(id),
  subject_code text not null,
  subject_title text not null,
  section text not null,
  course text,
  year_level text,
  schedule text,
  room text,
  status text not null default 'active' check (status in ('active','archived')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.students (
  id uuid primary key default gen_random_uuid(),
  student_number text not null unique,
  last_name text not null,
  first_name text not null,
  middle_name text,
  suffix text,
  email text,
  course text,
  year_level text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.class_enrollments (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id),
  student_id uuid not null references public.students(id),
  status text not null default 'active' check (status in ('active','dropped','withdrawn','incomplete')),
  enrolled_at timestamptz not null default now(),
  unique (class_id, student_id)
);

create table public.assessment_items (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id),
  grading_period text not null default 'prelim' check (grading_period in ('prelim','midterm','prefinal','final')),
  category text not null check (category in ('quiz','activity','assignment','participation','attendance','performance_task','examination')),
  title text not null,
  maximum_score numeric(10,2) not null check (maximum_score > 0),
  position integer not null default 0,
  source text not null default 'manual' check (source in ('manual','csv','excel','google_classroom')),
  external_course_id text,
  external_item_id text,
  locked boolean not null default false,
  archived boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique nulls not distinct (external_course_id, external_item_id)
);

create table public.scores (
  id uuid primary key default gen_random_uuid(),
  enrollment_id uuid not null references public.class_enrollments(id),
  assessment_item_id uuid not null references public.assessment_items(id),
  raw_score numeric(10,2),
  status text not null default 'missing' check (status in ('scored','missing','excused','late','not_applicable')),
  source text not null default 'manual' check (source in ('manual','csv','excel','google_classroom')),
  external_submission_id text unique,
  updated_by uuid references public.profiles(id),
  updated_at timestamptz not null default now(),
  unique (enrollment_id, assessment_item_id)
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  user_id uuid references public.profiles(id),
  class_id uuid references public.classes(id),
  action text not null,
  affected_table text not null,
  affected_id text,
  previous_value jsonb,
  new_value jsonb,
  source text not null default 'app',
  reason text,
  created_at timestamptz not null default now()
);

create index classes_teacher_idx on public.classes(teacher_id, status);
create index enrollments_class_idx on public.class_enrollments(class_id, status);
create index assessments_class_period_idx on public.assessment_items(class_id, grading_period, category);
create index scores_assessment_idx on public.scores(assessment_item_id);

alter table public.profiles enable row level security;
alter table public.school_years enable row level security;
alter table public.terms enable row level security;
alter table public.classes enable row level security;
alter table public.students enable row level security;
alter table public.class_enrollments enable row level security;
alter table public.assessment_items enable row level security;
alter table public.scores enable row level security;
alter table public.audit_logs enable row level security;

create policy "users read own profile" on public.profiles for select to authenticated using ((select auth.uid()) = id);
create policy "users update own profile" on public.profiles for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);
create policy "teachers read school years" on public.school_years for select to authenticated using (true);
create policy "teachers read terms" on public.terms for select to authenticated using (true);

create policy "teachers manage own classes" on public.classes for all to authenticated
  using ((select auth.uid()) = teacher_id)
  with check ((select auth.uid()) = teacher_id);

create policy "teachers read students in own classes" on public.students for select to authenticated using (
  exists (select 1 from public.class_enrollments ce join public.classes c on c.id=ce.class_id where ce.student_id=students.id and c.teacher_id=(select auth.uid()))
);
create policy "teachers add students" on public.students for insert to authenticated with check ((select auth.uid()) is not null);
create policy "teachers update students in own classes" on public.students for update to authenticated using (
  exists (select 1 from public.class_enrollments ce join public.classes c on c.id=ce.class_id where ce.student_id=students.id and c.teacher_id=(select auth.uid()))
) with check (
  exists (select 1 from public.class_enrollments ce join public.classes c on c.id=ce.class_id where ce.student_id=students.id and c.teacher_id=(select auth.uid()))
);

create policy "teachers manage own enrollments" on public.class_enrollments for all to authenticated
  using (exists (select 1 from public.classes c where c.id=class_id and c.teacher_id=(select auth.uid())))
  with check (exists (select 1 from public.classes c where c.id=class_id and c.teacher_id=(select auth.uid())));
create policy "teachers manage own assessments" on public.assessment_items for all to authenticated
  using (exists (select 1 from public.classes c where c.id=class_id and c.teacher_id=(select auth.uid())))
  with check (exists (select 1 from public.classes c where c.id=class_id and c.teacher_id=(select auth.uid())));
create policy "teachers manage scores in own classes" on public.scores for all to authenticated
  using (exists (select 1 from public.class_enrollments ce join public.classes c on c.id=ce.class_id where ce.id=enrollment_id and c.teacher_id=(select auth.uid())))
  with check (exists (select 1 from public.class_enrollments ce join public.classes c on c.id=ce.class_id where ce.id=enrollment_id and c.teacher_id=(select auth.uid())));
create policy "teachers read own audit logs" on public.audit_logs for select to authenticated
  using (user_id=(select auth.uid()) or exists (select 1 from public.classes c where c.id=class_id and c.teacher_id=(select auth.uid())));
create policy "teachers create own audit logs" on public.audit_logs for insert to authenticated with check (user_id=(select auth.uid()));

grant usage on schema public to authenticated;
grant select, insert, update, delete on public.profiles, public.classes, public.students, public.class_enrollments, public.assessment_items, public.scores, public.audit_logs to authenticated;
grant select on public.school_years, public.terms to authenticated;
grant usage, select on all sequences in schema public to authenticated;

alter table public.classes
  add column grading_base integer not null default 30
  check (grading_base in (0, 30));

comment on column public.classes.grading_base is
  'Score transmutation base: 0 for board courses and 30 for non-board courses.';

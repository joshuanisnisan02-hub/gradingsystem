create table public.grading_weights (
  id uuid primary key default gen_random_uuid(),
  class_id uuid not null references public.classes(id) on delete cascade,
  grading_period text not null check (grading_period in ('prelim','midterm','semifinal','final')),
  category text not null check (category in ('participation','quiz','assignment','attendance','examination')),
  weight numeric(5,2) not null check (weight >= 0 and weight <= 100),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (class_id, grading_period, category)
);

create index grading_weights_class_period_idx
  on public.grading_weights(class_id, grading_period);

alter table public.grading_weights enable row level security;

create policy "teachers manage own grading weights"
  on public.grading_weights
  for all
  to authenticated
  using (
    exists (
      select 1 from public.classes c
      where c.id = class_id and c.teacher_id = (select auth.uid())
    )
  )
  with check (
    exists (
      select 1 from public.classes c
      where c.id = class_id and c.teacher_id = (select auth.uid())
    )
  );

grant select, insert, update, delete on public.grading_weights to authenticated;

insert into public.grading_weights (class_id, grading_period, category, weight)
select c.id, p.period, w.category, w.weight
from public.classes c
cross join (values ('prelim'), ('midterm'), ('semifinal'), ('final')) as p(period)
cross join (values
  ('participation', 10::numeric),
  ('quiz', 20::numeric),
  ('assignment', 20::numeric),
  ('attendance', 10::numeric),
  ('examination', 40::numeric)
) as w(category, weight)
on conflict (class_id, grading_period, category) do nothing;

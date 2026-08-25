update public.assessment_items
set grading_period = 'semifinal'
where grading_period = 'prefinal';

alter table public.assessment_items
  drop constraint if exists assessment_items_grading_period_check;

alter table public.assessment_items
  add constraint assessment_items_grading_period_check
  check (grading_period in ('prelim','midterm','semifinal','final'));

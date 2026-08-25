insert into public.school_years(label,is_active) values ('2026–2027',true) on conflict do nothing;
insert into public.terms(school_year_id,name,is_active)
select id,'First Semester',true from public.school_years where label='2026–2027'
on conflict do nothing;

-- Create the demo teacher through Supabase Authentication first, then create
-- classes through the app so teacher_id is always a real auth.users UUID.

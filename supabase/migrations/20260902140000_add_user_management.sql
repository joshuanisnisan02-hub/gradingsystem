alter table public.profiles
  add column if not exists must_change_password boolean not null default false,
  add column if not exists is_active boolean not null default true;

alter table public.profiles drop constraint if exists profiles_role_check;
alter table public.profiles
  add constraint profiles_role_check
  check (role in ('administrator', 'teacher', 'encoder'));

create index if not exists profiles_role_idx on public.profiles (role);

-- Profile roles and password-state flags are security-sensitive. They are
-- changed only by the authenticated user-management Edge Function.
drop policy if exists "users update own profile" on public.profiles;
revoke update on public.profiles from authenticated;


create index audit_logs_class_idx on public.audit_logs(class_id);
create index audit_logs_user_idx on public.audit_logs(user_id);
create index enrollments_student_idx on public.class_enrollments(student_id);
create index classes_term_idx on public.classes(term_id);
create index scores_updated_by_idx on public.scores(updated_by);

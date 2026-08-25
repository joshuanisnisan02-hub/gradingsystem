alter table public.assessment_items
  drop constraint if exists assessment_items_external_course_id_external_item_id_key;

drop index if exists public.assessment_items_external_course_id_external_item_id_key;

create unique index assessment_items_external_ids_unique_idx
  on public.assessment_items(external_course_id, external_item_id)
  where external_course_id is not null and external_item_id is not null;

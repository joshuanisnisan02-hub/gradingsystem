-- Keep numbered assessment items in their natural sequence (Quiz 1, Quiz 2, ...).
with ranked as (
  select
    id,
    row_number() over (
      partition by class_id, grading_period, category
      order by
        coalesce(nullif(substring(lower(title) from '([0-9]+)'), '')::integer, 2147483647),
        created_at,
        id
    ) - 1 as new_position
  from public.assessment_items
  where archived = false
)
update public.assessment_items as item
set position = ranked.new_position
from ranked
where item.id = ranked.id
  and item.position is distinct from ranked.new_position;

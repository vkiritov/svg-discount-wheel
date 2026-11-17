-- Match the requested 20 equal wheel slices:
-- 5%, 10%, 15% each occupy 6 slices; 20% occupies 2 slices.
update public.rewards
set segments = case
  when discount_percent = 5 then 6
  when discount_percent = 10 then 6
  when discount_percent = 15 then 6
  when discount_percent = 20 then 2
  else segments
end
where discount_percent in (5,10,15,20);

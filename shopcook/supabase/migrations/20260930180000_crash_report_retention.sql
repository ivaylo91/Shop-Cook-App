-- Crash reports are kept for 90 days, as the privacy policy says, and then
-- deleted by a daily job rather than by hand.
create extension if not exists pg_cron;

select cron.schedule(
  'purge-old-crash-reports',
  '17 3 * * *',
  $$delete from public.crash_reports where created_at < now() - interval '90 days'$$
);

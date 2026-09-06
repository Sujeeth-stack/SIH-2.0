-- Evidence has to survive a redeploy.
--
-- Phase 1 wrote uploads to ./media on local disk. That works on a laptop and
-- silently loses every photo on a hosted platform, where the filesystem is
-- rebuilt on each deploy — a report would keep its media rows while the files
-- behind them 404. There is no object store in Phase 1, so the bytes go in
-- Postgres, which is the one thing that is actually persistent.
--
-- Files are capped at 25 MB by the API, comfortably inside what bytea handles.
-- When Phase 2 introduces S3/MinIO, storage_key comes back and content is
-- backfilled out.

ALTER TABLE problem_media ADD COLUMN IF NOT EXISTS content BYTEA;

-- storage_key was NOT NULL for the on-disk path; hosted rows have no path.
ALTER TABLE problem_media ALTER COLUMN storage_key DROP NOT NULL;

-- Keep listings cheap: never drag the blob into a query that only wants
-- the metadata.
CREATE INDEX IF NOT EXISTS idx_media_problem_created
  ON problem_media(problem_id, created_at);

-- Togethr Compliance Assistant — Supabase Setup
-- Run this in the Supabase SQL Editor after enabling the "vector" extension
-- (Database → Extensions → search "vector" → enable)

-- Table that stores each chunk of policy text, its metadata (including source
-- document name, used for citations), and its embedding.
-- vector(4096) matches the Nebius Qwen/Qwen3-Embedding-8B model's output size —
-- if you swap embedding models later, this number must match the new model's
-- dimension count.
create table documents (
  id bigserial primary key,
  content text,
  metadata jsonb,
  embedding vector(4096)
);

-- Function that lets n8n search for the most relevant chunks by similarity.
create function match_documents (
  query_embedding vector(4096),
  match_count int default null,
  filter jsonb DEFAULT '{}'
) returns table (
  id bigint,
  content text,
  metadata jsonb,
  similarity float
)
language plpgsql
as $$
#variable_conflict use_column
begin
  return query
  select
    id,
    content,
    metadata,
    1 - (documents.embedding <=> query_embedding) as similarity
  from documents
  where metadata @> filter
  order by documents.embedding <=> query_embedding
  limit match_count;
end;
$$;

-- Required: grant the service_role key permission to use the auto-incrementing
-- id sequence. Without this, inserts fail with "permission denied for sequence
-- documents_id_seq" even though service_role can otherwise bypass RLS.
grant usage, select on all sequences in schema public to service_role;

-- After running the above, also do the following in the Supabase dashboard
-- (not SQL): Settings → Data API → expose the "documents" table and the
-- "match_documents" function, since tables created via the SQL Editor are not
-- automatically exposed to the API layer.

-- Fixture for plugin unit/golden tests — not wired to examples/users sqlc.yaml.
-- :copyfrom requires INSERT INTO (not COPY ... FROM STDIN) per sqlc parser.
-- :batch is not supported for postgresql in sqlc v1.31 (codegen exists in plugin IR only).

-- name: ImportUsers :copyfrom
INSERT INTO users (name, email) VALUES ($1, $2);

-- name: BulkInsertUsers :batch
INSERT INTO users (name, email) VALUES ($1, $2);

#!/bin/bash
# PostgreSQL Multi-Database Initialization Script
# Creates separate databases for Immich, Matrix, and Paperless

set -e
set -u

function create_database() {
    local database=$1
    echo "Creating database: $database"

    # Matrix requires special collation (LC_COLLATE='C')
    if [ "$database" = "matrix" ]; then
        echo "  -> Creating Matrix database with C collation"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
            CREATE DATABASE $database
            OWNER $POSTGRES_USER
            ENCODING 'UTF8'
            LC_COLLATE 'C'
            LC_CTYPE 'C'
            TEMPLATE template0;
            GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
    else
        echo "  -> Creating standard database"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" <<-EOSQL
            CREATE DATABASE $database;
            GRANT ALL PRIVILEGES ON DATABASE $database TO $POSTGRES_USER;
EOSQL
    fi

    # Immich requires pgvecto.rs extension
    if [ "$database" = "immich" ]; then
        echo "  -> Installing vectors extension for Immich"
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$database" <<-EOSQL
            CREATE EXTENSION IF NOT EXISTS vectors;
EOSQL
    fi
}

# Create databases if POSTGRES_MULTIPLE_DATABASES is set
if [ -n "$POSTGRES_MULTIPLE_DATABASES" ]; then
    echo "Multiple database creation requested: $POSTGRES_MULTIPLE_DATABASES"
    for db in $(echo $POSTGRES_MULTIPLE_DATABASES | tr ',' ' '); do
        create_database $db
    done
    echo "Multiple databases created successfully"
fi

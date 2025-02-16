FROM mysql:latest

# Ensure the path is relative to the build context, which is `mysql/` folder
COPY user_database.sql /docker-entrypoint-initdb.d/

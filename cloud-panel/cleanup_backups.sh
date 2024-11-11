#!/bin/bash

# cleanup_all_backups.sh
# 
# This script performs cleanup of old database backups for each user under the specified BASE_DIR.
# It keeps only the most recent backups as specified by the BACKUPS_TO_KEEP variable in each
# date-based folder within the structure BASE_DIR/USER/backups/databases/DB_NAME/DATE.
# All older backups are deleted to free up space and maintain only recent backups.
#
# Usage:
# - Place this script in a directory like /usr/local/bin and make it executable with: chmod +x cleanup_backups.sh
# - To run manually, use: sudo /usr/local/bin/cleanup_all_backups.sh
# - Set up a cron job to run it automatically every 30 minutes (see example below).
#
# Example Cron Job (every 30 minutes):
# Edit the crontab file to add a job that runs the script every 30 minutes:
# Run: crontab -e
# Add the following
# */30 * * * * /usr/local/bin/cleanup_all_backups.sh >> /var/log/cleanup_all_backups.log 2>&1
#
# Directory Structure:
# - The script expects the following directory structure:
#   BASE_DIR/USER/backups/databases/DB_NAME/DATE
#     where:
#       - USER is each user directory under BASE_DIR.
#       - DB_NAME is the name of each database (e.g., zenfii, test-db).
#       - DATE is in the format YYYY-MM-DD (e.g., 2024-11-11).
#     Each DATE directory contains `.sql.gz` files as backups.
#
# Script Logic:
# - For each user under BASE_DIR:
#     - Check if BASE_DIR/USER/backups/databases exists.
#     - For each database (DB_NAME) in backups/databases:
#         - For each DATE directory within DB_NAME:
#             - Keep only the BACKUPS_TO_KEEP most recent .sql.gz backup files, delete older files.
# 
# Note:
# - Ensure you have permission to delete files in the specified directories.

# Configuration
BASE_DIR="/home"              # Base directory for all user folders
BACKUPS_TO_KEEP=2             # Number of recent backups to retain

# Start of Script

# Loop over each user directory in BASE_DIR
for USER_DIR in "$BASE_DIR"/*; do
    # Check if it's a directory and contains the backups/databases path
    if [ -d "$USER_DIR/backups/databases" ]; then
        echo "Processing backups in $USER_DIR/backups/databases"

        # Loop over each database folder in the user's backups/databases directory
        for DB_DIR in "$USER_DIR/backups/databases"/*; do
            if [ -d "$DB_DIR" ]; then
                echo "  Cleaning up in $DB_DIR"

                # Loop over each date-based subdirectory in the database directory
                for DATE_DIR in "$DB_DIR"/*; do
                    if [ -d "$DATE_DIR" ]; then
                        echo "    Cleaning up old backups in $DATE_DIR"

                        # Find and sort the backup files, delete all but the BACKUPS_TO_KEEP most recent
                        ls -1t "$DATE_DIR"/*.sql.gz | tail -n +$((BACKUPS_TO_KEEP + 1)) | xargs rm -f
                    fi
                done
            fi
        done
    fi
done

echo "Full cleanup completed for all users."

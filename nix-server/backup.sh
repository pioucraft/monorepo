#!/bin/sh
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DATA_DIR="/home/nix/git/monorepo/data"
ENV_FILE="$SCRIPT_DIR/.env"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found at $ENV_FILE"
    exit 1
fi

# Load environment variables
set -a
. "$ENV_FILE"
set +a

# Check required variables
if [ -z "$R2_ACCESS_KEY_ID" ] || [ -z "$R2_SECRET_ACCESS_KEY" ] || [ -z "$R2_BUCKET_NAME" ] || [ -z "$R2_ENDPOINT" ]; then
    echo "Error: Missing required environment variables. Check your .env file."
    exit 1
fi

# Export AWS credentials for AWS CLI
export AWS_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID"
export AWS_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY"

# Generate timestamp
TIMESTAMP=$(date +%s)
echo "Starting backup with timestamp: $TIMESTAMP"

# Create temp directory for backup
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Create archive
ARCHIVE_NAME="backup-${TIMESTAMP}.tar.gz"
ARCHIVE_PATH="$TEMP_DIR/$ARCHIVE_NAME"

echo "Creating archive of $DATA_DIR..."
tar -czf "$ARCHIVE_PATH" -C "$DATA_DIR" .

# Upload to R2
echo "Uploading to Cloudflare R2..."
if ! aws s3 cp "$ARCHIVE_PATH" "s3://$R2_BUCKET_NAME/$TIMESTAMP/$ARCHIVE_NAME" \
    --endpoint-url "$R2_ENDPOINT" \
    --region auto 2>&1; then
    echo "Upload failed - check credentials and endpoint URL"
    exit 1
fi

echo "Backup completed successfully: $TIMESTAMP/$ARCHIVE_NAME"
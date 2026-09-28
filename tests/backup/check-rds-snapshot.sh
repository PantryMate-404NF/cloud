#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need aws
ID="${RDS_IDENTIFIER:?Set RDS_IDENTIFIER}"
REGION="${AWS_REGION:-ap-northeast-2}"
capture "rds-instance.json" aws rds describe-db-instances --db-instance-identifier "$ID" --region "$REGION"
capture "rds-snapshots.json" aws rds describe-db-snapshots --db-instance-identifier "$ID" --region "$REGION"
log "RDS snapshot metadata captured; restore is NOT performed."

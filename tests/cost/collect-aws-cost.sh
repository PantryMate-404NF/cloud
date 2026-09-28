#!/usr/bin/env bash
source "$(dirname "$0")/../lib/common.sh"
need aws
START="${START:?Set START=YYYY-MM-DD}"
END="${END:?Set END=YYYY-MM-DD (exclusive)}"
capture "aws-cost.json" aws ce get-cost-and-usage --time-period "Start=$START,End=$END" --granularity MONTHLY --metrics UnblendedCost --group-by Type=DIMENSION,Key=SERVICE
capture "ec2-instances.json" aws ec2 describe-instances --region "${AWS_REGION:-ap-northeast-2}" --query 'Reservations[].Instances[].[InstanceId,InstanceType,State.Name,Placement.AvailabilityZone,Tags]' --output json
capture "rds-instances.json" aws rds describe-db-instances --region "${AWS_REGION:-ap-northeast-2}"
log "Cost Explorer amounts are historical billed data; EC2 inventory is current-state."

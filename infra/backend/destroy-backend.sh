#!/usr/bin/env bash
set -euo pipefail

PROJECT_NAME="${PROJECT_NAME:-modern-ai-strategies}"
ENVIRONMENT="${ENVIRONMENT:-dev}"
AWS_REGION="${AWS_REGION:-us-east-1}"

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
TF_STATE_BUCKET="${TF_STATE_BUCKET:-${PROJECT_NAME}-${ENVIRONMENT}-terraform-state-${ACCOUNT_ID}}"
TF_LOCK_TABLE="${TF_LOCK_TABLE:-${PROJECT_NAME}-${ENVIRONMENT}-terraform-locks}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "This will PERMANENTLY delete the Terraform backend:"
echo "  bucket:     ${TF_STATE_BUCKET} (and every state file it holds)"
echo "  lock table: ${TF_LOCK_TABLE}"
echo ""
echo "Make sure every layer (networking, compute, services) has already"
echo "been destroyed via 'terraform destroy' first -- deleting the bucket"
echo "does NOT destroy the AWS resources those states describe, it just"
echo "makes them unmanageable by Terraform afterwards."
echo ""
read -r -p "Type the bucket name to confirm (${TF_STATE_BUCKET}): " CONFIRM
if [[ "${CONFIRM}" != "${TF_STATE_BUCKET}" ]]; then
  echo "Confirmation did not match. Aborting." >&2
  exit 1
fi

if aws s3api head-bucket --bucket "${TF_STATE_BUCKET}" >/dev/null 2>&1; then
  echo "Emptying bucket ${TF_STATE_BUCKET} (all object versions and delete markers)..."

  # Versioned buckets keep old versions after a plain delete, so
  # delete-bucket fails until every version and delete marker is gone too.
  # This isn't paginated: fine for a small Terraform state bucket, not for
  # a bucket with thousands of object versions.
  OBJECTS="$(aws s3api list-object-versions \
    --bucket "${TF_STATE_BUCKET}" \
    --query 'Versions[].{Key:Key,VersionId:VersionId}' \
    --output json)"
  if [[ "${OBJECTS}" != "null" && "${OBJECTS}" != "[]" ]]; then
    aws s3api delete-objects \
      --bucket "${TF_STATE_BUCKET}" \
      --delete "{\"Objects\": ${OBJECTS}}" >/dev/null
  fi

  MARKERS="$(aws s3api list-object-versions \
    --bucket "${TF_STATE_BUCKET}" \
    --query 'DeleteMarkers[].{Key:Key,VersionId:VersionId}' \
    --output json)"
  if [[ "${MARKERS}" != "null" && "${MARKERS}" != "[]" ]]; then
    aws s3api delete-objects \
      --bucket "${TF_STATE_BUCKET}" \
      --delete "{\"Objects\": ${MARKERS}}" >/dev/null
  fi

  aws s3api delete-bucket --bucket "${TF_STATE_BUCKET}" --region "${AWS_REGION}"
  echo "Deleted bucket ${TF_STATE_BUCKET}"
else
  echo "Bucket ${TF_STATE_BUCKET} does not exist, skipping."
fi

if aws dynamodb describe-table --table-name "${TF_LOCK_TABLE}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  aws dynamodb delete-table --table-name "${TF_LOCK_TABLE}" --region "${AWS_REGION}" >/dev/null
  echo "Deleted DynamoDB table ${TF_LOCK_TABLE}"
else
  echo "DynamoDB table ${TF_LOCK_TABLE} does not exist, skipping."
fi

for layer in networking compute services; do
  rm -f "${INFRA_DIR}/${layer}/backend.${ENVIRONMENT}.hcl"
done
rm -f "${INFRA_DIR}/compute/backend.auto.tfvars"

echo "Backend teardown complete."

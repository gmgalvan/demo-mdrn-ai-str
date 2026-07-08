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

echo "Creating Terraform backend resources"
echo "  project:     ${PROJECT_NAME}"
echo "  environment: ${ENVIRONMENT}"
echo "  region:      ${AWS_REGION}"
echo "  bucket:      ${TF_STATE_BUCKET}"
echo "  lock table:  ${TF_LOCK_TABLE}"

if aws s3api head-bucket --bucket "${TF_STATE_BUCKET}" >/dev/null 2>&1; then
  echo "S3 bucket already exists: ${TF_STATE_BUCKET}"
else
  if [[ "${AWS_REGION}" == "us-east-1" ]]; then
    aws s3api create-bucket --bucket "${TF_STATE_BUCKET}" --region "${AWS_REGION}"
  else
    aws s3api create-bucket \
      --bucket "${TF_STATE_BUCKET}" \
      --region "${AWS_REGION}" \
      --create-bucket-configuration "LocationConstraint=${AWS_REGION}"
  fi
fi

aws s3api put-bucket-versioning \
  --bucket "${TF_STATE_BUCKET}" \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket "${TF_STATE_BUCKET}" \
  --server-side-encryption-configuration '{
    "Rules": [
      {
        "ApplyServerSideEncryptionByDefault": {
          "SSEAlgorithm": "AES256"
        }
      }
    ]
  }'

aws s3api put-public-access-block \
  --bucket "${TF_STATE_BUCKET}" \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

if aws dynamodb describe-table --table-name "${TF_LOCK_TABLE}" --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "DynamoDB table already exists: ${TF_LOCK_TABLE}"
else
  aws dynamodb create-table \
    --table-name "${TF_LOCK_TABLE}" \
    --region "${AWS_REGION}" \
    --billing-mode PAY_PER_REQUEST \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH >/dev/null

  aws dynamodb wait table-exists --table-name "${TF_LOCK_TABLE}" --region "${AWS_REGION}"
fi

for layer in networking compute services; do
  cat > "${INFRA_DIR}/${layer}/backend.${ENVIRONMENT}.hcl" <<EOF
bucket         = "${TF_STATE_BUCKET}"
key            = "${ENVIRONMENT}/${layer}/terraform.tfstate"
region         = "${AWS_REGION}"
dynamodb_table = "${TF_LOCK_TABLE}"
encrypt        = true
EOF
  echo "Generated ${layer}/backend.${ENVIRONMENT}.hcl"
done

cat > "${INFRA_DIR}/compute/backend.auto.tfvars" <<EOF
terraform_state_bucket = "${TF_STATE_BUCKET}"
networking_state_key   = "${ENVIRONMENT}/networking/terraform.tfstate"
EOF
echo "Generated compute/backend.auto.tfvars"

echo "Backend is ready."

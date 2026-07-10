# Setting up the `AWS_ROLE_TO_ASSUME` GitHub secret

Manual, CLI-only procedure to create the IAM role that
[build-payments-api.yml](../.github/workflows/build-payments-api.yml),
[build-webui.yml](../.github/workflows/build-webui.yml),
[deploy-payments-api.yml](../.github/workflows/deploy-payments-api.yml) and
[deploy-webui.yml](../.github/workflows/deploy-webui.yml) assume via OIDC
(`aws-actions/configure-aws-credentials`, no access keys). No Terraform —
just `aws` CLI commands, run once.

## 0. Set these once

Adjust to your setup and export them — every command below reuses these:

```bash
export AWS_REGION="us-east-1"
export ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
export GITHUB_ORG="<your-github-org-or-user>"
export GITHUB_REPO="<your-repo-name>"          # exactly as it appears in the GitHub URL, e.g. github.com/<org>/<repo>
export ROLE_NAME="modern-ai-strategies-dev-github-actions"
export EKS_CLUSTER_NAME="modern-ai-strategies-dev"
export ECR_REPOS="payment-api webui"            # space-separated
```

## 1. Create the GitHub OIDC identity provider (once per AWS account)

Check first — an AWS account can only have **one** provider per URL. If you've
ever connected any other repo to this account via OIDC, it may already
exist:

```bash
aws iam list-open-id-connect-providers
```

If `token.actions.githubusercontent.com` is **not** in that list, create it:

```bash
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1 1c58a3a8518e8759bce07eeeba2eaddad4d4c0e1
```

(Those thumbprints are GitHub's own, publicly documented values — AWS no
longer actually validates them for this provider, but the flag is still
required.)

## 2. Create the trust policy (who can assume the role)

```bash
cat > /tmp/trust-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Federated": "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
      },
      "Action": "sts:AssumeRoleWithWebIdentity",
      "Condition": {
        "StringEquals": {
          "token.actions.githubusercontent.com:aud": "sts.amazonaws.com"
        },
        "StringLike": {
          "token.actions.githubusercontent.com:sub": "repo:${GITHUB_ORG}/${GITHUB_REPO}:*"
        }
      }
    }
  ]
}
EOF
```

The `sub` condition scopes this to *only* workflow runs from
`${GITHUB_ORG}/${GITHUB_REPO}` (any branch, PR or tag in that repo — the
build workflows also assume this role on pull requests, just without
pushing, so don't narrow this to specific branches or PR runs will fail).

## 3. Create the role

```bash
aws iam create-role \
  --role-name "$ROLE_NAME" \
  --assume-role-policy-document file:///tmp/trust-policy.json \
  --description "GitHub Actions CI/CD role for modern-ai-strategies (OIDC)"
```

## 4. Attach an ECR push policy

```bash
ECR_RESOURCES=$(for repo in $ECR_REPOS; do echo "\"arn:aws:ecr:${AWS_REGION}:${ACCOUNT_ID}:repository/${repo}\","; done | sed '$ s/,$//')

cat > /tmp/ecr-push-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "ECRAuth",
      "Effect": "Allow",
      "Action": "ecr:GetAuthorizationToken",
      "Resource": "*"
    },
    {
      "Sid": "ECRPush",
      "Effect": "Allow",
      "Action": [
        "ecr:BatchCheckLayerAvailability",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload",
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer"
      ],
      "Resource": [${ECR_RESOURCES}]
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name ecr-push \
  --policy-document file:///tmp/ecr-push-policy.json
```

The two ECR repos (`payment-api`, `webui`) need to already exist (from
`infra/services`) — this only grants push permission, it doesn't create
them.

## 5. Attach an EKS access policy

```bash
cat > /tmp/eks-access-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "EKSAccess",
      "Effect": "Allow",
      "Action": [
        "eks:DescribeCluster",
        "eks:AccessKubernetesApi"
      ],
      "Resource": "arn:aws:eks:${AWS_REGION}:${ACCOUNT_ID}:cluster/${EKS_CLUSTER_NAME}"
    }
  ]
}
EOF

aws iam put-role-policy \
  --role-name "$ROLE_NAME" \
  --policy-name eks-deploy \
  --policy-document file:///tmp/eks-access-policy.json
```

This only covers the **IAM** side. It is *not* enough by itself — see the
next step.

## 6. Grant the role Kubernetes RBAC access on the cluster

IAM permissions let the role *call the EKS API*, but the cluster's own RBAC
decides what it can actually do once connected — that's a separate
authorization layer. `infra/compute/main.tf` sets
`enable_cluster_creator_admin_permissions = true`, which only grants admin
to whoever ran `terraform apply` on that layer — **not** to this new role.
Without this step, the deploy workflows' `kubectl apply` calls will fail
with `Unauthorized` even though the AWS credentials step succeeds.

```bash
ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${ROLE_NAME}"

aws eks create-access-entry \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --principal-arn "$ROLE_ARN"

aws eks associate-access-policy \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --principal-arn "$ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy \
  --access-scope type=cluster
```

Use **`AmazonEKSClusterAdminPolicy`**, not `AmazonEKSAdminPolicy` — they
sound interchangeable but aren't. `AmazonEKSAdminPolicy` maps to
Kubernetes' built-in `admin` ClusterRole, which by design excludes
cluster-scoped resources (Namespaces, Nodes, ClusterRoles, ...). Since
`deploy-payments-api.yml`/`deploy-webui.yml` run `kubectl create namespace`,
that policy fails with `Forbidden: cannot create resource "namespaces" ...
at the cluster scope`. `AmazonEKSClusterAdminPolicy` maps to `cluster-admin`
(no restrictions) and is what you actually want here. Narrow it down with a
`namespace`-scoped access scope and a less privileged policy
(`AmazonEKSEditPolicy`) if you want tighter permissions later — but then
you'd also need to pre-create the namespaces some other way, since
namespace-scoped access can't touch the cluster-scoped Namespace resource
at all.

## 7. Get the role ARN and set the GitHub secret

```bash
aws iam get-role --role-name "$ROLE_NAME" --query Role.Arn --output text
```

Copy that value into GitHub: **Settings → Secrets and variables → Actions →
Secrets → New repository secret**, name `AWS_ROLE_TO_ASSUME`, paste the ARN.

## 8. Verify

Push a small change to `payments_api/` on `develop` (or run
`build-payments-api.yml` via `workflow_dispatch`) and check the "Configure
AWS credentials" and "Log in to Amazon ECR" steps succeed. For
`deploy-payments-api.yml`/`deploy-webui.yml`, run them manually
(`workflow_dispatch`) and confirm the `kubectl apply` steps don't error with
`Unauthorized` or `Forbidden`.

## Rollback

To undo everything from this doc:

```bash
aws eks disassociate-access-policy \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --principal-arn "$ROLE_ARN" \
  --policy-arn arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy

aws eks delete-access-entry \
  --cluster-name "$EKS_CLUSTER_NAME" \
  --principal-arn "$ROLE_ARN"

aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name ecr-push
aws iam delete-role-policy --role-name "$ROLE_NAME" --policy-name eks-deploy
aws iam delete-role --role-name "$ROLE_NAME"

# Only if nothing else in the account uses it:
# aws iam delete-open-id-connect-provider \
#   --open-id-connect-provider-arn "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
```

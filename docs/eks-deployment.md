# Deploying to the real AWS EKS cluster

This is the end-to-end procedure to provision the AWS infrastructure,
connect `kubectl` to it, and deploy `payment-api`/`webui` on a real EKS
cluster — as opposed to the local `kind` cluster used in
[kodekloud-deployment.md](kodekloud-deployment.md) and `scripts/setup-demo.sh`.

## 1. Provision the infrastructure

Full details in [infra/README.md](../infra/README.md) and
[infra/backend/README.md](../infra/backend/README.md). Summary:

```bash
cd infra

# 1a. One-time: create the S3/DynamoDB Terraform backend
cd backend
make create        # or: ./bootstrap-backend.sh
cd ..

# 1b. Networking (VPC, subnets, NAT Gateway)
cd networking
terraform init -backend-config=backend.dev.hcl
terraform plan -out=networking.tfplan
terraform apply networking.tfplan
cd ..

# 1c. Compute (EKS cluster + managed node group)
cd compute
terraform init -backend-config=backend.dev.hcl
terraform plan -out=compute.tfplan
terraform apply compute.tfplan
cd ..

# 1d. Services (ECR repositories) -- independent, can run any time
cd services
terraform init -backend-config=backend.dev.hcl
terraform plan -out=services.tfplan
terraform apply services.tfplan
cd ..
```

Each `terraform init` needs to run **inside that layer's own folder**
(`infra/<layer>/`), using the `backend.dev.hcl` generated there in step 1a.
`terraform apply` always asks for interactive confirmation (`yes`) — nothing
here is scripted to run unattended.

## 2. Connect kubectl to the cluster

The `compute` layer exposes the exact command as a Terraform output:

```bash
cd infra/compute
terraform output configure_kubectl
# "aws eks update-kubeconfig --region us-east-1 --name modern-ai-strategies-dev"
```

Run it (or copy-paste the value):

```bash
aws eks update-kubeconfig --region us-east-1 --name modern-ai-strategies-dev
```

This adds/updates a context in your kubeconfig and switches `kubectl` to it
automatically. Verify:

```bash
kubectl config current-context
kubectl get nodes
```

You should see the `demo` node group's `t3.small` node(s) in `Ready` state.

Requirements: AWS CLI v2 with active credentials. Whoever ran
`terraform apply` on the `compute` layer gets cluster-admin automatically
(`enable_cluster_creator_admin_permissions = true` in
[infra/compute/main.tf](../infra/compute/main.tf)); anyone else needs an
EKS access entry granted separately.

## 3. Get images into ECR

The `services` layer created two ECR repositories (`payment-api`, `webui`).
Get images in there either via CI or manually.

**Via CI (recommended):** push to `payments_api/**` or `webui/**` on
`main`/`master` and the corresponding workflow
([build-payments-api.yml](../.github/workflows/build-payments-api.yml) /
[build-webui.yml](../.github/workflows/build-webui.yml)) builds, tests and
pushes to ECR automatically. Requires the `AWS_ROLE_TO_ASSUME` secret (OIDC
role with ECR push permissions) configured in the repo.

**Manually:**

```bash
cd infra/services
REGISTRY="$(terraform output -json repository_urls | jq -r '."payment-api"' | cut -d/ -f1)"
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin "$REGISTRY"

docker build -t "$REGISTRY/payment-api:latest" ../../payments_api
docker push "$REGISTRY/payment-api:latest"

docker build -t "$REGISTRY/webui:latest" ../../webui
docker push "$REGISTRY/webui:latest"
```

## 4. Deploy the app manifests

The manifests under [k8s/](../k8s/) (`deployment-payment-api.yaml`,
`payment-api-service.yaml`, `webui-deployment.yaml`, `webui-service.yaml`)
default to `image: payment-api:demo` / `webui:demo` with
`imagePullPolicy: Never`, meant for `kind load` on a local cluster. On EKS
they need to point at ECR instead.

**Via CI (recommended):** [deploy-eks.yml](../.github/workflows/deploy-eks.yml)
is manual-only (`workflow_dispatch`, no automatic trigger). Run it from the
Actions tab (or `gh workflow run deploy-eks.yml`) with the desired
`image_tag` input (defaults to `latest`). It resolves the image from ECR,
renders `k8s/deployment-payment-api.yaml` + `k8s/payment-api-service.yaml`
with `sed` (swapping the image and `imagePullPolicy: IfNotPresent`), and
applies them. It currently only deploys `payment-api`, not `webui`.

**Manually**, same idea:

```bash
REGISTRY="$(cd infra/services && terraform output -json repository_urls | jq -r '."payment-api"' | cut -d/ -f1)"

sed \
  -e "s|image: payment-api:demo|image: ${REGISTRY}/payment-api:latest|g" \
  -e "s|imagePullPolicy: Never|imagePullPolicy: IfNotPresent|g" \
  k8s/deployment-payment-api.yaml | kubectl apply -f -

kubectl apply -f k8s/payment-api-service.yaml

kubectl rollout status deployment/payment-api -n demo --timeout=180s
kubectl get pods,svc -n demo
```

Before applying, double-check `replicas`, `resources.requests/limits` and
any other values in the manifest actually match what you want running —
they're plain YAML, nothing enforces "production-ready" defaults.

## 5. Tear down

Reverse order — destroy the app first, then the layers (in the order given
in [infra/README.md](../infra/README.md)):

```bash
kubectl delete -f k8s/webui-service.yaml -f k8s/webui-deployment.yaml \
  -f k8s/payment-api-service.yaml -f k8s/deployment-payment-api.yaml \
  --ignore-not-found

cd infra/compute && terraform destroy
cd ../networking && terraform destroy
cd ../services && terraform destroy
```

Only tear down the Terraform backend itself
([infra/backend/destroy-backend.sh](../infra/backend/destroy-backend.sh) /
`make destroy` in `infra/backend/`) once every layer above has already been
destroyed — see the warning in
[infra/backend/README.md](../infra/backend/README.md).

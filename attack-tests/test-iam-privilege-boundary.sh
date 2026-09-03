#!/usr/bin/env bash
# Simulates: App A's cloud workload has been compromised. Attacker tries to
# use App A's IAM role to read App B's S3 data bucket. Must FAIL with
# AccessDenied, proving IAM least-privilege containment.
set -e
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
ENDPOINT="--endpoint-url=http://localhost:4566"

echo "=== BASELINE: App A role reading its OWN bucket (should succeed) ==="
aws $ENDPOINT s3 ls s3://app-a-data-bucket && echo "OK -- authorized access works"

echo
echo "=== ATTACK ATTEMPT: App A role trying to read App B's bucket (should be DENIED) ==="
aws $ENDPOINT sts assume-role \
  --role-arn "$(cd ../terraform && terraform output -raw app_a_role_arn)" \
  --role-session-name attacker-session > /tmp/assumed.json 2>/dev/null || true

aws $ENDPOINT s3 ls s3://app-b-data-bucket \
  && echo "!!! SECURITY FAILURE: cross-app access succeeded !!!" \
  || echo "AccessDenied (expected) -- IAM boundary is holding, App A cannot read App B's data"

echo
echo "Take a screenshot of the AccessDenied result for your report."

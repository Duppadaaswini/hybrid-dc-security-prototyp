#!/usr/bin/env bash
# Simulates: an attacker has compromised App A's frontend pod and tries to
# move laterally into App B (a different application). This must FAIL.
set -e

echo "=== BASELINE: authorized traffic (App A frontend -> App A backend) ==="
kubectl -n app-a exec deploy/app-a-frontend -- \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" --max-time 3 http://app-a-backend.app-a.svc.cluster.local || true

echo
echo "=== ATTACK ATTEMPT 1: App A frontend -> App B frontend (cross-app, should be BLOCKED) ==="
kubectl -n app-a exec deploy/app-a-frontend -- \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" --max-time 3 http://app-b-frontend.app-b.svc.cluster.local \
  || echo "BLOCKED (connection timed out / refused) -- segmentation working as intended"

echo
echo "=== ATTACK ATTEMPT 2: App A frontend -> App B backend directly (should be BLOCKED) ==="
kubectl -n app-a exec deploy/app-a-frontend -- \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" --max-time 3 http://app-b-backend.app-b.svc.cluster.local \
  || echo "BLOCKED (connection timed out / refused) -- segmentation working as intended"

echo
echo "=== ATTACK ATTEMPT 3: App A backend trying unsolicited egress to App B (should be BLOCKED) ==="
kubectl -n app-a exec deploy/app-a-backend -- \
  curl -s -o /dev/null -w "HTTP %{http_code}\n" --max-time 3 http://app-b-frontend.app-b.svc.cluster.local \
  || echo "BLOCKED -- default-deny-all egress on app-a namespace is doing its job"

echo
echo "Take a screenshot of this terminal output for your report."

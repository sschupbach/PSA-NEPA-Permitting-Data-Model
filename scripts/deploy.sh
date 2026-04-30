#!/usr/bin/env bash
# deploy.sh — PSA-NEPA-Permitting-Data-Model deployment script
#
# Usage:
#   ./scripts/deploy.sh <target-org-alias> [--check]
#
# Options:
#   --check   Validate-only (dry run). No changes deployed.
#
# Requirements:
#   - sf CLI v2 authenticated to <target-org-alias>
#   - Public Sector Solutions (PSS) installed in target org
#   - Run from repo root

set -euo pipefail

# ── args ──────────────────────────────────────────────────────────────────────
TARGET_ORG="${1:-}"
DRY_RUN=false

if [[ -z "$TARGET_ORG" ]]; then
    echo "Usage: $0 <target-org-alias> [--check]" >&2
    exit 1
fi

for arg in "$@"; do
    if [[ "$arg" == "--check" ]]; then
        DRY_RUN=true
    fi
done

DEPLOY_FLAG=""
if $DRY_RUN; then
    DEPLOY_FLAG="--dry-run"
    echo "==> Validate-only mode (--check). No changes will be deployed."
fi

# ── preflight ─────────────────────────────────────────────────────────────────
echo ""
echo "==> Preflight checks"
sf --version
sf org display --target-org "$TARGET_ORG" --json | jq -r '.result | "    Org: \(.alias) (\(.instanceUrl))"'

# ── phase 1: custom objects + metadata type schemas ───────────────────────────
# Objects and __mdt schemas must exist before fields, permission sets, or flows.
echo ""
echo "==> Phase 1: Custom objects and metadata type schemas"
sf project deploy start \
    --metadata "CustomObject:NEPA_Flow_Error__c" \
    --metadata "CustomObject:nepa_engagement__c" \
    --metadata "CustomObject:nepa_litigation__c" \
    --metadata "CustomObject:nepa_process_related_agencies__c" \
    --metadata "CustomObject:nepa_project_agency_relationship__c" \
    --metadata "CustomObject:nepa_legal_structure__c" \
    --metadata "CustomObject:nepa_decision_element__c" \
    --metadata "CustomObject:nepa_gis_data_element__c" \
    --metadata "CustomObject:NEPA_Agency_Risk_Rate__mdt" \
    --metadata "CustomObject:NEPA_Circuit_Risk_Weight__mdt" \
    --metadata "CustomObject:NEPA_Challenge_Prediction_Rule__mdt" \
    --metadata "CustomObject:NEPA_CE_Screening_Rule__mdt" \
    --metadata "CustomObject:NEPA_CE_Code__mdt" \
    --metadata "CustomObject:NEPA_Required_Document__mdt" \
    --metadata "CustomObject:NEPA_Statute_Risk_Weight__mdt" \
    --target-org "$TARGET_ORG" \
    --wait 30 \
    $DEPLOY_FLAG \
    --json | jq -r '.result | "    Status: \(.status)  (\(.numberComponentsDeployed // 0)/\(.numberComponentsTotal // 0) components)"'

# ── phase 2: custom fields on PSS objects + custom objects ────────────────────
echo ""
echo "==> Phase 2: Custom fields"
sf project deploy start \
    --source-dir force-app/main/default/objects \
    --target-org "$TARGET_ORG" \
    --wait 30 \
    $DEPLOY_FLAG \
    --json | jq -r '.result | "    Status: \(.status)  (\(.numberComponentsDeployed // 0)/\(.numberComponentsTotal // 0) components)"'

# ── phase 3: custom labels ────────────────────────────────────────────────────
echo ""
echo "==> Phase 3: Custom labels"
sf project deploy start \
    --source-dir force-app/main/default/labels \
    --target-org "$TARGET_ORG" \
    --wait 30 \
    $DEPLOY_FLAG \
    --json | jq -r '.result | "    Status: \(.status)  (\(.numberComponentsDeployed // 0)/\(.numberComponentsTotal // 0) components)"'

# ── phase 4: permission set ───────────────────────────────────────────────────
echo ""
echo "==> Phase 4: Permission set"
sf project deploy start \
    --source-dir force-app/main/default/permissionsets \
    --target-org "$TARGET_ORG" \
    --wait 30 \
    $DEPLOY_FLAG \
    --json | jq -r '.result | "    Status: \(.status)  (\(.numberComponentsDeployed // 0)/\(.numberComponentsTotal // 0) components)"'

# ── phase 5: custom metadata seed records ────────────────────────────────────
echo ""
echo "==> Phase 5: Custom metadata seed records"
sf project deploy start \
    --source-dir force-app/main/default/customMetadata \
    --target-org "$TARGET_ORG" \
    --wait 30 \
    $DEPLOY_FLAG \
    --json | jq -r '.result | "    Status: \(.status)  (\(.numberComponentsDeployed // 0)/\(.numberComponentsTotal // 0) components)"'

# ── phase 6: flows (as Draft) ─────────────────────────────────────────────────
echo ""
echo "==> Phase 6: Flows (deployed as Draft)"
sf project deploy start \
    --source-dir force-app/main/default/flows \
    --target-org "$TARGET_ORG" \
    --wait 30 \
    $DEPLOY_FLAG \
    --json | jq -r '.result | "    Status: \(.status)  (\(.numberComponentsDeployed // 0)/\(.numberComponentsTotal // 0) components)"'

# ── phase 7: layouts, flexipages, action plan templates ──────────────────────
echo ""
echo "==> Phase 7: Layouts, FlexiPages, Action Plan Templates, OmniStudio"
sf project deploy start \
    --source-dir force-app/main/default/layouts \
    --source-dir force-app/main/default/flexipages \
    --source-dir force-app/main/default/actionPlanTemplates \
    --target-org "$TARGET_ORG" \
    --wait 30 \
    $DEPLOY_FLAG \
    --json | jq -r '.result | "    Status: \(.status)  (\(.numberComponentsDeployed // 0)/\(.numberComponentsTotal // 0) components)"' || true

# ── phase 8: apex controllers (portal data layer) ─────────────────────────────
echo ""
echo "==> Phase 8: Apex controllers"
sf project deploy start \
    --source-dir force-app/main/default/classes \
    --target-org "$TARGET_ORG" \
    --wait 30 \
    $DEPLOY_FLAG \
    --json | jq -r '.result | "    Status: \(.status)  (\(.numberComponentsDeployed // 0)/\(.numberComponentsTotal // 0) components)"'

# ── post-deploy notes ─────────────────────────────────────────────────────────
echo ""
if $DRY_RUN; then
    echo "==> Validation complete. Review output above before running without --check."
else
    echo "==> Deployment complete."
    echo ""
    echo "    Post-deploy checklist:"
    echo "    1. Activate Flows: go to Setup > Flows and activate each NEPA_* flow."
    echo "       Recommended order: NEPA_Litigation_Risk_Scorer → NEPA_Challenge_Predictor"
    echo "       → NEPA_CE_Screener → NEPA_CE_Determination_Router"
    echo "       → NEPA_Defensibility_Gap_Checker → NEPA_Defensibility_Trigger_*"
    echo "       → NEPA_Timeline_Risk_Assessor → NEPA_Stage_Gate"
    echo "       → NEPA_Administrative_Record_Checker → NEPA_Error_Logger"
    echo "    2. Assign permission set: sf org assign permset --name NEPA_Permitting --target-org $TARGET_ORG"
    echo "    3. Verify Custom Metadata records loaded in Setup > Custom Metadata Types."
    echo "    4. Grant Apex class access to Experience Cloud guest user profile:"
    echo "       NepaProjectController, NepaDocumentController, NepaEngagementController,"
    echo "       NepaCommentController, NepaTimelineController"
    echo "    5. If deploying OmniStudio transforms/processes, run:"
    echo "       sf project deploy start --source-dir force-app/main/default/omniDataTransforms"
    echo "       sf project deploy start --source-dir force-app/main/default/omniProcesses"
fi

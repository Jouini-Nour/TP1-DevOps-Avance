#!/bin/bash
# =============================================================================
# Scénario 2 : Configuration Drift & Self-Healing
# Objectif : Montrer qu'ArgoCD détecte et corrige les modifications manuelles
# =============================================================================

echo "========================================"
echo "Scénario 2 : Drift Detection + Self-Heal"
echo "========================================"
echo ""

if ! kind get clusters | grep -q "gitops-tp"; then
    echo "[ERREUR] Le cluster 'gitops-tp' n'existe pas."
    exit 1
fi

echo "[INFO] Deployment avant drift :"
kubectl get deployment nginx-deployment -n gitops-namespace
echo ""

echo "[ACTION] Suppression manuelle du deployment via kubectl..."
kubectl delete deployment nginx-deployment -n gitops-namespace --ignore-not-found
echo ""

echo "[VERIFICATION] Attente de la réconciliation ArgoCD (~30-60s)..."
echo ""

DEPLOY_RESTORED=false
MAX_WAIT=90
ELAPSED=0

while [ $ELAPSED -lt $MAX_WAIT ]; do
    DEPLOY_COUNT=$(kubectl get deployments -n gitops-namespace -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | wc -w)
    if [ "$DEPLOY_COUNT" -gt 0 ]; then
        DEPLOY_RESTORED=true
        break
    fi
    sleep 5
    ELAPSED=$((ELAPSED + 5))
done

if [ "$DEPLOY_RESTORED" = true ]; then
    echo ""
    echo "[SUCCES] ArgoCD a recrée le deployment automatiquement !"
    kubectl get deployment nginx-deployment -n gitops-namespace -o wide
    echo ""
    echo "[INFO] Dans l'UI ArgoCD, verifiez :"
    echo "  - Sync Status: OutOfSync -> Synced (pendant la correction)"
    echo "  - Event log indique la correction du drift"
    echo "  - Self-Heal est actif et a restaure l'etat désirée ✓"
else
    echo ""
    echo "[ATTENTION] Le deploy n'a pas été recréé dans le delai attendu."
    echo "   Verifier que l'auto-sync et self-heal sont bien actifs dans ArgoCD."
    echo "   Essayez: kubectl get app -n argocd nginx-gitops-app"
fi

echo ""
echo "[INFO] Second test - Modification d'un label manuellement..."
kubectl label deployment/nginx-deployment manual-label=test -n gitops-namespace --overwrite
echo ""
echo "[ATTENTE] Auto-Heal retire le label manuel (~30s)..."
sleep 40

echo ""
echo "[VERIFICATION] Labels après auto-heal:"
kubectl get deployment nginx-deployment -n gitops-namespace --show-labels
echo ""
echo "[INFO] Le label manuel devrait avoir été retiré par ArgoCD ✓"
echo ""
echo "========================================"
echo "Fin du Scénario 2 - Verification dans l'UI ArgoCD:"
echo "  - Le drift a été détecté et corrigé automatiquement"
echo "  - Self-Heal est bien opérationnel"
echo "========================================"


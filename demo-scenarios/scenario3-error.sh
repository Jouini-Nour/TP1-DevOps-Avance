#!/bin/bash
# =============================================================================
# Scénario 3 : Gestion des erreurs - Sync vs Health
# Objectif : Montrer qu'une application peut être Synced mais Degraded (santé défaillante)
# =============================================================================

echo "========================================"
echo "Scénario 3 : Sync Status vs Health Status"
echo "========================================"
echo ""

if ! kind get clusters | grep -q "gitops-tp"; then
    echo "[ERREUR] Le cluster 'gitops-tp' n'existe pas."
    exit 1
fi

echo "[INFO] Situation initiale :"
kubectl get deployment nginx-deployment -n gitops-namespace
kubectl get pods -n gitops-namespace -o wide
echo ""

echo "[ACTION] Introduction d'une erreur - Image inexistante..."
echo "   Changement de l'image vers: nourahmidi/tp1-nginx-app:v99.99.99"
kubectl set image deployment/nginx-deployment \
  nginx=nourahmidi/tp1-nginx-app:v99.99.99 \
  -n gitops-namespace --record

sleep 10

echo ""
echo "[VERIFICATION] Etat immédiat après modification:"
echo ""
echo "--- Deployments ---"
kubectl get deployment nginx-deployment -n gitops-namespace -o wide
echo ""
echo "--- Pods ---"
kubectl get pods -n gitops-namespace
echo ""

echo "[ATTENTE] Attente que les pods échouent (ErrImagePull / ImagePullBackOff)..."
sleep 30

echo ""
echo "--- Events récents ---"
kubectl get events -n gitops-namespace --sort-by='.lastTimestamp' | tail -n 8
echo ""

echo "[ANALYSE CRITIQUE - A MONTRER EN DEMO] :"
echo ""
echo "  Dans l'UI ArgoCD, observer :"
echo ""
echo "  Sync Status = SYNCED"
echo "    -> Les manifests correspondent exactement à Git"
echo "    -> La configuration déclarée == configuration appliquée"
echo "    -> ✅ Pas de drift, tout est synchronisé avec le dépôt"
echo ""
echo "  Health Status = DEGRADED (ou Error)"
echo "    -> Les pods ne démarrent PAS (image introuvable)"
echo "    ->kubectl describe pod -> ErrImagePull ou ImagePullBackOff"
echo "    -> ❌ L'application NE FONCTIONNE PAS malgré la syncronisation"
echo ""
echo "  CONCLUSION clé du TP :"
echo "  Synced ≠ Healthy ! Une app peut parfaitement synchronisée"
echo "  mais fonctionner en raison d'un problème technique."
echo ""
echo "========================================"
echo "Fin du Scénario 3"
echo "  Cette distinction est fondamentale en GitOps"
echo "========================================"

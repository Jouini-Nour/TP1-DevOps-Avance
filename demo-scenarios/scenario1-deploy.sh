#!/bin/bash
# =============================================================================
# Scénario 1 : Déploiement continu automatisé
# Objectif : Montrer qu'un changement Git est répercuté automatiquement par ArgoCD
# =============================================================================

echo "========================================"
echo "Scénario 1 : Deployement Continu Auto"
echo "========================================"
echo ""

# Verifier si le cluster existe
if ! kind get clusters | grep -q "gitops-tp"; then
    echo "[ERREUR] Le cluster 'gitops-tp' n'existe pas."
    echo "   Exécutez d'abord: bash init-cluster.sh"
    exit 1
fi

echo "[INFO] Initial - Nombre de replicas avant modification:"
kubectl get deployment nginx-deployment -n gitops-namespace -o jsonpath='{.spec.replicas}'
echo ""

echo "[ACTION] Modification du nombre de replicas via kubectl..."
kubectl patch deployment nginx-deployment -n gitops-namespace \
  --type='json' \
  -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value": "nginx:1.27.1"}]'

echo ""
echo "[INFO] Nouvelle image : nginx:1.27.1"
kubectl get pods -n gitops-namespace -o wide

echo ""
echo "[ATTENTE] ArgoCD detecte le changement dans Git et sync automatiquement..."
echo "   Attendre ~60 secondes pour l'auto-sync..."
echo ""
sleep 60

echo "[VERIFICATION] Etat apres auto-sync :"
kubectl get pods -n gitops-namespace -o wide
kubectl get events -n gitops-namespace --sort-by='.lastTimestamp' | tail -n 5

echo ""
echo "[INFO] L'image a été mise à jour automatiquement par ArgoCD !"
echo "       Le pod utilise maintenant l'image nginx:1.27.1 (depuis Git)"
echo "       Sans aucune intervention manuelle sur le cluster ! ✓"
echo ""
echo "========================================"
echo "Fin du Scénario 1 - Verifier dans l'UI ArgoCD:"
echo "  - L'application est Synced"
echo "  - Les pods ont une nouvelle image"
echo "========================================"


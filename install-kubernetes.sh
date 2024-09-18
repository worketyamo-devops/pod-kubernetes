#!/bin/bash

# Fonction pour installer Docker
install_docker() {
  echo "[INFO] Installation de Docker..."
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update
  sudo apt-get install -y docker-ce docker-ce-cli containerd.io
  sudo systemctl enable docker
  sudo systemctl start docker
}

# Fonction pour configurer les paramètres requis pour Kubernetes
setup_kubernetes_prerequisites() {
  echo "[INFO] Configuration des prérequis pour Kubernetes..."
  sudo modprobe overlay
  sudo modprobe br_netfilter

  cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF

  cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

  sudo sysctl --system
}

# Fonction pour installer kubeadm, kubelet, et kubectl
install_kubernetes_tools() {
  echo "[INFO] Installation de kubeadm, kubelet, et kubectl..."
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -
  sudo apt-add-repository "deb http://apt.kubernetes.io/ kubernetes-xenial main"
  sudo apt-get update
  sudo apt-get install -y kubelet kubeadm kubectl
  sudo apt-mark hold kubelet kubeadm kubectl
}

# Fonction pour initialiser le nœud maître
initialize_master_node() {
  echo "[INFO] Initialisation du nœud maître..."
  sudo kubeadm init --pod-network-cidr=10.244.0.0/16

  echo "[INFO] Configuration de kubectl pour l'utilisateur..."
  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

  echo "[INFO] Déploiement du réseau Calico pour Kubernetes..."
  kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml
}

# Fonction pour joindre les nœuds de travail au cluster
join_worker_node() {
  echo "[INFO] Rejoindre le nœud de travail au cluster..."
  read -p "Veuillez entrer la commande join fournie par kubeadm init: " join_command
  sudo $join_command
}

# Vérification si le script est exécuté en tant que root
if [ "$EUID" -ne 0 ]
  then echo "[ERREUR] Veuillez exécuter le script en tant que root"
  exit
fi

# Menu pour choisir entre le nœud maître et le nœud de travail
echo "Choisissez une option pour la configuration du cluster Kubernetes:"
echo "1) Configurer le nœud maître"
echo "2) Rejoindre un nœud de travail"

read -p "Entrez votre choix [1-2]: " node_type

# Exécution des étapes en fonction du type de nœud
case $node_type in
  1)
    install_docker
    setup_kubernetes_prerequisites
    install_kubernetes_tools
    initialize_master_node
    ;;
  2)
    install_docker
    setup_kubernetes_prerequisites
    install_kubernetes_tools
    join_worker_node
    ;;
  *)
    echo "[ERREUR] Option non valide. Exécutez le script à nouveau."
    exit 1
    ;;
esac

echo "[INFO] Configuration de Kubernetes terminée."


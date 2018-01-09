#!/bin/bash

echo "[$(date)][INFO] Checking for container image presence."
eval "$(minikube docker-env)"
if [ "$(docker images sshd-gateway -q)" == "" ]; then
  echo "[$(date)][INFO] Building sshd-gateway container."
  docker build -t sshd-gateway -f ./Dockerfile.sshd .
else
  echo "[$(date)][INFO] sshd-gateway image found."
fi
if [ "$(docker images centos-sudo -q)" == "" ]; then
  echo "[$(date)][INFO] Building centos-sudo container."
  docker build -t centos-sudo -f ./Dockerfile.sudo .
else
  echo "[$(date)][INFO] Centos-sudo image found."
fi
if [ "$(docker images ubuntu-ip -q)" == "" ]; then
  echo "[$(date)][INFO] Building ubuntu-ip container."
  docker build -t ubuntu-ip -f ./Dockerfile.iputil .
else
  echo "[$(date)][INFO] ubuntu-ip image found."
fi
eval "$(minikube docker-env -u)"

echo "[$(date)][INFO] Labeling namespace"
kubectl label ns default --overwrite=true session=true
echo "[$(date)][INFO] Creating/Updating configs and secrets..."

config_items=(
  config-idm
  config-sshd
  script-session-gateway
  script-session-host
  template-session-host
  )
config_types=(
  config
  config
  script
  script
  template
  )
config_length=${#config_items[@]}
for (( i=0; i<${config_length}; i++ )); do
  if ! kubectl get cm "${config_items[$i]}" > /dev/null 2>&1; then
    kubectl create cm "${config_items[$i]}" --from-file="${config_items[$i]}/"
  else
    kubectl create --dry-run cm "${config_items[$i]}" -o yaml \
            --from-file="${config_items[$i]}/" | kubectl replace -f -
  fi
  kubectl label cm "${config_items[$i]}" type="${config_types[$i]}"
done

secret_items=(
  config-idm-shadow
  config-sshd-host-keys
  )
secret_types=(
  config
  config
  )

secret_length=${#secret_items[@]}
for (( i=0; i<${secret_length}; i++ )); do
  if ! kubectl get secret "${secret_items[$i]}" > /dev/null 2>&1; then
    kubectl create secret generic "${secret_items[$i]}" --from-file="secret-${secret_items[$i]}/"
  else
    kubectl create secret generic "${secret_items[$i]}" --dry-run -o yaml \
            --from-file="secret-${secret_items[$i]}/" | kubectl replace -f -
  fi
  kubectl label secret "${secret_items[$i]}" type="${secret_types[$i]}"
done

echo "[$(date)][INFO] Creating Network Security Policies."
kubectl apply -f network-security-policies/

echo "[$(date)][INFO] Creating User Home NFS Server"
kubectl apply -f nfs-provisioner/
while [ "$(kubectl get deploy nfs-provisioner --no-headers=true | awk '{print $5}')" != "1" ]; do
  echo "[$(date)][INFO] Waiting for NFS Server to become ready."
  sleep 5
done

echo "[$(date)][INFO] Creating/Updating Users.."
kubectl apply -f users/

echo "[$(date)][INFO] Creating Home PVC"
kubectl apply -f pvc-home.yaml

echo "[$(date)][INFO] Preparing User Home"
kubectl apply -f job-create-user-home.yaml

echo "[$(date)][INFO] Deploying session-gateway"
kubectl apply -f session-gateway/

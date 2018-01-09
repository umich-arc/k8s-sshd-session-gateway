#!/bin/sh

echo "[$(date)][INFO] Adding Kubernetes Cluster environment variables to pam config."
printenv | grep KUBERNETES > /etc/security/pam_env.conf
echo "PATH=$PATH" >> /etc/security/pam_env.conf

while [ ! -S /syslog/log ]
do
  echo "[$(date)][INFO] Waiting for log socket to become available."
  sleep 5
done
ln -s /syslog/log /dev/log
echo "[$(date)][INFO] Syslog Socket ready."
echo "[$(date)][INFO] Starting sshd."
exec /usr/sbin/sshd -D

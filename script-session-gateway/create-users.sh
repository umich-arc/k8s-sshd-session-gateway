#!/bin/sh

user_home=${user_home:-/user_home}

for session_user in $(kubectl get cm -l type=user --output=jsonpath='{.items..metadata.name}'); do
  home_name="$(basename "$(kubectl get cm "$session_user" --output=jsonpath='{.data.home}')")"
  uid="$(kubectl get cm "$session_user" --output=jsonpath='{.data.uid}')"
  gid="$(kubectl get cm "$session_user" --output=jsonpath='{.data.gid}')"
  echo "[$(date)][INFO] Creating $user_home/$home_name"
  mkdir -p "$user_home/$home_name"
  echo "[$(date)][INFO] Chowning $uid:$gid $user_home/$home_name"
  chown -R "$uid":"$gid" "$user_home/$home_name"
done

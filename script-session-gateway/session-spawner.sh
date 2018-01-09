#!/bin/sh

export rm=${rm:-false}
export template=${template:-'/templates/default.json'}
export image=${image:-'ubuntu:latest'}

exec_session() {
  uid=$(kubectl get cm "user-$USER" -o jsonpath='{.data.uid}')
  gid=$(kubectl get cm "user-$USER" -o jsonpath='{.data.gid}')
  shell=$(kubectl get cm "user-$USER" -o jsonpath='{.data.shell}')
  overrides=$(
    sed -e "s/__UID__/$uid/g" -e "s/__USER__/$USER/g" \
        -e "s/__GID__/$gid/g" -e "s/__IMAGE__/$image/g" "$template"
  )
  echo "[$(date)][INFO] Starting session instance $pod_name with image $image rm: $rm"
  exec kubectl run "session-$USER" --rm="$rm" -i -t \
       --labels=app=session-host,user="$USER" --image="$image" \
       --overrides="$overrides" -- "$shell"
}


main() {
  pod_name=$(
    kubectl get pods -l app=session-host,user="$USER" \
     --output=jsonpath='{.items..metadata.name}'
  )

  if [ "$pod_name" != "" ]; then
    if [ "$rm" = "true" ]; then
      echo "[$(date)][INFO] Deleting previous instance.."
      kubectl delete deploy "session-$USER"
      while ! kubectl get pod -l "app=session-host,user=$USER" --no-headers=true 2>&1 \
            | grep -q "No resources found"; do
        echo "[$(date)][INFO] Waiting for Pod to terminate..."
        sleep 5
      done
      exec_session
    else
      echo "[$(date)][INFO] Attaching to session instance $pod_name"
      exec kubectl attach "$pod_name" -c session-host -i -t
    fi
  elif ! kubectl get cm "user-$USER" > /dev/null 2>&1; then
    echo "[$(date)][ERROR] Could not locate user configMap."
    exit 1
  else
    exec_session
  fi
}

main "$@"

#!/bin/sh

export USER_CONFIG_PATH=${USER_CONFIG_PATH:-'/userconfig'}
export USER_DATA_PATH=${USER_DATA_PATH:-'/userdata'}
export USER_SUDO=${USER_SUDO:-false}

terminate=false

if [ "x$SESSION_USER" = "x" ]; then
  >&2 echo "[$(date)][ERROR] No SESSION_USER specified."
  terminate=true
fi

if [ ! -d "$USER_CONFIG_PATH" ]; then
  >&2 echo "[$(date)][ERROR] No User Config directory found at $USER_CONFIG_PATH."
  terminate=true
fi

if [ ! -d "$USER_DATA_PATH" ]; then
  >&2 echo "[$(date)][ERROR] No User Data directory found at $USER_DATA_PATH."
  terminate=true
fi

if [ $terminate = true ]; then
  exit 1
fi

if [ ! -f "$USER_CONFIG_PATH/uid" ]; then
  >&2 echo "[$(date)][ERROR] uid not found at $USER_CONFIG_PATH/uid."
  terminate=true
else
  uid=$(cat "$USER_CONFIG_PATH/uid")
fi

if [ ! -f "$USER_CONFIG_PATH/gid" ]; then
  >&2 echo "[$(date)][ERROR] gid not found at $USER_CONFIG_PATH/gid."
  terminate=true
else
  gid=$(cat "$USER_CONFIG_PATH/gid")
fi

if [ $terminate = true ]; then
  exit 1
fi

if [ ! -f "$USER_CONFIG_PATH/home" ]; then
  >&2 echo "[$(date)][WARNING] User home not specified. Defaulting to /home."
  home="/home"
else
  home=$(cat "$USER_CONFIG_PATH/home")
fi

if [ ! -f "$USER_CONFIG_PATH/shell" ]; then
  >&2 echo "[$(date)][WARNING] User shell not specified. Defaulting to /bin/sh."
  shell="/bin/sh"
else
  shell=$(cat "$USER_CONFIG_PATH/shell")
fi

cp /etc/passwd "$USER_DATA_PATH/passwd"
cp /etc/group "$USER_DATA_PATH/group"

if grep -q -E "$SESSION_USER:x:" "$USER_DATA_PATH/passwd"; then
  >&2 echo "[$(date)][WARNING] $SESSION_USER already found in local passwd file. User will not be added."
else
  echo "[$(date)][INFO] Adding \"$SESSION_USER:x:$uid:$gid:$SESSION_USER:$home:$shell\" to passwd file."
  echo "$SESSION_USER:x:$uid:$gid:$SESSION_USER:$home:$shell" >> "$USER_DATA_PATH/passwd"
fi

if grep -q -E "^$SESSION_USER:x:" "$USER_DATA_PATH/group"; then
  >&2 echo "[$(date)][WARNING] $SESSION_USER group already found in local group file. Group will not be added."
else
  echo "[$(date)][INFO] Adding \"$SESSION_USER:x:$gid:\" to group file."
  echo "$SESSION_USER:x:$gid:" >> "$USER_DATA_PATH/group"
fi

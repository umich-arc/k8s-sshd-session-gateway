### SSHD k8s Session Gateway


## Overview
This project is a small proof of concept demo that provisions an ssh server and spawns a pod for each connecting user as their associated `uid` and mounts their home directory with the correct permissions.

Behind the scenes when a user successfully connects and authenticates, sshd will match the user, and then immediately execute a command via `ForceCommand` config option. This command will call the [`session-spawner.sh`](script-session-gateway/session-spawner.sh) script with some optional parameters.

The session-spawner script queries Kubernetes to check if the user's pod is already running, and if so attaches to it. If the pod is not present, the script fetches the user's profile information stored in a ConfigMap (`session-$USER`). This ConfigMap contains the user's uid, gid, home directory and default shell.

It then uses one of several [pre-configured deployment json templates](template-session-host) stored as another series of configmaps, modifying it with the user's information to generate a `kubectl run` command flagging it with `-i` and `-t` to give the session a tty and make it interactive.

These deployment templates strip the user session container down to a much smaller subset of linux capabilities, and configure the `securityContext` to run as the specific `uid` for the user, and adds the `gid` to the `suupplementalGroups` to ensure the home directory is mounted as the correct `uid` and `gid`. This measure is needed until the [`runAsGroup` feature](https://github.com/kubernetes/kubernetes/pull/52077) is implimented.

Before the user's container spins up, an init container is executed using the same image. This init container executes the [add-session-user.sh](script-session-host/add-session-user.sh) script which copies the container's `/etc/passwd` and `/etc/group` files to a shared `emptyDir` volume and appends the user's `uid` and `gid` to the copied files.

When the session-host container starts, the copied `passwd` and `group` file are mounted read-only into the new container, allowing it to be started as that particular user without erroring, or presenting something similar to `I have no name!@d969c8e14f66:/$`.

In addition to the `passwd` and `group` files, the home directory pvc is attached as a volume, with their home directory (username) being mounted via `subPath`. This gives the connecting user a near *'native'* ssh experience, while running within Kubernetes.


## Usage

From a Linux or OSX host, with minikube installed launch the `./init.sh` script in the root of the project directory. This will go through the steps of spinning up minikube, and provisioning everything needed to test.

Once the script is done, you can ssh as one of two users `demo` and `test`, with their passwords being the same as their username. The demo user launches an ubuntu based container with some additional network tools. The test user launches a CentOS based container with elevated privileges and sudo capabilities. **NOTE:** Enabling sudo in a container is not something that should be done in any prod capacity, simply there as a PoC.

The ssh service endpoint will be made available from the host at `192.168.99.100:32222`. e.g.
```
# Note: The 'Could not chdir to home directory' error is expected.
muninn:~$ ssh demo@192.168.99.100 -p 32222
Password:
Could not chdir to home directory : No such file or directory
[Wed Jan 17 19:29:58 UTC 2018][INFO] Starting session instance  with image ubuntu-ip:latest rm: false
If you don't see a command prompt, try pressing enter.
demo@session-demo-7988fb5967-mz8lq:/$
```

By default the user pods do not clean up when exited and the pod will stay running. However, if the user kills the connection by typing `exit` the pod will restart. SSH disconnect or simply closing the window will prevent this.

#### Terminating a Running Session

To delete the session container, or to create an ephemeral one, `rm=true` must be passed as an environment variable through ssh.
```
# Note: The 'Could not chdir to home directory' error is expected.
muninn:~ $ rm=true ssh demo@192.168.99.100 -p 32222 -o SendEnv=rm
Password:
Could not chdir to home directory : No such file or directory
[Wed Jan 17 19:34:04 UTC 2018][INFO] Deleting previous instance..
deployment "session-demo" deleted
[Wed Jan 17 19:34:08 UTC 2018][INFO] Waiting for Pod to terminate...
[Wed Jan 17 19:34:13 UTC 2018][INFO] Waiting for Pod to terminate...
[Wed Jan 17 19:34:18 UTC 2018][INFO] Waiting for Pod to terminate...
[Wed Jan 17 19:34:23 UTC 2018][INFO] Waiting for Pod to terminate...
[Wed Jan 17 19:34:29 UTC 2018][INFO] Waiting for Pod to terminate...
[Wed Jan 17 19:34:34 UTC 2018][INFO] Waiting for Pod to terminate...
[Wed Jan 17 19:34:39 UTC 2018][INFO] Waiting for Pod to terminate...
[Wed Jan 17 19:34:45 UTC 2018][INFO] Starting session instance session-demo-7988fb5967-mz8lq with image ubuntu-ip:latest rm: true
If you don't see a command prompt, try pressing enter.
demo@session-demo-7988fb5967-txmbc:/$
```

### Verifying home directory permissions

To verify the home directory file permissions, simply ssh in and touch a file in the user home directory:
```
demo@session-demo-7988fb5967-txmbc:~$ cd ~/
demo@session-demo-7988fb5967-txmbc:~$ pwd
/home/demo
demo@session-demo-7988fb5967-txmbc:~$ touch test
demo@session-demo-7988fb5967-txmbc:~$ ls -lah
total 12K
drwxr-sr-x 2 demo demo 4.0K Jan 17 19:37 .
drwxr-xr-x 1 root root 4.0K Jan 17 19:34 ..
-rw------- 1 demo demo   74 Jan 17 19:33 .bash_history
-rw-r--r-- 1 demo demo    0 Jan 17 19:37 test
demo@session-demo-7988fb5967-txmbc:~$
```

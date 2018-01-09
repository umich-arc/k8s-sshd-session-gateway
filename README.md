### SSHD k8s Session Gateway

This is a proof of concept demo spawning pods for each connected user. There are 2 users `demo` and `test`. With sshd being exposed on `NodePort: 32222`. By default pods will persist on disconnect, however they can be removed by passing the `rm=true` environment variable like this: `rm=true ssh demo192.168.99.100 -p 32222 -o SendEnv=rm`.
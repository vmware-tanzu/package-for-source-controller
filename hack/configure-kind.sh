# https://github.com/kubernetes-sigs/kind/issues/717
sysctl -w fs.inotify.max_user_watches=524288

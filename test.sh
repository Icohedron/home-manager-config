 systemctl --user stop atuin-ai-proxy.service
 if grep -q '/atuin-ai-proxy.service$' /proc/486/cgroup 2>/dev/null &&
    grep -aq litellm /proc/486/cmdline 2>/dev/null; then
     kill -TERM 486
 fi
 systemctl --user start atuin-ai-proxy.service
 sleep 5
 mask atuin status

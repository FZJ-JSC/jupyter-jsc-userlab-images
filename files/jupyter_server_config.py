c.NotebookApp.root_dir = "/"
# c.NotebookApp.default_url = "/lab/tree/home/jovyan"


def get_pod_resource_limits():
    import os
    """
    Returns:
        A dictionary with:
        - 'memory_limit_mb': float or None
        - 'cpu_limit_cores': float or None
    """
    limits = {
        'memory_limit_mb': None,
        'cpu_limit_cores': None
    }

    try:
        # Find cgroup v2 path
        with open('/proc/self/cgroup', 'r') as f:
            for line in f:
                if line.startswith("0::"):
                    cgroup_path = line.strip().split("::")[1]
                    break
            else:
                return limits  # No cgroup v2 path found

        base_path = os.path.join('/sys/fs/cgroup', cgroup_path.lstrip('/'))

        # --- Memory limit ---
        memory_max_path = os.path.join(base_path, 'memory.max')
        if os.path.exists(memory_max_path):
            with open(memory_max_path) as f:
                val = f.read().strip()
                if val != 'max':
                    limits['memory_limit_mb'] = int(int(val) / (1024 ** 2))

        # --- CPU limit ---
        cpu_max_path = os.path.join(base_path, 'cpu.max')
        if os.path.exists(cpu_max_path):
            with open(cpu_max_path) as f:
                content = f.read().strip()
            quota_str, period_str = content.split()
            if quota_str != 'max':
                quota = int(quota_str)
                period = int(period_str)
                limits['cpu_limit_cores'] = quota / period

    except Exception as e:
        print(f"[WARN] Failed to detect limits: {e}")

    return limits


limits = get_pod_resource_limits()
if limits['memory_limit_mb']:
    c.ResourceUseDisplay.mem_limit = limits['memory_limit_mb'] * 1024 * 1024
    c.ResourceUseDisplay.mem_warning_threshold = 0.1

if limits['cpu_limit_cores']:
    c.ResourceUseDisplay.track_cpu_percent = True
    c.ResourceUseDisplay.cpu_limit = limits['cpu_limit_cores']
    c.ResourceUseDisplay.cpu_warning_threshold = 0.1

c.ResourceUseDisplay.track_disk_usage = True

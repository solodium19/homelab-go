all:
  vars:
    ansible_user: vladislav
    ansible_ssh_private_key_file: /home/vladislav/.ssh/homelab
    ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  children:
    masters:
      hosts:
        master-1:
          ansible_host={{ master_ip }}

    workers:
      hosts:
{% for w, ip in worker_ips %}
        {{ w }}:
          ansible_host={{ ip }}
{% endfor %}
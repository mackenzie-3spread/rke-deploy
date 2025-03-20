[controller]
k8s-controller ansible_host=${controller} ansible_user=dusty

[workers]
k8s-worker-1 ansible_host=${worker1} ansible_user=dusty
k8s-worker-2 ansible_host=${worker2} ansible_user=dusty
k8s-worker-3 ansible_host=${worker3} ansible_user=dusty

[manager]
k8s-manager ansible_host=${manager} ansible_user=dusty

[kubernetes:children]
controller
workers

[all:vars]
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'

# Infrastructure Summary

Полная информация о развернутой инфраструктуре из всех tasks (1-5).

---

## 📋 Содержание

1. [Виртуальные машины](#виртуальные-машины)
2. [Kubernetes Кластер](#kubernetes-кластер)
3. [GitLab Deployment](#gitlab-deployment)
4. [GitLab Runner](#gitlab-runner)
5. [Network & DNS](#network--dns)
6. [Файлы и пути](#файлы-и-пути)

---

## Виртуальные машины

**Источник:** task_1 (Vagrant + VMware Fusion)

### Конфигурация

| Параметр       | Значение                    |
|----------------|-----------------------------|
| Provider       | VMware Fusion               |
| OS Image       | Ubuntu 22.04                |
| Network        | Private network 192.168.0.0/24 |
| SSH Key        | ~/.vagrant.d/insecure_private_key |

### Ноды

| Имя      | IP адрес    | RAM  | vCPU | Роль              | SSH Port |
|----------|-------------|------|------|-------------------|----------|
| master   | 192.168.0.10| 2 GB | 2    | K8s Master        | 2222     |
| worker1  | 192.168.0.11| 2 GB | 1    | K8s Worker + Runner | 2200   |
| worker2  | 192.168.0.12| 2 GB | 1    | K8s Worker + Runner | 2201   |

### Команды управления

```bash
# Статус
cd task_1
vagrant status

# Запустить
vagrant up

# Остановить
vagrant halt

# Подключиться
vagrant ssh master
vagrant ssh worker1
vagrant ssh worker2

# Или напрямую через SSH
ssh -i ~/.vagrant.d/insecure_private_key -p 2222 vagrant@127.0.0.1  # master
ssh -i ~/.vagrant.d/insecure_private_key -p 2200 vagrant@127.0.0.1  # worker1
ssh -i ~/.vagrant.d/insecure_private_key -p 2201 vagrant@127.0.0.1  # worker2
```

---

## Kubernetes Кластер

**Источник:** task_2 (Ansible + kubespray)

### Версии компонентов

| Компонент      | Версия  |
|----------------|---------|
| Kubernetes     | v1.28   |
| kubelet        | v1.28   |
| kubeadm        | v1.28   |
| kubectl        | v1.28   |
| containerd     | latest  |
| Flannel CNI    | latest  |

### Сетевые настройки

| Параметр       | Значение           |
|----------------|--------------------|
| Pod Network    | 10.244.0.0/16      |
| Master API     | 192.168.0.10:6443  |
| Cgroup Driver  | systemd            |
| Container RT   | containerd         |

### Архитектура

```
Kubernetes Cluster (v1.28)
├── Master (192.168.0.10)
│   ├── API Server
│   ├── Controller Manager
│   ├── Scheduler
│   ├── etcd
│   └── kubelet
├── Worker1 (192.168.0.11)
│   ├── kubelet
│   ├── kube-proxy
│   └── Container Runtime (containerd)
└── Worker2 (192.168.0.12)
    ├── kubelet
    ├── kube-proxy
    └── Container Runtime (containerd)
```

### Полезные команды

```bash
# На master ноде
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
kubectl get svc -A

# Проверить CNI
kubectl get daemonset -n kube-system
kubectl get po -n kube-system

# Проверить health
kubectl get componentstatuses
```

### Inventory

```
# task_2/inventory.ini
[k8s_master]
master ansible_host=127.0.0.1 ansible_user=vagrant ansible_port=2222

[k8s_workers]
worker1 ansible_host=127.0.0.1 ansible_user=vagrant ansible_port=2200
worker2 ansible_host=127.0.0.1 ansible_user=vagrant ansible_port=2201
```

---

## GitLab Deployment

**Источник:** task_3, task_4 (Helm + K8s)

### Основная информация

| Параметр       | Значение                  |
|----------------|---------------------------|
| URL            | http://gitlab.test.local  |
| Namespace      | gitlab                    |
| Ingress Class  | traefik                   |
| TLS            | Disabled (for testing)    |
| Domain         | test.local                |

### Установленные компоненты

- **GitLab CE** (Community Edition)
- **PostgreSQL** (база данных)
- **Redis** (кэш)
- **MinIO** (object storage)
- **GitLab Registry** (container registry)
- **GitLab KAS** (Agent Server)

### Сервисы

| Сервис      | Адрес                          | Namespace  |
|-------------|--------------------------------|------------|
| GitLab      | http://gitlab.test.local       | gitlab     |
| Registry    | http://registry.gitlab.test.local | gitlab   |
| MinIO       | http://minio.gitlab.test.local    | gitlab   |
| KAS         | http://kas.test.local             | gitlab   |

### Credentials

```
Username: root
Password: см. task_4/DEPLOYMENT_INFO.md
```

**Получить заново:**
```bash
kubectl get secret gitlab-gitlab-initial-root-password \
  -n gitlab -o jsonpath='{.data.password}' | base64 --decode
```

### DNS Configuration

**CoreDNS ConfigMap** в `kube-system` namespace:

```
test.local → разрешается в cluster
gitlab.test.local → gitlab-webservice
registry.gitlab.test.local → gitlab-registry
minio.gitlab.test.local → gitlab-minio-svc
kas.test.local → gitlab-kas
```

### Полезные команды

```bash
# Проверить поды
kubectl get pods -n gitlab
kubectl get pods -n gitlab --watch

# Логи
kubectl logs -n gitlab -l app=webservice
kubectl logs -n gitlab -l app=gitaly

# Ingress
kubectl get ingress -n gitlab
kubectl describe ingress -n gitlab

# PVC
kubectl get pvc -n gitlab
kubectl get pv

# Helm release
helm list -n gitlab
helm status gitlab -n gitlab
helm get values gitlab -n gitlab
```

---

## GitLab Runner

**Источник:** task_5 (Ansible + Docker)

### Установленные runners

| Runner         | Worker     | Executor | Status   |
|----------------|------------|----------|----------|
| k8s-runner-worker1 | worker1   | Docker   | Online   |
| k8s-runner-worker2 | worker2   | Docker   | Online   |

### Конфигурация

| Параметр       | Значение                      |
|----------------|-------------------------------|
| GitLab URL     | http://gitlab.test.local      |
| Executor Type  | Docker                        |
| Docker Image   | ubuntu:22.04                  |
| Tags           | docker, k8s, shell            |
| Cache Type     | S3 (MinIO)                    |

### Расположение

На каждой worker ноде:

```
Service:      /etc/systemd/system/gitlab-runner.service
Config:       /etc/gitlab-runner/config.toml
User:         gitlab-runner
Group:        gitlab-runner (member of docker group)
```

### Установка и управление

```bash
# Активировать venv (важно!)
source task_2/kubespray/venv/bin/activate

# Установить
cd task_5
export GITLAB_RUNNER_TOKEN="glrt_XXXXXXXXXXXXX"
ansible-playbook -i ../task_2/inventory.ini install-runner.yml -v

# Проверить статус на worker ноде
sudo gitlab-runner list
sudo gitlab-runner status
sudo systemctl status gitlab-runner

# Логи
sudo journalctl -u gitlab-runner -f

# Перезагрузить
sudo systemctl restart gitlab-runner
```

---

## Network & DNS

### Network Topology

```
MacOS Host (192.168.1.x)
    ↓
VMware Fusion (NAT Network)
    ↓
Vagrant Network (192.168.0.0/24)
    ├── Master (192.168.0.10)
    │   └── API Server :6443
    ├── Worker1 (192.168.0.11)
    │   └── GitLab Runner
    └── Worker2 (192.168.0.12)
        └── GitLab Runner
    
K8s Network:
    └── Pod Network (10.244.0.0/16)
        └── Flannel CNI
```

### DNS Resolution

#### Внутри K8s кластера

**CoreDNS** в `kube-system` namespace:

```
test.local:53 (custom domain)
  ↓ CoreDNS ConfigMap (coredns-custom)
  ↓
gitlab.test.local → gitlab-webservice-default.gitlab.svc.cluster.local
registry.gitlab.test.local → gitlab-registry.gitlab.svc.cluster.local
minio.gitlab.test.local → gitlab-minio-svc.gitlab.svc.cluster.local
```

#### На локальной машине MacOS

Можно добавить в `/etc/hosts`:

```bash
# Получить IP из ingress (через port-forward или minikube ip)
kubectl get svc -n ingress-nginx

# Добавить в /etc/hosts
sudo nano /etc/hosts

# Добавить строку
192.168.0.10 gitlab.test.local registry.gitlab.test.local minio.gitlab.test.local
```

---

## Файлы и пути

### Project Structure

```
practice-task/
├── task_1/                          # Vagrant VMs
│   ├── Vagrantfile
│   └── .vagrant/
│       └── machines/
│           ├── master/vmware_fusion/private_key
│           ├── worker1/vmware_fusion/private_key
│           └── worker2/vmware_fusion/private_key
│
├── task_2/                          # Kubernetes Cluster
│   ├── k8s-cluster.yml              # Ansible playbook
│   ├── inventory.ini                # Ansible inventory
│   ├── ansible.cfg
│   ├── kubespray/                   # kubespray submodule
│   │   └── venv/bin/
│   │       ├── ansible
│   │       ├── ansible-playbook
│   │       └── ... (Ansible 2.16.14)
│   └── k8s_join_command.sh
│
├── task_3/                          # GitLab Setup Guide
│   ├── README.md
│   ├── gitlab-deployment-guide.md
│   ├── k8s-config-map-dns.yaml
│   └── gitlab-values.yaml
│
├── task_4/                          # GitLab Deployment
│   ├── DEPLOYMENT_INFO.md           # Credentials & info
│   ├── gitlab-values.yaml
│   ├── coredns-custom.yaml
│   └── gitlab-values.yaml
│
└── task_5/                          # GitLab Runner
    ├── README.md                    # Quick start
    ├── QUICK_START.md               # Activation + deploy
    ├── DEPLOYMENT_GUIDE.md          # Full documentation
    ├── INFRASTRUCTURE_SUMMARY.md    # Этот файл
    ├── install-runner.yml           # Ansible playbook
    ├── config.toml.example          # Runner config
    └── run-playbook.sh              # Deployment script
```

### Важные пути

```
Ansible:
  /Users/kirylputseyeu/Desktop/practice-task/task_2/kubespray/venv/bin/ansible-playbook

SSH Keys:
  task_1/.vagrant/machines/master/vmware_fusion/private_key
  task_1/.vagrant/machines/worker1/vmware_fusion/private_key
  task_1/.vagrant/machines/worker2/vmware_fusion/private_key

kubeconfig:
  ~/.kube/config (на master ноде, скопировать с /etc/kubernetes/admin.conf)

GitLab Runner:
  /etc/gitlab-runner/config.toml (на worker ноде)
  /var/log/gitlab-runner/ (логи)

K8s:
  /etc/kubernetes/ (на master ноде)
  /var/lib/kubelet/ (на worker ноде)
```

---

## Быстрый старт

### 1. Запустить ВМ

```bash
cd task_1
vagrant up
```

### 2. Инициализировать K8s кластер

```bash
cd task_2
source kubespray/venv/bin/activate
ansible-playbook -i inventory.ini k8s-cluster.yml -v
```

### 3. Деплой GitLab

```bash
cd task_4
# Следовать DEPLOYMENT_INFO.md
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  -f gitlab-values.yaml
```

### 4. Установить GitLab Runner

```bash
cd task_5
source ../task_2/kubespray/venv/bin/activate
export GITLAB_RUNNER_TOKEN="glrt_XXXXXXXXXXXXX"
ansible-playbook -i ../task_2/inventory.ini install-runner.yml -v
```

---

## Мониторинг и Troubleshooting

### Check Cluster Health

```bash
# На master ноде
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A

# Проверить все сервисы
kubectl get svc -A

# Проверить PVC
kubectl get pvc -A
```

### Check GitLab Status

```bash
# Pods
kubectl get pods -n gitlab -o wide

# Logs
kubectl logs -n gitlab -l app=webservice

# Events
kubectl get events -n gitlab --sort-by='.lastTimestamp'
```

### Check Runner Status

```bash
# На worker ноде
sudo gitlab-runner list
sudo gitlab-runner verify

# Logs
sudo journalctl -u gitlab-runner -n 100

# Docker
docker ps | grep gitlab
docker logs <runner-container-id>
```

### Common Issues

| Issue | Solution |
|-------|----------|
| K8s pods not starting | Проверить PVC, ресурсы, логи |
| GitLab not accessible | Проверить Ingress, CoreDNS, Network |
| Runner offline | Проверить connectivity, токен, логи |
| SSH connection fails | Проверить vagrant VMs status, SSH ключи |

---

## References

- [Kubernetes v1.28 Docs](https://kubernetes.io/docs/v1.28/)
- [GitLab Helm Chart](https://docs.gitlab.com/charts/)
- [GitLab Runner](https://docs.gitlab.com/runner/)
- [Ansible Documentation](https://docs.ansible.com/)
- [Docker Documentation](https://docs.docker.com/)

---

**Для более подробной информации смотрите документацию в каждом task:**

- task_1: Vagrant & VirtualMachines
- task_2: Kubernetes Setup
- task_3: GitLab Setup Guide
- task_4: GitLab Deployment
- task_5: GitLab Runner Deployment

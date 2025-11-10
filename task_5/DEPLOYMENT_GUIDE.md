# GitLab Runner Deployment Guide

## Обзор инфраструктуры

### Виртуальные машины (task_1)

На основе Vagrant конфигурации созданы следующие ВМ:

| Хост      | IP адрес    | RAM   | vCPU | ОС           | Роль         |
|-----------|-------------|-------|------|--------------|--------------|
| master    | 192.168.0.10| 2048  | 2    | Ubuntu 22.04 | K8s Master   |
| worker1   | 192.168.0.11| 2048  | 1    | Ubuntu 22.04 | K8s Worker   |
| worker2   | 192.168.0.12| 2048  | 1    | Ubuntu 22.04 | K8s Worker   |

**Provider:** VMware Fusion

### Kubernetes Кластер (task_2)

- **Версия K8s:** v1.28
- **CNI:** Flannel (CIDR: 10.244.0.0/16)
- **Container Runtime:** containerd
- **Cgroup Driver:** systemd
- **Master API:** 192.168.0.10:6443

**Компоненты:**
- kubelet, kubeadm, kubectl v1.28
- containerd (container runtime)
- Flannel (network plugin)

### GitLab Deployment (task_3, task_4)

- **URL:** http://gitlab.test.local
- **Namespace:** gitlab
- **Ingress Controller:** Traefik
- **DNS Domain:** test.local
- **Sервисы:**
  - GitLab: gitlab.test.local
  - Registry: registry.gitlab.test.local
  - MinIO: minio.gitlab.test.local
  - KAS: kas.test.local

**CoreDNS Configuration:** Custom ConfigMap в kube-system namespace для разрешения test.local домена

---

## GitLab Runner Deployment (task_5)

### Архитектура

GitLab Runner будет установлен на worker ноды (worker1, worker2) с использованием Docker executor. Это позволит выполнять CI/CD jobs в контейнерах.

### Требования

1. **Доступ к Ansible inventory** из task_2
2. **GitLab Registration Token** из GitLab (user -> Preferences -> Access Tokens -> Runner Registration Token)
3. **Docker** установлен на worker nodes (входит в setup K8s)

### Шаг 1: Получить Runner Registration Token

```bash
# В GitLab UI:
# 1. Перейти в Admin -> CI/CD -> Runners
# 2. Получить Registration token
# 3. ИЛИ Через API:

curl --request POST "http://gitlab.test.local/api/v4/admin/runners" \
  --header "PRIVATE-TOKEN: your-personal-access-token" \
  --form "runner_type=instance_type" \
  --form "runner_version_out_of_date_check_allow_list=[]"
```

### Шаг 2: Установить GitLab Runner

```bash
# Перейти в директорию task_5
cd /Users/kirylputseyeu/Desktop/practice-task/task_5

# Экспортировать токен (важно!)
export GITLAB_RUNNER_TOKEN="glrt_XXXXXXXXXXXXX"

# Запустить ansible playbook (используя inventory из task_2)
ansible-playbook -i ../task_2/inventory.ini install-runner.yml
```

### Шаг 3: Проверить установку

```bash
# SSH на worker node
ssh -i ../task_1/.vagrant/machines/worker1/vmware_fusion/private_key \
    -p 2200 \
    vagrant@127.0.0.1

# Проверить статус runner
sudo gitlab-runner status
sudo gitlab-runner list
sudo systemctl status gitlab-runner

# Просмотреть логи
sudo journalctl -u gitlab-runner -f
```

### Шаг 4: Проверить в GitLab

```bash
# В GitLab UI:
# 1. Перейти в Admin -> CI/CD -> Runners
# 2. Должны появиться runners: k8s-runner-worker1, k8s-runner-worker2
# 3. Создать .gitlab-ci.yml в проекте для тестирования
```

### Пример .gitlab-ci.yml для тестирования runner

```yaml
stages:
  - test

hello_world:
  stage: test
  image: ubuntu:22.04
  script:
    - echo "Hello from GitLab Runner on K8s!"
    - docker --version
    - kubectl version --client
  tags:
    - docker
    - k8s
```

---

## Конфигурация Runner

### Использумый Executor: Docker

**Преимущества:**
- Каждый job запускается в чистом контейнере
- Изоляция jobs друг от друга
- Легко масштабировать
- Интеграция с K8s через Docker daemon

**Конфигурация:**
- Docker image по умолчанию: ubuntu:22.04
- Volume mounting: /var/run/docker.sock
- Docker daemon socket доступен через gitlab-runner пользователя

### Расположение конфигурации

На worker nodes конфиг runner находится в:
```
/etc/gitlab-runner/config.toml
```

Пример конфига смотри в `config.toml.example`

---

## Troubleshooting

### Runner не запускается

```bash
# Проверить статус
sudo systemctl status gitlab-runner

# Просмотреть логи
sudo journalctl -u gitlab-runner -n 100

# Перезагрузить runner
sudo systemctl restart gitlab-runner
```

### Runner не регистрируется

```bash
# Проверить токен
echo $GITLAB_RUNNER_TOKEN

# Проверить URL доступности GitLab
curl -I http://gitlab.test.local

# Посмотреть существующие runners
sudo gitlab-runner list
```

### Docker executor не работает

```bash
# Проверить docker
sudo docker ps
sudo docker images

# Проверить права gitlab-runner пользователя
id gitlab-runner
groups gitlab-runner

# Проверить docker socket
sudo ls -la /var/run/docker.sock
```

### Job выполняется слишком долго

```bash
# Проверить ресурсы на worker ноде
free -h
df -h
top -b -n 1

# Проверить логи job в GitLab UI
# Project -> CI/CD -> Pipelines -> Job -> Logs
```

---

## Полезные команды

### На worker node

```bash
# Посмотреть все registered runners
sudo gitlab-runner list

# Verify runner конфигурация
sudo gitlab-runner verify --delete

# Перезагрузить конфигурацию (без перезагрузки сервиса)
sudo gitlab-runner reload

# Включить debug логирование
sudo gitlab-runner --debug run
```

### На master node (kubectl)

```bash
# Проверить pods GitLab
kubectl get pods -n gitlab

# Посмотреть логи webservice
kubectl logs -n gitlab -l app=webservice

# Проверить ingress
kubectl get ingress -n gitlab
```

### Ansible

```bash
# Переустановить runner на все workers
ansible-playbook -i ../task_2/inventory.ini install-runner.yml

# Только на specific worker
ansible-playbook -i ../task_2/inventory.ini install-runner.yml -l worker1

# С verbose output
ansible-playbook -i ../task_2/inventory.ini install-runner.yml -v
```

---

## Параметры Playbook

Переменные, которые можно переопределить при запуске:

```bash
ansible-playbook -i ../task_2/inventory.ini install-runner.yml \
  -e "gitlab_url=http://gitlab.test.local" \
  -e "gitlab_runner_version=latest"
```

**Доступные переменные:**
- `gitlab_url` - URL GitLab (default: http://gitlab.test.local)
- `gitlab_runner_version` - версия runner (default: latest)
- `runner_registration_token` - из env GITLAB_RUNNER_TOKEN

---

## Интеграция с K8s

GitLab Runner на worker ноде может:

1. **Выполнять jobs через Docker** (текущая конфигурация)
2. **Запускать jobs непосредственно в K8s** (требует дополнительной конфигурации с K8s executor)
3. **Получать доступ к K8s API** через kubelet

### Для запуска jobs в K8s контейнерах

Требуется переконфигурация с K8s executor:

```bash
# Установить Helm chart для GitLab Runner на K8s
helm repo add gitlab https://charts.gitlab.io
helm install gitlab-runner gitlab/gitlab-runner \
  --namespace gitlab-runners \
  --create-namespace \
  -f runner-values.yaml
```

---

## Безопасность

⚠️ **Важные замечания:**

1. **Runner Token** - храни в переменной окружения, не в коде
2. **Docker Socket** - mounting /var/run/docker.sock может быть рискованным
3. **SSH Keys** - используются для доступа к worker ноде (из task_1)
4. **Firewall** - убедись что ports открыты (Git SSH 22, HTTP 80, HTTPS 443)

### Рекомендации

```bash
# Генерировать новый personal access token в GitLab
# Settings -> Access Tokens -> Create personal access token

# Использовать для runner registration через API вместо веб-UI
# Это безопаснее и удобнее для automation
```

---

## Файлы проекта

```
task_5/
├── install-runner.yml           # Ansible playbook для установки
├── config.toml.example          # Пример конфигурации runner
├── DEPLOYMENT_GUIDE.md          # Этот файл
└── README.md                    # Quick start guide

Используется inventory из:
└── task_2/inventory.ini         # Ansible inventory с IP worker ноод
```

---

## References

- [GitLab Runner Documentation](https://docs.gitlab.com/runner/)
- [GitLab Runner Ansible Role](https://docs.gitlab.com/runner/install/linux-repository.html)
- [Docker Executor](https://docs.gitlab.com/runner/executors/docker.html)
- [Kubernetes Executor](https://docs.gitlab.com/runner/executors/kubernetes.html)

# Task 5: GitLab Runner Deployment

## Quick Start

### 1. Активировать kubespray venv

```bash
source ../task_2/kubespray/venv/bin/activate
```

После этого в терминале должно быть: `(venv) user@mac task_5 %`

### 2. Получить Registration Token

В GitLab UI:
- Admin → CI/CD → Runners → New instance runner
- Скопировать **Runner Registration Token**

### 3. Установить Runner

```bash
cd task_5

# Экспортировать токен
export GITLAB_RUNNER_TOKEN="glrt_XXXXXXXXXXXXX"

# Запустить playbook (используется inventory из task_2)
ansible-playbook -i ../task_2/inventory.ini install-runner.yml -v
```

### 3. Проверить установку

```bash
# На master ноде
kubectl get pods -n gitlab

# Проверить runners в GitLab UI
# Admin → CI/CD → Runners
# Должны появиться: k8s-runner-worker1, k8s-runner-worker2
```

## Файлы

| Файл                  | Описание                                              |
|----------------------|-------------------------------------------------------|
| install-runner.yml   | Ansible playbook для установки GitLab Runner        |
| config.toml.example  | Пример конфигурации runner с Docker executor       |
| DEPLOYMENT_GUIDE.md  | Детальная документация инфраструктуры и деплоя     |
| README.md            | Этот файл                                           |

## Infrastructure Overview

### Виртуальные машины (from task_1)

```
master (192.168.0.10) - K8s Master
  ├── worker1 (192.168.0.11) - K8s Worker + GitLab Runner
  └── worker2 (192.168.0.12) - K8s Worker + GitLab Runner
```

### Kubernetes (from task_2)

- **Version:** v1.28
- **CNI:** Flannel (10.244.0.0/16)
- **Runtime:** containerd
- **Inventory:** ../task_2/inventory.ini

### GitLab (from task_3, task_4)

- **URL:** http://gitlab.test.local
- **Namespace:** gitlab
- **Ingress:** Traefik
- **DNS:** CoreDNS custom ConfigMap

## What Gets Installed

На каждой worker ноде устанавливается:

1. **GitLab Runner** - CI/CD executor
2. **Docker.io** - для Docker executor
3. **Ansible configuration** - для управления
4. **Service** - systemd unit для автостарта

## Configuration

### Executor Type: Docker

- Каждый job выполняется в отдельном контейнере
- Image по умолчанию: ubuntu:22.04
- Docker socket mounted: /var/run/docker.sock
- Tags: docker, k8s, shell

### Runner Configuration

После установки находится в:
```
/etc/gitlab-runner/config.toml
```

Смотри `config.toml.example` для полного примера.

## Troubleshooting

```bash
# Проверить статус
sudo systemctl status gitlab-runner

# Посмотреть логи
sudo journalctl -u gitlab-runner -f

# Переустановить
ansible-playbook -i ../task_2/inventory.ini install-runner.yml --extra-vars "force=true"

# Удалить
ansible-playbook -i ../task_2/inventory.ini install-runner.yml -e "remove=true"
```

## Test Runner

Создай `.gitlab-ci.yml` в проекте:

```yaml
test_runner:
  image: ubuntu:22.04
  script:
    - echo "Hello from GitLab Runner!"
    - docker --version
  tags:
    - docker
```

## References

- [DEPLOYMENT_GUIDE.md](./DEPLOYMENT_GUIDE.md) - Полная документация
- [GitLab Runner Docs](https://docs.gitlab.com/runner/)
- [Docker Executor](https://docs.gitlab.com/runner/executors/docker.html)

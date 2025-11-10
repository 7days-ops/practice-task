# Quick Start - Activate venv и запустить Ansible

## TL;DR (для спешки)

```bash
# 1. Активировать kubespray venv
source ../task_2/kubespray/venv/bin/activate

# 2. Экспортировать токен
export GITLAB_RUNNER_TOKEN="glrt_XXXXXXXXXXXXX"

# 3. Запустить установку
ansible-playbook -i ../task_2/inventory.ini install-runner.yml -v
```

---

## Что это делает?

Эти три команды:

1. **Активируют виртуальное окружение** с Ansible 2.16.14 (из kubespray)
2. **Устанавливают переменную окружения** для регистрации runner
3. **Запускают Ansible playbook** для установки GitLab Runner на worker ноды

---

## Пошагово

### Шаг 1: Активировать venv

```bash
cd /Users/kirylputseyeu/Desktop/practice-task/task_5

source ../task_2/kubespray/venv/bin/activate
```

После этого ты увидишь в терминале:
```
(venv) user@mac task_5 %
```

Это означает что venv активирован и `ansible-playbook` доступен в PATH.

### Шаг 2: Получить Runner Token

Обратись в GitLab:

1. Открыть: http://gitlab.test.local
2. Логин: **root** / пароль из task_4 (есть в DEPLOYMENT_INFO.md)
3. Admin → CI/CD → Runners → **New instance runner**
4. Скопировать **Registration token** (начинается с `glrt_`)

Или через API:
```bash
curl -s -H "PRIVATE-TOKEN: glpat_YOUR_TOKEN" \
  http://gitlab.test.local/api/v4/user/runners_tokens | jq
```

### Шаг 3: Экспортировать токен

```bash
export GITLAB_RUNNER_TOKEN="glrt_XXXXXXXXXXXXX"

# Проверить что установлено
echo $GITLAB_RUNNER_TOKEN
```

### Шаг 4: Запустить playbook

```bash
ansible-playbook -i ../task_2/inventory.ini install-runner.yml -v
```

Флаги:
- `-i ../task_2/inventory.ini` - использовать inventory с корректными IP и SSH ключами
- `install-runner.yml` - playbook файл
- `-v` - verbose output (вижу что происходит)

---

## Что происходит во время установки?

Playbook выполняет на каждой worker ноде:

1. ✅ Обновляет apt кэш
2. ✅ Устанавливает необходимые пакеты (docker, curl, gnupg)
3. ✅ Добавляет GitLab Runner APT репозиторий
4. ✅ Устанавливает gitlab-runner пакет
5. ✅ Добавляет gitlab-runner юзера в docker группу
6. ✅ Запускает systemd сервис
7. ✅ Регистрирует runner с Docker executor
8. ✅ Проверяет что runner работает

---

## После установки

### Проверить статус в GitLab UI

http://gitlab.test.local/admin/runners

Должны появиться:
- `k8s-runner-worker1` ✓
- `k8s-runner-worker2` ✓

### Проверить на worker ноде (SSH)

```bash
# Подключиться к worker1
ssh -i ../task_1/.vagrant/machines/worker1/vmware_fusion/private_key \
    -p 2200 \
    vagrant@127.0.0.1

# На worker ноде:
sudo gitlab-runner list
sudo gitlab-runner status

# Посмотреть логи
sudo journalctl -u gitlab-runner -f
```

### Протестировать runner

Создай в GitLab репозитории файл `.gitlab-ci.yml`:

```yaml
test_job:
  image: ubuntu:22.04
  script:
    - echo "Hello from GitLab Runner!"
    - docker --version
  tags:
    - docker
```

Push → Pipeline запустится на runner

---

## Troubleshooting

### "command not found: ansible-playbook"

❌ venv не активирован

**Решение:**
```bash
source ../task_2/kubespray/venv/bin/activate
```

### "GITLAB_RUNNER_TOKEN not set"

❌ Забыл экспортировать токен

**Решение:**
```bash
export GITLAB_RUNNER_TOKEN="glrt_XXXXXXXXXXXXX"
```

### "permission denied (publickey)"

❌ SSH ключ недостижим

**Решение:** Проверь что Vagrant ВМ запущены
```bash
cd ../task_1
vagrant status
vagrant up
```

### Runner stuck in "offline"

❌ Runner не может подключиться к GitLab

**На worker:**
```bash
sudo systemctl restart gitlab-runner
sudo journalctl -u gitlab-runner -f

# Проверить доступность GitLab
curl -I http://gitlab.test.local
```

---

## Дополнительно

### Повторно запустить только на одной worker ноде

```bash
ansible-playbook -i ../task_2/inventory.ini install-runner.yml -l worker1 -v
```

### Переустановить (удалить и установить заново)

```bash
# Удалить
ansible -i ../task_2/inventory.ini k8s_workers -m shell -a "sudo systemctl stop gitlab-runner && sudo apt remove gitlab-runner -y"

# Установить заново
ansible-playbook -i ../task_2/inventory.ini install-runner.yml -v
```

### Просмотреть статус без SSH

В GitLab UI:
- Admin → CI/CD → Runners
- Кликнуть на runner
- Посмотреть Last contact, Status, Jobs

---

## Файлы

```
task_5/
├── QUICK_START.md               ← Ты здесь
├── README.md                    
├── DEPLOYMENT_GUIDE.md          
├── install-runner.yml           # Ansible playbook
└── config.toml.example          # Пример конфига

Требуется:
├── ../task_1/Vagrantfile        # Vagrant ВМ
├── ../task_2/inventory.ini      # Ansible inventory
└── ../task_2/kubespray/venv/bin/activate  # Это окружение
```

---

## Что дальше?

Когда runner установлен:

1. 📝 Создай `.gitlab-ci.yml` в проекте
2. 🚀 Запусти pipeline
3. 📊 Посмотри логи в GitLab UI
4. 🔧 Настрой CI/CD для своих нужд

---

**Готов? Поехали!** 🚀

```bash
source ../task_2/kubespray/venv/bin/activate
export GITLAB_RUNNER_TOKEN="glrt_XXXXXXXXXXXXX"
ansible-playbook -i ../task_2/inventory.ini install-runner.yml -v
```





```bash
brew install helm
```


```bash
kubectl version --client
helm version
```



Выберите один из вариантов:

### Minikube
```bash

brew install minikube
minikube start --cpus=4 --memory=8192 --disk-size=50g
```

### k3s
#### Я выбрал k3s
```bash
brew install k3d
k3d cluster create gitlab-cluster
```

###  Kind
```bash
brew install kind
kind create cluster --name gitlab-cluster
```

### Проверить что кластер работает
```bash
kubectl cluster-info
kubectl get nodes
```

## Шаг 3: Настроить DNS для домена test.local

### 3.1  ConfigMap для CoreDNS с кастомным доменом
```bash

apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  test.local.server: |
    test.local:53 {
        errors
        cache 30
        forward . /etc/resolv.conf
        hosts {
            fallthrough
        }
    }
  test.local.hosts: |
    # Эти записи будут обновлены после развертывания GitLab
    # IP адреса будут указывать на Ingress или LoadBalancer


kubectl apply -f coredns-custom.yaml
```

### 3.2 Перезапустить CoreDNS
```bash
kubectl -n kube-system rollout restart deployment coredns
```

## Шаг 4: Установить Ingress Controller (NGINX)

GitLab требует Ingress для маршрутизации трафика.

```bash
# Добавить Helm репозиторий для NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update

# Установить NGINX Ingress Controller
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  --set controller.service.type=NodePort

# Проверить установку
kubectl wait --namespace ingress-nginx \
  --for=condition=ready pod \
  --selector=app.kubernetes.io/component=controller \
  --timeout=120s
```

## Шаг 5: Добавить GitLab Helm репозиторий

```bash
helm repo add gitlab https://charts.gitlab.io/
helm repo update
```

## Шаг 6: Создать namespace для GitLab

```bash
kubectl create namespace gitlab
```

## Шаг 7: Создать файл конфигурации для GitLab

```bash

# Основные настройки
global:
  # Настройка домена
  hosts:
    domain: test.local
    hostSuffix: null
    https: false
    externalIP: null

  # Ingress настройки
  ingress:
    enabled: true
    class: nginx
    annotations:
      nginx.ingress.kubernetes.io/ssl-redirect: "false"
    configureCertmanager: false

  # Отключить HTTPS для упрощения (для production включите)
  gitlab:
    https: false

# Настройки для уменьшения требований к ресурсам (для локальной разработки)
gitlab:
  gitaly:
    resources:
      requests:
        cpu: 50m
        memory: 200Mi
  gitlab-shell:
    resources:
      requests:
        cpu: 50m
        memory: 100Mi
  webservice:
    resources:
      requests:
        cpu: 200m
        memory: 1Gi
    workhorse:
      resources:
        requests:
          cpu: 50m
          memory: 100Mi
  sidekiq:
    resources:
      requests:
        cpu: 50m
        memory: 650Mi

# PostgreSQL настройки
postgresql:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi

# Redis настройки
redis:
  resources:
    requests:
      cpu: 50m
      memory: 128Mi




nginx-ingress:
  enabled: false  # Мы уже установили ingress-nginx отдельно


certmanager:
  install: false

```

## Шаг 8: Установить GitLab с помощью Helm

```bash
# Установка может занять 10-15 минут
helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --timeout 600s \
  -f gitlab-values.yaml

# Следить за процессом установки
kubectl get pods -n gitlab --watch
```

## Шаг 9: Получить IP адрес Ingress

```bash
# Получить NodePort или External IP
kubectl get svc -n ingress-nginx

# Если используете minikube
minikube service ingress-nginx-controller -n ingress-nginx --url
```

## Шаг 10: Обновить DNS записи

### 10.1 Получить IP адрес для GitLab
```bash
# Для minikube
INGRESS_IP=$(minikube ip)

# Для других кластеров
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Ingress IP: $INGRESS_IP"
```

### 10.2 Обновить CoreDNS ConfigMap
```bash
cat <<EOF > coredns-hosts-update.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: coredns-custom
  namespace: kube-system
data:
  test.local.server: |
    test.local:53 {
        errors
        cache 30
        forward . /etc/resolv.conf
        hosts {
            $INGRESS_IP gitlab.test.local
            $INGRESS_IP registry.test.local
            $INGRESS_IP minio.test.local
            fallthrough
        }
    }
EOF

kubectl apply -f coredns-hosts-update.yaml
kubectl -n kube-system rollout restart deployment coredns
```

### 10.3 Добавить запись в /etc/hosts на вашем Mac (для доступа с локальной машины)
```bash
# Для minikube
echo "$(minikube ip) gitlab.test.local" | sudo tee -a /etc/hosts
```

## Шаг 11: Получить пароль root пользователя

```bash
# Дождаться готовности всех подов
kubectl get pods -n gitlab

# Получить пароль root
kubectl get secret gitlab-gitlab-initial-root-password -n gitlab -o jsonpath='{.data.password}' | base64 --decode ; echo
```

## Шаг 12: Проверить доступ к GitLab

```bash
# Проверить ingress
kubectl get ingress -n gitlab

# Открыть GitLab в браузере (для minikube)
echo "GitLab URL: http://gitlab.test.local"

# Или использовать curl для проверки
curl -I http://gitlab.test.local
```

## Шаг 13: Войти в GitLab

1. Откройте браузер и перейдите на `http://gitlab.test.local`
2. Войдите с учетными данными:
   - Username: `root`
   - Password: (пароль из Шага 11)

## Дополнительные полезные команды

### Проверить статус всех подов GitLab
```bash
kubectl get pods -n gitlab -o wide
```

### Посмотреть логи конкретного пода
```bash
kubectl logs -n gitlab <pod-name>
```

### Удалить GitLab (если нужно переустановить)
```bash
helm uninstall gitlab -n gitlab
kubectl delete namespace gitlab
```

### Остановить minikube
```bash
minikube stop
```

### Удалить кластер
```bash
minikube delete
```

## Troubleshooting

### Pods не запускаются (pending)
- Проверьте ресурсы кластера: `kubectl top nodes`
- Увеличьте ресурсы minikube при запуске

### GitLab недоступен по URL
- Проверьте ingress: `kubectl get ingress -n gitlab`
- Проверьте /etc/hosts на локальной машине
- Проверьте что NGINX ingress работает: `kubectl get pods -n ingress-nginx`

### DNS не резолвится внутри кластера
- Проверьте CoreDNS: `kubectl get pods -n kube-system | grep coredns`
- Проверьте логи CoreDNS: `kubectl logs -n kube-system -l k8s-app=kube-dns`
- Тестируйте DNS из пода:
  ```bash
  kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup gitlab.test.local
  ```

## Примечания

- Этот гайд настроен для локальной разработки с минимальными требованиями к ресурсам
- Для production окружения:
  - Включите HTTPS и cert-manager
  - Увеличьте ресурсы для всех компонентов
  - Настройте persistent volumes
  - Настройте backup и мониторинг
  - Используйте внешнюю PostgreSQL и Redis

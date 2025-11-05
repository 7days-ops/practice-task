



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

  # Отключить HTTPS для упрощения 
  gitlab:
    https: false

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


postgresql:
  resources:
    requests:
      cpu: 100m
      memory: 256Mi


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

helm install gitlab gitlab/gitlab \
  --namespace gitlab \
  --timeout 600s \
  -f gitlab-values.yaml


kubectl get pods -n gitlab --watch
```

## Шаг 9: Получить IP адрес Ingress

```bash

kubectl get svc -n ingress-nginx

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


echo "GitLab URL: http://gitlab.test.local"
curl -I http://gitlab.test.local
```



### Проверить статус всех подов GitLab
```bash
kubectl get pods -n gitlab -o wide
```

### Посмотреть логи конкретного пода
```bash
kubectl logs -n gitlab <pod-name>
```




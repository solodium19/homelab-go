# Homelab

My homelab repository for begginer DevOps

---

# Установка кластера Kubernetes

## Мой K8s Cluster
| Role         | IP            |
|--------------|---------------|
| ControlPlane | 10.10.31.15   |
| Node01       | 10.10.31.14   |

---

# Установка kubeadm

Следуем официальной документации:  
https://v1-33.docs.kubernetes.io/docs/setup/production-environment/tools/kubeadm/install-kubeadm/

Потребуется **CRI — Container Runtime**. По документации рекомендуется **containerd**, его и устанавливаем:  
https://docs.docker.com/desktop/setup/install/linux/ubuntu/

### Костыли (ускоренная загрузка kubeadm/kubectl):
Меняем DNS на `8.8.8.8` и `1.1.1.1`, затем выполняем:
```
sudo kubeadm config images pull
```

---

# Загрузка кластера

1. Создаем ВМ: **2 CPU, 2GB RAM, 25GB Disk**  
2. Включаем IP forwarding в `/etc/sysctl.conf`  
3. Выключаем swap:  
   ```
   sudo swapoff -a
   ```  
4. Включаем CRI plugin + cgroup:  
   ```
   sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

   sudo sed -i 's/disabled_plugins = \["cri"\]/# disabled_plugins = ["cri"]/' /etc/containerd/config.toml
   ```  
5. Загружаем пакеты Kubernetes и инициализируем кластер с указанием сети:  
   ```
   sudo kubeadm init --pod-network-cidr=10.244.0.0/16
   ```  
6. Следуем инструкции после инициализации; при ошибках — выдаем себе права на `/etc/kubernetes`  
7. Устанавливаем сетевой плагин:  
   ```
   kubectl apply -f https://reweave.azurewebsites.net/k8s/v1.33/net.yaml
   ```
   Где `v` — версия вашего кластера (пример: 1.33)

---

# Containerd: Частые проблемы

### Containerd без конфига
```
sudo containerd config default | sudo tee /etc/containerd/config.toml
```

### Containerd не запускается
Проверяем конфиг:
```
sudo cat /etc/containerd/config.toml
```

Убедитесь, что присутствует блок:
```
[plugins."io.containerd.grpc.v1.cri"]
  stream_server_address = "127.0.0.1"
  stream_server_port = "10010"
```

---

## Касательно kustomize и обьяснение выбора

Кастомайз - это встроенная(есть и невстроенная) утилита в k8s, которая позволяет развертывать те же приложения, но с патчами в разных окружениях. У нас так и сделано, в папке k8s есть папочки base и overlays, где в base размещены все базовые манифесты нашего приложения. В overlays же мы используем манифесты из base и добавляем им что-то с помощью патча. У меня реализовано так, что мы изменяем образы в приложениях(очень спасает мои пайплайны такой выбор хранения манифестов), и меняем саму конфигруацию манифеста зависимо от окружения.

Например:
В окружении develop нам не нужны большие мощности, нам нужно посмотреть саму работу приложения, оценить его, увидеть баги или пилить фичи по нему, поэтому ограничения в ресурсах не стоит, скалирования нет, кол-во реплик - 1.

В окружении Stage уже не так, тут мы воссоздаём среду для тестирования и предпродового состояния, в котором оценим реальную нагрузку приложения, посмотрим как оно себя ведёт в разных состояниях, сделаем небольшое скалирование HPA или Keda, ограничим ресурсы, возможно воспользуемся VPA, вообщем приведем к предпродовому состоянию, а вот уже в окружении Prod сделаем конечные манифесты(Это планируется добавить в будущем, сейчас Prod пустует(нет ресурсов на реализацию))


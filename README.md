#  TechMarket Orders - Operación Resiliencia (EKS CI/CD)

Este repositorio almacena la Infraestructura como Código (IaC) y la configuración completa del pipeline de Integración y Despliegue Continuo (CI/CD) para el microservicio transaccional **"Orders"** de TechMarket. 

El propósito de este proyecto de ingeniería es refactorizar un flujo de despliegue riesgoso y transformarlo en una arquitectura de alta disponibilidad (Zero-Downtime), aplicando estrategias avanzadas de gestión de tráfico y mecanismos de auto-recuperación (Auto-Healing) frente a fallos productivos.

---

##  1. Arquitectura de Infraestructura (AWS & EKS)
Toda la capa base está provisionada de manera declarativa utilizando **Terraform**. Se diseñó una topología de red aislada y resiliente:
* **VPC Dedicada (10.0.0.0/16):** Red virtual personalizada que incluye soporte DNS y un Internet Gateway para la salida a internet de los nodos.
* **Alta Disponibilidad de Red:** Se configuraron dos subredes públicas distribuidas en distintas Zonas de Disponibilidad (AZs) de la región `us-east-1` para garantizar tolerancia a fallos a nivel de centro de datos.
* **Amazon EKS (Elastic Kubernetes Service):** Clúster administrado (`techmarket-cluster`) que orquesta el microservicio mediante un *Node Group* auto-escalable con instancias EC2 `t3.medium`.

---

##  2. Orquestación CI/CD y Aporte al Negocio (GitHub Actions)
Se abandonaron los scripts manuales en favor de **GitHub Actions**. El pipeline (`main.yml`) está construido sobre el principio de modularidad mediante *Reusable Workflows*:

1.  **Plantilla de Construcción (`build-template.yml`):** Gestiona la construcción y empaquetado de la imagen Docker.
2.  **Plantilla de Despliegue (`deploy-template.yml`):** Utiliza acciones oficiales (`aws-actions/configure-aws-credentials`) para inyectar credenciales seguras mediante *Secrets* y aplica los manifiestos de Kubernetes.

**Contribución al Negocio (Agilidad y Mejora Continua):**
La implementación de estas plantillas modulares acelera drásticamente los tiempos de despliegue y elimina el error humano asociado a las configuraciones manuales. Al parametrizar los *inputs*, el equipo de desarrollo puede iterar y desplegar en distintos entornos (ej. staging, prod) de forma autónoma, alineándose con los objetivos organizacionales de entrega continua y reducción de fricción operativa.

---

##  3. Análisis y Selección de Estrategia de Despliegue
Para proteger el Acuerdo de Nivel de Servicio (SLA) de TechMarket, se analizaron los efectos de diversas estrategias en el contexto ágil:

| Estrategia | Efecto en Uptime / Continuidad | Impacto en Costos (AWS EKS) | Velocidad de Rollback |
| :--- | :--- | :--- | :--- |
| **All-in-Once** | Downtime total durante la actualización. | **Bajo.** No duplica nodos. | Lenta. Requiere reiniciar el proceso completo. |
| **Rolling Update** | Riesgo de degradación si la nueva versión falla. | **Bajo.** Usa recursos existentes. | Media. Depende del estado de los pods. |
| **Canary Deploy** | Aísla el fallo a un % de usuarios. | **Medio.** Requiere ligero aumento de capacidad. | Rápida. Reversión de porcentaje de tráfico. |
| **Blue-Green** | **Máxima.** Cero downtime asegurado. | **Alto.** Duplica pods temporalmente. | **Inmediata.** Actualización del selector del *Service*. |

**Selección y Justificación (Blue-Green Deployment):**
Dada la criticidad transaccional del servicio "Orders", se seleccionó la estrategia **Blue-Green**. Se justifica técnicamente por la necesidad de alta disponibilidad y riesgo nulo. El entorno estable (Blue) atiende el 100% del tráfico mediante el `selector` del K8s `Service`. La nueva versión (Green) se despliega aislada y solo recibe tráfico tras una validación de salud exhaustiva, permitiendo un cambio atómico e imperceptible para el usuario.

---

##  4. Escenarios de Error y Contingencia en EKS
En un entorno ágil, es fundamental prever las anomalías de la infraestructura. Este pipeline contempla la mitigación de los siguientes fallos en EKS:
* **CrashLoopBackOff:** Causado por dependencias rotas, variables de entorno faltantes o errores fatales en el código que impiden el arranque del contenedor.
* **Fallos de Liveness/Readiness Probe:** Errores de red o de configuración interna donde el contenedor arranca, pero la aplicación agota el *timeout* o devuelve un error HTTP 500, impidiendo que el tráfico sea enrutado al pod.
* **Errores de Aplicación de Manifiestos:** Sintaxis incorrecta en los archivos YAML que rompen el estado deseado del clúster.

---

##  5. Auto-Healing y Remediación Temprana
Para asegurar la continuidad operativa y evitar que incidentes prolongados aumenten los costos de infraestructura en AWS y la pérdida de ventas, se implementó un mecanismo de *Rollback* automático. Este diseño minimiza el Tiempo Medio de Recuperación (MTTR) de horas a segundos.

**Flujo de Remediación:**
1.  **Detección (Health Check):** El pipeline ejecuta `kubectl rollout status` con un *timeout* estricto de 60s para validar la salud de los pods Green.
2.  **Acción (Rollback Condicional):** Si la detección falla (Exit Code 1), se gatilla el paso de rescate mediante la lógica `if: failure()`, ejecutando `kubectl rollout undo` de forma automatizada.
3.  **Notificación:** El flujo aborta el cambio de tráfico, aísla la versión defectuosa, restaura el estado estable e imprime las alertas en consola para el equipo de desarrollo.

---

##  6. Guía de Despliegue (Paso a Paso)

Para replicar este entorno de infraestructura y CI/CD desde cero:

### 1. Despliegue de Infraestructura Base (Terraform)
Asegúrate de tener configuradas tus credenciales de AWS (`LabRole` compatible) en tu terminal local.
```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

### 2. Configuración de Credenciales en GitHub
Para que el orquestador se autentique contra AWS EKS, configura los siguientes Secrets en tu repositorio (Settings > Secrets and variables > Actions):

* `AWS_ACCESS_KEY_ID`
* `AWS_SECRET_ACCESS_KEY`
* `AWS_SESSION_TOKEN`

### 3. Ejecución del Pipeline CI/CD
Con el clúster operativo y los secrets configurados, cualquier `git push` a la rama `main` gatillará el flujo automatizado, ejecutando la construcción, el despliegue Blue-Green y activando los protocolos de Auto-Healing en caso de contingencia.
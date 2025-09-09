# TITVO Installer ECR Publisher

Un contenedor Docker especializado para construir y publicar imágenes Docker en Amazon ECR usando BuildKit, diseñado para ejecutarse en AWS Batch.

## 📋 Descripción

Este proyecto proporciona una herramienta containerizada que puede:

- ✅ Clonar repositorios Git
- ✅ Construir imágenes Docker usando BuildKit
- ✅ Autenticarse automáticamente con Amazon ECR
- ✅ Publicar imágenes construidas a ECR
- ✅ Ejecutarse en entornos de CI/CD como AWS Batch

## 🚀 Características

- **BuildKit v0.23.2**: Utiliza la versión más reciente de BuildKit para construcción moderna de imágenes
- **AWS CLI v2**: Integración completa con servicios AWS
- **Autenticación automática ECR**: Manejo transparente de credenciales AWS
- **Configuración por variables de entorno**: Fácil integración en pipelines CI/CD
- **Soporte para build args**: Paso de argumentos de construcción via JSON
- **Cleanup automático**: Limpieza de recursos y procesos al finalizar

## 🛠️ Requisitos

- Docker con soporte para `--privileged` mode
- Credenciales AWS válidas
- Repositorio ECR existente en AWS

## 📦 Instalación

### Opción 1: Usar imagen pre-construida

```bash
# Próximamente disponible en ECR público
```

### Opción 2: Construir localmente

```bash
git clone <este-repositorio>
cd titvo-installer-ecr-publisher
docker build -t titvo-installer .
```

## 🔧 Uso

### Variables de entorno requeridas

```bash
# AWS Credentials
AWS_ACCESS_KEY_ID=<your-access-key>
AWS_SECRET_ACCESS_KEY=<your-secret-key>
AWS_SESSION_TOKEN=<your-session-token>  # Si usas credenciales temporales
REGION=<aws-region>

# Configuración del repositorio
GIT_URL=<git-repository-url>
IMAGE_REPO=<ecr-repository-name>

# Variables opcionales
GIT_REF=main                    # Branch/tag a construir (default: main)
CONTEXT_PATH=.                  # Directorio de contexto (default: .)
DOCKERFILE=Dockerfile           # Nombre del Dockerfile (default: Dockerfile)
IMAGE_TAG=latest               # Tag de la imagen (default: latest)
BUILD_ARGS_JSON={}             # Build args en formato JSON
```

### Ejemplo de uso

```bash
# Crear archivo .env
cat > .env << EOF
AWS_ACCESS_KEY_ID=AKIA...
AWS_SECRET_ACCESS_KEY=...
REGION=us-west-2
GIT_URL=https://github.com/tu-org/tu-repo.git
IMAGE_REPO=mi-aplicacion
IMAGE_TAG=v1.0.0
BUILD_ARGS_JSON={"NODE_ENV":"production","VERSION":"1.0.0"}
EOF

# Ejecutar el contenedor
docker run --rm --privileged --env-file=.env titvo-installer
```

### Uso con AWS Batch

```hcl
# Definición de Job en Terraform
resource "aws_batch_job_definition" "titvo_installer" {
  name = "titvo-installer-job"
  type = "container"

  container_properties = jsonencode({
    image      = "tu-account.dkr.ecr.region.amazonaws.com/titvo-installer:latest"
    vcpus      = 2
    memory     = 4096
    privileged = true
    
    environment = [
      { name = "GIT_URL", value = "https://github.com/tu-org/tu-repo.git" },
      { name = "IMAGE_REPO", value = "mi-aplicacion" },
      { name = "REGION", value = "us-west-2" }
    ]

    jobRoleArn = aws_iam_role.batch_execution_role.arn
  })
}
```

## 🏗️ Arquitectura

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Git Repository│    │  TITVO Installer │    │   Amazon ECR    │
│                 │───▶│                  │───▶│                 │
│  - Dockerfile   │    │  - BuildKit      │    │  - Docker Image │
│  - Source Code  │    │  - AWS CLI       │    │  - Tags         │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │   AWS Batch      │
                       │  - Job Queue     │
                       │  - Compute Env   │
                       └──────────────────┘
```

## 🔧 Componentes incluidos

### Software instalado

- **Debian Bookworm Slim**: Base image ligera
- **BuildKit v0.23.2**: Motor de construcción moderno
- **AWS CLI v2.17.40**: Herramientas AWS más recientes
- **runc**: Runtime de contenedores para BuildKit
- **Git**: Control de versiones
- **jq**: Procesamiento de JSON

### Scripts principales

- **`publish.sh`**: Script principal que orquesta todo el proceso
  - Validación de parámetros
  - Clonado del repositorio
  - Autenticación con ECR
  - Construcción con BuildKit
  - Publicación de imagen
  - Cleanup de recursos

## 🔒 Seguridad

### Permisos requeridos

El contenedor requiere ejecutarse con `--privileged` para que BuildKit pueda:
- Crear namespaces de red
- Montar sistemas de archivos
- Gestionar procesos de construcción

### IAM Permisos AWS

El rol/usuario AWS debe tener los siguientes permisos:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "sts:GetCallerIdentity"
      ],
      "Resource": "*"
    }
  ]
}
```

## 🐛 Troubleshooting

### Errores comunes

1. **"ERROR: GIT_URL e IMAGE_REPO are required"**
   - Verificar que las variables de entorno estén configuradas

2. **"buildkitd no se inició correctamente"**
   - Verificar que el contenedor se ejecute con `--privileged`
   - Comprobar logs para errores de buildkitd

3. **"The security token included in the request is invalid"**
   - Verificar credenciales AWS
   - Comprobar que las credenciales no hayan expirado

4. **"Repository does not exist"**
   - Verificar que el repositorio ECR exista
   - Comprobar permisos ECR del usuario/rol

### Logs de debugging

Para obtener logs detallados:

```bash
docker run --rm --privileged --env-file=.env titvo-installer 2>&1 | tee build.log
```

## 🧪 Testing

### Test básico

```bash
# Test que el contenedor se inicia correctamente
docker run --rm titvo-installer echo "Container OK"

# Test con variables mínimas
docker run --rm -e GIT_URL=test -e IMAGE_REPO=test titvo-installer
# Debería fallar en AWS auth (esperado sin credenciales válidas)
```

## 📁 Estructura del proyecto

```
titvo-installer-ecr-publisher/
├── Dockerfile              # Definición de la imagen
├── publish.sh              # Script principal
├── README.md               # Este archivo
├── .dockerignore           # Archivos ignorados por Docker
├── .gitignore              # Archivos ignorados por Git
├── aws/                    # Configuración Terraform
│   ├── batch/              # Definición AWS Batch
│   ├── ecr/                # Configuración ECR
│   └── ssm/                # Parámetros SSM
├── .github/
│   └── workflows/          # GitHub Actions
└── terragrunt.hcl          # Configuración Terragrunt
```

## 🤝 Contribución

Las contribuciones son bienvenidas. Por favor:

1. Fork el proyecto
2. Crea una branch para tu feature (`git checkout -b feature/AmazingFeature`)
3. Commit tus cambios (`git commit -m 'Add some AmazingFeature'`)
4. Push a la branch (`git push origin feature/AmazingFeature`)
5. Abre un Pull Request

## 📄 Licencia

Este proyecto está bajo la licencia [Apache License 2.0](LICENSE).

## 📞 Soporte

Para reportar bugs o solicitar features, por favor abre un [issue](../../issues) en GitHub.

---

**Nota**: Este proyecto está optimizado para uso en entornos AWS con BuildKit moderno. Para casos de uso específicos o configuraciones especiales, consulta la documentación o abre un issue.

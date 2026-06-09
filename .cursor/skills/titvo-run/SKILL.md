---
name: titvo-run
description: Ejecuta el contenedor TITVO Installer ECR Publisher para construir y publicar imágenes Docker en Amazon ECR. Use cuando el usuario quiera ejecutar el publisher, hacer build, correr el contenedor, o desplegar imágenes a ECR.
---

# TITVO Installer - Ejecutar Contenedor

Cuando el usuario quiera ejecutar el contenedor del publisher, seguir estos pasos:

## 1. Verificar configuración

Primero verificar que existe el archivo `.env` en la raíz del proyecto:

```
Verificando configuración...
```

## 2. Construir imagen (si no existe)

Si la imagen `titvo-installer` no existe, construirla:

```bash
docker build -t titvo-installer .
```

## 3. Ejecutar contenedor

Ejecutar con privilegios y el archivo .env:

```bash
docker run --rm --privileged --env-file=.env titvo-installer
```

## Variables requeridas en .env

El archivo `.env` debe contener:

```bash
AWS_ACCESS_KEY_ID=...
AWS_SECRET_ACCESS_KEY=...
REGION=us-west-2
GIT_URL=https://github.com/org/repo.git
IMAGE_REPO=nombre-app
```

## Casos especiales

- **Shell interactivo**: Si el usuario quiere debugging, ejecutar con `--entrypoint /bin/bash`
- **Archivo .env diferente**: Usar la ruta especificada en `--env-file=PATH`
- **No reconstruir**: Omitir el paso 2 si el usuario especifica que no quiere rebuild

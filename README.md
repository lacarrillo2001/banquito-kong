# Kong despliegue

Overlay liviano para desplegar Kong en una VM separada de los microservicios Core.

Topologia prevista:

- `mapi`: VM de Kong con IP privada `10.128.0.8`
- `backdocker`: VM de Core con IP privada `10.128.0.9`

## Que cambia

- Este `kong/kong.yml` enruta Core por IP privada de la VM `backdocker`.
- Se incluyen solo rutas de Core para evitar upstreams rotos de Switch en esta variante.
- El Admin API de Kong queda publicado solo en `127.0.0.1:8001`.
- El status endpoint queda publicado solo en `127.0.0.1:8100`.

## Archivos

- `docker-compose.yml`: stack de Kong para VM separada
- `.env.example`: plantilla minima de entorno
- `kong/kong.yml`: rutas y plugins para Core y Switch via `10.128.0.9`

## Levantamiento en `mapi`

```powershell
cd C:\ruta\a\kong-despliegue
copy .env.example .env
docker compose up -d
```

## Validacion rapida en `mapi`

```powershell
curl.exe -i http://127.0.0.1:8100/status
docker logs banquito-deck-sync
curl.exe -i http://localhost:8000/api/v1/auth/login
```

## Despliegue automatico con GitHub Actions

El repositorio incluye el workflow `.github/workflows/deploy.yml` para desplegar automaticamente en la VM `mapi` cada vez que hay un `push` a `main` con cambios en `docker-compose.yml`, `kong/**` o el mismo workflow.

Antes de usarlo, configura estos secrets en GitHub:

- `GCP_HOST`: IP publica o hostname de la VM
- `GCP_USER`: usuario SSH, por ejemplo `Andresl`
- `GCP_SSH_KEY`: clave privada SSH en formato PEM
- `GCP_PORT`: opcional, por defecto `22`

El workflow entra por SSH y ejecuta este flujo en `~/banquito-kong`:

```bash
git pull origin main
docker compose pull
docker compose up -d
docker image prune -f
docker compose ps
curl -f http://127.0.0.1:8100/status
```

El archivo `.env` debe existir solo en la VM y no debe subirse al repositorio.

## Cambios requeridos en `backdocker`

Los servicios Core no pueden quedarse solo con `expose`, porque Kong vive en otra VM. Debes publicar al host privado los puertos HTTP REST `8081` a `8087`. Si el Switch corre en la misma VM `backdocker`, tambien debes publicar `8081` y `8085` del compose del Switch para que Kong pueda exponer `/api/v1/batches...`.

Ejemplo de ajuste en el compose de Core:

```yaml
identity-access-service:
  ports:
    - "10.128.0.9:8081:8081"

core-customer-service:
  ports:
    - "10.128.0.9:8082:8082"

core-admin-service:
  ports:
    - "10.128.0.9:8083:8083"

core-accounting-service:
  ports:
    - "10.128.0.9:8084:8084"

core-account-service:
  ports:
    - "10.128.0.9:8085:8085"

document-service:
  ports:
    - "10.128.0.9:8086:8086"

notification-service:
  ports:
    - "10.128.0.9:8087:8087"
```

No hace falta publicar los puertos gRPC `9092` a `9097` para Kong.

Si el Switch usa `docker-compose.cloud.hub.yml`, los puertos minimos hacia Kong son:

```yaml
batch-service:
  ports:
    - "10.128.0.9:8081:8081"

reporting-service:
  ports:
    - "10.128.0.9:8085:8085"
```

## Firewall recomendado

Permitir solo trafico privado desde `10.128.0.8` hacia `10.128.0.9` en:

- TCP `8081-8087`

Si Kong debe publicar endpoints del Switch desde otra VM, incluir tambien:

- TCP `8081`
- TCP `8085`

No abrir esos puertos a Internet.

## Notas

- Si la IP privada de `backdocker` cambia, actualiza `kong/kong.yml`.
- Si el Switch se mueve a otra VM distinta de Core, actualiza `kong/kong.yml` para que `switch-batch-service` y `switch-reporting-service` apunten a la nueva IP privada.
- Si luego tienes DNS privado, conviene cambiar `10.128.0.9` por un hostname interno estable.
- Esta carpeta no reemplaza `banquito-kong`; solo agrega una variante de despliegue para VMs separadas.

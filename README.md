# BanQuito Core V2 - Infraestructura Docker Only

Esta carpeta levanta el ecosistema del Core BanQuito V2 usando únicamente Docker Compose. No requiere scripts PowerShell/Bash.

## Estructura esperada

La carpeta `infra` debe estar al mismo nivel que los microservicios y la carpeta `database`:

```text
banquito-core/
├── identity-access-service/
├── core-customer-service/
├── core-admin-service/
├── core-accounting-service/
├── core-account-service/
├── document-service/
├── notification-service/
├── database/
│   ├── mysql/
│   │   ├── 00_identity_access_db.sql
│   │   ├── 01_core_customer_db.sql
│   │   ├── 02_core_admin_db.sql
│   │   ├── 03_core_account_db.sql
│   │   ├── 04_core_accounting_db.sql
│   │   └── 06_notification_db.sql
│   └── mongodb/
│       └── 05_document_mongodb.js
└── infra/
    ├── docker-compose.yml
    ├── .env.example
    └── kong/
        └── kong.yml
```

## Decisiones incluidas

- RabbitMQ no se despliega en el Core V2. El Core usa REST/OpenAPI vía Kong y gRPC interno.
- Kong es el único punto de entrada HTTP principal.
- Los microservicios se construyen desde sus Dockerfiles internos.
- Las bases de datos usan volúmenes Docker persistentes.
- Mailpit queda habilitado como SMTP local para pruebas. En nube puede reemplazarse por SMTP real cambiando variables de entorno.

## Primer despliegue

Desde `banquito-core/infra`:

```powershell
copy .env.example .env
```

Edita `.env` y cambia contraseñas antes de nube.

Levantar todo:

```powershell
docker compose --env-file .env up -d --build
```

Ver estado:

```powershell
docker compose --env-file .env ps
```

Ver logs:

```powershell
docker compose --env-file .env logs -f core-account-service
```

Apagar sin borrar datos:

```powershell
docker compose --env-file .env down
```

Borrar contenedores y volúmenes, solo para reinicio total de laboratorio:

```powershell
docker compose --env-file .env down -v
```

## Puertos expuestos en host

| Puerto | Uso |
|---:|---|
| 8000 | Kong Proxy/API Gateway |
| 8100 | Kong status, solo localhost |
| 8025 | Mailpit UI, solo localhost |
| 1025 | Mailpit SMTP, solo localhost |

Las bases de datos y microservicios no se exponen al host por defecto. Se comunican por la red Docker `banquito-net`.

## Volúmenes persistentes

Docker Compose crea volúmenes nombrados para conservar datos:

```text
mysql_identity_data
mysql_customer_data
mysql_admin_data
mysql_account_data
mysql_accounting_data
mysql_notification_data
mongo_document_data
kong_postgres_data
```

Mientras no ejecutes `docker compose down -v`, los datos se conservan entre reinicios.

## Prueba rápida por Kong

```powershell
$loginBody = @{
  username = "admin.core"
  password = "password"
} | ConvertTo-Json

$loginResponse = Invoke-RestMethod `
  -Method Post `
  -Uri "http://localhost:8000/api/v1/auth/login" `
  -ContentType "application/json" `
  -Body $loginBody

$token = $loginResponse.accessToken

Invoke-RestMethod `
  -Method Get `
  -Uri "http://localhost:8000/api/v1/accounts/0010515383395/balance" `
  -Headers @{ Authorization = "Bearer $token" }
```

## SMTP local con Mailpit

Con `.env` local:

```env
NOTIFICATION_DELIVERY_MODE=SMTP
SMTP_HOST=mailpit
SMTP_PORT=1025
SMTP_AUTH=false
SMTP_STARTTLS_ENABLE=false
SMTP_FROM=no-reply@banquito.com
```

UI local:

```text
http://localhost:8025
```

Para nube, cambia únicamente variables SMTP:

```env
SMTP_HOST=smtp.proveedor.com
SMTP_PORT=587
SMTP_USERNAME=usuario-o-api-key
SMTP_PASSWORD=secreto
SMTP_AUTH=true
SMTP_STARTTLS_ENABLE=true
SMTP_FROM=no-reply@banquito.com
```

## Docker Hub / Registry

No es obligatorio usar Docker Hub. Este compose hace `build` desde el código fuente. Para un flujo más profesional con CI/CD, se puede construir y publicar cada imagen a un registry y luego reemplazar `build:` por `image:` con etiquetas versionadas.

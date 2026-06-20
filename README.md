# BanQuito Core V2 - Infraestructura separada de Kong

Esta carpeta deja el Core y Kong en stacks Docker Compose independientes. El Core vive en la raiz y Kong en `kong/` para poder desplegarse en otra instancia.

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
        ├── docker-compose.yml
        ├── .env.example
        ├── kong.yml.template
        └── render-kong.sh
```

## Decisiones incluidas

- RabbitMQ no se despliega en el Core V2. El Core usa REST/OpenAPI via Kong y gRPC interno.
- Kong se despliega aislado en otra instancia con su propio Compose y su propio `.env`.
- Kong puede mantenerse encendido aunque Core o Switch esten parciales o totalmente apagados; solo fallan las rutas del upstream no disponible.
- Los microservicios se construyen desde sus Dockerfiles internos.
- Las bases de datos usan volúmenes Docker persistentes.
- Mailpit queda habilitado como SMTP local para pruebas. En nube puede reemplazarse por SMTP real cambiando variables de entorno.

## Primer despliegue del Core

Desde `banquito-core/infra`:

```powershell
copy .env.example .env
```

Edita `.env` y cambia contraseñas antes de nube.

Levantar Core:

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

## Despliegue de Kong aislado

Desde `banquito-core/infra/kong`:

```powershell
copy .env.example .env
```

Edita `kong/.env` con las IPs publicas y puertos reales de backends y frontends. Kong ya no usa nombres Docker internos; ahora apunta a URLs externas completas y permite repartir servicios entre varias instancias.

Levantar Kong:

```powershell
docker compose --env-file .env up -d
```

Ver estado:

```powershell
docker compose --env-file .env ps
```

Ver logs del sync declarativo:

```powershell
docker compose --env-file .env logs -f kng-sync
```

UI grafica disponible:

```text
http://localhost:9000
http://localhost:1337
```

- `http://localhost:9000`: Portainer para contenedores y stacks Docker.
- `http://localhost:1337`: Konga para administrar servicios, rutas y plugins de Kong.

La topologia visual del enrutamiento queda documentada en `docs/KONG_TOPOLOGIA.mmd`.

## Que hace cada contenedor de Kong

- `kng-db`: base de datos principal de Kong; guarda rutas, servicios, plugins y configuracion del gateway.
- `kng-migrations`: contenedor temporal que crea o actualiza el esquema de `kng-db`; es normal que termine en `Exited (0)`.
- `kng-gateway`: el API Gateway de Kong; expone `8000` para trafico y `8001` para administracion local.
- `kng-sync`: contenedor temporal que renderiza `kong/kong.yml.template` y ejecuta `deck gateway sync`; es normal que termine en `Exited (0)` cuando acaba.
- `kng-portainer`: interfaz grafica para ver contenedores, redes, volumenes y stacks Docker.
- `kng-konga-db`: base de datos propia de Konga; se separa de Kong para no mezclar datos de UI con datos del gateway.
- `kng-konga-prepare`: contenedor temporal que inicializa la base de Konga; es normal que termine en `Exited (0)` si todo sale bien.
- `kng-konga`: interfaz grafica para administrar servicios, rutas y plugins de Kong.

## Por que hay dos bases de datos

- `kng-db` pertenece a Kong.
- `kng-konga-db` pertenece a Konga.

Se mantienen separadas porque Kong y Konga no comparten esquema ni responsabilidad.

## Puertos expuestos en host

| Puerto | Uso |
|---:|---|
| 8000 | Kong Proxy/API Gateway |
| 8001 | Kong Admin API, solo localhost |
| 8100 | Kong status, solo localhost |
| 9000 | Portainer UI, solo localhost |
| 1337 | Konga UI, solo localhost |
| 8025 | Mailpit UI, solo localhost |
| 1025 | Mailpit SMTP, solo localhost |

Las bases de datos y microservicios del Core no se exponen al host por defecto. Kong usa URLs publicas configuradas desde `kong/.env`.

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
```

Mientras no ejecutes `docker compose down -v`, los datos se conservan entre reinicios.

El volumen `kong_postgres_data` ahora pertenece al stack de `kong/docker-compose.yml`.

## Rutas de frontends por Kong

Kong publica los frontends por path:

```text
/web
/ventanilla
/switch
```

Si un frontend necesita base path explicito, debe construirse para servir correctamente bajo esa ruta.

## Convencion de nombres en Kong

- `core-bck-*`: backends del Core
- `sw-bck-*`: backends del Switch
- `core-fr-*`: frontends del Core
- `sw-fr-*`: frontends del Switch
- `kng-*`: servicios internos del stack de Kong

Variables del `.env` de Kong:

```env
KONGA_PG_DATABASE=konga
CORE_BCK_SEC_URL=http://IP_PUBLICA_CORE:8012
SW_BCK_ENR_URL=http://IP_PUBLICA_SWITCH:8014
CORE_FR_WEB_URL=http://IP_PUBLICA_FRONT:3000
SW_FR_APP_URL=http://IP_PUBLICA_FRONT:3002
```

Puedes agregar mas IPs o mas servicios manteniendo el mismo patron `*_URL`. Si un servicio cambia de instancia, solo cambias su URL en `kong/.env` y vuelves a ejecutar `docker compose --env-file .env up -d` en `kong/`.

En el primer ingreso a Konga crea un usuario administrador y registra Kong apuntando a `http://kng-gateway:8001` desde la red interna del stack o a `http://localhost:8001` si accedes desde tu navegador local.

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

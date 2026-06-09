# Decisiones de infraestructura

## RabbitMQ

No se despliega RabbitMQ en el Core V2. El documento del Core prioriza consistencia síncrona entre Account y Accounting; el documento del Switch sí justifica Message Broker para procesamiento asíncrono de lotes. Por tanto, RabbitMQ queda fuera del despliegue del Core para evitar sobreingeniería y consumo innecesario de recursos.

## gRPC interno

El Core usa gRPC únicamente para comunicación interna crítica:

- core-account-service -> core-customer-service
- core-account-service -> core-admin-service
- core-account-service -> core-accounting-service

## REST/OpenAPI vía Kong

Kong es el punto de entrada para canales externos, frontend, Switch y pruebas Postman/Newman.

## Persistencia

Cada base tiene volumen nombrado. No usar `down -v` salvo cuando se quiera reiniciar desde cero.

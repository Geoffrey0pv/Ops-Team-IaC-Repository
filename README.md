# Microservice Infrastructure

## Estrategia de Infraestructura

Este repositorio implementa una arquitectura de microservicios cloud-native utilizando Docker y Docker Compose como estrategia de Infrastructure as Code (IaC). La solución despliega una aplicación distribuida completa usando imágenes pre-construidas, eliminando la necesidad de código fuente local.

## Arquitectura de la Solución

### Componentes Principales

| Servicio | Imagen Docker | Puerto | Función |
|----------|---------------|--------|---------|
| API Gateway | nginx:1.29.1 | 80, 8888 | Proxy reverso y load balancer |
| Users API | geoffrey0pv/users-api:latest-master | 8083 | Gestión de usuarios con cache Redis |
| Auth API | geoffrey0pv/auth-api:latest-master | 8000 | Autenticación JWT |
| Todos API | geoffrey0pv/todos-api:latest-master | 8082 | CRUD de tareas |
| Frontend | geoffrey0pv/frontend:latest-master | 8080 | Interfaz de usuario Vue.js |
| Log Processor | geoffrey0pv/log-message-processor:latest-master | - | Procesamiento de logs Python |
| Redis | redis:7.0-alpine | 6379 | Base de datos en memoria y cache |
| Zipkin | openzipkin/zipkin:2.23.19 | 9411 | Distributed tracing |

## Diagrama de Arquitectura

```mermaid
graph TB
    %% Cliente y API Gateway
    Client[Cliente]
    Gateway[API Gateway<br/>Nginx:1.29.1<br/>:80, :8888]
    
    %% Frontend
    Frontend[Frontend<br/>Vue.js SPA<br/>:8080]
    
    %% Microservicios Backend
    AuthAPI[Auth API<br/>Go + JWT<br/>:8000]
    UsersAPI[Users API<br/>Spring Boot<br/>:8083]
    TodosAPI[Todos API<br/>Node.js Express<br/>:8082]
        
    %% Procesador de Logs
    LogProcessor[Log Processor<br/>Python<br/>Redis Consumer]
    
    %% Almacenamiento y Cache
    Redis[(Redis<br/>Cache & Message Queue<br/>:6379)]
    
    %% Monitoreo
    Zipkin[Zipkin<br/>Distributed Tracing<br/>:9411]
    
    %% Red Docker
    subgraph Network["Docker Network: microservices-net"]
        Gateway
        Frontend
        AuthAPI
        UsersAPI
        TodosAPI
        LogProcessor
        Redis
        Zipkin
    end
    
    %% Flujos principales
    Client -->|HTTP :80| Gateway
    Client -->|Zipkin UI :9411| Zipkin
    
    %% API Gateway routing
    Gateway -->|"/api/auth/*"| AuthAPI
    Gateway -->|"/api/users/*"| UsersAPI
    Gateway -->|"/api/todos/*"| TodosAPI
    Gateway -->|"/api/zipkin/*"| Zipkin
    Gateway -->|"/* (SPA)"| Frontend
    
    %% Dependencias entre servicios
    AuthAPI -.->|"User validation"| UsersAPI
    UsersAPI -->|"Tracing"| Zipkin
    AuthAPI -->|"Tracing"| Zipkin
    TodosAPI -->|"Tracing"| Zipkin
    Frontend -->|"Tracing"| Zipkin
    LogProcessor -->|"Tracing"| Zipkin
    
    %% Cache y almacenamiento
    UsersAPI <-->|"Cache"| Redis
    TodosAPI <-->|"Cache"| Redis
    TodosAPI -->|"Pub/Sub"| Redis
    Redis -->|"Subscribe"| LogProcessor
    
    %% Health Checks
    Gateway -.->|"Health Check"| UsersAPI
    Gateway -.->|"Health Check"| TodosAPI
    
    %% Estilos
    classDef client fill:#2196F3,stroke:#1976D2,stroke-width:2px,color:#fff
    classDef gateway fill:#FF9800,stroke:#F57C00,stroke-width:2px,color:#fff
    classDef api fill:#9C27B0,stroke:#7B1FA2,stroke-width:2px,color:#fff
    classDef storage fill:#4CAF50,stroke:#388E3C,stroke-width:2px,color:#fff
    classDef monitor fill:#E91E63,stroke:#C2185B,stroke-width:2px,color:#fff
    classDef frontend fill:#00BCD4,stroke:#0097A7,stroke-width:2px,color:#fff
    
    class Client client
    class Gateway gateway
    class AuthAPI,UsersAPI,TodosAPI api
    class Redis storage
    class Zipkin monitor
    class Frontend,LogProcessor frontend
```

### Flujo de Datos Detallado

```mermaid
sequenceDiagram
    participant C as Cliente
    participant G as API Gateway
    participant A as Auth API
    participant U as Users API
    participant T as Todos API
    participant R as Redis
    participant Z as Zipkin
    participant L as Log Processor

    %% Flujo de autenticación
    C->>G: POST /api/auth/login
    G->>A: Forward request
    A->>U: Validate user credentials
    U->>R: Check user cache
    R-->>U: User data or miss
    U-->>A: User validation result
    A->>Z: Send trace data
    A-->>G: JWT Token
    G-->>C: Authentication response

    %% Flujo de operaciones con TODOs
    C->>G: GET /api/todos/ (with JWT)
    G->>T: Forward authenticated request
    T->>R: Check todos cache
    R-->>T: Cached todos or miss
    T->>R: Publish log message
    R->>L: Notify log processor
    T->>Z: Send trace data
    T-->>G: Todos response
    G-->>C: Todos data

    %% Procesamiento asíncrono de logs
    L->>R: Subscribe to log_channel
    L->>Z: Send processing traces
```

## Patrones de Diseño Implementados

### 1. API Gateway Pattern
- Nginx actua como punto único de entrada
- Ruteo inteligente basado en paths (/api/users/, /api/todos/, /api/auth/)
- Load balancing automático entre instancias
- Health checks integrados

### 2. Cache-Aside Pattern
- Redis como store de cache distribuido
- Los microservicios implementan lógica de cache transparente
- Mejora significativa en tiempos de respuesta
- Reduce carga en servicios backend

### 3. Service Discovery
- Comunicación inter-servicios via nombres DNS de contenedor
- Red Docker bridge compartida (microservices-net)
- Resolución automática de servicios
- Failover transparente

### 4. Distributed Tracing
- Zipkin para monitoreo de requests distribuidos
- Correlación de traces entre microservicios
- Identificación de cuellos de botella
- Análisis de performance end-to-end

### 5. Horizontal Scaling
- Escalado automático de instancias via Docker Compose
- Load balancing round-robin entre réplicas
- Alta disponibilidad por redundancia
- Capacidad de manejar picos de tráfico

## Estrategia de Despliegue

### Automatización Completa
```bash
./setup.sh          # Configuración inicial automatizada
./deploy.sh          # Despliegue con escalado personalizado
./monitor.sh         # Monitoreo en tiempo real
./cleanup.sh         # Limpieza de infraestructura
./test-patterns.sh   # Validación de patrones implementados
```

### Configuración de Red
- Red bridge dedicada para microservicios
- Aislamiento de tráfico interno
- Comunicación segura entre contenedores
- Exposición controlada de puertos

### Gestión de Estado
- Volúmenes persistentes para Redis
- Configuración externalizada via environment variables
- Secretos gestionados a través de Docker Compose
- Backups automáticos de datos críticos

## Ventajas de esta Estrategia

### Simplicidad Operacional
- Un comando para desplegar toda la infraestructura
- No requiere conocimiento profundo de cada microservicio
- Configuración declarativa via docker-compose.yml
- Scripts automatizados para operaciones comunes

### Portabilidad
- Funciona en cualquier sistema con Docker
- Independiente del sistema operativo host
- Fácil migración entre entornos
- Reproducibilidad garantizada

### Escalabilidad
- Escalado horizontal transparente
- Ajuste dinámico de recursos
- Load balancing automático
- Alta disponibilidad por diseño

### Observabilidad
- Monitoreo integrado de todos los componentes
- Logs centralizados
- Métricas de performance en tiempo real
- Distributed tracing para debugging

## Comandos Básicos

### Despliegue
```bash
# Inicializar infraestructura completa
./setup.sh

# Escalar servicios específicos
./deploy.sh --users-api 3 --todos-api 2 --auth-api 2
```

### Monitoreo
```bash
# Dashboard completo
./monitor.sh

# Logs específicos
docker-compose logs -f users-api
```

### Mantenimiento
```bash
# Reiniciar servicio específico
docker-compose restart users-api

# Cleanup completo
./cleanup.sh --all
```

Esta estrategia de infraestructura proporciona una base sólida para aplicaciones de microservicios modernas, combinando simplicidad operacional con patrones de diseño probados en producción.

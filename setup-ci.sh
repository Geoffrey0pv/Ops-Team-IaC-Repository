#!/bin/bash

# 🚀 MICROSERVICE INFRASTRUCTURE - CI SETUP SCRIPT
# =================================================
# Script optimizado para CI/CD sin prompts interactivos

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Funciones de utilidad
show_step() {
    echo -e "\n${CYAN}🔧 $1${NC}"
}

show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_info() {
    echo -e "${YELLOW}ℹ️  $1${NC}"
}

# Verificar prerequisitos
check_prerequisites() {
    show_step "Verificando prerequisitos para CI"
    
    if ! command -v docker &> /dev/null; then
        show_error "Docker no está instalado"
        exit 1
    fi
    show_success "Docker disponible: $(docker --version)"
    
    if ! command -v docker-compose &> /dev/null; then
        show_error "Docker Compose no está instalado"
        exit 1
    fi
    show_success "Docker Compose disponible: $(docker-compose --version)"
    
    if ! docker info &> /dev/null; then
        show_error "Docker daemon no está corriendo"
        exit 1
    fi
    show_success "Docker daemon está corriendo"
}

# Limpiar puertos ocupados
free_ports() {
    show_step "Liberando puertos necesarios"
    
    local ports=(80 9411)
    
    for port in "${ports[@]}"; do
        local process_using_port
        process_using_port=$(netstat -tulpn 2>/dev/null | grep ":$port " || echo "")
        
        if [ -n "$process_using_port" ]; then
            show_info "Puerto $port está ocupado - intentando liberar"
            
            # Intentar terminar procesos usando el puerto
            sudo fuser -k "$port/tcp" 2>/dev/null || true
            sleep 2
            
            # Verificar si se liberó
            if netstat -tulpn 2>/dev/null | grep -q ":$port "; then
                show_error "No se pudo liberar puerto $port"
                show_info "Continuando - Docker manejará el conflicto"
            else
                show_success "Puerto $port liberado"
            fi
        else
            show_success "Puerto $port disponible"
        fi
    done
}

# Cleanup previo
cleanup_previous() {
    show_step "Limpiando despliegue previo"
    
    # Detener servicios del compose
    docker-compose down -v --remove-orphans 2>/dev/null || true
    
    # Limpiar contenedores huérfanos
    docker container prune -f >/dev/null 2>&1 || true
    
    # Limpiar volúmenes huérfanos
    docker volume prune -f >/dev/null 2>&1 || true
    
    show_success "Cleanup previo completado"
}

# Descargar imágenes
pull_images() {
    show_step "Descargando imágenes"
    
    local images=(
        "raulqode/auth-api:latest"
        "raulqode/users-api:latest"
        "raulqode/todos-api:latest"
        "raulqode/frontend:latest"
        "raulqode/log-message-processor:latest"
        "nginx:1.29.1"
        "redis:7.0-alpine"
        "openzipkin/zipkin:2.23.19"
    )
    
    for image in "${images[@]}"; do
        echo -e "${BLUE}Descargando: ${image}${NC}"
        if docker pull "$image"; then
            show_success "Descargado: $image"
        else
            show_error "Error descargando: $image"
            exit 1
        fi
    done
}

# Despliegue por etapas
deploy_staged() {
    show_step "Desplegando servicios por etapas"
    
    # Etapa 1: Servicios base
    echo -e "${BLUE}Etapa 1: Servicios base (Redis, Zipkin)${NC}"
    if docker-compose up -d redis zipkin; then
        show_success "Servicios base iniciados"
        sleep 5
    else
        show_error "Error en servicios base"
        exit 1
    fi
    
    # Etapa 2: APIs backend
    echo -e "${BLUE}Etapa 2: APIs backend${NC}"
    if docker-compose up -d users-api auth-api todos-api log-message-processor; then
        show_success "APIs backend iniciadas"
        sleep 10
    else
        show_error "Error en APIs backend"
        exit 1
    fi
    
    # Etapa 3: Frontend y Gateway
    echo -e "${BLUE}Etapa 3: Frontend y Gateway${NC}"
    if docker-compose up -d frontend nginx-gateway; then
        show_success "Frontend y Gateway iniciados"
        sleep 5
    else
        show_error "Error en Frontend/Gateway"
        exit 1
    fi
}

# Verificación de salud
health_check() {
    show_step "Verificando salud de servicios"
    
    local max_attempts=24
    local attempt=1
    
    echo -e "${BLUE}Esperando que servicios estén listos...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        echo -e "${YELLOW}Intento $attempt/$max_attempts${NC}"
        
        # Verificar API Gateway
        if curl -sf "http://localhost/health" >/dev/null 2>&1; then
            show_success "API Gateway: Healthy"
            
            # Verificar Redis
            if docker-compose exec -T redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
                show_success "Redis: Healthy"
                
                # Verificar servicios corriendo
                local running_services
                running_services=$(docker-compose ps --services --filter "status=running" | wc -l)
                
                if [ "$running_services" -ge 6 ]; then
                    show_success "Health check pasado - $running_services servicios corriendo"
                    return 0
                fi
            fi
        fi
        
        echo -e "${YELLOW}Servicios no están listos, esperando...${NC}"
        sleep 5
        ((attempt++))
    done
    
    show_error "Health check falló después de $max_attempts intentos"
    
    # Mostrar diagnóstico
    echo -e "\n${BLUE}=== DIAGNÓSTICO ===${NC}"
    docker-compose ps
    echo -e "\n${BLUE}=== LOGS DE SERVICIOS ===${NC}"
    docker-compose logs --tail=20
    
    return 1
}

# Mostrar información final
show_final_info() {
    show_step "Información de despliegue CI"
    
    local running_services
    running_services=$(docker-compose ps -q | wc -l)
    
    echo -e "${GREEN}🎉 Despliegue CI completado!${NC}\n"
    
    echo -e "${CYAN}📊 Estado del despliegue:${NC}"
    echo -e "   ${BLUE}Contenedores corriendo: ${YELLOW}$running_services${NC}"
    echo -e "   ${BLUE}API Gateway: ${YELLOW}http://localhost/${NC}"
    echo -e "   ${BLUE}Zipkin: ${YELLOW}http://localhost:9411/${NC}\n"
    
    echo -e "${CYAN}🔧 Comandos de monitoreo:${NC}"
    echo -e "   ${BLUE}Estado: ${YELLOW}docker-compose ps${NC}"
    echo -e "   ${BLUE}Logs: ${YELLOW}docker-compose logs -f${NC}"
    echo -e "   ${BLUE}Health: ${YELLOW}curl http://localhost/health${NC}"
}

# Script principal
main() {
    echo -e "\n${CYAN}${BOLD}"
    echo "🚀 MICROSERVICE INFRASTRUCTURE - CI SETUP"
    echo "========================================="
    echo -e "${NC}"
    
    check_prerequisites
    free_ports
    cleanup_previous
    pull_images
    deploy_staged
    
    if health_check; then
        show_final_info
        echo -e "\n${GREEN}✅ Setup CI exitoso!${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Setup CI falló!${NC}"
        exit 1
    fi
}

# Ejecutar
main "$@"
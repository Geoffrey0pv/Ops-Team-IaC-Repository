#!/bin/bash

# 🚀 MICROSERVICE INFRASTRUCTURE - SETUP SCRIPT
# ==============================================
# Script para desplegar la infraestructura completa usando imágenes de Docker Hub
# No requiere código fuente, solo Docker y Docker Compose

set -e  # Salir si cualquier comando falla

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Información del proyecto
PROJECT_NAME="Microservice Infrastructure"
VERSION="1.0.0"
DOCKER_IMAGES=(
    "raulqode/auth-api:latest"
    "raulqode/users-api:latest"
    "raulqode/todos-api:latest"
    "raulqode/frontend:latest"
    "raulqode/log-message-processor:latest"
)

# Funciones de utilidad
print_header() {
    echo -e "\n${CYAN}${BOLD}"
    echo "🏗️  $PROJECT_NAME - Setup Script"
    echo "=================================="
    echo -e "Version: $VERSION${NC}\n"
}

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

show_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

# Verificar prerequisitos
check_prerequisites() {
    show_step "Verificando prerequisitos"
    
    # Verificar Docker
    if ! command -v docker &> /dev/null; then
        show_error "Docker no está instalado"
        echo -e "${BLUE}Instala Docker desde: ${YELLOW}https://docs.docker.com/get-docker/${NC}"
        exit 1
    fi
    show_success "Docker está instalado: $(docker --version)"
    
    # Verificar Docker Compose
    if ! command -v docker-compose &> /dev/null; then
        show_error "Docker Compose no está instalado"
        echo -e "${BLUE}Instala Docker Compose desde: ${YELLOW}https://docs.docker.com/compose/install/${NC}"
        exit 1
    fi
    show_success "Docker Compose está instalado: $(docker-compose --version)"
    
    # Verificar que Docker esté corriendo
    if ! docker info &> /dev/null; then
        show_error "Docker no está corriendo"
        echo -e "${BLUE}Inicia Docker y vuelve a ejecutar el script${NC}"
        exit 1
    fi
    show_success "Docker está corriendo correctamente"
}

# Verificar puertos disponibles
check_ports() {
    show_step "Verificando puertos disponibles"
    
    local ports=(80 9411)
    local busy_ports=()
    
    for port in "${ports[@]}"; do
        if netstat -an 2>/dev/null | grep -q ":$port "; then
            busy_ports+=($port)
        fi
    done
    
    if [ ${#busy_ports[@]} -gt 0 ]; then
        show_warning "Los siguientes puertos están ocupados: ${busy_ports[*]}"
        echo -e "${BLUE}¿Deseas continuar? Los servicios podrían no iniciarse correctamente. (y/N)${NC}"
        read -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            show_info "Setup cancelado por el usuario"
            exit 0
        fi
    else
        show_success "Todos los puertos necesarios están disponibles"
    fi
}

# Descargar imágenes de Docker Hub
pull_images() {
    show_step "Descargando imágenes desde Docker Hub"
    
    for image in "${DOCKER_IMAGES[@]}"; do
        echo -e "${BLUE}Descargando: ${YELLOW}$image${NC}"
        if docker pull "$image"; then
            show_success "Imagen descargada: $image"
        else
            show_error "Error descargando: $image"
            exit 1
        fi
    done
    
    # Descargar imágenes de dependencias
    show_info "Descargando imágenes base (nginx, redis, zipkin)..."
    docker pull nginx:1.29.1 || show_warning "No se pudo descargar nginx:1.29.1"
    docker pull redis:7.0-alpine || show_warning "No se pudo descargar redis:7.0-alpine"
    docker pull openzipkin/zipkin:2.23.19 || show_warning "No se pudo descargar zipkin"
}

# Limpiar instalación previa
cleanup_previous() {
    show_step "Limpiando instalación previa"
    
    if docker-compose ps -q 2>/dev/null | grep -q .; then
        show_info "Deteniendo servicios existentes..."
        docker-compose down -v 2>/dev/null || true
        show_success "Servicios detenidos"
    else
        show_info "No hay servicios previos corriendo"
    fi
    
    # Limpiar volumes huérfanos
    docker volume prune -f >/dev/null 2>&1 || true
    show_success "Cleanup completado"
}

# Desplegar servicios
deploy_services() {
    show_step "Desplegando servicios"
    
    echo -e "${BLUE}Iniciando servicios base...${NC}"
    if docker-compose up -d redis zipkin; then
        show_success "Servicios base iniciados (Redis, Zipkin)"
    else
        show_error "Error iniciando servicios base"
        exit 1
    fi
    
    sleep 5  # Esperar a que los servicios base se inicialicen
    
    echo -e "${BLUE}Iniciando APIs backend...${NC}"
    if docker-compose up -d users-api auth-api todos-api log-message-processor; then
        show_success "APIs backend iniciadas"
    else
        show_error "Error iniciando APIs backend"
        exit 1
    fi
    
    sleep 10  # Esperar a que las APIs se inicialicen
    
    echo -e "${BLUE}Iniciando frontend y gateway...${NC}"
    if docker-compose up -d frontend nginx-gateway; then
        show_success "Frontend y Gateway iniciados"
    else
        show_error "Error iniciando frontend y gateway"
        exit 1
    fi
    
    show_success "Todos los servicios desplegados correctamente"
}

# Verificar estado de los servicios
verify_deployment() {
    show_step "Verificando estado de servicios"
    
    echo -e "${BLUE}Esperando que los servicios estén listos...${NC}"
    sleep 15
    
    # Verificar servicios corriendo
    local running_services
    running_services=$(docker-compose ps --services --filter "status=running" | wc -l)
    local total_services
    total_services=$(docker-compose config --services | wc -l)
    
    show_info "Servicios corriendo: $running_services/$total_services"
    
    # Health checks básicos
    local health_checks_passed=0
    
    echo -e "\n${BLUE}Ejecutando health checks:${NC}"
    
    # API Gateway health check
    if curl -s -f "http://localhost/health" >/dev/null 2>&1; then
        show_success "API Gateway: Healthy"
        ((health_checks_passed++))
    else
        show_error "API Gateway: Not responding"
    fi
    
    # Redis health check
    if docker-compose exec -T redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
        show_success "Redis: Healthy"
        ((health_checks_passed++))
    else
        show_error "Redis: Not responding"
    fi
    
    # Zipkin health check
    if curl -s -f "http://localhost:9411/health" >/dev/null 2>&1; then
        show_success "Zipkin: Healthy"
        ((health_checks_passed++))
    else
        show_warning "Zipkin: Not responding (puede tardar en iniciarse)"
    fi
    
    if [ $health_checks_passed -ge 2 ]; then
        show_success "Health checks principales pasaron correctamente"
    else
        show_warning "Algunos servicios pueden no estar listos aún"
    fi
}

# Mostrar información de acceso
show_access_info() {
    show_step "Información de acceso"
    
    echo -e "${GREEN}🎉 ¡Infraestructura desplegada exitosamente!${NC}\n"
    
    echo -e "${CYAN}📋 URLs de acceso:${NC}"
    echo -e "   ${BLUE}🌐 Aplicación principal: ${YELLOW}http://localhost/${NC}"
    echo -e "   ${BLUE}📊 Zipkin (Tracing): ${YELLOW}http://localhost:9411/${NC}"
    echo -e "   ${BLUE}❤️  Health Check: ${YELLOW}http://localhost/health${NC}\n"
    
    echo -e "${CYAN}🔧 Comandos útiles:${NC}"
    echo -e "   ${BLUE}Ver logs: ${YELLOW}docker-compose logs -f${NC}"
    echo -e "   ${BLUE}Ver estado: ${YELLOW}docker-compose ps${NC}"
    echo -e "   ${BLUE}Escalar servicios: ${YELLOW}docker-compose up -d --scale users-api=3${NC}"
    echo -e "   ${BLUE}Detener todo: ${YELLOW}docker-compose down${NC}\n"
    
    echo -e "${CYAN}🧪 Testing:${NC}"
    echo -e "   ${BLUE}Ejecutar tests: ${YELLOW}./test-patterns.sh${NC}"
    echo -e "   ${BLUE}Monitoreo: ${YELLOW}./monitor.sh${NC}\n"
    
    echo -e "${GREEN}✨ La infraestructura está lista para usar!${NC}"
}

# Script principal
main() {
    print_header
    
    # Verificar que estamos en el directorio correcto
    if [ ! -f "docker-compose.yml" ]; then
        show_error "docker-compose.yml no encontrado"
        echo -e "${BLUE}Ejecuta este script desde el directorio de la infraestructura${NC}"
        exit 1
    fi
    
    check_prerequisites
    check_ports
    cleanup_previous
    pull_images
    deploy_services
    verify_deployment
    show_access_info
    
    echo -e "\n${GREEN}🚀 Setup completado exitosamente!${NC}"
}

# Manejo de señales
trap 'echo -e "\n${RED}❌ Setup interrumpido${NC}"; exit 1' INT TERM

# Ejecutar script principal
main "$@"

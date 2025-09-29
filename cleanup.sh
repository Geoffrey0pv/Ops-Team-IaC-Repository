#!/bin/bash

# 🧹 MICROSERVICE INFRASTRUCTURE - CLEANUP SCRIPT
# ===============================================
# Script para limpiar completamente la infraestructura

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
print_header() {
    echo -e "\n${CYAN}${BOLD}"
    echo "🧹 Microservice Infrastructure - Cleanup"
    echo "======================================="
    echo -e "${NC}"
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

# Mostrar ayuda
show_help() {
    echo -e "${BLUE}Uso: ./cleanup.sh [OPTIONS]${NC}"
    echo -e "\n${CYAN}Opciones:${NC}"
    echo -e "  ${BLUE}-a, --all${NC}                 Cleanup completo (servicios + imágenes + volúmenes)"
    echo -e "  ${BLUE}-v, --volumes${NC}             Eliminar también volúmenes de datos"
    echo -e "  ${BLUE}-i, --images${NC}              Eliminar también imágenes locales"
    echo -e "  ${BLUE}-f, --force${NC}               No pedir confirmación"
    echo -e "  ${BLUE}-h, --help${NC}                Mostrar esta ayuda"
    echo -e "\n${CYAN}Ejemplos:${NC}"
    echo -e "  ${YELLOW}./cleanup.sh${NC}                     # Cleanup básico (solo detener servicios)"
    echo -e "  ${YELLOW}./cleanup.sh -v${NC}                  # Cleanup + eliminar volúmenes"
    echo -e "  ${YELLOW}./cleanup.sh --all${NC}               # Cleanup completo"
    echo -e "  ${YELLOW}./cleanup.sh -a -f${NC}               # Cleanup completo sin confirmación"
}

# Parsear argumentos
parse_arguments() {
    CLEANUP_VOLUMES=false
    CLEANUP_IMAGES=false
    FORCE_MODE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -a|--all)
                CLEANUP_VOLUMES=true
                CLEANUP_IMAGES=true
                shift
                ;;
            -v|--volumes)
                CLEANUP_VOLUMES=true
                shift
                ;;
            -i|--images)
                CLEANUP_IMAGES=true
                shift
                ;;
            -f|--force)
                FORCE_MODE=true
                shift
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                show_error "Opción desconocida: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Mostrar configuración de cleanup
show_cleanup_config() {
    show_step "Configuración de Cleanup"
    
    echo -e "${BLUE}🗑️  Elementos a limpiar:${NC}"
    echo -e "   ${YELLOW}✅ Detener y remover contenedores${NC}"
    echo -e "   ${YELLOW}$([ "$CLEANUP_VOLUMES" = true ] && echo "✅" || echo "❌") Eliminar volúmenes de datos${NC}"
    echo -e "   ${YELLOW}$([ "$CLEANUP_IMAGES" = true ] && echo "✅" || echo "❌") Eliminar imágenes locales${NC}"
    echo -e "   ${YELLOW}Modo forzado: $([ "$FORCE_MODE" = true ] && echo "Activado" || echo "Desactivado")${NC}"
}

# Pedir confirmación
confirm_cleanup() {
    if [ "$FORCE_MODE" = true ]; then
        show_info "Modo forzado activado, saltando confirmación"
        return 0
    fi
    
    echo -e "\n${YELLOW}⚠️  ¿Estás seguro de que quieres proceder con el cleanup?${NC}"
    
    if [ "$CLEANUP_VOLUMES" = true ]; then
        show_warning "ATENCIÓN: Se eliminarán los datos de Redis (cache y colas)"
    fi
    
    if [ "$CLEANUP_IMAGES" = true ]; then
        show_warning "ATENCIÓN: Se eliminarán las imágenes Docker locales"
    fi
    
    echo -e "\n${BLUE}Escribe 'yes' para continuar o cualquier otra cosa para cancelar:${NC}"
    read -r response
    
    if [ "$response" != "yes" ]; then
        show_info "Cleanup cancelado por el usuario"
        exit 0
    fi
}

# Verificar servicios corriendo
check_running_services() {
    show_step "Verificando servicios corriendo"
    
    if [ ! -f "docker-compose.yml" ]; then
        show_warning "docker-compose.yml no encontrado en el directorio actual"
        return 1
    fi
    
    local running_containers
    running_containers=$(docker-compose ps -q 2>/dev/null | wc -l)
    
    if [ "$running_containers" -gt 0 ]; then
        show_info "Se encontraron $running_containers contenedores corriendo"
        docker-compose ps
        return 0
    else
        show_info "No hay servicios corriendo"
        return 1
    fi
}

# Detener servicios
stop_services() {
    show_step "Deteniendo servicios"
    
    if docker-compose ps -q 2>/dev/null | grep -q .; then
        echo -e "${BLUE}Deteniendo todos los servicios...${NC}"
        
        if docker-compose down; then
            show_success "Servicios detenidos correctamente"
        else
            show_error "Error deteniendo servicios"
            return 1
        fi
    else
        show_info "No hay servicios que detener"
    fi
}

# Limpiar volúmenes
cleanup_volumes() {
    if [ "$CLEANUP_VOLUMES" = false ]; then
        return 0
    fi
    
    show_step "Limpiando volúmenes"
    
    # Eliminar volúmenes específicos del proyecto
    local project_volumes=(
        "microservice-redis-data"
        "microservice-app-example_redis-data"
    )
    
    for volume in "${project_volumes[@]}"; do
        if docker volume ls -q | grep -q "^${volume}$"; then
            echo -e "${BLUE}Eliminando volumen: ${volume}${NC}"
            if docker volume rm "$volume" 2>/dev/null; then
                show_success "Volumen eliminado: $volume"
            else
                show_warning "No se pudo eliminar volumen: $volume"
            fi
        fi
    done
    
    # Limpiar volúmenes huérfanos
    echo -e "${BLUE}Eliminando volúmenes huérfanos...${NC}"
    docker volume prune -f >/dev/null 2>&1 || true
    show_success "Volúmenes huérfanos eliminados"
}

# Limpiar imágenes
cleanup_images() {
    if [ "$CLEANUP_IMAGES" = false ]; then
        return 0
    fi
    
    show_step "Limpiando imágenes"
    
    # Imágenes del proyecto
    local project_images=(
        "geoffrey0pv/auth-api:latest-master"
        "geoffrey0pv/users-api:latest-master"
        "geoffrey0pv/todos-api:latest-master"
        "geoffrey0pv/frontend:latest-master"
        "geoffrey0pv/log-message-processor:latest-master"
    )
    
    echo -e "${BLUE}Eliminando imágenes del proyecto...${NC}"
    for image in "${project_images[@]}"; do
        if docker images -q "$image" 2>/dev/null | grep -q .; then
            echo -e "${BLUE}Eliminando imagen: ${image}${NC}"
            if docker rmi "$image" 2>/dev/null; then
                show_success "Imagen eliminada: $image"
            else
                show_warning "No se pudo eliminar imagen: $image"
            fi
        fi
    done
    
    # Limpiar imágenes huérfanas
    echo -e "${BLUE}Eliminando imágenes huérfanas...${NC}"
    docker image prune -f >/dev/null 2>&1 || true
    show_success "Imágenes huérfanas eliminadas"
}

# Limpiar redes
cleanup_networks() {
    show_step "Limpiando redes"
    
    # Eliminar red específica del proyecto
    if docker network ls -q --filter "name=microservices-net" | grep -q .; then
        echo -e "${BLUE}Eliminando red: microservices-net${NC}"
        if docker network rm microservices-net 2>/dev/null; then
            show_success "Red eliminada: microservices-net"
        else
            show_warning "No se pudo eliminar red: microservices-net"
        fi
    fi
    
    # Limpiar redes huérfanas
    echo -e "${BLUE}Eliminando redes huérfanas...${NC}"
    docker network prune -f >/dev/null 2>&1 || true
    show_success "Redes huérfanas eliminadas"
}

# Verificar cleanup
verify_cleanup() {
    show_step "Verificando cleanup"
    
    local remaining_containers
    local remaining_volumes
    local remaining_images
    
    # Verificar contenedores
    remaining_containers=$(docker-compose ps -q 2>/dev/null | wc -l)
    if [ "$remaining_containers" -eq 0 ]; then
        show_success "No hay contenedores del proyecto corriendo"
    else
        show_warning "$remaining_containers contenedores aún corriendo"
    fi
    
    # Verificar volúmenes (si se limpiaron)
    if [ "$CLEANUP_VOLUMES" = true ]; then
        remaining_volumes=$(docker volume ls -q | grep -E "(redis|microservice)" | wc -l || echo "0")
        if [ "$remaining_volumes" -eq 0 ]; then
            show_success "Volúmenes del proyecto eliminados"
        else
            show_warning "$remaining_volumes volúmenes del proyecto aún presentes"
        fi
    fi
    
    # Verificar imágenes (si se limpiaron)
    if [ "$CLEANUP_IMAGES" = true ]; then
        remaining_images=$(docker images -q | grep -f <(echo -e "geoffrey0pv/auth-api\ngeoffrey0pv/users-api\ngeoffrey0pv/todos-api\ngeoffrey0pv/frontend\ngeoffrey0pv/log-message-processor") | wc -l || echo "0")
        if [ "$remaining_images" -eq 0 ]; then
            show_success "Imágenes del proyecto eliminadas"
        else
            show_warning "$remaining_images imágenes del proyecto aún presentes"
        fi
    fi
}

# Mostrar información final
show_cleanup_summary() {
    show_step "Resumen del Cleanup"
    
    echo -e "${GREEN}🧹 Cleanup completado!${NC}\n"
    
    echo -e "${CYAN}📊 Elementos procesados:${NC}"
    echo -e "   ${GREEN}✅ Servicios detenidos y removidos${NC}"
    echo -e "   $([ "$CLEANUP_VOLUMES" = true ] && echo "${GREEN}✅" || echo "${BLUE}➖") Volúmenes $([ "$CLEANUP_VOLUMES" = true ] && echo "eliminados" || echo "conservados")${NC}"
    echo -e "   $([ "$CLEANUP_IMAGES" = true ] && echo "${GREEN}✅" || echo "${BLUE}➖") Imágenes $([ "$CLEANUP_IMAGES" = true ] && echo "eliminadas" || echo "conservadas")${NC}"
    echo -e "   ${GREEN}✅ Redes limpiadas${NC}\n"
    
    echo -e "${CYAN}🔧 Para volver a desplegar:${NC}"
    echo -e "   ${BLUE}Setup completo: ${YELLOW}./setup.sh${NC}"
    echo -e "   ${BLUE}Deploy rápido: ${YELLOW}./deploy.sh --quick${NC}"
    echo -e "   ${BLUE}Deploy custom: ${YELLOW}./deploy.sh -u 3 -t 2${NC}\n"
    
    if [ "$CLEANUP_VOLUMES" = true ]; then
        show_warning "Nota: Los datos de Redis fueron eliminados. La aplicación creará nuevos datos al iniciarse."
    fi
}

# Script principal
main() {
    print_header
    
    parse_arguments "$@"
    show_cleanup_config
    confirm_cleanup
    
    check_running_services
    stop_services
    cleanup_volumes
    cleanup_images
    cleanup_networks
    verify_cleanup
    show_cleanup_summary
    
    echo -e "\n${GREEN}✨ Cleanup exitoso!${NC}"
}

# Manejo de errores
trap 'echo -e "\n${RED}❌ Cleanup interrumpido${NC}"; exit 1' INT TERM

# Ejecutar script
main "$@"

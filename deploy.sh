#!/bin/bash

# 📈 MICROSERVICE INFRASTRUCTURE - DEPLOY & SCALE SCRIPT
# ======================================================
# Script para desplegar con escalamiento automático y alta disponibilidad

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuración de escalamiento por defecto
DEFAULT_USERS_API_REPLICAS=3
DEFAULT_TODOS_API_REPLICAS=2
DEFAULT_AUTH_API_REPLICAS=2

# Funciones de utilidad
print_header() {
    echo -e "\n${CYAN}${BOLD}"
    echo "📈 Microservice Infrastructure - Deploy & Scale"
    echo "=============================================="
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

# Mostrar ayuda
show_help() {
    echo -e "${BLUE}Uso: ./deploy.sh [OPTIONS]${NC}"
    echo -e "\n${CYAN}Opciones:${NC}"
    echo -e "  ${BLUE}-u, --users-api <num>${NC}     Número de réplicas para Users API (default: $DEFAULT_USERS_API_REPLICAS)"
    echo -e "  ${BLUE}-t, --todos-api <num>${NC}     Número de réplicas para Todos API (default: $DEFAULT_TODOS_API_REPLICAS)"  
    echo -e "  ${BLUE}-a, --auth-api <num>${NC}      Número de réplicas para Auth API (default: $DEFAULT_AUTH_API_REPLICAS)"
    echo -e "  ${BLUE}-q, --quick${NC}               Deploy rápido sin health checks detallados"
    echo -e "  ${BLUE}-h, --help${NC}                Mostrar esta ayuda"
    echo -e "\n${CYAN}Ejemplos:${NC}"
    echo -e "  ${YELLOW}./deploy.sh${NC}                          # Deploy con configuración por defecto"
    echo -e "  ${YELLOW}./deploy.sh -u 5 -t 3${NC}               # 5 Users API, 3 Todos API"
    echo -e "  ${YELLOW}./deploy.sh --quick${NC}                  # Deploy rápido"
    echo -e "  ${YELLOW}./deploy.sh -u 4 -t 2 -a 3 --quick${NC}  # Configuración personalizada rápida"
}

# Parsear argumentos de línea de comandos
parse_arguments() {
    USERS_API_REPLICAS=$DEFAULT_USERS_API_REPLICAS
    TODOS_API_REPLICAS=$DEFAULT_TODOS_API_REPLICAS
    AUTH_API_REPLICAS=$DEFAULT_AUTH_API_REPLICAS
    QUICK_MODE=false
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -u|--users-api)
                USERS_API_REPLICAS="$2"
                shift 2
                ;;
            -t|--todos-api)
                TODOS_API_REPLICAS="$2"
                shift 2
                ;;
            -a|--auth-api)
                AUTH_API_REPLICAS="$2"
                shift 2
                ;;
            -q|--quick)
                QUICK_MODE=true
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
    
    # Validar números
    if ! [[ "$USERS_API_REPLICAS" =~ ^[0-9]+$ ]] || [ "$USERS_API_REPLICAS" -lt 1 ] || [ "$USERS_API_REPLICAS" -gt 10 ]; then
        show_error "Users API replicas debe ser un número entre 1 y 10"
        exit 1
    fi
    
    if ! [[ "$TODOS_API_REPLICAS" =~ ^[0-9]+$ ]] || [ "$TODOS_API_REPLICAS" -lt 1 ] || [ "$TODOS_API_REPLICAS" -gt 10 ]; then
        show_error "Todos API replicas debe ser un número entre 1 y 10"
        exit 1
    fi
    
    if ! [[ "$AUTH_API_REPLICAS" =~ ^[0-9]+$ ]] || [ "$AUTH_API_REPLICAS" -lt 1 ] || [ "$AUTH_API_REPLICAS" -gt 10 ]; then
        show_error "Auth API replicas debe ser un número entre 1 y 10"
        exit 1
    fi
}

# Verificar prerequisitos
check_prerequisites() {
    show_step "Verificando prerequisitos"
    
    if [ ! -f "docker-compose.yml" ]; then
        show_error "docker-compose.yml no encontrado"
        exit 1
    fi
    
    if ! command -v docker-compose &> /dev/null; then
        show_error "Docker Compose no está instalado"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        show_error "Docker no está corriendo"
        exit 1
    fi
    
    show_success "Prerequisitos verificados"
}

# Mostrar configuración del deploy
show_deploy_config() {
    show_step "Configuración del Deploy"
    
    echo -e "${BLUE}📊 Réplicas configuradas:${NC}"
    echo -e "   ${YELLOW}Users API: $USERS_API_REPLICAS réplicas${NC}"
    echo -e "   ${YELLOW}Todos API: $TODOS_API_REPLICAS réplicas${NC}"
    echo -e "   ${YELLOW}Auth API: $AUTH_API_REPLICAS réplicas${NC}"
    echo -e "   ${YELLOW}Modo rápido: $([ "$QUICK_MODE" = true ] && echo "Activado" || echo "Desactivado")${NC}"
    
    local total_replicas=$((USERS_API_REPLICAS + TODOS_API_REPLICAS + AUTH_API_REPLICAS))
    echo -e "\n${CYAN}Total de réplicas de API: $total_replicas${NC}"
}

# Deploy inicial de servicios base
deploy_base_services() {
    show_step "Desplegando servicios base"
    
    show_info "Iniciando Redis y Zipkin..."
    if docker-compose up -d redis zipkin; then
        show_success "Servicios base iniciados"
        if [ "$QUICK_MODE" = false ]; then
            sleep 5
        fi
    else
        show_error "Error iniciando servicios base"
        exit 1
    fi
}

# Deploy con escalamiento
deploy_with_scaling() {
    show_step "Desplegando APIs con escalamiento"
    
    local scale_args=""
    scale_args+="--scale users-api=$USERS_API_REPLICAS "
    scale_args+="--scale todos-api=$TODOS_API_REPLICAS "
    scale_args+="--scale auth-api=$AUTH_API_REPLICAS"
    
    show_info "Comando: docker-compose up -d $scale_args"
    
    if docker-compose up -d $scale_args; then
        show_success "APIs escaladas correctamente"
        if [ "$QUICK_MODE" = false ]; then
            sleep 10
        fi
    else
        show_error "Error en el escalamiento"
        exit 1
    fi
}

# Deploy frontend y gateway
deploy_frontend_gateway() {
    show_step "Desplegando Frontend y API Gateway"
    
    # Mantener las escalas en este comando también
    local scale_args=""
    scale_args+="--scale users-api=$USERS_API_REPLICAS "
    scale_args+="--scale todos-api=$TODOS_API_REPLICAS "
    scale_args+="--scale auth-api=$AUTH_API_REPLICAS"
    
    if docker-compose up -d $scale_args frontend nginx-gateway; then
        show_success "Frontend y Gateway desplegados"
        if [ "$QUICK_MODE" = false ]; then
            sleep 5
        fi
    else
        show_error "Error desplegando frontend/gateway"
        exit 1
    fi
}

# Verificar escalamiento
verify_scaling() {
    show_step "Verificando escalamiento"
    
    echo -e "${BLUE}Estado actual de los servicios:${NC}"
    
    # Contar réplicas activas
    local users_running
    local todos_running
    local auth_running
    
    users_running=$(docker-compose ps users-api | grep -c "users-api" || echo "0")
    todos_running=$(docker-compose ps todos-api | grep -c "todos-api" || echo "0")
    auth_running=$(docker-compose ps auth-api | grep -c "auth-api" || echo "0")
    
    # Mostrar resultados
    if [ "$users_running" -eq "$USERS_API_REPLICAS" ]; then
        show_success "Users API: $users_running/$USERS_API_REPLICAS réplicas corriendo"
    else
        show_error "Users API: $users_running/$USERS_API_REPLICAS réplicas corriendo"
    fi
    
    if [ "$todos_running" -eq "$TODOS_API_REPLICAS" ]; then
        show_success "Todos API: $todos_running/$TODOS_API_REPLICAS réplicas corriendo"
    else
        show_error "Todos API: $todos_running/$TODOS_API_REPLICAS réplicas corriendo"
    fi
    
    if [ "$auth_running" -eq "$AUTH_API_REPLICAS" ]; then
        show_success "Auth API: $auth_running/$AUTH_API_REPLICAS réplicas corriendo"
    else
        show_error "Auth API: $auth_running/$AUTH_API_REPLICAS réplicas corriendo"
    fi
    
    # Mostrar distribución de puertos
    echo -e "\n${BLUE}Distribución de puertos por servicio:${NC}"
    docker-compose ps --format "table {{.Service}}\t{{.Ports}}" | grep -E "(users-api|todos-api|auth-api)" || true
}

# Health checks básicos
run_health_checks() {
    if [ "$QUICK_MODE" = true ]; then
        show_info "Saltando health checks detallados (modo rápido)"
        return 0
    fi
    
    show_step "Ejecutando health checks"
    
    local health_passed=0
    local total_checks=3
    
    # API Gateway
    echo -e "${BLUE}Probando API Gateway...${NC}"
    if curl -s -f "http://localhost/health" >/dev/null 2>&1; then
        show_success "API Gateway: Healthy"
        ((health_passed++))
    else
        show_error "API Gateway: No responde"
    fi
    
    # Redis
    echo -e "${BLUE}Probando Redis...${NC}"
    if docker-compose exec -T redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
        show_success "Redis: Healthy"
        ((health_passed++))
    else
        show_error "Redis: No responde"
    fi
    
    # Load balancing test
    echo -e "${BLUE}Probando load balancing...${NC}"
    local lb_success=0
    for i in {1..5}; do
        if curl -s "http://localhost/api/users/" >/dev/null 2>&1; then
            ((lb_success++))
        fi
    done
    
    if [ $lb_success -ge 3 ]; then
        show_success "Load Balancing: Funcionando ($lb_success/5 requests exitosos)"
        ((health_passed++))
    else
        show_error "Load Balancing: Problemas ($lb_success/5 requests exitosos)"
    fi
    
    echo -e "\n${CYAN}Health Checks: $health_passed/$total_checks pasaron${NC}"
}

# Mostrar información final
show_deployment_info() {
    show_step "Información de despliegue"
    
    local total_containers
    total_containers=$(docker-compose ps -q | wc -l)
    local total_replicas=$((USERS_API_REPLICAS + TODOS_API_REPLICAS + AUTH_API_REPLICAS))
    
    echo -e "${GREEN}🎉 Deploy completado exitosamente!${NC}\n"
    
    echo -e "${CYAN}📊 Resumen del despliegue:${NC}"
    echo -e "   ${BLUE}Total de contenedores: ${YELLOW}$total_containers${NC}"
    echo -e "   ${BLUE}Réplicas de APIs: ${YELLOW}$total_replicas${NC}"
    echo -e "   ${BLUE}Users API: ${YELLOW}$USERS_API_REPLICAS réplicas${NC}"
    echo -e "   ${BLUE}Todos API: ${YELLOW}$TODOS_API_REPLICAS réplicas${NC}"
    echo -e "   ${BLUE}Auth API: ${YELLOW}$AUTH_API_REPLICAS réplicas${NC}\n"
    
    echo -e "${CYAN}🌐 URLs de acceso:${NC}"
    echo -e "   ${BLUE}🌐 Aplicación: ${YELLOW}http://localhost/${NC}"
    echo -e "   ${BLUE}📊 Zipkin: ${YELLOW}http://localhost:9411/${NC}"
    echo -e "   ${BLUE}❤️  Health: ${YELLOW}http://localhost/health${NC}\n"
    
    echo -e "${CYAN}🔧 Comandos de gestión:${NC}"
    echo -e "   ${BLUE}Ver estado: ${YELLOW}docker-compose ps${NC}"
    echo -e "   ${BLUE}Ver logs: ${YELLOW}docker-compose logs -f [service]${NC}"
    echo -e "   ${BLUE}Escalar más: ${YELLOW}docker-compose up -d --scale users-api=5${NC}"
    echo -e "   ${BLUE}Detener: ${YELLOW}docker-compose down${NC}\n"
}

# Script principal
main() {
    print_header
    
    parse_arguments "$@"
    check_prerequisites
    show_deploy_config
    
    deploy_base_services
    deploy_with_scaling
    deploy_frontend_gateway
    verify_scaling
    run_health_checks
    show_deployment_info
    
    echo -e "\n${GREEN}🚀 Deploy con escalamiento completado!${NC}"
}

# Manejo de errores
trap 'echo -e "\n${RED}❌ Deploy interrumpido${NC}"; exit 1' INT TERM

# Ejecutar script
main "$@"

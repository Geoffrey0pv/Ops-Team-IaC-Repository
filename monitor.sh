#!/bin/bash

# 📊 MICROSERVICE INFRASTRUCTURE - MONITORING SCRIPT
# ==================================================
# Script para monitorear la infraestructura en tiempo real

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Configuración
REFRESH_INTERVAL=5
MONITOR_MODE="dashboard"

# Funciones de utilidad
print_header() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "📊 MICROSERVICE INFRASTRUCTURE - REAL-TIME MONITORING"
    echo "====================================================="
    echo -e "${NC}"
    echo -e "${BLUE}Actualización cada ${REFRESH_INTERVAL}s | Presiona Ctrl+C para salir${NC}"
    echo ""
}

show_help() {
    echo -e "${BLUE}Uso: ./monitor.sh [OPTIONS]${NC}"
    echo -e "\n${CYAN}Opciones:${NC}"
    echo -e "  ${BLUE}-d, --dashboard${NC}           Modo dashboard completo (default)"
    echo -e "  ${BLUE}-s, --services${NC}            Solo estado de servicios"
    echo -e "  ${BLUE}-r, --resources${NC}           Solo recursos (CPU, memoria)"
    echo -e "  ${BLUE}-l, --logs [service]${NC}      Logs en tiempo real de un servicio"
    echo -e "  ${BLUE}-i, --interval <seconds>${NC}  Intervalo de actualización (default: 5s)"
    echo -e "  ${BLUE}-h, --help${NC}                Mostrar esta ayuda"
    echo -e "\n${CYAN}Ejemplos:${NC}"
    echo -e "  ${YELLOW}./monitor.sh${NC}                     # Dashboard completo"
    echo -e "  ${YELLOW}./monitor.sh -s${NC}                  # Solo servicios"
    echo -e "  ${YELLOW}./monitor.sh -l users-api${NC}        # Logs de Users API"
    echo -e "  ${YELLOW}./monitor.sh -i 10 -r${NC}            # Recursos cada 10s"
}

# Parsear argumentos
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -d|--dashboard)
                MONITOR_MODE="dashboard"
                shift
                ;;
            -s|--services)
                MONITOR_MODE="services"
                shift
                ;;
            -r|--resources)
                MONITOR_MODE="resources"
                shift
                ;;
            -l|--logs)
                MONITOR_MODE="logs"
                LOG_SERVICE="$2"
                shift 2
                ;;
            -i|--interval)
                REFRESH_INTERVAL="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                echo -e "${RED}❌ Opción desconocida: $1${NC}"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Validar intervalo
    if ! [[ "$REFRESH_INTERVAL" =~ ^[0-9]+$ ]] || [ "$REFRESH_INTERVAL" -lt 1 ]; then
        echo -e "${RED}❌ Intervalo debe ser un número positivo${NC}"
        exit 1
    fi
}

# Verificar prerequisitos
check_prerequisites() {
    if ! command -v docker-compose &> /dev/null; then
        echo -e "${RED}❌ Docker Compose no está instalado${NC}"
        exit 1
    fi
    
    if ! docker info &> /dev/null; then
        echo -e "${RED}❌ Docker no está corriendo${NC}"
        exit 1
    fi
    
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}❌ docker-compose.yml no encontrado${NC}"
        echo -e "${BLUE}Ejecuta desde el directorio de la infraestructura${NC}"
        exit 1
    fi
}

# Mostrar estado de servicios
show_services_status() {
    echo -e "${CYAN}🔧 ESTADO DE SERVICIOS${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..50})${NC}"
    
    # Usar formato personalizado para docker-compose ps
    if docker-compose ps --format "table {{.Service}}\t{{.State}}\t{{.Ports}}" 2>/dev/null; then
        echo ""
    else
        echo -e "${YELLOW}⚠️  No se pudo obtener estado de servicios${NC}"
    fi
    
    # Contar servicios por estado
    local running_count total_count
    running_count=$(docker-compose ps --services --filter "status=running" 2>/dev/null | wc -l || echo "0")
    total_count=$(docker-compose config --services 2>/dev/null | wc -l || echo "0")
    
    echo -e "${BLUE}📊 Resumen: ${running_count}/${total_count} servicios corriendo${NC}"
}

# Mostrar uso de recursos
show_resources() {
    echo -e "${CYAN}💻 USO DE RECURSOS${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..50})${NC}"
    
    # Obtener estadísticas de contenedores
    if docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" 2>/dev/null | head -20; then
        echo ""
    else
        echo -e "${YELLOW}⚠️  No se pudo obtener estadísticas de recursos${NC}"
    fi
}

# Mostrar health checks
show_health_checks() {
    echo -e "${CYAN}❤️  HEALTH CHECKS${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..30})${NC}"
    
    # API Gateway health
    if curl -s -f "http://localhost/health" >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅ API Gateway: Healthy${NC}"
    else
        echo -e "   ${RED}❌ API Gateway: Unhealthy${NC}"
    fi
    
    # Redis health
    if docker-compose exec -T redis redis-cli ping 2>/dev/null | grep -q "PONG"; then
        echo -e "   ${GREEN}✅ Redis: Healthy${NC}"
    else
        echo -e "   ${RED}❌ Redis: Unhealthy${NC}"
    fi
    
    # Zipkin health
    if curl -s -f "http://localhost:9411/health" >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅ Zipkin: Healthy${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Zipkin: Not responding${NC}"
    fi
    
    # APIs health (básico)
    local api_health=0
    if curl -s -H "Authorization: Bearer dummy" "http://localhost/api/users/" >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅ Users API: Responding${NC}"
        ((api_health++))
    fi
    
    if curl -s -H "Authorization: Bearer dummy" "http://localhost/api/todos/" >/dev/null 2>&1; then
        echo -e "   ${GREEN}✅ Todos API: Responding${NC}"
        ((api_health++))
    fi
    
    echo -e "   ${BLUE}📊 APIs responding: ${api_health}/2${NC}"
}

# Mostrar información de red
show_network_info() {
    echo -e "${CYAN}🌐 INFORMACIÓN DE RED${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..30})${NC}"
    
    # Mostrar puertos expuestos
    echo -e "${BLUE}Puertos expuestos:${NC}"
    docker-compose ps --format "table {{.Service}}\t{{.Ports}}" 2>/dev/null | grep -E ":[0-9]+->" || echo -e "   ${YELLOW}No hay puertos expuestos${NC}"
    
    echo ""
    echo -e "${BLUE}URLs de acceso:${NC}"
    echo -e "   ${YELLOW}🌐 Aplicación: http://localhost/${NC}"
    echo -e "   ${YELLOW}📊 Zipkin: http://localhost:9411/${NC}"
    echo -e "   ${YELLOW}❤️  Health: http://localhost/health${NC}"
}

# Dashboard completo
show_dashboard() {
    print_header
    
    # Mostrar timestamp
    echo -e "${BLUE}⏰ Última actualización: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
    
    # Dividir en columnas
    {
        show_services_status
        echo ""
        show_health_checks
    } &
    
    wait
    
    echo ""
    show_resources
    echo ""
    show_network_info
}

# Modo solo servicios
show_services_only() {
    print_header
    echo -e "${BLUE}⏰ Última actualización: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
    show_services_status
    echo ""
    show_health_checks
}

# Modo solo recursos
show_resources_only() {
    print_header
    echo -e "${BLUE}⏰ Última actualización: $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo ""
    show_resources
}

# Modo logs en tiempo real
show_logs_mode() {
    if [ -z "$LOG_SERVICE" ]; then
        echo -e "${RED}❌ Debes especificar un servicio para ver logs${NC}"
        echo -e "${BLUE}Servicios disponibles:${NC}"
        docker-compose config --services
        exit 1
    fi
    
    echo -e "${CYAN}📋 LOGS EN TIEMPO REAL - ${LOG_SERVICE^^}${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..50})${NC}"
    echo -e "${BLUE}Presiona Ctrl+C para salir${NC}"
    echo ""
    
    # Seguir logs del servicio especificado
    docker-compose logs -f "$LOG_SERVICE"
}

# Loop principal de monitoreo
monitoring_loop() {
    case $MONITOR_MODE in
        "dashboard")
            while true; do
                show_dashboard
                sleep "$REFRESH_INTERVAL"
            done
            ;;
        "services")
            while true; do
                show_services_only
                sleep "$REFRESH_INTERVAL"
            done
            ;;
        "resources")
            while true; do
                show_resources_only
                sleep "$REFRESH_INTERVAL"
            done
            ;;
        "logs")
            show_logs_mode
            ;;
        *)
            echo -e "${RED}❌ Modo de monitoreo desconocido: $MONITOR_MODE${NC}"
            exit 1
            ;;
    esac
}

# Función de cleanup al salir
cleanup() {
    echo -e "\n${YELLOW}📊 Monitoring detenido${NC}"
    exit 0
}

# Script principal
main() {
    parse_arguments "$@"
    check_prerequisites
    
    # Configurar manejo de señales
    trap cleanup INT TERM
    
    echo -e "${CYAN}🚀 Iniciando monitoreo en modo: ${MONITOR_MODE}${NC}"
    sleep 1
    
    monitoring_loop
}

# Ejecutar script
main "$@"

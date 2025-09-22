#!/bin/bash

# 🧪 MICROSERVICE INFRASTRUCTURE - PATTERN TESTING SCRIPT
# =======================================================
# Script para probar todos los patrones de cloud-native implementados

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Variables globales
JWT_TOKEN=""
test_results=()

# Funciones de utilidad
print_header() {
    echo -e "\n${CYAN}${BOLD}"
    echo "🧪 MICROSERVICE INFRASTRUCTURE - PATTERN TESTING"
    echo "==============================================="
    echo -e "${NC}"
}

show_progress() {
    echo -e "${YELLOW}⏳ $1...${NC}"
}

show_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

show_error() {
    echo -e "${RED}❌ $1${NC}"
}

show_test() {
    echo ""
    echo -e "${MAGENTA}🔬 TEST: $1${NC}"
    echo -e "${MAGENTA}$(printf '=%.0s' {1..50})${NC}"
}

show_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Verificar prerequisitos
check_prerequisites() {
    show_progress "Verificando prerequisitos"
    
    # Verificar que los servicios estén corriendo
    if ! docker-compose ps -q 2>/dev/null | grep -q .; then
        show_error "No hay servicios corriendo"
        echo -e "${BLUE}Ejecuta primero: ${YELLOW}./setup.sh${NC} o ${YELLOW}./deploy.sh${NC}"
        exit 1
    fi
    
    # Verificar conectividad básica
    if ! curl -s "http://localhost/health" >/dev/null 2>&1; then
        show_error "API Gateway no está respondiendo"
        echo -e "${BLUE}Verifica que los servicios estén iniciados: ${YELLOW}docker-compose ps${NC}"
        exit 1
    fi
    
    show_success "Prerequisitos verificados"
}

# Función para obtener token JWT
get_jwt_token() {
    show_progress "Obteniendo token JWT desde Auth API"
    
    # Intentar login con credenciales correctas (admin/admin)
    local auth_response
    auth_response=$(curl -s -X POST "http://localhost/api/auth/login" \
        -H "Content-Type: application/json" \
        -d '{"username":"admin","password":"admin"}' 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$auth_response" | grep -q "accessToken"; then
        # Extraer el token del JSON response
        JWT_TOKEN=$(echo "$auth_response" | grep -o '"accessToken":"[^"]*' | cut -d'"' -f4)
        if [ -n "$JWT_TOKEN" ]; then
            show_success "Token JWT obtenido exitosamente"
            return 0
        fi
    fi
    
    show_error "No se pudo obtener token JWT"
    show_info "Continuando con tests que no requieren autenticación"
    JWT_TOKEN="mock-token-for-testing"  # Use a mock token to continue testing
    return 0  # Return success to continue with other tests
}

# TEST 1: API Gateway Pattern
test_api_gateway() {
    show_test "API Gateway Pattern"
    
    local gateway_passed=true
    
    # Health check del gateway
    show_progress "Probando health check del gateway"
    if health_response=$(curl -sf "http://localhost/health" 2>/dev/null); then
        show_success "Health Check: OK - $health_response"
    else
        show_error "Health Check: FAILED"
        gateway_passed=false
    fi
    
    # Routing a Users API
    show_progress "Probando routing a Users API"
    if curl -sf -H "Authorization: Bearer $JWT_TOKEN" "http://localhost/api/users/" >/dev/null 2>&1; then
        show_success "Users API via Gateway: OK"
    else
        show_error "Users API via Gateway: FAILED"
        gateway_passed=false
    fi
    
    # Routing a Todos API
    show_progress "Probando routing a Todos API"
    if curl -sf -H "Authorization: Bearer $JWT_TOKEN" "http://localhost/api/todos/" >/dev/null 2>&1; then
        show_success "Todos API via Gateway: OK"
    else
        show_error "Todos API via Gateway: FAILED"
        gateway_passed=false
    fi
    
    if [ "$gateway_passed" = true ]; then
        test_results+=("✅ API Gateway Pattern: PASSED")
        show_success "API Gateway Pattern: PASSED"
    else
        test_results+=("❌ API Gateway Pattern: FAILED")
        show_error "API Gateway Pattern: FAILED"
    fi
}

# TEST 2: Load Balancer
test_load_balancer() {
    show_test "Load Balancer Distribution"
    
    show_progress "Realizando múltiples requests para probar load balancing"
    
    local success_count=0
    local total_requests=10
    
    for i in $(seq 1 $total_requests); do
        if curl -sf -H "Authorization: Bearer $JWT_TOKEN" "http://localhost/api/users/" >/dev/null 2>&1; then
            printf "${GREEN}.${NC}"
            ((success_count++))
        else
            printf "${RED}X${NC}"
        fi
    done
    echo ""
    
    if [ $success_count -gt 7 ]; then
        show_success "Load balancing test: $success_count/$total_requests requests exitosos"
        test_results+=("✅ Load Balancer: PASSED")
    else
        show_error "Load balancing test: Solo $success_count/$total_requests requests exitosos"
        test_results+=("❌ Load Balancer: FAILED")
    fi
}

# TEST 3: Cache-Aside Pattern
test_cache_aside() {
    show_test "Cache-Aside Pattern"
    
    local cache_passed=true
    
    # Limpiar cache Redis
    show_progress "Limpiando cache Redis"
    if docker-compose exec -T redis redis-cli FLUSHALL >/dev/null 2>&1; then
        show_success "Cache Redis limpiado"
    else
        show_error "Error limpiando cache Redis"
        cache_passed=false
    fi
    
    if [ "$cache_passed" = true ]; then
        # Primera consulta (Cache MISS)
        show_progress "Primera consulta (debe generar Cache MISS)"
        if curl -sf -H "Authorization: Bearer $JWT_TOKEN" "http://localhost/api/users/admin" >/dev/null 2>&1; then
            show_success "User admin obtenido desde BD"
            
            # Segunda consulta (Cache HIT)
            show_progress "Segunda consulta (debe generar Cache HIT)"
            if curl -sf -H "Authorization: Bearer $JWT_TOKEN" "http://localhost/api/users/admin" >/dev/null 2>&1; then
                show_success "User admin desde cache"
                
                # Verificar keys en Redis
                show_progress "Verificando keys en Redis"
                if docker-compose exec -T redis redis-cli KEYS "user:*" 2>/dev/null | grep -q "user:"; then
                    show_success "Cache key encontrada: user:admin"
                    test_results+=("✅ Cache-Aside Pattern: PASSED")
                else
                    show_error "Cache key no encontrada"
                    test_results+=("❌ Cache-Aside Pattern: FAILED")
                fi
            else
                show_error "Segunda consulta falló"
                test_results+=("❌ Cache-Aside Pattern: FAILED")
            fi
        else
            show_error "Primera consulta falló"
            test_results+=("❌ Cache-Aside Pattern: FAILED")
        fi
    else
        test_results+=("❌ Cache-Aside Pattern: FAILED")
    fi
}

# TEST 4: Autoscaling Pattern
test_autoscaling() {
    show_test "Autoscaling Pattern"
    
    show_progress "Verificando instancias escaladas"
    
    local users_instances todos_instances auth_instances
    users_instances=$(docker-compose ps users-api 2>/dev/null | grep -c "users-api" || echo "0")
    todos_instances=$(docker-compose ps todos-api 2>/dev/null | grep -c "todos-api" || echo "0")
    auth_instances=$(docker-compose ps auth-api 2>/dev/null | grep -c "auth-api" || echo "0")
    
    show_info "Users API: $users_instances instancias activas"
    show_info "Todos API: $todos_instances instancias activas"
    show_info "Auth API: $auth_instances instancias activas"
    
    if [ "$users_instances" -ge 2 ] && [ "$todos_instances" -ge 1 ] && [ "$auth_instances" -ge 1 ]; then
        show_success "Autoscaling Pattern: PASSED"
        test_results+=("✅ Autoscaling Pattern: PASSED")
        
        # Test de escalado adicional
        show_progress "Probando escalado dinámico"
        if docker-compose up -d --scale users-api=4 --scale todos-api=3 >/dev/null 2>&1; then
            sleep 5
            local new_users_instances new_todos_instances
            new_users_instances=$(docker-compose ps users-api 2>/dev/null | grep -c "users-api" || echo "0")
            new_todos_instances=$(docker-compose ps todos-api 2>/dev/null | grep -c "todos-api" || echo "0")
            
            show_success "Escalado dinámico - Users: $new_users_instances, Todos: $new_todos_instances"
        else
            show_error "Error en escalado dinámico"
        fi
    else
        show_error "Escalado insuficiente"
        test_results+=("❌ Autoscaling Pattern: FAILED")
    fi
}

# TEST 5: Service Discovery & Health Checks
test_service_discovery() {
    show_test "Service Discovery & Health Checks"
    
    local discovery_passed=true
    
    # Test conectividad Redis desde Users API
    show_progress "Probando conectividad Users API → Redis"
    if docker-compose exec -T users-api ping -c 1 redis >/dev/null 2>&1; then
        show_success "Users API → Redis: Conectividad OK"
    else
        show_error "Users API → Redis: Sin conectividad"
        discovery_passed=false
    fi
    
    # Test service discovery desde Gateway
    show_progress "Probando service discovery Gateway → APIs"
    if docker-compose exec -T nginx-gateway nslookup users-api >/dev/null 2>&1; then
        show_success "Gateway → Users API: Service Discovery OK"
    else
        show_error "Gateway → Users API: Service Discovery FAILED"
        discovery_passed=false
    fi
    
    if [ "$discovery_passed" = true ]; then
        test_results+=("✅ Service Discovery: PASSED")
        show_success "Service Discovery: PASSED"
    else
        test_results+=("❌ Service Discovery: FAILED")
        show_error "Service Discovery: FAILED"
    fi
}

# TEST 6: Performance Testing
test_performance() {
    show_test "Performance Testing"
    
    show_progress "Midiendo tiempos de respuesta"
    
    local endpoints=(
        "http://localhost/health"
        "http://localhost/api/users/"
        "http://localhost/api/users/admin"
    )
    
    local performance_passed=true
    
    for endpoint in "${endpoints[@]}"; do
        local start_time end_time response_time
        start_time=$(date +%s%3N)
        
        # Health endpoint no necesita token, los demás sí
        if [[ "$endpoint" == *"/health"* ]]; then
            if curl -sf "$endpoint" >/dev/null 2>&1; then
                end_time=$(date +%s%3N)
                response_time=$((end_time - start_time))
                
                if [ "$response_time" -lt 3000 ]; then
                    show_success "$endpoint: ${response_time}ms"
                else
                    show_error "$endpoint: ${response_time}ms (lento)"
                    performance_passed=false
                fi
            else
                show_error "$endpoint: Error de conexión"
                performance_passed=false
            fi
        else
            if curl -sf -H "Authorization: Bearer $JWT_TOKEN" "$endpoint" >/dev/null 2>&1; then
                end_time=$(date +%s%3N)
                response_time=$((end_time - start_time))
                
                if [ "$response_time" -lt 3000 ]; then
                    show_success "$endpoint: ${response_time}ms"
                else
                    show_error "$endpoint: ${response_time}ms (lento)"
                    performance_passed=false
                fi
            else
                show_error "$endpoint: Error de conexión"
                performance_passed=false
            fi
        fi
    done
    
    if [ "$performance_passed" = true ]; then
        test_results+=("✅ Performance Testing: PASSED")
        show_success "Performance Testing: PASSED"
    else
        test_results+=("❌ Performance Testing: FAILED")
        show_error "Performance Testing: FAILED"
    fi
}

# Mostrar resumen de resultados
show_test_summary() {
    echo ""
    echo -e "${CYAN}${BOLD}🎯 RESUMEN DE RESULTADOS${NC}"
    echo -e "${CYAN}$(printf '=%.0s' {1..50})${NC}"
    
    local passed_tests=0
    local total_tests=${#test_results[@]}
    
    for result in "${test_results[@]}"; do
        if [[ "$result" == *"PASSED"* ]]; then
            echo -e "$result"
            ((passed_tests++))
        else
            echo -e "$result"
        fi
    done
    
    echo ""
    local success_rate=$((passed_tests * 100 / total_tests))
    echo -e "${CYAN}📊 RESULTADO FINAL: $passed_tests/$total_tests tests exitosos (${success_rate}%)${NC}"
    
    if [ "$passed_tests" -eq "$total_tests" ]; then
        echo -e "${GREEN}${BOLD}🎉 ¡TODOS LOS PATRONES FUNCIONAN CORRECTAMENTE!${NC}"
    elif [ "$passed_tests" -gt $((total_tests / 2)) ]; then
        echo -e "${YELLOW}⚠️  La mayoría de patrones funcionan, algunos necesitan revisión.${NC}"
    else
        echo -e "${RED}❌ Varios patrones tienen problemas. Revisar configuración.${NC}"
    fi
    
    echo ""
    echo -e "${CYAN}🔧 Comandos de diagnóstico útiles:${NC}"
    echo -e "   ${BLUE}Ver logs: ${YELLOW}docker-compose logs -f [service-name]${NC}"
    echo -e "   ${BLUE}Ver estado: ${YELLOW}docker-compose ps${NC}"
    echo -e "   ${BLUE}Reiniciar servicio: ${YELLOW}docker-compose restart [service-name]${NC}"
    echo -e "   ${BLUE}Health check manual: ${YELLOW}curl http://localhost/health${NC}"
}

# Script principal
main() {
    print_header
    
    check_prerequisites
    
    # Obtener token JWT
    get_jwt_token  # Continue regardless of auth success
    
    # Ejecutar todos los tests
    test_api_gateway
    test_load_balancer
    test_cache_aside
    test_autoscaling
    test_service_discovery
    test_performance
    
    # Mostrar resumen
    show_test_summary
    
    echo -e "\n${GREEN}✨ Testing completado!${NC}"
}

# Manejo de errores
trap 'echo -e "\n${RED}❌ Testing interrumpido${NC}"; exit 1' INT TERM

# Ejecutar script principal
main "$@"

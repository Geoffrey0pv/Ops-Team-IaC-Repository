pipeline {
    agent any
    
    environment {
        // Variables de entorno para comportamiento consistente
        COMPOSE_PROJECT_NAME = "infra-microservicios-${env.BUILD_NUMBER}"
        CI = "true"
    }
    
    stages {
        stage('Checkout & Setup') {
            steps {
                echo "Preparando workspace y permisos..."
                // Dar permisos a todos los scripts desde el inicio
                sh 'chmod +x *.sh || true'
                
                // Listar archivos para debug
                sh 'ls -la *.sh'
                
                echo "Workspace preparado correctamente"
            }
        }
        
        stage('Validar Docker Compose') {
            steps {
                echo "Validando la sintaxis de docker-compose.yml..."
                sh 'docker-compose -f docker-compose.yml config'
                echo "Sintaxis de docker-compose.yml es valida."
            }
        }
        
        stage('Validar Scripts de Bash') {
            steps {
                echo "Analizando scripts de Bash con shellcheck..."
                
                script {
                    try {
                        // Ejecutar shellcheck usando docker run directamente
                        def shellFiles = sh(
                            script: 'ls *.sh 2>/dev/null || echo ""',
                            returnStdout: true
                        ).trim()
                        
                        if (shellFiles) {
                            def files = shellFiles.split('\n')
                            for (file in files) {
                                try {
                                    echo "Validando ${file}..."
                                    sh """
                                        docker run --rm -v "\$(pwd):/mnt" koalaman/shellcheck:stable /mnt/${file} || echo "Advertencias en ${file}"
                                    """
                                    echo "Validacion de ${file} completada"
                                } catch (Exception e) {
                                    echo "Advertencias encontradas en ${file}: ${e.getMessage()}"
                                    // No fallar el build por warnings de shellcheck
                                }
                            }
                        } else {
                            echo "No se encontraron archivos .sh para validar"
                        }
                    } catch (Exception e) {
                        echo "Error en validacion de scripts: ${e.getMessage()}"
                        echo "Continuando con el pipeline..."
                    }
                }
                
                echo "Analisis de scripts completado."
            }
        }
        
        stage('CD: Despliegue y Pruebas') {
            when {
                branch 'main'
            }
            steps {
                echo "Iniciando despliegue y pruebas de integracion..."
                
                script {
                    try {
                        // Limpiar cualquier instancia previa
                        echo "Limpiando entorno previo..."
                        sh './cleanup.sh --all --force || true'
                        sleep 5
                        
                        // Ejecutar setup
                        echo "Ejecutando setup de infraestructura..."
                        sh './setup.sh'
                        
                        // Esperar a que servicios estén completamente listos
                        echo "Esperando que los servicios esten listos..."
                        sh 'sleep 45'
                        
                        // Verificar que los servicios estén corriendo
                        echo "Verificando estado de servicios..."
                        sh 'docker-compose ps'
                        
                        // Health check basico
                        echo "Ejecutando health checks basicos..."
                        sh '''
                            # Verificar API Gateway
                            curl -f http://localhost/health || echo "API Gateway no responde aun"
                            
                            # Verificar Redis
                            docker-compose exec -T redis redis-cli ping || echo "Redis no responde aun"
                        '''
                        
                        // Ejecutar pruebas de patrones
                        echo "Ejecutando pruebas de patrones..."
                        sh './test-patterns.sh'
                        
                        echo "Deploy y testing completados exitosamente"
                        
                    } catch (Exception e) {
                        echo "Error en despliegue: ${e.getMessage()}"
                        
                        // Mostrar logs para debugging
                        echo "Mostrando logs para debugging..."
                        sh '''
                            echo "=== Estado de contenedores ==="
                            docker-compose ps || true
                            echo "=== Logs de servicios ==="
                            docker-compose logs --tail=100 || true
                            echo "=== Procesos Docker ==="
                            docker ps -a | head -20 || true
                        '''
                        
                        throw e
                    }
                }
            }
        }
    }
    
    post {
        always {
            echo "Limpiando el entorno del agente de Jenkins..."
            
            script {
                try {
                    // Limpiar con script personalizado
                    sh './cleanup.sh --all --force || true'
                    
                    // Cleanup adicional por si el script falla
                    sh '''
                        echo "Ejecutando limpieza adicional..."
                        
                        # Forzar limpieza de contenedores del proyecto
                        docker-compose down -v --remove-orphans || true
                        
                        # Esperar un momento
                        sleep 5
                        
                        # Limpiar contenedores huerfanos
                        docker container prune -f || true
                        
                        # Limpiar volumenes huerfanos
                        docker volume prune -f || true
                        
                        # Limpiar redes huerfanas
                        docker network prune -f || true
                        
                        echo "Limpieza adicional completada"
                    '''
                    
                    echo "Limpieza completada correctamente"
                } catch (Exception e) {
                    echo "Advertencia en limpieza - algunos recursos podrian quedar: ${e.getMessage()}"
                    // No fallar el pipeline por problemas en cleanup
                }
            }
        }
        success {
            echo "Pipeline de infraestructura completado exitosamente!"
            echo "Para inspeccion manual: docker-compose ps"
        }
        failure {
            echo "Pipeline fallo. Revisando informacion de debugging..."
            
            script {
                try {
                    // Mostrar estado final para debugging
                    sh '''
                        echo "=== Estado final de servicios ==="
                        docker-compose ps || true
                        echo "=== Contenedores activos ==="
                        docker ps -a | head -20 || true
                        echo "=== Uso de recursos ==="
                        docker system df || true
                    '''
                } catch (Exception e) {
                    echo "No se pudo obtener informacion de debugging: ${e.getMessage()}"
                }
            }
        }
    }
}
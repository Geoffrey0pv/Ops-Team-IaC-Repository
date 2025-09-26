pipeline {
    agent any

    stages {
        stage('CI: Validación de Scripts') {
            steps {
                echo "Validando la calidad del código de infraestructura..."
                
                // 1. Validar la sintaxis del archivo Docker Compose
                sh 'docker-compose -f docker-compose.yml config'
                echo "Sintaxis de docker-compose.yml es válida."
                
                // 2. Usar un contenedor con shellcheck para analizar los scripts de Bash
                // Esto es una buena práctica para no tener que instalarlo en el agente
                docker.image('koalaman/shellcheck:stable').inside {
                    sh 'shellcheck *.sh'
                }
                echo "Análisis de scripts de Bash completado sin errores."
            }
        }

        stage('CD: Despliegue del Entorno de Simulación') {
            when {
                branch 'main'
            }
            steps {
                echo "Desplegando el ecosistema completo para pruebas..."
                // Otorgar permisos de ejecución a los scripts
                sh 'chmod +x *.sh'
                
                // Ejecutar el script de setup
                sh './setup.sh'
            }
        }

        stage('CD: Pruebas de Patrones de Diseño') {
            when {
                branch 'main'
            }
            steps {
                echo "Ejecutando pruebas de integración sobre la infraestructura..."
                // El script test-patterns.sh devolverá un código de salida 0 si todo va bien
                sh './test-patterns.sh'
            }
        }
    }

    post {
        always {
            echo "Limpiando el entorno del agente de Jenkins..."
            sh 'chmod +x cleanup.sh'
            sh './cleanup.sh --all --force'
        }
    }
}
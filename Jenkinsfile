pipeline {
    agent any

    stages {
        // Etapa 1: Se ejecuta en el agente principal (el que corre Jenkins)
        stage('Validar Docker Compose') {
            steps {
                echo "Validando la sintaxis de docker-compose.yml..."
                sh 'docker-compose -f docker-compose.yml config'
                echo "Sintaxis de docker-compose.yml es válida."
            }
        }

        // Etapa 2: Se ejecuta DENTRO de un contenedor de shellcheck
        stage('Validar Scripts de Bash') {
            // Se define un agente específico solo para esta etapa
            agent {
                docker { image 'koalaman/shellcheck:stable' }
            }
            steps {
                echo "Analizando scripts de Bash con shellcheck..."
                // Este comando se ejecuta dentro del contenedor 'shellcheck' sobre el workspace clonado
                sh 'shellcheck *.sh'
                echo "Análisis de scripts de Bash completado sin errores."
            }
        }

        // Etapas de CD: Se ejecutan en el agente principal
        stage('CD: Despliegue y Pruebas') {
            when {
                branch 'main'
            }
            steps {
                echo "Iniciando despliegue y pruebas de integración..."
                // Otorgar permisos de ejecución a todos los scripts
                sh 'chmod +x *.sh'
                
                // Ejecutar el script de setup para levantar el entorno
                sh './setup.sh'

                // Ejecutar el script de pruebas de patrones
                sh './test-patterns.sh'
            }
        }
    }

    post {
        always {
            echo "Limpiando el entorno del agente de Jenkins..."
            sh 'chmod +x cleanup.sh || true'
            sh './cleanup.sh --all --force'
        }
    }
}
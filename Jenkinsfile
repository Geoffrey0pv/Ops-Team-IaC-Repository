pipeline {
    agent any

    stages {
        // ETAPA 1: Se ejecuta en el agente principal
        stage('Validar Docker Compose') {
            steps {
                echo "Validando la sintaxis de docker-compose.yml..."
                sh 'docker-compose -f docker-compose.yml config'
                echo "Sintaxis de docker-compose.yml es válida."
            }
        }

        // ETAPA 2: Se ejecuta DENTRO de un contenedor de shellcheck
        stage('Validar Scripts de Bash') {
            // Se define un agente específico solo para esta etapa
            agent {
                docker { image 'koalaman/shellcheck:stable' }
            }
            steps {
                echo "Analizando scripts de Bash con shellcheck..."
                // Los comandos ahora se ejecutan dentro del contenedor 'shellcheck'
                sh 'shellcheck *.sh'
                echo "Análisis de scripts de Bash completado sin errores."
            }
        }

        stage('CD: Despliegue del Entorno de Simulación') {
            when { branch 'main' }
            steps {
                echo "Desplegando el ecosistema completo para pruebas..."
                sh 'chmod +x *.sh'
                sh './setup.sh'
            }
        }

        stage('CD: Pruebas de Patrones de Diseño') {
            when { branch 'main' }
            steps {
                echo "Ejecutando pruebas de integración sobre la infraestructura..."
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
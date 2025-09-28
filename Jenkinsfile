pipeline {
    agent any

    stages {
        stage('CI: Validación de Código') {
            steps {
                
                script {
                    echo "Validando la calidad del código de infraestructura..."
                    
                    // 1. Validar la sintaxis del archivo Docker Compose
                    sh 'docker-compose -f docker-compose.yml config'
                    echo "Sintaxis de docker-compose.yml es válida."
                    
                    // 2. Usar un contenedor con shellcheck para analizar los scripts de Bash
                    // El bloque 'script' permite usar la sintaxis docker.image().inside() de forma segura.
                    docker.image('koalaman/shellcheck:stable').inside {
                        sh 'shellcheck *.sh'
                    }
                    echo "Análisis de scripts de Bash completado sin errores."
                }
            }
        }

        stage('CD: Despliegue y Pruebas de Integración') {
            when {
                branch 'main'
            }
            steps {
                echo "Iniciando despliegue y pruebas de integración..."
                
                sh 'chmod +x *.sh'
                
                sh './setup.sh'

                sh './test-patterns.sh'
            }
        }
    }

    post {
        always {
            script {
                echo "Limpiando el entorno del agente de Jenkins..."
                sh 'chmod +x cleanup.sh'
                sh './cleanup.sh --all --force'
            }
        }
    }
}
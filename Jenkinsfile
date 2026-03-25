// =================================================================
// HELPER FUNCTION: ส่ง Notification ไปยัง n8n (ตามแนวทางของ Express Pipeline)
// =================================================================



pipeline {
    agent any

    tools {
        dockerTool 'docker' 
    }

    options {
        skipDefaultCheckout(true)
    }

    environment {
        DOCKER_HUB_CREDENTIALS_ID = 'exam-narupon'
        DOCKER_REPO               = "famnekon/flask-docker-app"
        DEV_APP_NAME              = "flask-app-dev"
        DEV_HOST_PORT             = "5001"
        PROD_APP_NAME             = "flask-app-prod"
        PROD_HOST_PORT            = "5000"
    }

    parameters {
        choice(name: 'ACTION', choices: ['Build & Deploy', 'Rollback'], description: 'เลือก Action ที่ต้องการ')
        string(name: 'ROLLBACK_TAG', defaultValue: '', description: 'สำหรับ Rollback: ใส่ Image Tag (เช่น Git Hash หรือ dev-123)')
        choice(name: 'ROLLBACK_TARGET', choices: ['dev', 'prod'], description: 'สำหรับ Rollback: เลือก Environment')
    }

    stages {
        // Stage 1: Checkout (รวมการแก้ปัญหา Git Ownership)
        stage('Checkout') {
            when { expression { params.ACTION == 'Build & Deploy' } }
            steps {
                script {
                    // แก้ปัญหา fatal: detected dubious ownership
                    sh "git config --global --add safe.directory ${WORKSPACE}"
                }
                echo "Checking out code..."
                checkout scm
            }
        }

        // Stage 2: Install & Test
        stage('Install & Test') {
            when { expression { params.ACTION == 'Build & Deploy' } }
            steps {
                echo "Running tests inside a consistent Docker environment..."
                script {
                    docker.image('python:3.13-slim').inside {
                        sh '''
                            pip install --no-cache-dir -r requirements.txt
                            pytest -v --tb=short --junitxml=test-results.xml
                        '''
                    }
                }
            }
            post {
                always {
                    junit 'test-results.xml'
                }
            }
        }

        // Stage 3: Build & Push Docker Image
        stage('Build & Push Docker Image') {
            when { expression { params.ACTION == 'Build & Deploy' } }
            steps {
                script {
                    def imageTag = (env.BRANCH_NAME == 'main') ? sh(script: 'git rev-parse --short HEAD', returnStdout: true).trim() : "dev-${env.BUILD_NUMBER}"
                    env.IMAGE_TAG = imageTag

                    docker.withRegistry('https://index.docker.io/v1/', DOCKER_HUB_CREDENTIALS_ID) {
                        echo "Building image: ${DOCKER_REPO}:${env.IMAGE_TAG}"
                        def customImage = docker.build("${DOCKER_REPO}:${env.IMAGE_TAG}")

                        echo "Pushing images to Docker Hub..."
                        customImage.push()
                        if (env.BRANCH_NAME == 'main') {
                            customImage.push('latest')
                        }
                    }
                }
            }
        }

        // Stage 4: Deploy to DEV
        stage('Deploy to DEV (Local Docker)') {
            when {
                expression { params.ACTION == 'Build & Deploy' }
                branch 'develop'
            }
            steps {
                script {
                    def deployCmd = """
                            echo "Deploying container ${DEV_APP_NAME} from image ${env.IMAGE_TAG}..."
                            docker pull ${DOCKER_REPO}:${env.IMAGE_TAG}
                            docker stop ${DEV_APP_NAME} || true
                            docker rm ${DEV_APP_NAME} || true
                            docker run -d --name ${DEV_APP_NAME} -p ${DEV_HOST_PORT}:5000 ${DOCKER_REPO}:${env.IMAGE_TAG}
                        """
                    sh deployCmd
                }
            }
            post {
                success {
                    sendNotificationToN8n('success', 'Deploy to DEV', env.IMAGE_TAG, env.DEV_APP_NAME, env.DEV_HOST_PORT)
                }
            }
        }

        // Stage 5: Approval
        stage('Approval for Production') {
            when {
                expression { params.ACTION == 'Build & Deploy' }
                branch 'main'
            }
            steps {
                timeout(time: 1, unit: 'HOURS') {
                    input message: "Deploy image tag '${env.IMAGE_TAG}' to PRODUCTION?"
                }
            }
        }

        // Stage 6: Deploy to PROD
        stage('Deploy to PRODUCTION (Local Docker)') {
            when {
                expression { params.ACTION == 'Build & Deploy' }
                branch 'main'
            }
            steps {
                script {
                    def deployCmd = """
                            echo "Deploying container ${PROD_APP_NAME} from image ${env.IMAGE_TAG}..."
                            docker pull ${DOCKER_REPO}:${env.IMAGE_TAG}
                            docker stop ${PROD_APP_NAME} || true
                            docker rm ${PROD_APP_NAME} || true
                            docker run -d --name ${PROD_APP_NAME} -p ${PROD_HOST_PORT}:5000 ${DOCKER_REPO}:${env.IMAGE_TAG}
                        """
                    sh deployCmd
                }
            }
            post {
                success {
                    sendNotificationToN8n('success', 'Deploy to PRODUCTION', env.IMAGE_TAG, env.PROD_APP_NAME, env.PROD_HOST_PORT)
                }
            }
        }

        // Stage 7: Rollback
        stage('Execute Rollback') {
            when { expression { params.ACTION == 'Rollback' } }
            steps {
                script {
                    if (params.ROLLBACK_TAG.trim().isEmpty()) {
                        error "กรุณาระบุ ROLLBACK_TAG"
                    }
                    def targetApp = (params.ROLLBACK_TARGET == 'dev') ? env.DEV_APP_NAME : env.PROD_APP_NAME
                    def targetPort = (params.ROLLBACK_TARGET == 'dev') ? env.DEV_HOST_PORT : env.PROD_HOST_PORT
                    def imageToDeploy = "${DOCKER_REPO}:${params.ROLLBACK_TAG.trim()}"

                    sh """
                        docker pull ${imageToDeploy}
                        docker stop ${targetApp} || true
                        docker rm ${targetApp} || true
                        docker run -d --name ${targetApp} -p ${targetPort}:5000 ${imageToDeploy}
                    """
                    sendNotificationToN8n('success', "Rollback ${params.ROLLBACK_TARGET}", params.ROLLBACK_TAG, targetApp, targetPort)
                }
            }
        }
    }

    post {
        always {
            script {
                if (params.ACTION == 'Build & Deploy' && env.IMAGE_TAG) {
                    echo "Cleaning up Docker images..."
                    sh "docker image rm -f ${DOCKER_REPO}:${env.IMAGE_TAG} || true"
                }
                cleanWs()
            }
        }
        failure {
            echo 'การ Build ล้มเหลว กรุณาตรวจสอบ Console Output'
        }
    }
}

// ฟังก์ชันส่ง Notification (ต้องอยู่นอก pipeline block)
def sendNotificationToN8n(status, stage, tag, appName, port) {
    echo "NOTIFICATION: Stage [${stage}] is ${status}. (Image: ${tag}, App: ${appName}, Port: ${port})"
    // คุณสามารถเพิ่มโค้ด httpRequest เพื่อส่งไป N8N จริงๆ ได้ที่นี่
}
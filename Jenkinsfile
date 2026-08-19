pipeline {
    agent any

    options {
        disableConcurrentBuilds()
    }

    triggers {
        pollSCM('H/5 * * * *')
    }

    environment {
        AWS_REGION    = 'us-east-1'
        ECR_REPOSITORY = 'tech-challenge-2-app'
        EKS_CLUSTER    = 'tech-challenge-2-eks'
        K8S_NAMESPACE  = 'tech-challenge-2'
        HELM_RELEASE   = 'tech-challenge-2'
        HELM_CHART     = './helm/tech-challenge-2'
        TEST_CONTAINER = "tech-challenge-test-${BUILD_NUMBER}"
        KUBECONFIG     = "${WORKSPACE}/.kubeconfig"
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Prepare') {
            steps {
                script {
                    env.AWS_ACCOUNT_ID = sh(
                        script: "aws sts get-caller-identity --query Account --output text",
                        returnStdout: true
                    ).trim()

                    env.ECR_REGISTRY = "${env.AWS_ACCOUNT_ID}.dkr.ecr.${env.AWS_REGION}.amazonaws.com"
                    env.IMAGE_TAG = "${env.BUILD_NUMBER}"
                    env.IMAGE_URI = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:${env.IMAGE_TAG}"
                    env.LATEST_IMAGE_URI = "${env.ECR_REGISTRY}/${env.ECR_REPOSITORY}:latest"
                }

                sh '''
                    echo "Building image: $IMAGE_URI"
                    aws --version
                    docker --version
                    kubectl version --client
                    helm version --short
                '''
            }
        }

        stage('Build Docker Image') {
            steps {
                sh '''
                    docker build \
                      --tag "$IMAGE_URI" \
                      ./app
                '''
            }
        }

        stage('Test Application') {
            steps {
                sh '''
                    docker run --detach \
                      --name "$TEST_CONTAINER" \
                      --publish 3000:3000 \
                      "$IMAGE_URI"

                    sleep 5
                    curl --fail --silent --show-error \
                      http://localhost:3000/health

                    docker rm --force "$TEST_CONTAINER"
                '''
            }
        }

        stage('Push Image to ECR') {
            steps {
                sh '''
                    aws ecr get-login-password \
                      --region "$AWS_REGION" |
                    docker login \
                      --username AWS \
                      --password-stdin "$ECR_REGISTRY"

                    docker push "$IMAGE_URI"

                    docker tag \
                      "$IMAGE_URI" \
                      "$LATEST_IMAGE_URI"

                    docker push "$LATEST_IMAGE_URI"
                '''
            }
        }

        stage('Deploy to EKS with Helm') {
            steps {
                sh '''
                    aws eks update-kubeconfig \
                      --region "$AWS_REGION" \
                      --name "$EKS_CLUSTER" \
                      --kubeconfig "$KUBECONFIG"

                    helm lint "$HELM_CHART"

                    helm upgrade --install "$HELM_RELEASE" "$HELM_CHART" \
                      --namespace "$K8S_NAMESPACE" \
                      --set image.repository="$ECR_REGISTRY/$ECR_REPOSITORY" \
                      --set image.tag="$IMAGE_TAG" \
                      --atomic \
                      --wait \
                      --timeout 10m
                '''
            }
        }

        stage('Verify Deployment') {
            steps {
                sh '''
                    kubectl rollout status \
                      deployment/tech-challenge-2 \
                      --namespace "$K8S_NAMESPACE" \
                      --timeout 5m

                    kubectl get pods \
                      --namespace "$K8S_NAMESPACE"

                    kubectl get hpa \
                      --namespace "$K8S_NAMESPACE"
                '''
            }
        }
    }

    post {
        always {
            sh '''
                docker rm --force "$TEST_CONTAINER" 2>/dev/null || true
                rm --force "$KUBECONFIG"
                docker system prune --force
            '''
        }

        success {
            echo 'Pipeline completed successfully.'
        }

        failure {
            echo 'Pipeline failed. Check the failed stage for details.'
        }
    }
}
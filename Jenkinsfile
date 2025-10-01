pipeline {
    agent any

    environment {
        EC2_HOST = "*.*.*.*"
        EC2_USER = "root"
        WORKDIR = "~/bubsy-ml-api"
        SONAR_HOST_URL = "https://sonarqube.app.com"
        SONAR_TOKEN = "squ_************"
        PROJECT_KEY = "bubsy-ml"
    }

    stages {
        stage('Run Tests on EC2') {
            steps {
                sshagent(['ec2-ssh-key']) { // Jenkins credential ID for EC2 private key
                    sh '''
                    ssh -o StrictHostKeyChecking=no $EC2_USER@$EC2_HOST << 'EOF'
                        set -e
                        cd $WORKDIR

                        # Kill running app if any
                        sudo pkill -9 -f "uvicorn" || true

                        # Update repo
                        git checkout production
                        git pull origin production

                        # Python setup
                        source venv/bin/activate
                        python -m pip install --upgrade pip
                        pip install -r requirements.txt

                        # Run tests
                        coverage run -m unittest test_suite || { echo "Tests failed"; exit 1; }

                        # Generate coverage report
                        coverage xml --omit=config-3.py -o coverage.xml --ignore-errors
                    EOF
                    '''
                }
            }
        }

        stage('Copy Coverage Report') {
            steps {
                sshagent(['ec2-ssh-key']) {
                    sh '''
                    scp -o StrictHostKeyChecking=no $EC2_USER@$EC2_HOST:$WORKDIR/coverage.xml $WORKSPACE/
                    '''
                }
            }
        }

        stage('SonarQube Analysis') {
            steps {
                withSonarQubeEnv('SonarQube') { // "SonarQube" must match Jenkins SonarQube config name
                    sh '''
                    sonar-scanner \
                        -Dsonar.projectKey=$PROJECT_KEY \
                        -Dsonar.sources=. \
                        -Dsonar.host.url=$SONAR_HOST_URL \
                        -Dsonar.login=$SONAR_TOKEN \
                        -Dsonar.python.coverage.reportPaths=coverage.xml \
                        -Dsonar.qualitygate.wait=true
                    '''
                }
            }
        }

        stage('Deploy Application') {
            steps {
                sshagent(['ec2-ssh-key']) {
                    sh '''
                    ssh -o StrictHostKeyChecking=no $EC2_USER@$EC2_HOST << 'EOF'
                        cd $WORKDIR
                        sudo docker-compose stop app
                        sudo docker-compose rm -f app
                        sudo docker-compose up --build -d app
                    EOF
                    '''
                }
            }
        }
    }

    post {
        failure {
            echo "Pipeline failed. Please check logs."
        }
        success {
            echo "Pipeline completed successfully 🚀"
        }
    }
}

node {
    def app
    currentBuild.result = "SUCCESS"
    try {
        stage ('Pull SCM') {
            checkout scm
        }
        
        sh "ls ${env.workspace}"
        
        stage('Build Docker Image') {
            app = docker.build("cityofsandy/docker-geoserver")
        }

        stage('Test image') {
            app.inside {
                sh 'echo "Tests passed"'
            }
        }
        
        stage('Push image') {
            docker.withRegistry('https://prod.nexus.aws.cityofsandy.com', 'sn-dev-nexus-user-pass') {
                if (env.BRANCH_NAME != 'master') {
                    echo 'This is not master'
                    app.push("latest-dev")
                } else {
                    app.push("latest-prod")
                }
                
            }
        }
        
    } catch (e) {
        currentBuild.result = 'FAILURE'
        throw e
    } finally {
        step([$class: 'Mailer', notifyEveryUnstableBuild: true, recipients: "${sn_dev_email_dist_list}", sendToIndividuals: true])
    }
}
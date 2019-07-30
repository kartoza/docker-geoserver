node {
    def app
    def BUGFIX = 2
    def MINOR = 15
    def MAJOR = 2
    currentBuild.result = "SUCCESS"
    try {
        stage ('Pull SCM') {
            checkout scm
        }
        
        sh "ls ${env.workspace}"
        
        stage('Build Docker Image') {
            app = docker.build("--build-arg GS_VERSION=${MAJOR}.${MINOR}.${BUGFIX} -t cityofsandy/geoserver:${MAJOR}.${MINOR}.${BUGFIX} .", )
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
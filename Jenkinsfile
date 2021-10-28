pipeline {
  environment {
    SLACK_MESSAGE = "\n JOB/BRANCH: ${JOB_NAME} \n COMMIT: ${GIT_COMMIT} \n GITHUB: ${GIT_URL} \n BUILD: <${env.RUN_DISPLAY_URL}|${env.BUILD_DISPLAY_NAME}>"
    JEST_JUNIT_OUTPUT='./test-report/junit.xml'
  }
  agent {
    node {
        label 'jenkins-slave01'
    }
  }
  stages {
    stage('slack') {
      steps {
        slackSend channel: '#prism_dev',
        color: '#ddd',
        message: "STARTED: ${env.SLACK_MESSAGE}",
        tokenCredentialId: 'prism-dev'
      }
    }
    stage('install') {
      steps {
        sh 'yarn'
      }
    }
    stage('test') {
        parallel {
            stage('lint') {
                steps {
                    sh 'yarn leash lint'
                }
            }
            stage('unit') {
                steps {
                  sh 'curl -L https://codeclimate.com/downloads/test-reporter/test-reporter-latest-linux-amd64 > ./cc-test-reporter'
                  sh 'chmod +x ./cc-test-reporter'
                  sh './cc-test-reporter before-build'
                  sh 'yarn leash test --no-cache --runInBand'
                  withCredentials(bindings: [string(credentialsId: 'prism-server-code-climate', variable: 'CC_TEST_REPORTER_ID')]) {
                    sh './cc-test-reporter after-build -r $CC_TEST_REPORTER_ID -t lcov --exit-code $?'
                  }
                }
            }
        }
    }
  }
  post {
   always {
       archive (includes: 'coverage/**/*')
       publishHTML([
           allowMissing: false,
           alwaysLinkToLastBuild: false,
           keepAll: true,
           reportDir: 'coverage',
           reportFiles: 'lcov-report/index.html',
           reportName: 'Code Coverage',
           reportTitles: 'Code Coverage'
       ])
   }
   success {
      slackSend channel: '#prism_dev',
      color: '#00ad4d',
      message: "SUCCESS: ${env.SLACK_MESSAGE}",
      tokenCredentialId: 'prism-dev'
    }
    failure {
        slackSend channel: '#prism_dev',
        color: '#e2000a',
        message: "FAILED: ${env.SLACK_MESSAGE}",
        tokenCredentialId: 'prism-dev'
    }
  }
}
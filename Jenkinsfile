// Declarative Jenkins pipeline running the SAME scripts and CMake presets as
// GitHub Actions, inside the SAME Dockerfile.dev image. Jenkins is the
// common choice for internal build farms; nothing here is GitHub-specific.
//
// Local Jenkins with this job preconfigured: infra/jenkins/README.md
pipeline {
    agent none

    options {
        timestamps()
        timeout(time: 60, unit: 'MINUTES')
        buildDiscarder(logRotator(numToKeepStr: '30', artifactNumToKeepStr: '10'))
        disableConcurrentBuilds(abortPrevious: true)
    }

    parameters {
        booleanParam(name: 'RUN_PACKAGING', defaultValue: true, description: 'Build and lint .deb/.rpm packages')
    }

    environment {
        CCACHE_DIR = '/ccache'
        DRIVERFORGE_GIT_SHA = "${env.GIT_COMMIT ?: 'unknown'}"
    }

    stages {
        stage('Lint') {
            agent { dockerfile { filename 'Dockerfile.dev'; reuseNode false } }
            steps {
                sh 'CLANG_FORMAT=clang-format-18 scripts/check_format.sh'
                sh 'shellcheck scripts/*.sh scripts/ci/*.sh infra/k8s/arc/*.sh'
                sh 'cd tools/buildstats && python3 -m unittest discover -s tests -t .'
            }
        }

        stage('Build and test matrix') {
            matrix {
                axes {
                    axis { name 'COMPILER'; values 'gcc-12', 'gcc-14', 'clang-16', 'clang-18' }
                    axis { name 'BUILD_TYPE'; values 'debug', 'release' }
                }
                agent {
                    dockerfile {
                        filename 'Dockerfile.dev'
                        // Persistent ccache volume on the agent: warm builds across runs.
                        args '-v jenkins-ccache:/ccache'
                    }
                }
                stages {
                    stage('Build and test') {
                        steps {
                            script {
                                def cc = env.COMPILER
                                def cxx = cc.startsWith('gcc') ? cc.replace('gcc', 'g++') : cc.replace('clang', 'clang++')
                                withEnv(["CC=${cc}", "CXX=${cxx}"]) {
                                    sh "scripts/ci/build_and_test.sh ci-${env.BUILD_TYPE}"
                                }
                            }
                        }
                        post {
                            always {
                                junit allowEmptyResults: true, testResults: "build/ci-${env.BUILD_TYPE}/junit.xml"
                                archiveArtifacts allowEmptyArchive: true, artifacts: "build/ci-${env.BUILD_TYPE}/metrics.json"
                            }
                        }
                    }
                }
            }
        }

        stage('Quality gates') {
            parallel {
                stage('ASan + UBSan') {
                    agent { dockerfile { filename 'Dockerfile.dev' } }
                    environment { CC = 'clang-18'; CXX = 'clang++-18' }
                    steps { sh 'scripts/ci/build_and_test.sh asan' }
                }
                stage('ABI') {
                    agent { dockerfile { filename 'Dockerfile.dev' } }
                    environment { CC = 'gcc-12'; CXX = 'g++-12' }
                    steps {
                        sh 'cmake --workflow --preset abi'
                        sh 'scripts/check_abi.sh build/abi/drivers/nvk/libnvk_driver.so.1.0.0'
                    }
                }
                stage('Reproducible') {
                    agent { dockerfile { filename 'Dockerfile.dev' } }
                    environment { CC = 'gcc'; CXX = 'g++' }
                    steps { sh 'scripts/check_reproducible.sh "$WORKSPACE/repro"' }
                }
                stage('Cross aarch64') {
                    agent { dockerfile { filename 'Dockerfile.dev' } }
                    steps { sh 'scripts/ci/package.sh cross-aarch64' }
                    post { success { archiveArtifacts artifacts: 'dist/*', fingerprint: true } }
                }
            }
        }

        stage('Package') {
            when { expression { params.RUN_PACKAGING } }
            agent { dockerfile { filename 'Dockerfile.dev' } }
            environment { CC = 'gcc'; CXX = 'g++' }
            steps {
                sh 'scripts/ci/package.sh release'
                sh 'scripts/ci/package.sh release-rpm'
                sh 'cd dist && sha256sum -- * > SHA256SUMS'
            }
            post {
                // fingerprint: Jenkins tracks which build produced each package.
                success { archiveArtifacts artifacts: 'dist/*', fingerprint: true }
            }
        }
    }
}

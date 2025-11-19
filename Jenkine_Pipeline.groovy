pipeline {
    agent any

    parameters {
        string(name: 'VERSION_TAG', defaultValue: 'V5.26_Feature3', description: '版本號 (例如 V5.26_Feature3)')
        string(name: 'FTP_USER',     defaultValue: '',         description: 'FTP 使用者帳號')
        password(name: 'FTP_PASS',   defaultValue: '',             description: 'FTP 使用者密碼')
    }

    stages {

        stage('Build') {
            steps {
                echo "=== 建置專案 (PWsh) ==="
                 bat """
                pwsh -NoProfile -ExecutionPolicy Bypass -File D:\\POSAP_BuildScripts\\Jenkins_Build.ps1 -VersionTag "${VERSION_TAG}"
                """
            }
        }

        stage('Package') {
            steps {
                echo "=== 打包專案 (PWsh) ==="
                bat """
                pwsh -NoProfile -ExecutionPolicy Bypass -File D:\\POSAP_BuildScripts\\Jenkins_Package.ps1 -VersionTag "${VERSION_TAG}"
                """
            }
        }

       stage('Upload FTP') {
            steps {
                echo "=== 上傳 FTP (PWsh) ==="
                bat '''

            pwsh -NoProfile -ExecutionPolicy Bypass ^
                -File D:\\POSAP_BuildScripts\\Jenkins_UploadToFtp.ps1 ^
                -VersionTag "%VERSION_TAG%" -FtpUser "%FTP_USER%"
        '''
            }
        }

    }
}

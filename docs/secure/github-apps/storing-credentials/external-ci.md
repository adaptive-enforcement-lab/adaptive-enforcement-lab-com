---
title: External CI/CD Platform Credentials
description: >-
  Store GitHub App credentials in external CI/CD platforms including Jenkins, GitLab CI, and CircleCI.
---

# External CI/CD Platform Credentials

## Jenkins Credentials

Store GitHub App credentials in Jenkins credential store.

### Jenkins Setup

1. Navigate to **Manage Jenkins** → **Credentials**
2. Select appropriate domain (usually `(global)`)
3. Click **Add Credentials**
4. Create two credentials:

**App ID (Secret text)**:

- **Kind**: Secret text
- **Scope**: Global
- **Secret**: `123456`
- **ID**: `github-app-id`
- **Description**: GitHub App ID for Core App

**Private Key (Secret file)**:

- **Kind**: Secret file
- **Scope**: Global
- **File**: Upload `.pem` file
- **ID**: `github-app-private-key`
- **Description**: GitHub App Private Key for Core App

### Pipeline Usage

```groovy
pipeline {
    agent any

    environment {
        GH_APP_ID = credentials('github-app-id')
        GH_APP_PRIVATE_KEY = credentials('github-app-private-key')
    }

    stages {
        stage('Generate Token') {
            steps {
                script {
                    // Install dependencies
                    sh 'pip install pyjwt cryptography requests'

                    // Generate token using Python script
                    def token = sh(
                        script: '''
                            python3 - <<'EOF'
import jwt
import time
import requests
import os

app_id = os.environ['GH_APP_ID']
with open(os.environ['GH_APP_PRIVATE_KEY'], 'r') as f:
    private_key = f.read()

payload = {
    'iat': int(time.time()) - 60,
    'exp': int(time.time()) + (10 * 60),
    'iss': app_id
}

jwt_token = jwt.encode(payload, private_key, algorithm='RS256')

# Get installation ID (replace with your org)
headers = {
    'Authorization': f'Bearer {jwt_token}',
    'Accept': 'application/vnd.github+json'
}
response = requests.get('https://api.github.com/app/installations', headers=headers)
installation_id = response.json()[0]['id']

# Generate installation token
response = requests.post(
    f'https://api.github.com/app/installations/{installation_id}/access_tokens',
    headers=headers
)
print(response.json()['token'])
EOF
                        ''',
                        returnStdout: true
                    ).trim()

                    env.GITHUB_TOKEN = token
                }
            }
        }

        stage('Use Token') {
            steps {
                sh '''
                    gh api /repos/my-org/my-repo/issues
                '''
            }
        }
    }
}
```

!!! danger "Jenkins Secret Masking"

    Jenkins doesn't automatically mask GitHub App tokens. Use credential masking plugins or avoid echoing tokens in logs.

### GitLab CI Variables

Store credentials as protected and masked CI/CD variables.

### GitLab CI Setup

1. Navigate to **Settings** → **CI/CD** → **Variables**
2. Add two variables:

**`CORE_APP_ID`**:

- **Type**: Variable
- **Environment scope**: All (or specific)
- **Flags**: ☑ Protected, ☑ Masked
- **Value**: `123456`

**`CORE_APP_PRIVATE_KEY`**:

- **Type**: File
- **Environment scope**: All (or specific)
- **Flags**: ☑ Protected, ☑ Masked
- **Value**: Complete PEM file contents

!!! tip "GitLab Variable Types"

    - Use **File** type for private key to avoid escaping issues
    - Private key becomes available as file at `$CORE_APP_PRIVATE_KEY` path

### GitLab Pipeline Usage

```yaml
generate_token:
  stage: setup
  image: python:3.11
  before_script:
    - pip install pyjwt cryptography requests
  script:
    - |
      python3 - <<'EOF' > token.txt
      import jwt
      import time
      import requests
      import os

      app_id = os.environ['CORE_APP_ID']
      with open(os.environ['CORE_APP_PRIVATE_KEY'], 'r') as f:
          private_key = f.read()

      payload = {
          'iat': int(time.time()) - 60,
          'exp': int(time.time()) + (10 * 60),
          'iss': app_id
      }

      jwt_token = jwt.encode(payload, private_key, algorithm='RS256')

      headers = {
          'Authorization': f'Bearer {jwt_token}',
          'Accept': 'application/vnd.github+json'
      }
      response = requests.get('https://api.github.com/app/installations', headers=headers)
      installation_id = response.json()[0]['id']

      response = requests.post(
          f'https://api.github.com/app/installations/{installation_id}/access_tokens',
          headers=headers
      )
      print(response.json()['token'])
      EOF
    - export GITHUB_TOKEN=$(cat token.txt)
  artifacts:
    reports:
      dotenv: token.txt

use_token:
  stage: deploy
  dependencies:
    - generate_token
  script:
    - gh api /repos/my-org/my-repo/issues
```

### CircleCI Contexts

Store credentials in CircleCI contexts for secure sharing across projects.

### CircleCI Setup

1. Navigate to **Organization Settings** → **Contexts**
2. Create context (e.g., `github-app-credentials`)
3. Add environment variables:
   - `CORE_APP_ID`: `123456`
   - `CORE_APP_PRIVATE_KEY`: Complete PEM contents (use `\n` for line breaks)

### CircleCI Pipeline Usage

```yaml
version: 2.1

jobs:
  generate-token:
    docker:
      - image: cimg/python:3.11
    steps:
      - checkout
      - run:
          name: Install dependencies
          command: pip install pyjwt cryptography requests
      - run:
          name: Generate GitHub App token
          command: |
            python3 - <<'EOF' > /tmp/token.txt
            import jwt
            import time
            import requests
            import os

            app_id = os.environ['CORE_APP_ID']
            # CircleCI stores multi-line secrets with \n - convert back
            private_key = os.environ['CORE_APP_PRIVATE_KEY'].replace('\\n', '\n')

            payload = {
                'iat': int(time.time()) - 60,
                'exp': int(time.time()) + (10 * 60),
                'iss': app_id
            }

            jwt_token = jwt.encode(payload, private_key, algorithm='RS256')

            headers = {
                'Authorization': f'Bearer {jwt_token}',
                'Accept': 'application/vnd.github+json'
            }
            response = requests.get('https://api.github.com/app/installations', headers=headers)
            installation_id = response.json()[0]['id']

            response = requests.post(
                f'https://api.github.com/app/installations/{installation_id}/access_tokens',
                headers=headers
            )
            print(response.json()['token'])
            EOF
      - run:
          name: Use token
          command: |
            export GITHUB_TOKEN=$(cat /tmp/token.txt)
            gh api /repos/my-org/my-repo/issues

workflows:
  version: 2
  deploy:
    jobs:
      - generate-token:
          context: github-app-credentials
```

!!! warning "CircleCI Multi-line Secrets"

    CircleCI stores multi-line values with escaped `\n`. Convert back to actual newlines: `private_key.replace('\\n', '\n')`

### Platform Comparison

| Platform | Secret Type | Masking | Scoping | File Support | Multi-line Support |
| ---------- | ------------- | --------- | --------- | -------------- | -------------------- |
| **GitHub Actions** | Native secrets | Automatic | Repo/org/env | Via secrets | Yes (native) |
| **Jenkins** | Credentials | Plugin-based | Global/folder | Secret file type | Yes (file) |
| **GitLab CI** | CI/CD variables | Automatic (masked flag) | Project/group | File type | Yes (file type) |
| **CircleCI** | Context variables | Automatic | Organization | Environment variable | Yes (escaped `\n`) |
| **Bitbucket Pipelines** | Repository variables | Manual | Repository/deployment | Environment variable | Yes (escaped `\n`) |

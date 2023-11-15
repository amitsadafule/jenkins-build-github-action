# Jenkins Build GitHub Action

Start Jenkins jobs with GitHub actions and parameters. It checks for queued jobs, started jobs and status of the jobs
It also reports back the job status. This uses a shell based script

## Usage

You should create a user with below (casc) minimum permission and supply username and password to the action

```yaml
jenkins:
  securityRealm:
    local:
      users:
        - id: job-user
          password: '**********'
    authorizationStrategy:
    roleBased:
      roles:
        global:
          - entries:
              - user: "job-user"
            name: "job-user-role"
            pattern: ".*"
            permissions:
              - "Overall/Read"
        items:
          - entries:
              - user: "job-user"
            name: "job-user-jobs"
            pattern: "<regex paths to give access to>"
            permissions:
              - "Job/Build"
              - "Job/Discover"
              - "Job/Read"
```

It's best practice to save the password in [GitHub secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets).

### Example workflow

```yaml
name: jenkins-build-job

on:
  push:
    branches: [ main ]

jobs:
  build:
    name: Build
    runs-on: ubuntu-latest
    steps:
      - name: Trigger jenkins build job
        uses: amitsadafule/jenkins-build-github-action@v1.0.1-alpha
        with:
          JENKINS_URL: "https://jenkins.abc.xyz"
          PARAMETERS: '{"tag":"12234234242","b":"xyz"}'
          JENKINS_JOB_DIRECTORY_PATH: /job/some-dir/job/deploy/job/
          JOB_NAME: service-to-deploy
          JENKINS_USER: ${{ secrets.JENKINS_USER }}
          JENKINS_USER_PASS: ${{ secrets.JENKINS_TOKEN }}
```

### Inputs

| Input                        | Required | Description                                                                                                                                                    | Default |
|------------------------------|----------|----------------------------------------------------------------------------------------------------------------------------------------------------------------|---------|
| `jenkins_url`                | Yes      | Jenkins URL                                                                                                                                                    |         |
| `job_name`                   | Yes      | Job on which build needs to be triggered                                                                                                                       |         |
| `jenkins_job_directory_path` | No       | Jenkins job directory path. The must end with `/`                                                                                                              | `/job/` |
| `jenkins_user`               | Yes      | Jenkins user name. Please check above note for user accesses                                                                                                   |         |
| `jenkins_user_pass`          | Yes      | Jenkins user password                                                                                                                                          |         |
| `parameters`                 | Yes      | String in json format containing all the parameters that are needed to run the job and are required for the pipeline. e.g. `'{"tag":"12234234242","b":"xyz"}'` |         |

> [!NOTE]
> During the action trigger, it tries to create a temporary token for the user in jenkins. It also deletes the token at the end.
> If because of any reason action is abruptly terminated, you should delete the token of the user manually.

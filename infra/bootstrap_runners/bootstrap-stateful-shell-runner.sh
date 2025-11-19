## env

set -o allexport
source .env
set +o allexport



## install gitlab-runner

curl -L "https://packages.gitlab.com/install/repositories/runner/gitlab-runner/script.deb.sh" | sudo bash
sudo apt install -y gitlab-runner

## register gitlab-runner

sudo gitlab-runner register \
  --non-interactive \
  --url "$CI_SERVER_URL" \
  --token "$RUNNER_TOKEN" \
  --executor "shell" \
  --description "shell-runner"

sudo systemctl start gitlab-runner && sleep 3 && sudo systemctl status gitlab-runner

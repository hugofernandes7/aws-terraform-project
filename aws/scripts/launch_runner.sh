#!/bin/bash

# Launch gitlab runner in a docker container
docker run --rm -d \
  --name gitlab-runner \
  -v /srv/gitlab-runner/config:/etc/gitlab-runner \
  -v /var/run/docker.sock:/var/run/docker.sock \
  gitlab/gitlab-runner:latest
	
# Configure gitlab runner
docker exec -i gitlab-runner gitlab-runner register \
  --name gitlab-runner \
  --url ${gitlab_url} \
  --non-interactive \
  --executor docker \
  --docker-image alpine:latest \
  --docker-volumes /var/run/docker.sock:/var/run/docker.sock \
  --registration-token ${gitlab_token}

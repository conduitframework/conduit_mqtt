# ConduitMQTT

WIP

verneMQ  docker command for development testing:
```
docker run -p 1883:1883 -e "DOCKER_VERNEMQ_ALLOW_ANONYMOUS=on" -e "DOCKER_VERNEMQ_log.console.level=debug" -it erlio/docker-vernemq
```
# ConduitMQTT

WIP

verneMQ  docker command for development testing:
```
docker run -p 1883:1883 -e "DOCKER_VERNEMQ_ALLOW_ANONYMOUS=on" -e "DOCKER_VERNEMQ_log.console.level=debug" -it erlio/docker-vernemq
```
### TODO:
- Trim down some of the logging
- Lots of TODOs
- We need to handle headers and message fields
- Keyword lists in the GenServer's should probably be maps or normal lists
- building on circleci
- add the badges to the readme
- add a changelog
- add credo
- add dialyxir
- make sure it's formatted
- add this alias and the corresponding function?https://github.com/conduitframework/conduit/blob/master/mix.exs#L34
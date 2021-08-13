# LCU-Schema

A script to grab the LCU swagger/openapi spec and serve it on a gh-pages site.

### LCU online documentation

- [LCU OpenApi Tool](http://www.mingweisamuel.com/lcu-schema/tool/)
- [RCS OpenApi Tool](http://www.mingweisamuel.com/lcu-schema/tool/?url=..%2Frcs%2Fopenapi.json)

### Static files

OpenApi JSONs:
- [LCU v3 openapi.json](http://www.mingweisamuel.com/lcu-schema/lcu/openapi.json)
- [LCU v2 swagger.json](http://www.mingweisamuel.com/lcu-schema/lcu/swagger.json)
- [RCS v3 openapi.json](http://www.mingweisamuel.com/lcu-schema/rcs/openapi.json)
- [RCS v2 swagger.json](http://www.mingweisamuel.com/lcu-schema/rcs/swagger.json)

Data:
- [LCU maps.json (`/lol-maps/v1/maps`)](http://www.mingweisamuel.com/lcu-schema/maps.json)
- [LCU queues.json (`/lol-game-queues/v1/queues`)](http://www.mingweisamuel.com/lcu-schema/queues.json)
- [LCU catalog.json (`/lol-store/v1/catalog`)](http://www.mingweisamuel.com/lcu-schema/catalog.json)

## Updating

To update, call `.\update.ps1` with the League client closed. To get
information requiring log-in, add a file `lollogin.json` with `"username"` and
`"password"` fields for your League of Legends account.

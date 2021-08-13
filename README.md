# LCU-Schema

A script to grab the LCU swagger/openapi spec and serve it on a gh-pages site.

### LCU online documentation

- [OpenApi Tool](http://www.mingweisamuel.com/lcu-schema/tool/)

### Static files

OpenApi JSONs:
- [v3 openapi.json](http://www.mingweisamuel.com/lcu-schema/lcu/openapi.json)
- [v2 swagger.json](http://www.mingweisamuel.com/lcu-schema/lcu/swagger.json)

Data:
- [maps.json (`/lol-maps/v1/maps`)](http://www.mingweisamuel.com/lcu-schema/maps.json)
- [queues.json (`/lol-game-queues/v1/queues`)](http://www.mingweisamuel.com/lcu-schema/queues.json)
- [catalog.json (`/lol-store/v1/catalog`)](http://www.mingweisamuel.com/lcu-schema/catalog.json)

## Updating

To update, call `.\update.ps1` with the League client closed. To get
information requiring log-in, add a file `lollogin.json` with `"username"` and
`"password"` fields for your League of Legends account.

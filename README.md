# LCU-Schema

A script to grab the LCU swagger/openapi spec and serve it on a gh-pages site.

### LCU online documentation

[http://www.mingweisamuel.com/lcu-schema/tool/](http://www.mingweisamuel.com/lcu-schema/tool/)

### Static files

OpenAPI v3 spec:
- [openapi.json](http://www.mingweisamuel.com/lcu-schema/openapi.json)

Swagger v2 spec:
- [swagger.json](http://www.mingweisamuel.com/lcu-schema/swagger.json)

Data:
- [maps.json](http://www.mingweisamuel.com/lcu-schema/maps.json)
- [queues.json](http://www.mingweisamuel.com/lcu-schema/queues.json)
- [store-catalog.json](http://www.mingweisamuel.com/lcu-schema/store-catalog.json)

## Updating

To update, call `.\update.ps1` with the League client closed. To get
information requiring log-in, add a file `lollogin.json` with `"username"` and
`"password"` fields for your League of Legends account.

**Note: Riot has recently removed the OpenAPI/Swagger spec from the LCU, see [#5](https://github.com/MingweiSamuel/lcu-schema/issues/5). Spec may be out-of-date.**

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

## See Also

[Setup League Client](https://github.com/magisteriis/setup-league-client) - A
gh-action for setting up the League of Legends client (a.k.a. League Client/LCU).
Good for testing League Client integrations.

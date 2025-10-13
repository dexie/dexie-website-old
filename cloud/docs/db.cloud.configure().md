---
layout: docs-dexie-cloud
title: 'db.cloud.configure()'
---

Configure the URL of the database to keep in sync with, along with other options.

## Syntax

```
npm install dexie-cloud-addon
```

```ts
import Dexie from "dexie";
import dexieCloud from "dexie-cloud-addon";

const db = new Dexie("mydb", {addons: [dexieCloud]});

db.version(x).stores({
  ...
});

db.cloud.configure(options: DexieCloudOptions);
```

See interface [DexieCloudOptions](DexieCloudOptions)

## Example

```ts
import Dexie from 'dexie'
import dexieCloud from 'dexie-cloud-addon'

const db = new Dexie('mydb', { addons: [dexieCloud] })
db.version(1).stores({
  friends: `@id, name, age`,
})

db.cloud.configure({
  databaseUrl: 'https://xxxxxx.dexie.cloud', // Create DB: `npx dexie-cloud create`
})
```

## Remarks

The call to db.cloud.configure() must be done before any requests are put on the `db` (the Dexie instance) so that the database knows what to do when before opening it the first time.

## Options

| Parameter                                   | Type                              | Explanation                                                                                                                                                                                                                                                       |
| ------------------------------------------- | --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [databaseUrl](#databaseurl)                 | string                            | The URL to your Dexie Cloud database                                                                                                                                                                                                                              |
| [requireAuth](#requireauth)                 | boolean                           | Whether or not to require authentication initially or allow unauthorized usage with option to login when needed. A value of false enables unauthorized shopping basket example with possibility to authenticate to get the data become connected to user account. |
| [tryUseServiceWorker](#tryuseserviceworker) | boolean                           |  Let service worker take care of the sync job. See [tryUseServiceWorker](#tryuseserviceworker) below.                                                                                                                                                             |
| [periodicSync](#periodic-sync)              | `{minInterval: number}`           | The minimum interval time, in milliseconds, at which the service-worker's periodic sync should occur. See <https://github.com/WICG/background-sync/blob/main/explainers/periodicsync-explainer.md#timing-of-periodic-sync-tasks>                                  |
| [customLoginGui](#customlogingui)           | boolean                           | Disable default login GUI and replace it with your own by subscribing to the `db.cloud.userInteraction` observable and render its emitted data.                                                                                                                   |
| unsyncedTables                              | string[]                          | Array of table names that should be considered local-only and not be synced with Dexie Cloud                                                                                                                                                                      |
| unsyncedProperties                          | `{[tableName: string]: string[]}` | Array of properties (per table) that should be considered local-only and be synced.                                                                                                                                                                               |
| nameSuffix                                  | boolean                           | See [nameSuffix](#namesuffix) below                                                                                                                                                                                                                               |
| disableWebSocket                            | boolean                           | Disable websocket connection. This will disable listening of server changes and only sync when there is a client change. You can manually call `db.cloud.sync({purpose: 'pull'})` periodically as an alternative to using the WebSocket connection.               |
| disableEagerSync                            | boolean                           | When set, local changes will not trigger a sync towards the server.                                                                                                                                                                                               |
| fetchTokens                                 | Callback                          | Provide JWT tokens customly. Enables custom authentication. See [full client- and server example here](#example-integrate-custom-authentication).                                                                                                                 |

See the Typescript definition of this parametered object argument to get the typing details: [DexieCloudOptions](DexieCloudOptions).

### databaseUrl

The URL to the database. This is the URL to your Dexie Cloud database. If you don't know your database URL, you can login to [Dexie Cloud Manager](https://manager.dexie.cloud) to see what databases you have access to manage. You can also create a new database using [npx dexie-cloud create](/cloud/docs/cli#create) on a command prompt on any mac, PC or linux computer with node installed.

### requireAuth

If this parameter is true, the system will make sure there it has a valid authentication token before before any call to the database can proceed. In practice, this means that the user will be required to authenticate the very first time app is used on the device. Authentication token will be securely persistently stored until user logs out. If looking at your progressive web app as if it was a native app, regard the authentication as a part of the installation process. Once installed, the app should continue working as expected without the need of reauthentication. This policy will be configurable in a later version. We will also be looking at ways to separate the authentication policy for read and write - you might always be able to access data, but in order to mutate data you could apply a different policy with requiring reauthentication.

### tryUseServiceWorker

This option will make dexie-cloud-addon look for a service worker registration, and if it finds it, delegate all sync jobs to the service worker including background and periodic sync.

For `tryUseServiceWorker` option to have any effect, you must also register a service worker and importScripts("dexie-cloud-addon/dist/umd/service-worker[.min].js") from it. Service worker enables changes to be queued and synced also when your application is closed. It also allows for periodic background sync if user has Chrome and adds your progressive web app to home screen (installs it).

#### Background Sync

Dexie Cloud takes advantage of Service Worker Background Sync. It makes it possible to sync your local changes to the server even after the app has closed. Think chat application. You're on mobile and write a message and click send, but your network is flaky or down. Then, you close the phone and put it in your pocket. Some time later on, the phone detects a healthy network. At this point, your chat message will sync and reach the other participants. If it wasn't for background sync, your chat message would still have been queued in IndexedDB, but not actively synced until you'd open up the app again.

#### Periodic Sync

Periodic Sync is also a service worker feature and can be configured with a minimum requested interval (see [these docs from the specification](https://github.com/WICG/background-sync/blob/main/explainers/periodicsync-explainer.md#timing-of-periodic-sync-tasks)). If the `periodicSync` option is specified in `db.cloud.configure()`, it will be passed to the background-sync configuration for the service worker.

Periodic sync makes it possible to pull remote changes from a server even when the app is not open. Think weather app... You take up your phone and click the weather app and get an up-to-date weather report despite being offline! This is because you were online 2 hours ago while walking with the phone in your pocket and periodic sync kicked in and did a pull sync from the server, retrieving a recent weather report prepared for you.

Periodic sync registration will only be active when the PWA is actually installed on the user device (and as of October 2023, only works in Chrome, Edge, Opera and possibly in Ionic or Capacitor based installations). However, periodic sync is normally not a crucial feature, but quite nice to have as it can keep the offline database up-to-date before user starts interacting with the app.

#### Dexie Cloud without Sevice Worker

Service Worker enables Background Sync and Periodic Sync (and a bunch of other features not covered here). But life is not so hard without it anyway. Dexie Cloud works very well without a service worker. As long as the application is open and the user is active, it will keep a bidirectional eager sync connection to the server. Any change on the client will eagerly sync to server and any change on the server will be eagerly sent to the client over its websocket connection. The only downside with not using service worker is that it will only sync while application is open and never be able to sync in the background when the app is closed and phone is in your pocket.

#### Enable Service Worker With plain JS

Create your own service worker JS file. It can be a simple file named 'sw.js' and let it import dexie-cloud's service worker code:

```js
importScripts('<path to...>/dexie-cloud-addon/dist/umd/service-worker.js')
```

You can then extend your sw.js service worker for other purposes as well, such as caching etc, but for dexie-cloud to use it for sync, only the above single line will be needed.

Somewhere in your app code, register your service worker:

```js
if ('serviceWorker' in navigator) {
  navigator.serviceWorker.register('sw.js')
}
```

Then where you configure dexie cloud, use the option `{tryUseServiceWorker: true}`.

#### Enable Service Worker With `create-react-app`

For those who use [create-react-app](https://create-react-app.dev/docs/making-a-progressive-web-app/), run it with option `--template cra-template-pwa` or `--template cra-template-pwa-typescript` to get the service worker setup for you with a nice template for a full progressive web app including a PWA manifest etc so that your app becomes installable at peoples devices. Then add the following line to the top of the generated `service-worker.js` or `service-worker.ts` of your app:

```ts
// Import Dexie Cloud Service Worker
import 'dexie-cloud-addon/dist/umd/service-worker'
```

Also, in `index.jsx` / `index.tsx`, change the line `serviceWorkerRegistration.unregister();` to `serviceWorkerRegistration.register();` as described by [the docs from create-react-app](https://create-react-app.dev/docs/making-a-progressive-web-app/).

#### Only for Production Builds

Service workers are great for production but can be confusing while developing and debugging an application - specifically because they do not update unless you close down all instances of your application and reopen it. If you used create-react-app to generate the service worker, it will automatically turn off service worker when starting the dev version of your app but activates it in its production build.

### customLoginGui

Enable this option and subscribe to [db.cloud.userInteraction](db.cloud.userInteraction) to provide your own user interface for the built-in OTP authentication. Enabling this option will silence the built-in GUI of login dialogs and instead allow you to render a component that displays your preferred style of login dialogs. See [this react example](/cloud/docs/authentication#customizing-login-gui) on how to implement custom login GUI.

If you rather want to replace the authentication solution from email OTP to your own or a 3rd part solution, see [Example: Integrate Custom Authentication](#example-integrate-custom-authentication)

### nameSuffix

By default Dexie Cloud will append part of the given `databaseURL` to your IndexedDB database name. `'FriendsDatabase'` becomes `'FriendsDatabase-z0lesejpr'` or similar (last part is the ID part from your database URL). The reason it does this is to make your local IndexedDB database unique per database URL and so that vanilla Dexie databases can coexist with a cloud-connected database even when they specify the same name in their constructor. Likewise, if the databaseUrl is changed to another remote database, it will not try to connect the same local database to match the new remote one.

The `nameSuffix` option is considered `true` by default, so in order to disable it, you must explicitly set `nameSuffix` option to `false`.
By specifying `{nameSuffix: false}`, Dexie will name the database without appending a suffix - the same way as it does in plain Dexie.js.

### fetchTokens

Specify a callback here if you want to implement your own way of retrieving the JWT tokens. By default, these tokens will be generated by Dexie Cloud server.
But your application may have its own way of authenticating users, or integrate with a 3rd part authentication provider. In that case you will need to implement
your own server-side endpoint on a server that can authenticate your user. That server endpoint (who known your user's identity) can then request a token from Dexie Cloud without requiring the OTP step. This needs to happen server-side because in order to request a token without going through the OTP step will require the REST client to provide your client_id and client_secret in the request. You have client_id and client_secret in the dexie-cloud.key file that was generated when you created the database (using `npx dexie-cloud create`). These keys shall never be used from client side. The key file
should not be added to git either but be managed in a secure way using the cloud infrastructure of your own choice.

### Example: Integrate Custom Authentication

Dexie Cloud comes with zero-config email OTP authentication but if you need to replace that with any custom authentication, you can follow this guide. By defining the `fetchTokens` configuration parameter, you opt-out from zero-config authentication and control the the authentication flow yourself instead. The `fetchTokens` callback needs to return a promise containing the Dexie Cloud token. That token can be retrieved over server-to-server requests towards Dexie Cloud so you will need a server endpoint to do it. You can either integrate with your existing web server or create a new server endpoint using an authentication framework of your choice, such as Node.js and Passportjs. You need to extend the existing server to respond to a new URL (You can name the route what you want but in our example, we'll use `/dexie-cloud-tokens`). This new URL endpoint shall request tokens from Dexie Cloud via server-to-server communication using the logged in user and return the Dexie Cloud tokens to its client. The client of your new endpoint will be the browser where your dexie based app resides, and it will request server in the callback you configured in the `fetchTokens` option.

**Node.js server endpoint**

The code below exemplifies how to generate tokens if your authentication solution is based on Node.js and [Passport](http://www.passportjs.org){:target="\_blank"}. If you have another server-side platform or language for your existing authentication, you would need to translate this example to that language and platform. Note that the authentication platform (Passport or other) can use whatever mechanism to authenticate the user - integrate with OpenIDConnect, Google, GitHub, facebook etc. For guides for doing so, we refer to other guides on the internet
that covers this. If you are starting from a white paper and just need a way to get going, we recommend the guides from [auth0](https://auth0.com){:target="\_blank"} or [Passport](http://www.passportjs.org){:target="\_blank"} but remember that Dexie Cloud comes with zero config authentication based on one-time-passwords over email, so setting up custom authentication is just an optional next-step. Make sure to get up running Dexie Cloud with zero config authentication first.

```js
// ...other express / passport imports and setup...

const nodeFetch = require('node-fetch')

const DB_URL = process.env.DEXIE_CLOUD_DB_URL
const CLIENT_ID = process.env.DEXIE_CLOUD_CLIENT_ID
const CLIENT_SECRET = process.env.DEXIE_CLOUD_CLIENT_SECRET

// ...other express / passport endpoints here...

// The new endpoint to add:
app.post('/dexie-cloud-tokens', bodyParser.json(), async (req, res, next) => {
  try {
    // Parameters that you provide:
    // Assume you've configured passport to store user on request:
    const user = req.user // See http://www.passportjs.org/docs/configure/

    // Parameters that dexie-cloud client will provide via fetchTokens option.
    const public_key = req.body.public_key // For refresh token authentication

    // Request token from your Dexie Cloud database:
    const tokenResponse = await nodeFetch(`${DB_URL}/token`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Accept: 'application/json',
      },
      body: JSON.stringify({
        grant_type: 'client_credentials',
        scopes: ['ACCESS_DB'],
        public_key,
        client_id: CLIENT_ID,
        client_secret: CLIENT_SECRET,
        claims: {
          sub: user.userId, // or user.email. Your framework must provide this.
          email: user.email, // optional but nice.
          name: user.name, // optional but nice.
        },
      }),
    })
    if (!tokenResponse.ok) {
      throw new Error(`Failed to retrieve token from Dexie Cloud.`)
    }

    // Forward token response to your client:
    const tokenBody = await tokenResponse.json()
    res.set('Cache-Control', 'no-store')
    res.json(tokenBody)
  } catch (error) {
    return next(error)
  }
})
```

**fetchTokens implementation in your client code**

Assuming that your server endpoint will respond to the path "/dexie-cloud-tokens" as exemplified above (using whatever server side technology you have for that),
the client code to integrate it will be:

```js
db.cloud.configure({
  databaseUrl: '<database URL>',
  requireAuth: true,
  fetchTokens: (tokenParams) =>
    fetch('/dexie-cloud-tokens', {
      method: 'post',
      credentials: 'same-origin',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(tokenParams),
    }).then((res) => res.json()),
})
```

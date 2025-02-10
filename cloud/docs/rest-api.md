---
layout: docs-dexie-cloud
title: 'Dexie Cloud REST API'
---

This page documents the REST API that every database in Dexie Cloud has.

## Endpoints

| [/token](#token) | Token endpoint |
| [/token/validate](#tokenvalidate) | Token validation endpoint |
| [/all/...](#all-endpoint) | All data endpoint |
| [/my/...](#my-endpoint) | My data endpoint |
| [/public/...](#public-endpoint) | Public data endpoint |
| [/users/...](#users-endpoint) | Users data endpoint |

### /token

| Method | POST |
| Content-Type | application/json |
| Parameters | `{grant_type, client_id?, client_secret?, code?, name?, email?}`|
| Authentication | Either Basic or none (see explanation below) |

Request a token for the calling endpoint. This method can be called directly from web clients or from a server. When called from a web client, grant_type must be "authorization_code" and a valid "code" parameter retrieved from the authorize endpoint must be given. This is all handled by `dexie-cloud-addon`. But when called from one of your own servers, you can make the token endpoint produce a token for a user that your server has already authenticated:

```js
{
  grant_type: "client_credentials",
  scopes: Array<"ACCESS_DB" | "IMPERSONATE" | "MANAGE_DB" |  "GLOBAL_READ" | "GLOBAL_WRITE" | "DELETE_DB">,
  client_id: <your client ID>,
  client_secret: <your client secret>,
  public_key?: <public key> (if a refresh token is needed),
  claims?: {
    sub: <userid>,
    email: <email>,
    name: <name of user to authenticate>
  }
}
```

See a [sample code to call this endpoint to authenticate end users](<db.cloud.configure()#example-integrate-custom-authentication>).

A client must be given the "IMPERSONATE" scope in order to supply `claims` property to this endpoint.

#### scopes

You can only request a subset of the scopes that your client has. The default client of a database have all the scopes available. Additional clients are created using `npx dexie-cloud authorize` where the scopes can be configured.

For REST calls described here, you could either act on behalf of an end-user and use the /my/... endpoint to request and modify data. Or you can act with global database access and use the /all/... endpoint. The /public/... endpoint require no authorization whatsoever for GET requests, but require GLOBAL_READ and GLOBAL_WRITE in order to POST or DELETE objects.

##### Get a token on behalf of an end-user

If you're interested in acting on behalf of an end-user, you can request a token for the end-user as such:

```
POST /token HTTP/1.1
Host: xxxx.dexie.cloud
Content-Type: application/json

{
  "grant_type": "client_credentials",
  "scopes": ["ACCESS_DB"],
  "client_id": <your client ID>,
  "client_secret": <your client secret>,
  "claims": {
    "sub": <userid>,
    "email": <email>,
    "name": <name of user to authenticate>
  }
}
```

Then use the /my/... endpoint to access their data.

##### Get a token with global database access

```
POST /token HTTP/1.1
Host: xxxx.dexie.cloud
Content-Type: application/json

{
  "grant_type": "client_credentials",
  "scopes": ["ACCESS_DB","GLOBAL_READ","GLOBAL_WRITE"],
  "client_id": <your client ID>,
  "client_secret": <your client secret>,
}
```

A token with global access allows you to read data from any realm and if you include GLOBAL_WRITE you can also modify any data.

#### Response

The response body from POST /token can be described by the following interface:

```ts
export interface TokenFinalResponse {
  type: 'tokens'
  claims: {
    sub: string
    license?: 'ok' | 'expired' | 'deactivated'
    [claimName: string]: any
  }
  accessToken: string
  accessTokenExpiration: number
  refreshToken?: string
  refreshTokenExpiration?: number | null
  userType: 'demo' | 'eval' | 'prod' | 'client'
  evalDaysLeft?: number
  userValidUntil?: number
  alerts?: {
    type: 'warning' | 'info'
    messageCode: string
    message: string
    messageParams?: { [param: string]: string }
  }[]
}
```

Make sure that the response has the response code 200 with Content-Type "application/json". The access token can be picked
from the "accessToken" JSON property in the response body.

To use this response in the other REST requests, make sure to include an "Authorization" header with the accessToken provided as such

```js
;`Authorization: Bearer ${tokenResponse.accessToken}`
```

The token is valid in one hour from the time it was requested.

#### See Also

- [Tokens](authentication#tokens)
- [Example auth integration](<db.cloud.configure()#example-integrate-custom-authentication>)

### /token/validate

| Method | GET |
| Authorization | Bearer token |

Validates a JWT token.

```http
GET /token/validate HTTP/1.1
Host: xxxx.dexie.cloud
Origin: <the origin header from your client>
Authorization: Bearer <JWT token>
```

Expected result:

```http
HTTP/1.1 200 Ok
Content-Type: application/json

{
  valid: true,
  claims: {
    ...claims
  }
}
```

### /all/... endpoint

**Get all objects in given table:**

```http
GET /all/<table> HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with GLOBAL_READ and ACCESS_DB scopes)>
```

**Get all objects in given table and realm:**

```http
GET /all/<table>?realmId=<realmId> HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with GLOBAL_READ and ACCESS_DB scopes)>
```

**Get all objects in given table with a filter:**

```http
GET /all/<table>?<propName>=<propValue>&<propName2>=<propValue2>&... HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with GLOBAL_READ and ACCESS_DB scopes)>
```

This request will filter the query to only return matching objects. A concrete example:

```http
GET /all/todoItems?todoListId=xxx HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with GLOBAL_READ and ACCESS_DB scopes)>
```

_This example would give you all todoItems that has the property todoListId set to "xxx"._

**Get simple object by primary key:**

```http
GET /all/<table>/<primary key> HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with GLOBAL_READ and ACCESS_DB scopes)>
```

If primary key is [compound](/docs/Compound-Index#compound-primary-key), the JSON representation of the key shall be given. Always encode `<table>` and `<primaryKey>` using URL encoding (`encodeURIComponent()` in JS).

### /my/... endpoint

The /my/... endpoint works exactly like the /all/... endpoint, except that it doesn't search the global database but can only return objects that are accessible for the token subject.

```http
GET /my/<table> HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with ACCESS_DB scope)>
```

The token to use should be given out to a certain subject (userId) with the "ACCESS_DB" scope only.

**Example:**

```http
GET /my/todoLists HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with ACCESS_DB scope)>
```

_Lists all todoLists that the user has at least readonly access to. Either their own private lists or todo-lists that have been shared to the user._

### /public/... endpoint

The /public/... endpoint works exactly list the /all/... and /my/... endpoints except that it will only access public data - i.e. data that resides in the public realm "rlm-public".
This endpoint does not require authorization on GET requests.

**Examples:**

```http
GET /public/products HTTP/1.1
```

```http
GET /public/roles HTTP/1.1
```

### POST and DELETE

In either of the REST endpoints you can use GET, POST or DELETE methods where the two latter are used to mutate data.

#### POST

POST method requires the content-type to be "application/json" and the body to be a JSON array of the data to upsert. If given data is not a JSON array, it will be treated as a single upsert. The primary key of each object is determined by the primary key property defined in your dexie schema. The schema can be synced using [npx dexie-cloud import](/cloud/docs/cli#import).

If an object already exists with the given primary key, it will be replaced, otherwise created.

**/all:**

- Each posted object must have the `realmId` property set or the request will fail.
- If the table of the schema marks the primary key be auto-generated global ID '@'-prefixed primary key, the primary key may be omitted and if so, generated by the server.

```http
POST /all/<table> HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with GLOBAL_READ, GLOBAL_WRITE and ACCESS_DB scopes)>
Content-Type: application/json

[{
  [primaryKeyProp]: <primaryKey>,
  realmId: <theRealmId>,
  otherProperty: otherValue,
  ...
}]
```

**/my:**

- realmId will default to the private realm of the user who's token you are using.
- primary key will default to be auto-generated on server (if the table of the schema marks the primary key to auto-generated with global ID '@'-prefixed primary key) unless specified in the POST data.

```http
POST /my/<table> HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with ACCESS_DB scope and appropriate permissions if realmId is specified)>
Content-Type: application/json

[{
  ...properties
}]
```

**/public:**

- realmId can be omitted - it will be set to "rlm-public" by the server.
- primary key will default to be auto-generated on server (if the table of the schema marks the primary key to auto-generated with global ID '@'-prefixed primary key) unless specified in the POST data.

```http
POST /all/<table> HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with GLOBAL_READ, GLOBAL_WRITE and ACCESS_DB scopes)>
Content-Type: application/json

[{
  ...properties
}]
```

#### DELETE

DELETE method deletes any object in given table that matches the given primary key.

If primary key is [compound](/docs/Compound-Index#compound-primary-key), the JSON representation of the key shall be given. Always encode `<table>` and `<primaryKey>` using URL encoding (`encodeURIComponent()` in JS).

```http
DELETE /all/<table>/<primaryKey> HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with GLOBAL_READ, GLOBAL_WRITE and ACCESS_DB scopes)>

```

```http
DELETE /public/<table>/<primaryKey> HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with GLOBAL_READ, GLOBAL_WRITE and ACCESS_DB scopes)>

```

_The difference between `DELETE /all/<table>/id` and `DELETE /public/<table>/id` is that the latter will only delete the object if its property `realmId` is set to `"rlm-public"` (the public realm)._

```http
DELETE /my/<table>/<primaryKey> HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with ACCESS_DB scope and appropriate permissions on the object)>
Content-Type: application/json

```

_Deleting personal data does not require GLOBAL_WRITE scope but will fail to delete data where user does not have permissions to do so within the realm the object belongs to._

#### Examples

Delete a todoItem

```
DELETE /all/todoItems/tdi0Oma0cOxZhnmTbCQTMxP3Xetcal HTTP/1.1
Host: z0lesejpr.dexie.cloud
Authorization: Bearer <token from /token endpoint (with GLOBAL_READ, GLOBAL_WRITE and ACCESS_DB scopes)>

```

Delete a compound key (array key `["Bob",42]`)

```
DELETE /all/compoundTable/%5B%22Bob%22%2C42%5D HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with GLOBAL_READ, GLOBAL_WRITE and ACCESS_DB scopes)>
```

...where `%5B%22Bob%22%2C42%5D` is the URI encoded representation of JSON `["Bob",42]`.

### /users endpoint

The /users endpoint can be used to list, get, update and delete application users from your database. You can use the API to upgrade users from evaluation accounts to production accounts or vice versa. This API does supports sorting and paging results.

#### List users

**Request:**

```http
GET /users?<query> HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer <token from /token endpoint (with GLOBAL_READ and ACCESS_DB scopes)>
```

The query is optional and consists of a list of optional &amp;-separated key=value pairs (see below)

**Query Parameters:**

| Param                   | Description                           |
| ----------------------- | ------------------------------------- |
| `search=<searchText>`   | Fuzzy part of userId, email or name   |
| `active=true`           | Only return active users              |
| `active=false`          | Only return inactive users            |
| `type=eval`             | Only return evaluation users          |
| `type=prod`             | Only return production users          |
| `type=demo`             | Only return demo users                |
| `sort=created`          | Sort by creation date                 |
| `sort=validUntil`       | Sort by validUntil date               |
| `sort=updated`          | Sort by updated date property         |
| `sort=evalDaysLeft`     | Sort by evalDaysLeft property         |
| `sort=lastLogin`        | Sort by lastLogin property            |
| `sort=userId`           | Sort by userId property               |
| `sort=type`             | Sort by type property                 |
| `sort=displayName`      | Sort by displayName property          |
| `desc`                  | Sort descending                       |
| `desc=true`             | Sort descending                       |
| `desc=false`            | Sort ascending (default)              |
| `limit=N`               | Max number of result users (max 1000) |
| `pagingKey=<pagingKey>` | The pagingKey prop from last result   |

| Default query parameters | Description                                                  |
| ------------------------ | ------------------------------------------------------------ |
| `sort=userId`            | Sort by userId                                               |
| `desc=false`             | Sort ascending                                               |
| `limit=1000`             | Max 1000 users in result (use pagingKey to get more results) |

**JSON Response Format:**

```ts
{
  "data": DBUserJsonModel[],
  "hasMore": boolean, // true if more than "limit" results where available
  "pagingKey"?: string // The pagingKey to use in next request to get more results
}

interface DBUserJsonModel {
  readonly userId: string;
  readonly created: ISODateTimeString;
  readonly updated: ISODateTimeString;
  readonly lastLogin?: ISODateTimeString | null;
  type: 'eval' | 'prod' | 'demo';
  validUntil?: ISODateTimeString;
  evalDaysLeft?: number;
  readonly maxAllowedEvalDaysLeft: number
  deactivated?: ISODateTimeString;
  data: {
    displayName?: string;
    email?: string;
    [key: string]: any;
  };
}
```

**HTTP Example listing users:**

```http
GET /users?sort=userId&limit=2 HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer XXX...

HTTP/1.1 200 Ok
Content-Type: application/json

{
  "data": [
    {
      "created": "2023-10-27T22:10:29.922Z",
      "data": null,
      "deactivated": null,
      "lastLogin": "2023-10-31T08:22:56.816Z",
      "type": "demo",
      "updated": "2023-10-27T22:10:29.922Z",
      "userId": "alice@demo.local"
    },
    {
      "created": "2023-10-30T13:45:24.993Z",
      "data": {
        "email": "david@dexie.org",
        "displayName": "David Fahlander"
      },
      "deactivated": null,
      "evalDaysLeft": 30,
      "lastLogin": "2023-10-30T14:45:04.051Z",
      "maxAllowedEvalDaysLeft": 30,
      "type": "eval",
      "updated": "2023-10-30T13:45:24.981Z",
      "userId": "david@dexie.org"
    }
  ],
  "hasMore": true,
  "pagingKey": "WyJhbGljZUBkZW1vLmxvY2FsIiwiYWxpY2VAZGVtby5sb2NhbCJd"
}
```

**Paging:**

When `hasMore` is `true`, there will always be a `pagingKey`. To retrieve next page of data, just repeat the exact same request but with given `pagingKey` added in a query parameter:

```http
GET /users?sort=userId&limit=2&pagingKey=WyJhbGljZUBkZW1vLmxvY2FsIiwiYWxpY2VAZGVtby5sb2NhbCJd HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer XXX...
```

#### Get Single User

```http
GET /users/<userId> HTTP/1.1
Authorization: Bearer <token from /token endpoint>
```

**JSON Reponse format:**
The JSON format will be the plain user data.

**HTTP Example retrieving single user:**

```http
GET /users/alice@demo.local HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer XXX...

HTTP/1.1 200 Ok
Content-Type: application/json

{
   "created" : "2023-10-27T22:10:29.922Z",
   "data" : null,
   "deactivated" : null,
   "evalDaysLeft" : 0,
   "lastLogin" : "2023-10-31T08:22:56.816Z",
   "maxAllowedEvalDaysLeft" : 0,
   "type" : "demo",
   "updated" : "2023-10-27T22:10:29.922Z",
   "userId" : "alice@demo.local"
}
```

#### userId vs email

In all these samples, userId is the same as email. This is true when using the built-in OTP authentication that sends OTP to email address to authenticate a user. However, custom authentication solution might separate these two and that is the reason we have them separated in our models.

#### Create users

To create one or several users, do a POST request against /users endpoint with Content-Type: application/json. The JSON data must be an array of users. Each user in the array must at least have the "userId" and the "type" properties set. Optionally, supply the properties "validUntil", "evalDaysLeft", "deactivated" and "data" properties. This API is picky about unsupported properties and will fail if any unsupported or unauthorized property was present in the provided users. The only fuzzy part of a user is the data property that can contain arbritary sub properties.

```http
POST /users HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer XXX...
Content-Type: application/json

[
  {
    "userId": "david@dexie.org",
    "type": "eval",
    "evalDaysLeft": 30,
    "data": {
      "email": "david@dexie.org",
    }
  }
]
```

#### Update users

To update one or several users, do a POST request against /users endpoint with Content-Type: application/json. The JSON data must be an array of change objects. Each entry in the array does only need to specify the userId property along with the properties to update. This API is picky about unsupported properties and will fail if any unsupported or unauthorized property was present in the change objects. The only fuzzy part of a user is the data property that can contain arbritary sub properties.

**_Updateable user properties:_**

- type
- validUntil
- evalDaysLeft
- deactivated
- data

```http
POST /users HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer XXX...
Content-Type: application/json

[
  {
    "userId": "david@dexie.org",
    "type": "prod",
    "data": {
      "email": "david@dexie.org",
      "displayName": "David Fahlander"
    }
  }
]
```

#### Delete user

```http
DELETE /users/<userId>
Host: xxxx.dexie.cloud
Authorization: Bearer XXX...
```

To delete any other user than your own account, you need the GLOBAL_READ, GLOBAL_WRITE and ACCESS_DB scopes in your Bearer token. Any user have the permission to delete themselves. The permission to delete own user is for GDPR compliance.

Deleting a user will make the system erase everything associated with the user including private data that the user has created. If the user has shared data with other users, the user will be removed from the realm in question but the data will be kept and stay available for the other users.

If a deleted user was the only user with full permissions in a realm, we would end up with a realm that no one would have permissions to manage or delete. If that situation occurs, all other members of the realm will gain full control over it s that they will have the possibility to delete it or take ownership of it.

Evaluation users might extend their evaluation by deleting their own user (along with the associated data) in order to re-register and start a new evaluation period.

**NOTE!**

DELETING A USER IS A DESTRUCTIVE OPERATION AND WILL IMPLY DATA DELETION OF ALL DATA THAT WAS PRIVATE FOR THAT USER! Consider deactivating a user rather than deleting it.

#### Deactivate User

Deactivating a user is a soft delete. No data associated with the user will be deleted and the user may be reactivated later on.

```http
POST /users HTTP/1.1
Host: xxxx.dexie.cloud
Authorization: Bearer XXX...
Content-Type: application/json

[
  {
    "userId": "david@dexie.org",
    "deactivated": true
  }
]
```

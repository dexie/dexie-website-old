---
layout: docs
title: "Dexie Constructor"
---

Dexie.js (Official home page: [dexie.org](https://dexie.org)) is a library that makes it super simple to use [indexedDB](https://developer.mozilla.org/en-US/docs/Web/API/IndexedDB_API) - the standard client-side database in browsers. Read more about Dexie on it's [README](https://github.com/dexie/Dexie.js/blob/master/README.md) or at the [home page](https://dexie.org).

`Dexie` is the main class and the default export of the library. An instance of this class represents an indexedDB database connection.

### Syntax

```javascript
var db = new Dexie(databaseName, options?);
```

### Parameters

| Parameter                  | Description   |
| -------------------------- | ------------- |
| dbName: String             | Database name |
| options: Object (optional) | API Options   |

### Options

| Option                                                                                   | Description                                                                                                                                                                                                                                                                                                          |
| ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| addons: Array&lt;DexieAddon&gt;                                                                | Explicitly define the addons to activate for this db instance                                                                                                                                                                                                                                                        |
| autoOpen: boolean                                                                        | Default true. Whether database will open automatically on first query.                                                                                                                                                                                                                                               |
| indexedDB: [IDBFactory](https://developer.mozilla.org/en-US/docs/Web/API/IDBFactory)     | Supply an alternate implementation of indexedDB. If supplying this, also supply IDBKeyRange that works with that implementation.                                                                                                                                                                                     |
| IDBKeyRange: [IDBKeyRange](https://developer.mozilla.org/en-US/docs/Web/API/IDBKeyRange) | An implementation of the IDBKeyRange interface that works with provided indexedDB implementation.                                                                                                                                                                                                                    |
| allowEmptyDB: boolean                                                                    | If opening in [dynamic mode](<Dexie.open()#dynamic-mode>) (not defining a schema) the call to db.open() will normally reject if the database didn't exist and this option is false or not set. By setting this option to true, Dexie.open() will succeed to create a new empty database when opening it dynamically. |
| modifyChunkSize: number                                                                  | (since 3.1.0-alpha) Override the default value of 2000 rows per chunk used by Collection.modify(). See [FR #1152](https://github.com/dexie/Dexie.js/issues/1152).                                                                                                                                                |
| chromeTransactionDurability: 'default' \| 'strict' \| 'relaxed'                          | (since 3.2.0-beta.3) Override the default transaction durability in Chrome versions >=83. See [FR #1018](https://github.com/dexie/Dexie.js/issues/1018)                                                                                                                                                         |
| cache: 'cloned' \| 'immutable' \| 'disabled'                          | (since 4.0.1-alpha.17) Override the default caching behavior. Default is 'cloned' (dexie@>4 only) and allows optimistic updates to trigger liveQueries before transactions commit. 'immutable' also enables optimistic updates with some optimization - less cloning and less memory consumption but return values from read-operations from live queries are frozen. 'disabled' gives same behavior as dexie@3 with no cache or optimistic updates.                                                                                                                                              |

If the 'addons' option is omitted, it will default to the value of [Dexie.addons](/docs/Dexie/Dexie.addons).

### Return Value

[Dexie](/docs/Dexie/Dexie)

### Sample

```javascript
// Declare db instance
var db = new Dexie("MyDatabase");

// Define Database Schema
db.version(1).stores({
  friends: "++id, name, age, isCloseFriend",
  notes: "++id, title, date, *items",
});

// Interact With Database
db.transaction("rw", db.friends, db.notes, function* () {
  // Let's add some data to db:
  var friend1Id = yield db.friends.add({
    name: "Camilla",
    age: 25,
    isCloseFriend: 1,
  });
  var friend2Id = yield db.friends.add({
    name: "Ban Ki-moon",
    age: 70,
    isCloseFriend: 0,
  });

  var noteId = yield db.notes.add({
    title: "Shop tomorrow",
    date: new Date(),
    items: ["milk", "butter"],
  });

  // Let's query the db
  var closeFriends = yield db.friends
    .where("isCloseFriend")
    .equals(1)
    .toArray();

  console.log("Close friends:" + closeFriends.map((f) => f.name));

  var toShop = yield db.notes
    .where("title")
    .startsWithIgnoreCase("shop")
    .toArray();

  console.log("Shopping list: " + toShop.map((note) => note.items));
}).catch(function (err) {
  // Catch any error event or exception and log it:
  console.error(err.stack || err);
});
```

[Open sample in jsfiddle](https://fiddle.jshell.net/dfahlander/qmr9L6L8/)

### Sample: Open existing database 'as is'

```javascript
new Dexie("MyDatabase")
  .open()
  .then(function (db) {
    console.log("Found database: " + db.name);
    console.log("Database version: " + db.verno);
    db.tables.forEach(function (table) {
      console.log("Found table: " + table.name);
      console.log("Table Schema: " + JSON.stringify(table.schema, null, 4));
    });
  })
  .catch("NoSuchDatabaseError", function (e) {
    // Database with that name did not exist
    console.error("Database not found");
  })
  .catch(function (e) {
    console.error("Oh uh: " + e);
  });
```

[Open sample in jsfiddle](https://fiddle.jshell.net/dfahlander/b8Levamm/)

### Sample: Instantiate a Dexie with custom addon

```javascript

// Define the addon
function myForEachAddon(db) {
    db.Collection.prototype.forEach = function (callback) {
        // Make the forEach() method just an alias of the existing
        // each() method:
        return this.each(callback);
    });
}
// Register it (optional)
Dexie.addons.push(myForEachAddon);

// Use it:
var db = new Dexie('dbname');
db.version(1).stores({friends: 'name'});
db.transaction('rw', db.friends, function () {
    db.friends.clear();
    db.friends.bulkAdd([{name: "Foo"},{name: "Bar"}]);
}).then(function() {
    db.friends
      .where('name')
      .anyOfIgnoreCase('foo','bar')
      .forEach(friend => {
          console.log(friend.name);
      });
}).catch(ex => {
    console.error(ex);
});
```

How _options_ tells how to apply addons:

```javascript
// Open normally. Registered addons will be invoked automatically.
var db1 = new Dexie("dbname");

// Explicitly tell Dexie to ignore registered addons:
var db2 = new Dexie("dbname", { addons: [] });

// Explicitly tell Dexie to use just your set of addons:
var db3 = new Dexie("dbname", { addons: [myForEachAddon] });
```

### Methods

#### [version()](</docs/Dexie/Dexie.version()>)

Specify the database schema (object stores and indexes) for a certain version.

#### [on()](</docs/Dexie/Dexie.on()>)

Subscribe to events

#### [open()](</docs/Dexie/Dexie.open()>)

Open database and make it start functioning.

#### [table()](</docs/Dexie/Dexie.table()>)

Returns an object store to operate on

#### [transaction()](</docs/Dexie/Dexie.transaction()>)

Start a database transaction

#### [close()](</docs/Dexie/Dexie.close()>)

Close the database

#### [delete()](</docs/Dexie/Dexie.delete()>)

Delete the database

#### [isOpen()](</docs/Dexie/Dexie.isOpen()>)

Returns true if database is open.

#### [hasFailed()](</docs/Dexie/Dexie.hasFailed()>)

Returns true if database failed to open.

#### [backendDB()](</docs/Dexie/Dexie.backendDB()>)

Returns the native IDBDatabase instance.

#### [vip()](</docs/Dexie/Dexie.vip()>)

Enable on('ready') subscribers to use db before open() is complete.

### Properties

#### [name](/docs/Dexie/Dexie.name)

The database name.

#### [&#91;table&#93;](/docs/Dexie/Dexie.[table])

Each object store defined in [version().stores()](</docs/Version/Version.stores()>) gets a [Table](/docs/Table/Table) instance named by the object store.

#### [tables](/docs/Dexie/Dexie.tables)

Javascript Array containing all Table instances.

#### [verno](/docs/Dexie/Dexie.verno)

Version of current database

#### Static Methods

#### [Dexie.async()](</docs/Dexie/Dexie.async()>)

Declare an async function in today's modern browsers (2015) without the need for a transpiler.

#### [Dexie.spawn()](</docs/Dexie/Dexie.spawn()>)

Spawn an async function in today's modern browsers (2015) without the need for a transpiler.

#### [Dexie.delete()](</docs/Dexie/Dexie.delete()>)

Delete a database.

#### [Dexie.getDatabaseNames()](</docs/Dexie/Dexie.getDatabaseNames()>)

List all database names at current origin.

#### [Dexie.exists()](</docs/Dexie/Dexie.exists()>)

Detect whether a database with the given name exists.

#### [Dexie.getByKeyPath()](</docs/Dexie/Dexie.getByKeyPath()>)

Retrieve a property from an object given a key path.

#### [Dexie.setByKeyPath()](</docs/Dexie/Dexie.setByKeyPath()>)

Modify a property in an object given a key path and value.

#### [Dexie.delByKeyPath()](</docs/Dexie/Dexie.delByKeyPath()>)

Delete a property from an object given a key path.

#### [Dexie.shallowClone()](</docs/Dexie/Dexie.shallowClone()>)

Shallow clones an object.

#### [Dexie.deepClone()](</docs/Dexie/Dexie.deepClone()>)

Deep clones an object.

#### [Dexie.ignoreTransaction()](</docs/Dexie/Dexie.ignoreTransaction()>)

Create a a new scope where current transaction is ignored.

#### [Dexie.override()](</docs/Dexie/Dexie.override()>)

Override existing method and be able to call the original method.

#### [Dexie.defineClass()](</docs/Dexie/Dexie.defineClass()>)

Creates a function and populates its prototype with given structure.

#### [Dexie.derive()](</docs/Dexie/Dexie.derive()>)

Fixes the prototype chain for OOP inheritance.

#### [Dexie.extend()](</docs/Dexie/Dexie.extend()>)

Set given additional properties into given object.

#### [Dexie.Events()](</docs/Dexie/Dexie.events()>)

Create a set of events to subscribe to and fire.

### Static Properties

#### [addons](/docs/Dexie/Dexie.addons)

Array of extended constructors.

#### [debug](/docs/Dexie/Dexie.debug)

Get / set debug mode.

#### [semVer](/docs/Dexie/Dexie.semVer)

Contains the semantic version string from package.json.

#### [version](/docs/Dexie/Dexie.version)

Contains the version number of Dexie as a numeric comparable decimal value.

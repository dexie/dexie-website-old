---
layout: docs
title: 'Dexie.on.populate'
---

### Syntax

```ts
db.on("populate", (tx: Transaction) => {
  // Use provided transaction to populate database with initial data
  // tx.table('users').add({id: "me", name: "Me"});
});
```

### Description

The populate event occurs only once in a database' lifetime - in case the database was not present on the client when db.open() was called, and the object stores was needed to be created.

When upgrading database, on("populate") will NOT be called since it was already called before when database was created in the previous version. In case you change the code that subscribes to the populate event between versions, you should add an upgrade function to the new version that upgrades earlier populated data.

The populate event is fired during an onupgradeneeded event and before db.open() has been successfully committed. In case an exception is thrown or an error event happens during the populate event, the entire database creation will be aborted and db.open() will fail.

### Sample

```javascript
var db = new Dexie("MyDB");
db.version(1).stores({friends: "++id, name, gender"});
db.on("populate", function(transaction) {
    transaction.friends.add({name: "Josephina", gender: "unisex"});
});
db.open();
```

### Limitations

The transaction running when the populate event is firing is an upgrade transaction and as all IndexedDB transactions, it will commit as soon as you stop using it. This means that if you call other async APIs, such as ajax calls or setTimeout(), the transaction object will automatically commit and your database will finish opening. When you ajax request as arrives, you are not anymore within the upgrade transaction.

**NOTE: If the callback is an async function, make sure to use the provided transaction rather than the Dexie instance (see above sample). **

If your aim is to populate the database from an ajax- or other asynchronous request, the only bullet-proof way to do that is by using the on('ready') event rather than on('populate'). See a working (and fully tested) sample below:

#### Ajax Populate Sample

This sample shows how to populate your database from an ajax call. Note that on('populate') is not suitable for that and instead we are using on('ready'):

```javascript
    import Dexie from 'https://cdn.jsdelivr.net/npm/dexie@4.0.1/+esm';
    var db = new Dexie('someDB');
    // uncomment this to force the database to be reloaded
    // db.delete().then (()=>db.open()); 

    db.version(1).stores({
      productTable: "++id,price,brand,category"
    });
    db.on('ready', async vipDB => {
      const count = await vipDB.productTable.count();
      if (count > 0) {
        console.log(`productTable is already populated with ${count} rows`);
      } else {
        const data = await loadData();
        await vipDB.productTable.bulkAdd(data);
        console.warn(`populating productTable with ${data.length} rows`);
      }
    });

    db.open(); // open the database to trigger 'ready'

    // Following operation will be queued until we're finished populating data:
    db.productTable.each( (product) =>  {
      // When we come here, data is fully populated and we can log all objects.
      console.log("Found object: " + product.title);
    }).then(function () {
      console.log("Finished.");
    }).catch(function (error) {
      // In our each() callback above fails, OR db.open() fails due to any reason,
      // including our ajax call failed, this operation will fail and we will get
      // the error here!
      console.error(error.stack || error);
      // Note that we could also have caught it on db.open() but in this sample,
      // we show it here.
    });

    async function loadData() {
      let url = 'https://dummyjson.com/products?limit=3';
      const response = await fetch(url);
      return await response.json().then(data => data.products)
    }
```

Console Output on first run:
![image](https://github.com/dexie/dexie-website/assets/619585/4b929f62-9e7b-49a9-be5e-48684b66173c)

Console Output when data is already populated:

![image](https://github.com/dexie/dexie-website/assets/619585/2b5f3115-37c1-4887-88d3-63ed276e0f9c)

### See Also

[The Populate Event](/docs/Tutorial/Design#the-populate-event)

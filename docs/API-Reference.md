---
layout: docs
title: 'API Reference'
---

### Classes

* [Dexie](/docs/Dexie/Dexie)
* [DexieError](/docs/DexieErrors/DexieError)
* [Collection](/docs/Collection/Collection)
* [IndexSpec](/docs/IndexSpec)
* [Promise](/docs/Promise/Promise)
* [Table](/docs/Table/Table)
* [TableSchema](/docs/TableSchema)
* [Transaction](/docs/Transaction/Transaction)
* [Version](/docs/Version/Version)
* [WhereClause](/docs/WhereClause/WhereClause)

### [Cheat Sheet](#quick-reference)

### Operators & filters

* [WhereClause](/docs/WhereClause/WhereClause)
* [Collection](/docs/Collection/Collection)

### Addons, Adapters and Derived Work

[Derived Work](/docs/DerivedWork)

### Typescript

[Using Dexie with Typescript](/docs/Typescript)

### Knowledge Base
[Questions and Answers](/docs/Questions-and-Answers)

# Quick Reference 

#### Declare Database

```javascript
var db = new Dexie("MyDatabase");
db.version(1).stores({
    friends: "++id, name, age, *tags",
    gameSessions: "id, score"
});

```
**NOTE: Don't declare all columns like in SQL. You only declare properties you want to index, that is properties you want to use in a where(...) query.**



#### Schema Syntax

<table>
<tr><td>++</td><td>Auto-incremented primary key</td></tr>
<tr><td>&amp;</td><td>Unique</td></tr>
<tr><td>*</td><td><a href="/docs/MultiEntry-Index">Multi-entry</a> index</td></tr>
<tr><td>[A+B]</td><td><a href="/docs/Compound-Index">Compound index</a></td></tr>
</table>

[Complete Syntax Documentation](/docs/Version/Version.stores())

#### Upgrade

```javascript
db.version(1).stores({
    friends: "++id,name,age,*tags",
    gameSessions: "id,score"
});

db.version(2).stores({
    friends: "++id, [firstName+lastName], yearOfBirth, *tags", // Change indexes
    gameSessions: null // Delete table

}).upgrade(tx => {
    // Will only be executed if a version below 2 was installed.
    return tx.table("friends").update(friend => {
        friend.firstName = friend.name.split(' ')[0];
        friend.lastName = friend.name.split(' ')[1];
        friend.birthDate = new Date(new Date().getFullYear() - friend.age, 0);
        delete friend.name;
        delete friend.age;
    });
});
```
[Read more about database versioning](/docs/Tutorial/Design#database-versioning)

#### Class Binding
```javascript
class Friend {
    // Prototype method
    save() {
        return db.friends.put(this); // Will only save own props.
    }

    // Prototype property
    get age() {
        return moment(Date.now()).diff (this.birthDate, 'years');
    }
}

db.friends.mapToClass(Friend);

```
Reference: [Table.mapToClass()](/docs/Table/Table.mapToClass())

#### Add Items

```javascript
await db.friends.add({name: "Josephine", age: 21});
```

```javascript
await db.friends.bulkAdd([
  {name: "Foo", age: 31},
  {name: "Bar", age: 32}
]);
```

*Reference: [Table.add()](/docs/Table/Table.add()) [Table.bulkAdd()](/docs/Table/Table.bulkAdd())*


#### Update Items

```javascript
await db.friends.put({id: 4, name: "Foo", age: 33});
```

```javascript
await db.friends.bulkPut([
    {id: 4, name: "Foo2", age: 34},
    {id: 5, name: "Bar2", age: 44}
]);
```

```javascript
await db.friends.update(4, {name: "Bar"});
```

```javascript
await db.customers
    .where("age")
    .inAnyRange([ [0, 18], [65, Infinity] ])
    .modify({discount: 0.5});
```

*Reference: [Table.put()](/docs/Table/Table.put()), [Table.bulkPut()](/docs/Table/Table.bulkPut()), [Table.update()](/docs/Table/Table.update()), [Collection.modify()](/docs/Collection/Collection.modify())*


#### Delete items

```javascript
await db.friends.delete(4);
```

```javascript
await db.friends.bulkDelete([1,2,4]);
```

```javascript

const oneWeekAgo = new Date(Date.now() - 60*60*1000*24*7);

await db.logEntries
    .where('timestamp').below(oneWeekAgo)
    .delete();
```

*Reference: [Table.delete()](/docs/Table/Table.delete()), [Table.bulkDelete()](/docs/Table/Table.bulkDelete()), [Collection.delete()](/docs/Collection/Collection.delete())*


#### Query Items
```javascript
const someFriends = await db.friends
    .where("age").between(20, 25)
    .offset(150).limit(25)
    .toArray();
```

```javascript
await db.friends
    .where("name").equalsIgnoreCase("josephine")
    .each(friend => {
        console.log("Found Josephine", friend);
    });
```

```javascript
const abcFriends = await db.friends
    .where("name")
    .startsWithAnyOfIgnoreCase(["a", "b", "c"])
    .toArray();
```

*References: [Table.where()](/docs/Table/Table.where()), [WhereClause](/docs/WhereClause/WhereClause), [Collection](/docs/Collection/Collection)*

```javascript
await db.friends
    .where('age')
    .inAnyRange([[0,18], [65, Infinity]])
    .modify({discount: 0.5});
```

*References: [Table.where()](/docs/Table/Table.where()), [WhereClause](/docs/WhereClause/WhereClause), [Collection.modify()](/docs/Collection/Collection.modify())*

```javascript
const friendsContainingLetterA = await db.friends
    .filter(friend => /a/i.test(friend.name))
    .toArray();
```
*Reference: [Table.filter()](/docs/Table/Table.filter())*

```javascript
const forbundsKansler = await db.friends
    .where('[firstName+lastName]')
    .equals(["Angela", "Merkel"])
    .first();
```
[Read more about compound index](/docs/Compound-Index)

In Dexie 2.0, you could do the above query a little simpler:

```javascript
const forbundsKansler = await db.friends.where({
    firstName: "Angela",
    lastName: "Merkel"
}).first();
```
Or simply:
```javascript
const forbundsKansler = await db.friends.get({
    firstName: "Angela",
    lastName: "Merkel"
});
```

```javascript
// This query is equal to:
//   select * from friends where firstName='Angela' order by lastName
const angelasSortedByLastName = await db.friends
    .where('[firstName+lastName]')
    .between([["Angela", ""], ["Angela", "\uffff"])
    .toArray()
```

```javascript
await db.friends
    .where('age').above(25)
    .or('shoeSize').below(8)
    .or('interests').anyOf('sports', 'pets', 'cars')
    .modify(friend => friend.tags.push("marketing-target"));
```

*Reference: [Collection.or()](/docs/Collection/Collection.or())*

#### Retrieve TOP 5 items

```javascript
const best5GameSession = await db.gameSessions
    .orderBy("score").reverse()
    .limit(5)
    .toArray();
```
References: [Table.orderBy()](/docs/Table/Table.orderBy()), [Collection.reverse()](/docs/Collection/Collection.reverse()), [Collection.limit()](/docs/Collection/Collection.limit())

#### Joining
```javascript
var db = new Dexie('music');
db.version(1).stores({
    genres: '++id,name',
    albums: '++id,name,year,*tracks',
    bands: '++id,name,*albumIds,genreId'
});

async function getBandsStartingWithA () {
    // Query
    const bands = await db.bands
        .where('name')
        .startsWith('A')
        .toArray();
    
    // Attach resolved properies "genre" and "albums" on each band
    // using parallel queries:
    await Promise.all (bands.map (async band => {
      [band.genre, band.albums] = await Promise.all([
        db.genres.get (band.genreId),
        db.albums.where('id').anyOf(band.albumIds).toArray()
      ]);
    }));
    
    return bands;
}
```

#### Storing Binary Data

```javascript
var db = new Dexie("MyImgDb");
db.version(1).stores({
    friends: "name"
});

// Download and store an image
async function downloadAndStoreImage() {
    const res = await fetch("some-url-to-an-image.png");
    const blob = await res.blob();
    // Store the binary data in indexedDB:
    await db.friends.put({
        name: "David",
        image: blob
    });
}

```

#### Indexing Binary Data (IndexedDB 2.0)
IndexedDB 2.0 contains support for indexing binary data. This spec is supported by Chrome and Safari
and partially Firefox (Firefox has a bug when using binary primary key, but works well with binary index).

```javascript
var db = new Dexie("MyImgDb");
db.version(1).stores({
    friends: "id, name" // use binary UUID as id
});

// IndexedDB 2.0 allows indexing ArrayBuffer and XXXArray
// (typed arrays) (but not Blobs)
async function playWithBinaryPrimKey() {
    // Store the binary data in indexedDB:
    await db.friends.put({
        id: new Uint8Array([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]),
        name: "David"
    });

    // Retrieve by binary search
    const friend = await db.friends.get(
        new Uint8Array([1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16]));

    if (friend) {
        console.log(`Found friend: ${friend.name}`);
    } else {
        console.log(`Friend not found`);
    }
}

```

#### Transaction

```javascript

await db.transaction('rw', [db.friends], async () => {
  const friend = await db.friends.get(1);
  ++friend.age;
  await db.friends.put(friend);
});

```

#### Ongoing Transaction

```javascript
const db = new Dexie("MyImgDb");

db.version(1).stores({
    friends: "id, name, *tags"
});

function goodFriends() {
    return db.friends
        .where('tags')
        .equals('close-friend');
}

async function addComment(friendId, comment) {
    await db.friends
        .where('id')
        .equals(friendId)
        .modify(friend => {
            friend.comments.push(comment);
        });
}

async function spreadYourLove() {
    // Make an atomic change:
    await db.transaction('rw', db.friends, async () => {
        const goodFriendKeys = await goodFriends().primaryKeys();
        await Promise.all(
            goodFriendKeys.map(id => addComment(id, "I like you!"))
        );
    });
}

```

*The above code snippet shows that you can reuse "transactionless" code (function goodFriends() and addComment()) but execute it within a transaction (spreadYourLove()).*

Reference: [Dexie.transaction()](/docs/Dexie/Dexie.transaction())

#### Parent Transaction

```javascript
// Make one large atomic change that calls other
// functions that already use a transaction.
db.transaction('rw', db.friends, db.diary, async () => {
    await spreadYourLove();
    await db.diary.log({date: Date.now(), text: "Today I successfully spread my love"});
}).catch (err => {
    console.error ("I failed to spread my love :( " + err.stack);
});

```

*The above snippet shows that you can also reuse code that is indeed transaction-aware, but encapsulate several such functions in an overall umbrella-transaction.*

**NOTE: The code above may look like it could only execute this transaction one-at-a-time, but with thanks to [zone](/docs/Promise/Promise.PSD) technology, this code can work in parallel with other transactions. (Dexie implements its own zone system and is not dependent on zone.js)**

Reference: [Dexie.transaction()](/docs/Dexie/Dexie.transaction())

#### Working with Asynchronic APIs

Dexie.js is an asynchronic API. In synchronic APIs, errors are normally handled using exceptions. This is very convenient because you code on without doing error checking everywhere and instead catch exceptions on a higher level. Asynchronic APIs normally use success- and error events to signal back when operation complete. Since indexedDB uses a combination of exceptions and error events to notify the caller, it is quite cumbersome to code against it using correct error handling - you need both to do try..catch and request.onerror for each and every request. Dexie.js solves this by working with ECMAScript6 compliant [Promises](http://www.html5rocks.com/en/tutorials/es6/promises/) making error handling as easy as it is on a synchronous API with try..catch error handling.

#### Working with Promises
Promise based APIs (such as Dexie.js) will look more like synchronous APIs than event based APIs, but instead of returning the result, it will return an instance of [Promise](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/Promise). ECMAScript6 promises has two methods: [then()](/docs/Promise/Promise.then) and [catch()](/docs/Promise/Promise.catch). These methods expects a callback to call when the operation succeeds or fails respectively. All asynchronic methods in Dexie returns a Promise instance and this makes the API way more easy to use, as you will see in our examples.

#### Promise-Specific Data (zone)
Dexie Promises supports a pattern similar to [Thread-local storage](http://en.wikipedia.org/wiki/Thread-local_storage) where it is possible to have static properties that is bound to the executing promise and all it's child-promises. This is similar Angular's [zone.js](https://github.com/angular/zone.js/) but in an unobtrusive way (no requirement of including any monkey-patching script). Dexie.js and it's transaction API heavily depends on it's transaction zones since it enables code to be aware of the currently executing transaction without having to pass transaction objects around. [Promise-Specific Data doc](/docs/Promise/Promise.PSD).

#### Exception Handling

With Dexie, in contrary to indexedDB, there is one single way to catch exceptions - through the Promise.catch() method. Nowhere do you need to do a standard try..catch(). The reason for this is to not enforce the caller to need to think about several ways of error handling. When you work with transactions, you will also get the benefit of being able to catch all errors in one single place - at the end of the transaction, instead of having to catch() every promise of each database operation. Any uncaught error (no matter error events, exception or miss-spelled variable in your code) will abort the ongoing [Transaction](/docs/Transaction/Transaction) and trigger its returned [Promise](/docs/Promise/Promise) to reject, waking up any catch() clause attached to the transaction scope.

```javascript
db.transaction('rw', db.friends, function() {

    ...

    window.MissSpelledVar.NonExistingVar = 3; // Will fail!

}).catch (function (err) {

    // Transaction will abort!
    console.error(err);

});
```

All transaction promises should either be caught or returned to its caller.

#### Catching means Handling!
If you catch a Promise from a database operation within a transaction, it will be considered to be handled and the transaction will not be aborted. This could be a common pitfall when people catch promises within transactions just to log  it but expecting the transaction to abort. Solution: re-throw the errors that you don't handle!

```javascript
db.transaction('rw', db.friends, function() {

    db.friends.add({id: 1, name: "Foo"}).catch(function(e) {
        console.error("Failed to add Foo friend");
        throw e; // Rethrow to abort transaction.
    });

})
```

#### Working With Transactions

Whenever you want to do more than a single operation, you simplify your code by using transactions. By working with transactions, you get the following benefits:
* If modifying database and any error occur - error event or exception of any kind - then transaction will abort and every modification will be rolled back.
* No need to handle promises if you don't like. Everything is encapsulated in the transaction so you can handle that instead.
* You may do all write operations synchronically without the need to wait for it to finish before starting the next one. (see the 2nd example code below).
* Even read-operations can be done the line after a write operations without waiting for write to finish - still your result will include all modifications. This is possible because all operations are queued when there is a pending write operation going on in current transaction.
* Not a single error will just slip away - you catch all in the final catch() method - both error events and ordinary exceptions of any kind.

Here is how you enter a transaction block:

```javascript
db.transaction('rw', db.friends, db.pets, function () {
    // Any database error event that occur will abort transaction and
    // be sent to the catch() method below.
    // The exact same rule if any exception is thrown what so ever.

    return db.pets.add({name: 'Bamse', kind: 'cat'}).then(function (petId) {
        return db.friends.add({name: 'Kate', age: 89, pets: [petId]});
    });

}).catch(function (error) {
    // Log or display the error

    console.error (error.stack || error);

});
```
Notes:
* 'friends' and 'pets' are objectStores registered using [Version.stores()](/docs/Version/Version.stores()) method.
* `"rw"` should be replaced with `"r"` if you are just going to do read operations.
* Also errors from chained database operations within the transaction, or plain exceptions happening in any then() callback of any chained operation will be caught by the transaction's catch() method.
* It is possible to prohibit the transaction from being aborted if a failing DB operation is caught explicitly:

```javascript
db.transaction('rw', db.friends, function() {
    db.friends.add({id:1, name:"Fredrik"});
    db.friends.add({id:1, name:"Fredrik"}).catch(function (err) {
        // Adding same primary key twice will of course fail. But
        // since we catch this error explicitly, the transaction
        // wont abort. This makes it possible to continue the
        // transaction in a managed way. If you still want to abort
        // the transaction, just do Dexie.currentTransaction.abort(),
        // throw an exception, or just:
        // return Promise.reject(err);
    });
}).then (function () {
    alert ("Transaction successfully completed");
});
```

When working with transactions, you may query a recent add(), put(), update(), delete() or modify() operation on the next line without waiting for it to finish. The waiting is taken care of by the framework. See the difference below on how that may simplify your code to work with a transaction and not having to call .then() all the time.

##### Code Example Without Transaction
```javascript
db.friends.add({ name: "Ulla Bella", age: 87, isCloseFriend: 0 }).then(function () {

    return db.friends.add({ name: "Elna", age: 99, isCloseFriend: 1 });

}).then(function (){

    return db.friends.where("age").above(65).each(function (friend) {
        console.log("Retired friend: " + friend.name);
    });

}).catch(function (error) {

    console.error(error);

})
```

##### Same Code Example With Transaction
```javascript
db.transaction("rw", db.friends, function () {

    db.friends.add({ name: "Ulla Bella", age: 87, isCloseFriend: 0 });
    db.friends.add({ name: "Elna", age: 99, isCloseFriend: 1 });
    db.friends.where("age").above(65).each(function (friend) {
        console.log("Retired friend: " + friend.name);
    });

}).catch(function (error) {

    console.error(error);

});
```

The sample above shows that there's no need to wait for the add() operations to finish when working within the same transaction.

#### The Auto-Commit Behavior of IndexedDB Transactions

IndexedDB will commit a transaction as soon as it isn't used within the same task. This means that you MUST NOT call any other async API (at least not wait for it to finish) within a transaction scope. If you do, you will get a TransactionInactiveError thrown at you as soon as you try to continue using the transaction. This cannot be worked around by encapsulating the call with Dexie.Promise since it is a behaviour of IndexedDB.

*News in Dexie 2.0.0-beta.6: You can now wait for other async APIs and still hold the transaction active, using [Dexie.waitFor()](/docs/Dexie/Dexie.waitFor())*

#### Nested IndexedDB Transactions

Since version 0.9.8, Dexie supports nested transactions:

```javascript
db.transaction('rw', db.friends, db.pets, function () {
    // MAIN transaction block
    db.transaction('rw', db.pets, function () {
       // SUB transaction block
    });
});
```

The power with nested transactions is that functions that use a transaction can be reused by higher-level code that surrounds all of its calls into a bigger transaction.

See also [Dexie.transaction()](/docs/Dexie/Dexie.transaction()) for more information on how to use transactions.

---
layout: docs-dexie-cloud
title: 'Dexie Cloud Best Practices'
---

To maintain consistency across distributed data, there are a number of best practices to consider. This page takes you through the practices to adopt when using Dexie Cloud.

### Primary Keys

☞ Don't use auto-incremented keys (`++id`). Use `@id` (auto-generated) or just `id`, providing own strings with entropy enough for global uniqueness, such as GUIDs. See [examples](#examples-primary-keys).

☞ Primary key column must be string unless the primary key is a compound primary key, in which case it will be an array of strings or numbers.

☞ Primary keys on `@`-tables must be prefixed with a dedicated 3-letter defined in [db.cloud.schema[tableName]](/cloud/docs/db.cloud.schema). This rule does only apply in auto-generated primary keys (declared as `@<primary key field>` ) See [db.cloud.schema](/cloud/docs/db.cloud.schema)

☞ For [compound primary keys](/docs/Compound-Index#compound-primary-key), they need to be composed from string columns only, or a combination of string and number columns and their composition must have entropy enough to be globally unique. See [examples](#examples-primary-keys)

☞ If one row has a 1-1 relationship with another row in the same or different table, it is wise to generate its ID from the computation of the other ID in order to allow consistent deletion of related rows (see example later down...). See [examples](#examples-primary-keys)

☞ Never change the primary keys of a table. If you need to migrate, create another table and migrate the data using [REST](rest-api) or [cli export](cli#export) / [import](cli#import).

### Migration

☞ Don't use [Version.upgrade()](</docs/Version/Version.upgrade()>) except for non-synced tables. Migrations can never be consistently performed at the client side when table is synced. See [examples](#examples-migration)

☞ Don't populate data in [Dexie.on.populate](/docs/Dexie/Dexie.on.populate). You can use the `populate` event but only to register the [ready](/docs/Dexie/Dexie.on.ready) event and perform it from there. See [examples](#examples-migration)

☞ Only populate [private singletons](consistency#private-singleton-ids). This prohibits the data from being populated several times for the same account. See [examples](#examples-migration)

### Consistent Operations

☞ Declare transaction block when multiple operations should be bundled into an atomic all-or-nothing operation in the cloud.

☞ To get full consistency, avoid reading + JS condition + writing. Instead formulate the condition in a where-clause with a modify expression attached to it. This will persist the condition on the cloud and reexecute it on sync. See [examples](#examples-consistent-operations)

<br>
<br>

# Examples

## Examples: Primary Keys

### Example 1: Let dexie-cloud-addon generate primary keys:

```ts
db.version(1).stores({
  items: '@id',
})

async function doSomething() {
  // No need to specify the key here, just the other properties:
  const id = await db.items.add({ foo: bar })
  // id will be something like 'itm0OroMWmdWtMgzS5Udb2dfysp'

  // Now let's fetch the added item back from the local DB and see what we've got there:
  const item = await db.items.get(id)

  // item will be something like:
  // {
  //   id: "itm0OroMWmdWtMgzS5Udb2dfysp",
  //   foo: "bar",
  //   owner: "you@domain.com",
  //   realmId: "you@domain.com"
  // }
}
```

When using `@`, the keys will start with 3 letters representing a shortening of the table name ('itm' for 'items', 'frn' for 'friends' etc). The prefix of the ID reveals which table it belongs to. @-tables will encforce that policy and never accept keys that do not start with this 3-letter shorteing of the table name. Even if the table would be renamed later, the 3-letter shortening will stay the same throughout the database lifetime.

### Example 2: Generate your own random strings

```ts
db.version(1).stores({
  items: 'id', // No need to prefix id with @ if it's not auto-generated
})

async function doSomething() {
  // No need to specify the key here, just the other properties:
  const id = generateRandomString() // Generate a unique string, such as a GUID.
  await db.items.add({ foo: bar, id }) // Provide ID explicitely.
  const item = await db.items.get(id)
  // item will be something like:
  // {
  //   id: "ed3a25c3-9f08-4b5e-879d-d6ca8cc371ea",
  //   foo: "bar",
  //   owner: "you@domain.com",
  //   realmId: "you@domain.com"
  // }
}
```

### Example 3: Compute ID from other ID (1-1 relationships)

```ts
function shareTodoList(todoList) {
  // When making a todo-list sharable, we need to create a realm that is 1-1 tied to the todo-list:
  const computedRealmId = getTiedRealmId(todoList.id)
  return db.transaction('rw', db.todoLists, db.realms, db.members, () => {
    db.realms.upsert(
      computedRealmId, // Use a primary key computed from the main object in the realm.
      {
        name: todoList.name,
        represents: 'a to-do list',
      }
    )
    db.todoLists.update(todoList.id, {
      realmId: computedRealmId, // move todo-list into new realm
    })
    db.todoItems
      .where({ todoListId: todoList.id })
      .modify({ realmId: computedRealmId }) // move its items into realm as well
  })
}

// Delete it with 100% consistency (no matter if has been shared or not)
function deleteTodoList(todoListId) {
  return db.transaction('rw', db.todoLists, db.realms, db.todoItems, () => {
    // Delete related todo-items
    db.todoItems.where({ todoListId: todoListId }).delete()
    // Delete the list
    db.todoLists.delete(todoListId)
    // In case it has been shared (maybe by another off-line client),
    // delete any corresponding realm.
    // (Don't delete members to avoid 'sawing off your own branch'.
    //  instead members will be cascade deleted by the server and your local
    //  members will be deleted on next sync)
    const computedRealmId = getTiedRealmId(todoList.id)
    db.realms.delete(computedRealmId)
  })
}
```

The above sample shows the purpose of using a computed ID - as deletions can be done consistently for 1-1 related entities. In the sample above we're using `getTiedRealmId()` from dexie-cloud-addon but you can also use any custom way to compute an ID from another ID. If the id is declared with `@`, just make sure the primary key will be prefixed with 3-letter shortname of the table, available in [db.cloud.schema[tableName]](/cloud/docs/db.cloud.schema).

### Example 4: Compose primary keys from referred keys and other properties:

```ts
db.version(1).stores({
  friends: '@id',
  friendRelations: '[friend1Id+friend2Id+label]', // unique because referred to unique ids
})

function createTwoLovingFriends() {
  return db.transaction('rw', db.friends, db.friendRelations, async () => {
    const aliceId = await db.friends.add({ name: 'Alice' })
    const bobId = await db.friends.add({ name: 'Bob' })
    await db.friendRelations.add({
      friend1Id: aliceId,
      label: 'loves',
      friend2Id: bobId,
    })
  })
}
```

## Examples: Migration

Migrating synced data can be a complex task as data might be shared between clients with different versions of the data. Some clients might have pending changes based on the older model.

Dexie's ordinary upgrading framework operates on local data only and before the dexie-cloud-addon has been invoked to setup its required data.

For these reasons, a Dexie Cloud app need to be written to avoid migrations. Should a migration be needed anyway, the recommendation is currently to create a new database and manually migrate the data using [npx dexie-cloud export](/cloud/docs/cli#export), migrate it off-line and then import it to the new database using [npx dexie-cloud import](/cloud/docs/cli#import).

### Ad-hoc Migration

There are patterns to avoid migrations by letting your app continue to support the old and new model and migrating data ad-hoc. This is not a perfect nor fully consistent solution, but the best alternative to full migration.

If taking the example of having a table of friends with name and age, and in the new version, split the name in firstName and lastName:

```ts
function migrateFriend(friend: Friend) {
  if (!('name' in friend) && 'firstName' in friend) {
    // Already migrated
    return friend
  } else {
    // Return migrated instance for your app to render:
    const nameSplit = friend.name.split(' ')
    Object.assign(friendClone, friend)
    delete friendClone.name
    friendClone.firstName = nameSplit[0]
    friendClone.lastName = nameSplit.slice(1).join(' ')
    return friendClone
  }
}

db.friends.hook('reading', migrateFriend) // Let all queries that return friends go through the migrator
```

Notice however that queries such as `db.friends.where({firstName: 'foo'}).toArray()` won't match the non-migrated entities so queries might need to be adjusted to support both models.

### Migrating by exporting and importing

1. Export the database

   ```
   npx dexie-cloud export current-database.json
   ```

2. Write a node script that migrates the JSON file and produces a new file

   ```
   node migrationScript.js < current-database.json > upgraded-database.json
   ```

3. Import the new file to another database
   ```
   npx dexie-cloud import upgraded-database.json
   ```

### Populate private singletons

Populating data on DB creation can result in multiple objects being added for the same user in case the user later on open the app on another device and logs in, or if the user logs out and logs in. To avoid this, use a private ID and use [Table.put()](</docs/Table/Table.put()>) rather than [Table.add()](</docs/Table/Table.add()>). These data entities will work the same no matter if user is logged in or not and will be persisted in the cloud once user has logged in. If user goes to a new device these entities will be overwritten but no additional items would be created.

Private singletons are persisted on the cloud database just like normal objects but their primary key lives within a private namespace and cannot collide with other user's.

```ts
import { Dexie } from 'dexie'
import dexieCloud from 'dexie-cloud-addon'

const db = new Dexie('myDB', { addons: [dexieCloud] })
db.version(1).stores({
  myReadingLists: 'id',
})
db.on.populate.subscribe(() => {
  // In on.populate() don't use the DB directly because dexie-cloud-addon hasn't yet been
  // initialized. Instead subscribe for db.on.ready here and populate the data from there.
  db.on.ready.subscribe((db) => {
    // Create default placeholders for each user
    db.myReadingLists.put({
      id: '#favourites', // # = Private ID
      name: 'My favourites',
    })
  })
})
```

## Examples: Consistent Operations

By using [Collection.modify()](</docs/Collection/Collection.modify()>) and [Collection.delete()](</docs/Collection/Collection.delete()>) the where-conditions are propagated all the way to the server and re-executed on sync. By formulating the condition in the same expression that has the `.modify()` or `.delete()` call, the condition is preserved on the server and maintains the operation consistently. See also [Consistency in Dexie Cloud](/cloud/docs/consistency#consistent-modify--and-delete-operations).

### Avoid this

```ts
function deleteTodoList(todoListId) {
  return db.transaction('rw', db.todoLists, db.todoItems, async () => {
    const itemIds = await db.todoItems
      .where({ todoListId: todoListId })
      .primaryKeys()
    await db.todoItems.bulkDelete(itemIds)
    await db.todoLists.delete(todoListId)
  })
}
```

The example above will retrieve the primary keys of the items to delete as they were at the time on the client. This might not be true in case the client is offline. Even if the client is online, there might be other offline clients that has added items to the list and hasn't yet synced it. In both of these cases some items might be forgotten and left in the database pointing to a non-existing todoListId.

### Do this instead

```ts
function deleteTodoList(todoListId) {
  return db.transaction('rw', db.todoLists, db.todoItems, () => {
    db.todoItems.where({ todoListId: todoListId }).delete()
    db.todoLists.delete(todoListId)
  })
}
```

This example formulates the condition of the deletion in a where-clause. The condition is persisted on the cloud and re-executed in case the data has changed from what it was on the client when it performed the operation. Any added todoItem will also be deleted. Also, if another offline client would add items to that list and sync later on, some time after we made our sync, the persisted where-clause will be applied onto the other client's added items (because the server sees that the other client's data was based on a snapshot before we did our sync). Thus the added items from that client won't be added and the other client would instead get their local data updated and all these items deleted along with the list in its sync response.

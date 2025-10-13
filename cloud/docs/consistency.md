---
layout: docs-dexie-cloud
title: 'Consistency in Dexie Cloud'
---

This page describes the concepts that Dexie Cloud use in order to guarantee consistency in the synchronized offline-first database. Offline clients may share the same subset of data - and perform operations that may yield one direct result on the offline database, but would have yielded another result after a sync where updated data from another client would make the original operation yield another result. Consistent add-, modify-, put- and delete operations are core concepts of Dexie Cloud and makes sure to not just sync individual objects but also the conditions used in the operations, so that the same operations can be re-executed on updated data to guarantee the same consistency at all times.

If you are new to Dexie Cloud, please visit the [Dexie Cloud landing page](/cloud/).

If you prefer to jump right in to samples, here some shortcuts:

- [Consistently delete own access to a todo-list](https://github.com/dexie/Dexie.js/blob/v4.0.0-alpha.3/samples/dexie-cloud-todo-app/src/db/TodoList.ts#L144-L149)
- [Consistently delete a shared todo-list along with its todo items](https://github.com/dexie/Dexie.js/blob/v4.0.0-alpha.3/samples/dexie-cloud-todo-app/src/db/TodoList.ts#L151-L172)
- [Consistently detect whether a todo-list is shared or not](https://github.com/dexie/Dexie.js/blob/v4.0.0-alpha.3/samples/dexie-cloud-todo-app/src/db/TodoList.ts#L30-L32)
- [Consistently make a todo-list sharable and create a realm for its sharing](https://github.com/dexie/Dexie.js/blob/v4.0.0-alpha.3/samples/dexie-cloud-todo-app/src/db/TodoList.ts#L38-L72)

# Introduction

It can be a challenge to keep consistency in synced offline-first applications. You are working with data that is being copied across multiple devices - some of which might be offline while you perform an operation. Or you might be offline while you perform an operation that needs to be performed in a way that keeps the data 100% consistent at any point in time - and will be kept consistent after next sync - no matter what operations that have taken place by other users.

Dexie Cloud uses a combination of concepts that the application programmer can utilize in order to keep the data totally consistent at all times.

# Designing a Consistency-friendly model

If you work with Dexie Cloud, it is important to avoid storing objects in array properties if the array needs to be manipulated frequently by multiple clients. It is much better to use a relational model and let every type map to a table, and let collections belonging to an entity be represented in as its own database object, with its own ID and with a reference-property acting as a foreign key to the owning object (a traditional one-to-many relationship in relational databases). Many-to-many relations are best represented using an [associative entity](https://en.wikipedia.org/wiki/Associative_entity) for the same reason. By using a relational approach, these collections may be managed in a consistent manner also by offline clients and conflicts can be avoided using consistent modify- and delete operations as described later on this page.

# Consistency Concepts in Dexie Cloud

The concepts being used in Dexie Cloud to keep data consistent, are:

- Globally Unique IDs
- Atomic Transactions
- Canonical Server Data Snapshot
- Consistent Modify- and Delete Operations
- Consistently add or remove unique entries to sets of strings or numbers
- Consistent addition / subtraction
- Consistent hierarchial tree structures
- Tied Realms
- Update Operations
- Private Singleton IDs

## Globally Unique IDs

In contrast to auto-incremented numbers or short strings, globally unique IDs have the constraint that it virtually impossible to that two generated IDs are equal. That constraint make them avoid any conflict for add (insert) operations that occurs on different offline clients.

```
CLIENT A adds object with ID "AaIHn9smowhaFixqlcb7C4u"
CLIENT B adds object with ID "BbIXypXaau8MefAQPb77ivL"
CLIENT A syncs with server --> "AaIHn9smowhaFixqlcb7C4u" is inserted on server
CLIENT B syncs with server --> "BbIXypXaau8MefAQPb77ivL" is inserted on server. "AaIHn9smowhaFixqlcb7C4u" is retrieved back to CLIENT B.
CLIENT A pulls from server --> "BbIXypXaau8MefAQPb77ivL" is retrieved back to CLIENT A.
```

Note however, that [associative entities](https://en.wikipedia.org/wiki/Associative_entity) shall not have their own global ID but instead build up its primary key using the combination of the keys it refer to, using a [compound primary key](/docs/Compound-Index#compound-primary-key).

## Atomic Transactions

Any Dexie transaction will be regarded as an atomic all-or-nothing operation when it syncs to the cloud. If any of the involving operations fail to execute on the server for authorization reasons or any other reason, to other operations of the transaction be applied either and the server will send back a list of resulting operations that will make the client roll-back the operation.

## Canonical Server Data Snapshot

The protocol used when syncing between Dexie Cloud client and server assures that in the end of the sync, the client will have an identical snapshot of the data on the server (but just a subset of the database according to user's realm memberships). The algorithm for this can be described as so:

1. Client sends all mutated objects along with their primary keys. Client also provides a revision pointing out the server data snapshot from the last sync. The logical outcome of this, is that all non-provided keys are for sure unchanged.
2. Operations are executed on the server data
3. When done, server should virtually send back the entire data snapshot to assure the canonical server data snapshot at this point. However, since we know what keys the client has changed, and what keys the server has changed, we know that these objects and only these objects needs to be sent back to the client in order to fulfill this promise.
4. Before sending back all objects that have been changed by the server or client, the server will first further compute which parts of the objects (properties) that will actually have to be sent back - ignoring all properties that would be the same value anyway.

## Consistent Modify- and Delete Operations

Dexie Cloud can guarantee consistency within a graph of related entities so that two offline clients manipulating it in various ways end up in a consistent state that comply with the where-clause of the modify or delete operation.

If [Collection.modify()](</docs/Collection/Collection.modify()>) or [Collection.delete()](</docs/Collection/Collection.delete()>) is used on a collection filtered by a certain where-expression, the expression will be a part of the operation and be re-executed on the server snapshot to ensure consistency of the intension of the operation.

For example, let's say you want to modify all ToDo-items within a certain Todo-list to `{done: true}`:

```ts
await db.todoItems.where({ todoListId: todoListId }).modify({ done: true })
```

The intension here is to set all todo-items to done for the entire list. The intension is articulated using a where-clause and we'll describe below how this intention will affect the sync operation to maintain the intended consistency.

### Offline consistency

Given our previous operation to set all todoItems' `done` to `true` for a certain todoList; what if you were offline when you made the operation, and your client is not aware of some additional todo-items that has been added during your offline period? When the sync takes place, the where-expression will execute on the server data and if other items had been added to the list, they will also be updated. And items that had been removed from the list would not be affected by the operation (a roll-back will happen for these as if they were never affected by the operation).

Example:

1.  You commit the transaction locally while offline. It affects Todo-item A, B and C (which is the current items in the list on your offline copy and on the server as well).
2.  Another online client adds a new Todo-item D to the list and removes Todo-item A. It syncs the operation eagerly, so now the server has a list with items B, C and D.
3.  Your client goes online and syncs the operation.
4.  Server adjust your operation according to changes made after your last sync. It only applies the operation on Todo-items B, C and D but not on A.
5.  Server sends back a list of operations that will make the client roll-back Todo-item A with to how it is on the server, as if the operation had not affected Todo-item A. The list of operations also contains an add-operation for Todo-item D with `{done: true}` because of the operation has affected Todo-item D due to the where-clause of the operation.

### Consistency Guarantee for Future Syncs

Another more advanced trait of this consistency guarantee is the case when there is another client (else than yours) that also mutates its local database in a way that would affect the result of executing your where-clause on the objects they mutate in their operation while being offline. Dexie Cloud guarantees that when that client comes online eventually and syncs, it will have your operation applied consistently onto their not-yet-synced operations, the final outcome of their sync call will stay consistent. For example, if the other client did delete Todo-item B and added a new Todo-item E to your list while it was offline and you synced your operation to mark all todo-items in your list as done (using [Collection.modify()](/docs/Collection/Collection.modify() with a where-clause). When that client goes online again, AFTER your sync was already finished, it will perform your modify operation onto its own modifications before applying them to the server so that Todo-item E also gets the `done` property set.

Flow:

1. Other client (currently offline) adds new Todo-item E to the list.
2. You sync your consistent operation with the server `db.todoItems.where({todoListId: todoListId}).modify({done: true})`
3. Other client goes online and sends its changes to the server.
4. Server will apply your modify operation against the other client's changes before applying them because that client's last sync happened before your operation was synced, so:

   - The operation to add Todo-item E will be affected by your operation because the where-expression of your modify operation evaluates true.
   - Your modify operation (to set `{done: true}` on the item) is applied as a pseudo-operation for the client.

5. The end result will be that the Todo-list has item B, C, D and E - all with `{done: true}` which is fully consistent with the original intention of your operation `db.todoItems.where({todoListId: todoListId}).modify({done: true})`.

Basically, where-based modify- and delete-operations persist on the server until all clients have synced, and the operations can evaluate also onto future sync operations from other clients that was not aware of your operation when they did their operations.

## Update Operations

Update-operations manipulate individual properties rather than replacing entire objects. Update operations prohibit conflicts when two different clients mutate different properties on the same object. This requires that the dexie operation to update was a [Table.update()](</docs/Table/Table.update()>) (or [Collection.modify()](</docs/Collection/Collection.modify()>) with a where-clause using equality comparison on primary key) and that the provided changes was an object that listed the properties to update (not a JS callback). If [Table.put()](</docs/Table/Table.put()>) however was used instead of [Table.update()](</docs/Table/Table.update()>), the intention would be to actually replace the entire object and will therefore overwrite another update or put operation and not allow for two clients updating different props.

Update operations avoid conflicts as long as the different clients updates different properties on the object, but if two different clients update the same property, the latest performed operation will overwrite the previous one. An example would be a Todo item's `done` property. If user A sets `{done: true}` on the same object as user B sets `{done: false}` the operation that was performed latest in time will be the one that overwrites the other. The timestamp of when the actual operation took place on the client, decides which operation will overwrite the other. This timestamp is adjusted to each client's time-diff against the server.

## Consistently add or remove unique entries to sets of strings or numbers

Update- and modify operations take an object containing the properties to update. The value to be set can either be a plain value (such as `{name: "Foo"}` which will update the "name" property to "Foo") but can also be a consistent operation on the property such as mathematical add(2) or set manipulation remove(["foo"]). This can be utilized to modify the property relative to its current value. When working with array properties that represent a set of strings or numbers (such as `tags` or `hobbies`), the consistent operations `add()` and `remove()` can be used to manipulate the array consistently across sync rather than replacing the whole array. See [/docs/add()] and [/docs/remove()]. This has a meaning when multiple clients eventually syncs with a server.

## Consistent addition / subtraction

Number or BigInt properties can be manipulated using addition or subtraction that is consistent across sync.
See [/docs/add()] and [/docs/remove()].

## Consistent Tree Structures

One pattern for managing tree structures in a database is to have an indexed property representing the path to the parent node, such as `parentPath`. This makes it efficient to delete or list all descendants in one query without any need of recursion:

```ts
// Add new node
function addNode(childProps, parentId = null) {
  return db.transaction('rw', db.treeNodes, async ()=> {
    const parent = parentId && await db.treeNodes.get(parentId);
    await db.treeNodes.add({
      ...childProps,
      parentPath: parent
        ? `${parent.parentPath}${parent.id}/`
        : '' // If no parent, parentPath will be empty string (added at the root)
    });
  }
}

// List direct children
function listChildren(node) {
  return db.treeNodes.where({parentPath: `${node.parentPath}${node.id}/`}).toArray();
}

// List all descendants without recursion:
function listAllDescendants(node) {
  return db.treeNodes.where('parentPath').startsWith(`${node.parentPath}${node.id}/`).toArray();
}

// Load parent
function loadParent(node) {
  return db.treeNodes.get(node.parentPath.split('/').at(-2));
}

// Load all ancestors
function async loadAllAncestors(node) {
  return (node.parentPath
    ? await db.treeNodes.bulkGet(node.parentPath.substring(0, node.parentPath.length - 1).split('/'))
    : []
  );
}

// Delete the node and all its descendants:
function deleteNode(node) {
  return db.transaction('rw', db.treeNodes, () => {
    db.treeNodes.where('parentPath')
      .startsWith(`${node.parentPath}${node.id}/`)
      .delete();
    db.treeNodes.where({
      parentPath: node.parentPath, // for consistence
      id: node.id
    }).delete();
  });
}


// Move subtree with sync consistency:
import { replacePrefix } from 'dexie';

function moveNode(node, newParentPath) {
  return db.transaction('rw', db.treeNodes, () => {
    // Move node
    db.treeNodes.where({
      parentPath: node.parentPath, // consistency-check
      id: node.id
    }).modify({
      parentPath: newParentPath
    });
    // Move all its descendants in relation to their sub path:
    db.treeNodes
      .where('parentPath')
      .startsWith(`${node.parentPath}${node.id}/`)
      .modify({
        // Here we're in a declarative object - not a JS callback - ==> Consistent operation.
        parentPath: replacePrefix(node.parentPath, newParentPath);
      });
  });
}
```

All the mutating operations above are also [sync consistent](https://dexie.org/cloud/docs/consistency#consistent-modify--and-delete-operations): If one offline client adds a child under "/a/b/c" and another offline client modifies all descendants under "/a/b/c" to have a new property {color: "blue"}, the merge of these operation will set {color: "blue"} on the added child also no matter in which order the clients became online.

## The new support for moving trees

But modify-operations that use a JS callback does not benefit from sync consistency, only local consistency. Moving an entire tree from one node to another has been one of those operation that need a JS function because the new parentPath's value depends on its existing value. So a tree move has only been possible with local consistency but not sync consistency before:

```ts
function moveNode(node, newParentPath) {
  return db.transaction('rw', db.treeNodes, () => {
    // Move node. Having the parentPath criteria here is for consistency:
    // Only perform the 2 moves if parentPath is still the same.
    db.treeNodes
      .where({
        parentPath: node.parentPath,
        id: node.id,
      })
      .modify({
        parentPath: newParentPath,
      })
    // Move all its descendants in relation to their sub path:
    db.treeNodes
      .where('parentPath')
      .startsWith(`${node.parentPath}${node.id}/`)
      .modify((node) => {
        // This is a JS callback that cannot be expressed to the server
        node.parentPath =
          newParentPath + node.parentPath.substring(node.parentPath.length)
      })
  })
}
```

JS code cannot securely be sent to the server due to several reasons: closures information missing + the risk of sending code that injects arbitrary code on the server. The operation above won't be sync consistent. If an offline client did add a new node under /a/b/c and that node is moved to /x/y/z, the merging of these operations would not be consistent - a node would still be placed under /a/b/c even though the c node has moved and doesn't exist anymore. So there is a need for declarative ways of doing certain operations, and moving trees is one of them.

A new export `replacePrefix` now available for this purpose. We will add more of these in coming versions (such as increment, push, deleteArrayItem, etc). `replacePrefix` is the first "complex" operation that already has support in Dexie Cloud (if upgrading dexie-cloud-addon to 4.0.1-beta.58) and can be executed to perform sync consistent tree moves:

```ts
import { replacePrefix } from 'dexie';

// Move subtree with sync consistency:
function moveNode(node, newParentPath) {
  return db.transaction('rw', db.treeNodes, () => {
    // Move node
    db.treeNodes.where({
      parentPath: node.parentPath, // consistency-check
      id: node.id
    }).modify({
      parentPath: newParentPath
    });
    // Move all its descendants in relation to their sub path:
    db.treeNodes
      .where('parentPath')
      .startsWith(`${node.parentPath}${node.id}/`)
      .modify({
        // Here we're in a declarative object - not a JS callback - ==> Consistent operation.
        parentPath: replacePrefix(node.parentPath, newParentPath);
      });
  });
}

```

This transaction does it all - it moves the node and all its descendants consistently in one atomic all-or-nothing transaction but also preserves the where-condition and the `replacePrefix` operation in the information to the server so that if an offline client added a node under /a/b/c, and then this operation happened, moving all descendants to the new location, and then the offline client comes online again and syncs, the new node would be placed on the correct new location and be hanging below a non-existing /a/b/c.

### Consistency in conflicting move operations

If two operations competes in a move operation involving the same nodes, consistency is maintained by the extra criteria on parentPath in both the move of the parent node and the operation to move its descendants. A move operation will not be performed if another move operation came first. The end result will always be a consistent tree. The last syncer might then experience that the move operation they made got rolled back after a sync and they would instead see the peer's hierarchy.

### Remove unique item from array property

## Tied Realms

Tied realms are for objects that are created as private but may be shared later on.

All database objects in Dexie Cloud have a `realmId` property (defaulting to current user's private realmId). The realmId represents which access-realm an object belongs to. When a realmId is not given for an object, it will default to the built-in private realm for the current user, representing private access. Those objects can be considered private, such as a private todo-list with private todo-items in it. If a private object needs to be shared, you would typically need to create a new realm, add members to the new realm and move the related entities into that new realm by updating their `realmId` property.

If we would just create a new realm with a random new ID and move our entities into it, it would work in most scenarios. The problem would arise when two different clients would do this with the same entities while they are both offline (the clients may belong to the same user and therefore have access to the private realm of the user). Another problem occurs when an offline deletes an object without knowing that the object was shared / moved into a new realm, but we didn't know of this new realm when deleting the object (we were offline when object was shared by another user) so we missed to delete the object's realm. In the scenario when two offline client both creates a realm for the object (in order to share it), both clients would each create a new realm and when they sync later on, we'd have two realms but only one of the realms would be used while the other would be "empty" and be a 'hanging object' that would never be deleted - it would lose it's relation to the entities it was created to control.

### getTiedRealmId()

The solution to the problem described above is to generate an ID for the realm computed from the ID of the object it should be tied to. This way all offline clients knows the possible ID in case object will be shared, so that it becomes impossible to create multiple realms for the object, and also make sure to always delete any tied realm when deleting the object. Different offline clients would choose the same ID when creating the realm. When they sync later on, the end result would still be a single realm representing the sharing of involved entities. A concrete example: a to-do-list along with its to-do-items. To share the list, you compute realmID from the ToDo-list ID. Then you move the ToDo-list entity along with the ToDo-items to the new realm (by modifying the `realmId` property of these objects). Then to share the list with someone, you add a `member` entity to the `members` table with `realmId` set to the new realm ID. So if client A would share it with User A and client B would share it with User B - both of these operations would sync nicely so that both user A and User B would gain access to the todo-list and its items.

And when finally deleting an entity that MAY have a tied realm, application code should also delete the possibly existing realm along with its related entities (todoItems, realm and its members). By doing all these operations within a single Dexie transaction, atomicity is also guaranteed. In the end we have a waterproof and consistent way of managing entire life cycle of entities that may be shared or may be private.

```ts
import { getTiedRealmId } from 'dexie-cloud-addon'

async function shareList(todoList: TodoList) {
  await db.transaction(
    'rw',
    [db.todoLists, db.todoItems, db.realms],
    async () => {
      // Create realm (use put instead of add if other client did the same)
      const newRealmId = getTiedRealmId(todoList.id)
      await db.realms.upsert(newRealmId, {
        name: 'A todo list',
        represents: 'a todo list',
      })
      // Move todo-list into the new realm:
      await db.todoLists.update(todoList.id, { realmId: newRealmId })
      // Move all todo items into the new realm consistently (modify() is consistent across sync peers)
      await db.todoItems
        .where({ todoListId: todoList.id })
        .modify({ realmId: newRealmId })
    }
  )
}

// Consistently delete the list. Also delete its tied realm (even if it is on the private realm)
// Reason for always deleting its tied realm is: What if we are offline, and another client has
// shared the list while we're not yet aware of this. By always deleting a possible tied realm along
// with deleting the list, we make sure that the deletion will also delete the realm if it exists.
async function deleteList(todoList: TodoList) {
  await db.transaction(
    'rw',
    [db.todoLists, db.todoItems, db.realms, db.members],
    () => {
      const tiedRealmId = getTiedRealmId(todoList.id)
      db.todoLists.delete(todoList.id)
      db.todoItems.where({ todoListId: todoList.id }).delete()
      // Empty out any tied realm from members:
      db.members.where({ realmId: tiedRealmId }).delete()
      // Delete the tied realm if it exists:
      db.realms.delete(tiedRealmId)
    }
  )
}
```

## Private Singleton IDs

Private Singleton IDs are primary keys that starts with a hash "#". They only need to be unique per user and they can be created or referred to no matter whether the user is authenticated or not. When they sync, they can never collide with other user's private IDs even when being identical.

Some examples when private singleton IDs can be useful:

- You have some personal settings per user and you want the database objects representing a setting to be a singleton instance (one per setting and user).
- You want a default placeholder to exist for every user. In a music app, it could be "Favourite songs".

### Example: Personal Settings Object

```ts
// Database declaration
const db = new Dexie('MyAppDB')
db.version(1).stores({
  personalSettings: 'id',
})

// Read setting:
const themeSetting = await db.personalSettings.get('#theme')
console.log('User theme is:', themeSetting?.value ?? 'default-theme')

// Update setting:
await db.personalSettings.put({ id: '#theme', value: 'dark-mode' })
```

Like all data in Dexie Cloud, it is allowed to add objects even when not yet authenticated to the server. When user finally authenticates, his or her created objects will get their realmId set to the correct private realmId of the authenticated user and get synced to the server. This goes for private objects only - non-authenticated users may never create or manipulate objects in other realms than the private one.

Adding normal objects with globally unique IDs have a drawback in case you want to avoid multiple instances of an object after logging in to the service and syncing it with existing data (where the action to add the same object had been done by the same user on another client).

Private IDs prohibits getting multiple instances in these cases. The settings example above is a good example.

1. User opens app on phone and changes the theme to "light-mode".
2. User logs in. The #theme object with value "light-mode" is persisted on her account in the cloud.
3. User opens app on desktop (without logging in yet) but now chooses the theme "dark-mode".
4. User logs in. The #theme object with value "dark-mode" will overwrite the existing "light-mode".
5. User opens app on a third device where he or she have already logged in before.
6. The latest #theme object is synced to the client and user will get the latest chosed theme ("dark-mode")

### Private Singletons must never be shared

An object with an private ID (starting with "#") must never be shared but needs to always lie in the private realm. If your app allows for sharing placeholder objects such as To-do lists, music albums or similar, take special care if the placeholder uses a private ID, and if so, disable the possibility to share it.

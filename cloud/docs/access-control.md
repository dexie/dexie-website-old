---
layout: docs-dexie-cloud
title: 'Access Control in Dexie Cloud'
---

<div class="shoutouts" style="text-align: left; margin: 20px 0 35px 0;">
   <p>Minimalistic and easy to understand access model</p>
   <p>Share entities with teams and between individuals</p>
   <p>All users in a single (but shardable) database</p>
   <p>Fine grained table-, row- and property level permissions</p>
</div>
<hr/>

This page describes the access control model in Dexie Cloud.

If you are new to Dexie Cloud, please visit the [Dexie Cloud landing page](/cloud/).

If you prefer to jump right in to samples, here some shortcuts:

## Examples

- [Sharable ToDo list](#example-sharable-todo-list)
- [Simple project management model](#example-a-simple-project-management-model)

## Introduction

The server endpoint of Dexie Cloud controls access to data for every sync request, so that each user maintains a copy of the part of the database that is accessible for that user. It also controls what permissions each user has to mutate data.

The whole idea with Dexie Cloud is to create applications that work as identically as possible no matter if user is offline or online. This means that the application logic needs to be fully executable on the client. A ToDo app must be able to add items while offline, a barcode scanner app must work offline and store scanned codes in the offline database.

Dexie Cloud comes with an access control model that has the same security benefits as a server side app, but the creation of the objects that control access happens in your client side app. How is this possible? **It must all start with a user creating a realm**. Any user can do that. A realm does not give any new access or affect other users just yet. The realm owner can invite members to the realm and connect the application model objects to the realm (or several different objects to the same realm). Then, users that accepts the invitations will gain the access that the realm owner has given and the model continues to work with water-proof isolation between users and between customers.

The invitation step is important in non-enterprise use cases because it protects other users from unwillingly starting to see new data showing up in their app without their acceptance - data that could potentially confuse them or delude them to mix it up with authentic data.

For enterprise use cases, Dexie Cloud also has a server side REST API that enables realm and bulk member management without requiring an invititation step. The client of such an API could typically sync users from a directory with realm members in Dexie Cloud.

## Realms

A realm represents an access controlled partition of data. All objects in your database are connected to a realm via the `realmId` property also when that property isn't explicitly set. The realmId property of any object will implicitly be set to the private realmId of the object creator. Every user has its own unique realmId that is private for that user only.

New realms can be created by anyone but they are of little use unless that user invites members and the members accepts the invitation.

Realms are managed in the `db.realms` table. A given user will only have the realms they are member of visible for them and synced for offline access. When a realm is shared with new users, those users will get an invitation to join the realm and when users accept the invitation, they will get the realm in their next sync request together with objects that are connected to that realm. Invitations are created using the `db.members` table. Invited members can be given full, limited or no permission to mutate objects connected to the realm.

## Members

Realms have members. A member connected to a realm will have the realm and all objects connected to it synced locally if the member have accepted the membership. Each member can be given **permissions** to mutate objects connected to the realm. Zero permissions means readonly access. Member can also be given roles.

## Roles

Instead of giving members direct permissions, a member can be given one or many roles that grants certain permissions. Roles are global per database and needs to be imported using [npx dexie-cloud import](cli#import). Each role has a name and a set of permissions. The roles of a member is defined by the `roles` property of the [member](#properties-of-objects-in-members-table).

## Reserved property names

In all custom application tables, there are two reserved property names that affect access control:

- **realmId** - connects the object to a realm, making it visible (synced) for the members in the realm. If realmId is not specified, the current user's userID will be used, which is a built-in realmId that each user has. However, there are no realm objects representing these built-in realms.
- **owner** - connects the object to a user that gains full permissions on it. Ownership implies access to update and delete the object including changing realmId and owner properties, but it does not imply visibility (sync). If a member is removed from a realm, objects connected to that realm that are owned by the user will go out of scope for the user. If owner is not specified, it will default to user-ID of the current user. If explicitly set to null, it will not have an owner.

## Default Access Control

In the simplest setup of Dexie Cloud, you do not need to specify anything related to access control. All data that one user creates will be private. It will sync to the cloud but not visible for any other user. This is still a valid use case since the data is continuously backed up and possible to access from different devices for the same user.

### Example: Zero config Access Control

Let's say you write a ToDo app where you don't care at all about collaboration. You just want each user to get their IndexedDB synced with the cloud so that they can have their same ToDo list on multiple devices and have them in sync. No user should access another user's ToDo list - they are 100% private for each user.

The sample I'm gonna show you is almost identical to how you would declare it in a plain Dexie.js app. The difference is just that you've enabled the dexieCloud addon, connect it to a database and use the '@' sign to get generated universal IDs.

```js
import Dexie from 'dexie'
import dexieCloud from 'dexie-cloud-addon'

const db = new Dexie('mySyncedDB', { addons: [dexieCloud] })
db.version(1).stores({
  todoLists: '@id, title',
  todoItems: '@id, title, done, todoListId',
})

db.cloud.configure({
  databaseUrl: '<your database URL>',
  requireAuth: true,
})
```

_In this sample, we are only declaring application tables 'todoLists' and 'todoItems'. This is ok. Sync will work for each user, but users will not be able to share their lists with others_

## Access Control Tables

Access control is defined using the Dexie tables [realms](#table-realms), [members](#table-members) and [roles](#table-roles). To take advantage of these, just add them to your schema declaration. The server end-point will know how to handle these special tables if they are present.

```js
import Dexie from 'dexie'
import dexieCloud from 'dexie-cloud-addon'

const db = new Dexie('myDB', { addons: [dexieCloud] })
db.version(2).stores({
  // Application tables
  todoLists: '@id, title',
  todoItems: '@id, title, done, todoListId',

  // Access Control tables
  realms: '@realmId',
  members: '@id', // Optionally, index things also, like "realmId" or "email".
  roles: '[realmId+name]',
})
```

_Access Control tables needs to be spelled exactly as in this sample and their primary keys needs to be spelled exactly the same. On top of that, you are free to index those properties you will need to query. The properties of objects in these tables are documented under each table below._

We will walk through how to use these tables to share objects to others.

### Table "realms"

Access Control are defined using realms. Each object you create belongs to a realm even if realm is not specified. Every user has its own private realm. Users can create new realms and invite other users to them. The id of a realm needs to be a globally unique string.

| Table Name | "realms" |
| Primary key | realmId |

By default, when adding objects to a table, it will implicitly get a "realmId" property pointing out the private realm of the current user. To make an object belong to a custom realm, just set the "realmId" property to the ID of the created realm.

You normally reuse the same realm for multiple objects to easily share all included objects atomically by adding members to your realm. Each member within a realm can also be given different permissions. Permissions can optionally be organized via roles.

#### Properties of objects in "realms" table

```ts
interface Realm {
  /** Primary key of the realm.
   */
  realmId: string

  /** The name of the realm.
   *
   * This property is optional but it can be a good practice to name a realm for what it represents.
   */
  name?: string

  /** A short text that describes what the realm represents.
    This text will be used in invites to exlain what the user is invited to.
    Examples: 'a to-do list', 'a project', 'a team'.
  */
  represents?: string

  /** Contains the user-ID of the owner. An owner has implicit full write-access to the realm
   * and all objects connected to it. Ownership does not imply read (sync) access though,
   * so realm owners still needs to add themself as a member if they are going to use the realm
   * themselves.
   */
  owner?: string
}
```

### Example: Sharable ToDo list

This example shows how to create shareable entities, how to share them and how to connect related entities to it. It consists of three functions:

1. **createTodoList()** creates a shareable ToDo list
2. **shareTodoList()** shares the list to other users
3. **addTodoItem()** adds a todoItem related to the shared list that also inherits sharing.
4. **deleteTodoList()** deletes the todo-list along with all its related objects

```js
import Dexie from 'dexie'
import dexieCloud from 'dexie-cloud-addon'

//
// Declare database, tables, keys and indexes
//
const db = new Dexie('myToDoDB', { addons: [dexieCloud] })
db.version(2).stores({
  // Application tables
  todoLists: '@id, title',
  todoItems: '@id, title, done, todoListId',

  // Access Control tables
  // (Note: these tables need to be named exactly like in this sample,
  //        and will correspond to server-side access control of Dexie
  //        Cloud)
  realms: '@realmId',
  members: '@id,[realmId+email]',
  roles: '[realmId+name]',
})

//
// Example functions
//

/** Create a shareable ToDo list
 *
 * @param {string} listName Name of the ToDo list
 * @returns {Promise} Promise resolving with the ID of the created list.
 */
async function createTodoList(listName) {
  const id = await db.todoLists.add({ title: listName })
  return id
}

/** Share ToDoList with some friends
 *
 * @param {Object} todoList
 * @param {Array.<{name: string, email: string}>} friends
 * @returns {Promise}
 */
function shareTodoList(todoList, ...friends) {
  return db.transaction('rw', [db.todoLists, db.realms, db.members], () => {
    // Add or update a realm, tied to the todo-list using getTiedRealmId():
    const realmId = getTiedRealmId(todoList.id)
    db.realms.put({
      realmId,
      name: todoList.title,
      represents: 'a to-do list',
    })

    // Move todo-list into the realm (if not already there):
    db.todoLists.update(todoList.id, { realmId })

    // Add the members to share it to:
    db.members.bulkAdd(
      friends.map((friend) => ({
        realmId,
        email: friend.email,
        name: friend.name,
        invite: true, // Generates invite email on server on sync
        permissions: {
          manage: '*', // Give your friend full permissions within this new realm.
        },
      }))
    )
  })
}

/** Unshare ToDoList for given friends
 *
 * @param {Object} todoList
 * @param {Array.<{name: string, email: string}>} ...friends
 * @returns {Promise}
 */
function unshareTodoList(todoList, ...friends) {
  return db.members
    .where('[realmId+email]')
    .anyOf(friends.map((friend) => [todoList.realmId, friend.email]))
    .delete()
}

/** Add ToDo item
 *
 * @param {Object} todoList The TodoList object to connect the new toDo item to.
 * @param {string} todoTitle The title of the ToDo item.
 */
function addTodoItem(todoList, todoTitle) {
  return db.todoItems.add({
    todoListId: todoList.id, // Connect the item to the todoList
    realmId: todoList.realmId, // Connect it to the same realm
    title: todoTitle,
    done: 0,
  })
}

/** Delete todo-list along with any possible related entity.
 * For sync consistency, we do not rely on queries within the transaction, but
 * instead make sure to delete all possible related entities using where clauses
 * that also executes on server when syncing, as well as on future syncs from
 * other clients (see docs about consistency in dexie cloud)
 * */
function deleteTodoList(todoList) {
  // Use a transaction for full consistency also when syncing it:
  return db.transaction(
    'rw',
    [db.todoLists, db.todoItems, db.realms, db.members],
    () => {
      // Delete possible todo-items:
      db.todoItems.where({ todoListId: todoList.id }).delete()
      // Delete the list:
      db.todoLists.delete(todoList.id)
      // Delete possible realm in case list was shared:
      db.realms.delete(getTiedRealmId(todoList.id)) // members are auto-deleted with realm
    }
  )
}
```

For another example, see [TodoList class](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/TodoList.ts) in Dexie Cloud Todo-app example that encapsulates actions into class methods. Also read about [dexie cloud consistency concepts](consistency) that makes this model consistent using tied realm ID and where clauses when moving objects between realms.

### Table "members"

Contains the edges between a realm and its members. Each member must have at least a realmId and an email property. Members can be added before the target user even has any user account in the system.

| Table Name  | "members" |
| ----------- | --------- |
| Primary key | @id       |

#### Properties of objects in "members" table

```ts
interface Member {
  id?: string // Auto-generated universal primary key
  realmId: string
  userId?: string // User identity. Set by the system when user accepts invite.
  email?: string // The email of the requested user (for invites).
  name?: string // The name of the requested user (for invites).
  invite?: boolean
  invited?: Date
  accepted?: Date
  rejected?: Date
  roles?: string[] // Array of role names for this user.
  permissions?: {
    add?: string[] | '*' // array of tables or "*" (all).
    update?: {
      [tableName: string]: string[] | '*' // array of properties or "*" (all).
    }
    manage?: string[] | '*' // array of tables or "*" (all).
  }
}
```

**Properties with special restrictions**

- **realmId** - you will only have permission to specify a realm where you have permissions to add members in.
- **userId** - you can only set this field to your own userId, or leave it undefined unless you are database owner (for example if adding members via REST interface)
- **invited** - Managed by the system only. Cannot be set or updated by user.
- **accepted** - Managed by the system only. Cannot be set or updated by user.
- **rejected** - Managed by the system only. Cannot be set or updated by user.

#### The permissions field

See [Permissions](#permissions)

#### Default Membership flow

This is the typical flow for the non-enterprise use case in applications with a similar model as Slack, GitHub and ToDo list applications.

1. Client side: Add new object to the 'members' table with {invite: true}.
2. The changes are synced onto Dexie Cloud backend who will send an invite email to the added member.
3. User clicks link in email to accept the invitation.
4. User gains access: Next sync request from a device belonging to the user will start downloading data connected to the newly accepted realm.

#### Enterprise membership

If your app is targeting enterprise customers, a realm can represent an enterprise department or organisation and you might want to offer your customer to define access using their existing directory rather than having to invite all the employees manually.

Using the Dexie Cloud REST API, it is also possible to manage realms and members from a cloud function or service and by-pass the invite step and set the userId property of members directly.

### Table "roles"

Contains roles for each realm with predefined permissions. Users can then be assigned to roles and gain the permissions that comes with them.

| Table Name | "roles" |
| Primary key | [realmId+name] |

#### Properties of objects in "roles" table

```ts
interface Role {
  realmId: string
  name: string
  permissions: {
    add?: string[] | '*' // array of tables or "*" (all).
    update?: {
      [tableName: string]: string[] | '*' // array of properties or "*" (all).
    }
    manage?: string[] | '*' // array of tables or "*" (all).
  }
}
```

_See [Permissions](#permissions)_

### Example: A Simple Project Management Model

In this example, we declare a very simplistic project database and use roles to distinguish permissions. We create our own roles "manager", "doer" and "commenter". The function `addProject()` will return a promise of adding a new project, `addMember()` adds a member to it, `addTask()` adds tasks to the project, `markAsDone()` marks a task as done and `addComment()` to add comments on tasks.

```js
import Dexie from 'dexie'
import dexieCloud from 'dexie-cloud-addon'

const db = new Dexie('myProjectDB', { addons: [dexieCloud] })
db.version(1).stores({
  projects: '@id, title',
  tasks: '@id, projectId, title, done',
  comments: '@id, taskId, comment',

  // Access Control
  realms: '@realmId',
  members: '@id',
  roles: '[realmId+name]',
})

/** Add project.
 *
 * @param {string} projectName
 * @returns {Promise}
 *    Promise of string representing the ID of the added project.
 */
function addProject(projectName, description = '') {
  return db.transaction('rw', db.realms, db.projects, async () => {
    // Create the new realm
    const newRealmId = await db.realms.add({
      // A name and what it represents are used in invites -
      // to explain to invited members what they are invited to.
      name: `${projectName}`,
      represents: `a project`,
    })

    // Create project and put it in the new realm.
    return await db.projects.add({
      realmId: newRealmId,
      name: projectName,
      description,
    })
  })
}

/** Add project member.
 *
 * @param {Object} project The project object.
 * @param {string} email The email address of the member to add.
 * @param {string} name The name of the member to add.
 * @param {Array.<string>} roles Roles that the member should have.
 * @returns {Promise}
 */
function addMember(project, email, name, roles) {
  return db.members.add({
    realmId: project.realmId,
    email,
    name,
    roles,
    invite: true,
  })
}

/** Add project task.
 *
 * @param {Object} project The project object.
 * @param {string} taskTitle Task title.
 * @param {string} taskDescription Task description.
 * @param {Array.<string>} roles Member roles.
 * @returns {Promise}
 */
function addTask(project, taskTitle, taskDescription) {
  return db.tasks.add({
    projectId: project.id,
    realmId: project.realmId,
    title: taskTitle,
    done: 0,
    description: taskDescription,
  })
}

/** Mark task as done.
 *
 * @param {Object} task The task to update.
 */
function markAsDone(task) {
  return db.tasks.update(task.id, { done: Date.now() })
}

/** Add a comment to a task.
 *
 * @param {Object} task The task to comment.
 * @param {string} taskComment The comment to make.
 *
 * @returns {Promise}
 */
function addComment(task, taskComment) {
  return db.comments.add({
    taskId: task.id,
    realmId: task.realmId,
    comment: taskComment,
    timestamp: new Date(),
  })
}

/** Remove comment.
 *
 * @param commentId ID of comment to remove.
 * @returns {Promise}
 */
function removeComment(commentId) {
  return db.comments.delete(commentId)
}

/** Update comment
 *
 * @param commentId ID of comment to update.
 * @param newComment Updated text of the comment.
 * @returns {Promise}
 */
function updateComment(commentId, newComment) {
  return db.comments.update(commentId, {
    comment: newComment,
    timestamp: new Date(),
  })
}
```

_The sample uses roles, which need to be imported using the `dexie-cloud` command-line tool with command [npx dexie-cloud import](https://dexie.org/cloud/docs/cli#import)_

## The Public Realm

As mentioned before, realms can be created any time, but there are also one "built-in" realm per user, representing the user's private data. Those realms have the same ID as the user's ID. There is also another built-in realm with the id "rlm-public". All users, also unauthenicated users, have visibility / sync access to it. By default, only the owner of the database has permissions to mutate data in the public realm but everyone have access to see and access its data online or offline.

Public data can be populated using the REST API.

The public realm can be specifically useful when you have structured public data such as a product catalog, list of locations, etc that should be available offline and indexed by IndexedDB.

Public realm is also useful in the zero-auth use case - when your app can be used without logging in to Dexie Cloud.

## Permissions

Permissions can be set on members and / or roles. Here we explain their syntax and how they grant permissions within the realm they are connected to.

**add**

Permission to add new objects to given set of tables. Note that [object ownership](#object-ownership) imply full permissions of an object. So unless a user specifies `{owner: null}` when adding an object, the user will keep control of the object and be able to delete it or update any field of it no matter not having any other permission than the **add** permission.

Example

```js
{
  add: ['todoItems', 'comments']
}
```

The **add** permission also grants the user move an object of the given types (tables) into this realm (by changing the realmId property). Note though that the same user also needs to either be owner of the object in the source realm, or to have **manage** permission in the source realm.

**update**

Permission to update given set of properties in given set of tables. Allowing "\*" will allow updating all non-reserver properties (all properties but `realmId` and `owner`).

Example

```js
{
  update: {
    todoLists: ["title"],
    todoItems: "*",
  }
}
```

NOTES:

- `"*"` represents all properties except the reserved properties (`owner` and `realmId`). If you have `{update: {todoItems: "*"}}` permission, you can change the todoItems `title`, `done` fields etc but not its `owner` or `realmId`.
- In order to grant permissions for all fields including `owner` and `realmId` you have to specify them explicitly:
  ```js
  {
    update: {
      todoItems: ['*', 'realmId', 'owner']
    }
  }
  ```

**manage**

Full permissions on objects within the realm in given set of tables.

Example

```js
{
  manage: ['todoLists', 'todoItems']
}
```

```js
{
  manage: '*'
}
```

See [typescript interface DBPermissionSet](DBPermissionSet)

## Object Ownership

The ownership of objects are defined by the `owner` reserved property name of any object. The content of that property is the userId of the owner.

An owner have full permissions on an object. This applies even if the object is connected to a realm where the user has limited permissions.

For example if you have permissions `{add: ["comments"]}` within a realm but not `update` or `manage` permissions you can add new comments but also update or delete your own comments tied to that realm. You will not be able to update or delete other users' comments though.

<br/>
<br/>

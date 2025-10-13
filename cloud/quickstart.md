---
layout: docs-dexie-cloud
title: 'Dexie Cloud Quick-Start'
---

## Prerequisits

|      |                                                                     |
| ---- | ------------------------------------------------------------------- |
| OS   | MacOS, Linux or Windows with Git Bash (included in Git for Windows) |
| Node | Version >= 18                                                       |

## Steps

1. [Download our sample app](https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Fdexie%2FDexie.js%2Ftree%2Fmaster%2Fsamples%2Fdexie-cloud-todo-app&filename=dexie-cloud-todo-app) and unzip it

2. Start a Terminal or Git Bash Console and `cd` to the extracted zip (~/Downloads/dexie-cloud-todo-app) and install dependencies

   ```bash
   npm install
   ```

3. Create your own database in our cloud:

   ```bash
   npx dexie-cloud create
   ```

   _It will send you a one-time password. Fill it in to proceed with database creation._

4. Now, run our little script that configures your app and database for this sample and then start the application and a browser window will navigate to the application in dev mode:
   ```bash
   chmod +x ./configure-app.sh
   ./configure-app.sh
   npm start
   ```

## See Sync in Action

1. Start two browser windows (with different profiles to showcase two different users) to [http://localhost:3000](http://localhost:3000) and have both visible at the same time
2. Log in both using one of the password-free demo users or a real user.
3. See how everything is instantly synced between the two.
4. Turn WiFi off to test offline. Play around. Turn it on again and see it sync. Try different scenarios such as one offline client deletes a list while the other one adds a new item to it - and then let them sync their actions.

### Guide to the Source Code

#### Data Layer

[db.ts](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/db.ts) exports the singleton Dexie instance.

[TodoDB.ts](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/TodoDB.ts) declares its tables, primary keys and indexes.

[TodoItem](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/TodoItem.ts) - declared as a simple typescript interface

[TodoList](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/TodoList.ts) - declared as a class with methods for sharing, deleting etc - operations that involves transactions and logic, perfectly encapsulated in class! Please look at its methods to learn how realms, members, sharing and deletion should be done in order to [preserve consistency](/cloud/docs/consistency) across various offline use cases.

Whether to declare simple interfaces or Entity classes is only a question of taste. A service or a function based module could equally well have contained the data logic for TodoList.

#### Components

- [TodoLists](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/components/TodoLists.tsx) - a very simple example useLiveQuery()
- [TodoListView](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/components/TodoListView.tsx) - showcases the `usePermissions()` hook and how limited user access can disable certain actions. Also how to edit the name inline without any complex state management.
- [TodoItemView](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/components/TodoItemView.tsx) - shows another example of `usePermissions()` and inline editing
- [SyncStatusIcon](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/components/navbar/SyncStatusIcon.tsx) - showcases `useObservable()` and how to reflect the current offline state to the user.
- [Invites](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/components/access-control/Invites.tsx) - showcases in-app presentation of invites.

#### Roles and Access Control

- [roles.json](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/data/roles.json) - defining a set of permission per role.
- [configureApp.sh](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/configure-app.sh) - Showcases how to use the `dexie-cloud` CLI to import roles and demoUsers as well as white-listing the application URLs. It also creates an .env.local file with the database URL.

---
layout: docs-dexie-cloud
title: 'Dexie Cloud Quickstart'
---

### Get up and running in a minute!

This guide will help you:

1.  Create a simple **offline-first app** with **storage and sync**
2.  **Deploy it** to your own free static hosting on GitHub
3.  **Install** it on mobile
4.  See it **sync** between mobile and desktop
5.  Go through **the code** to learn the details.

This app is an educational PWA with focus on clean, minimalistic and correct code! (*not super-fancy-advanced because the purpose is to understand the code*).

## Prerequisits

|      |                                                                     |
| ---- | ------------------------------------------------------------------- |
| OS   | MacOS, Linux or Windows with Git Bash (included in Git for Windows) |
| Node | Version >= 18                                                       |

## Steps

1. <a href="https://download-directory.github.io/?url=https%3A%2F%2Fgithub.com%2Fdexie%2FDexie.js%2Ftree%2Fmaster%2Fsamples%2Fdexie-cloud-todo-app&filename=dexie-cloud-todo-app" target="_blank">Download our sample app</a> and unzip it

2. Start a Terminal or Git Bash Console and `cd` to the extracted zip (~/Downloads/dexie-cloud-todo-app) and install dependencies

   ```bash
   npm install
   ```

3. Create your own database in our cloud:

   ```bash
   npx dexie-cloud create
   ```

   _It will send you a one-time password. Fill it in to proceed with database creation._

4. Now, run our little script that configures your app and database for this sample

   ```bash
   chmod +x ./configure-app.sh
   ./configure-app.sh
   ```

5. Start the app in dev mode:
   ```bash
   npm run dev
   ```

## Deploy the PWA using Github Pages

The app is easily deployed to any static hosting provider. After running `npm run build`, the deployable PWA is all in the `build` folder. If you already have a GitHub account, here are the steps to deploy the app on GitHub Pages:

1. Initialize a new Git repository in your project folder:

   ```bash
   git init
   git add .
   git commit -m "Initial commit"
   ```

2. Create a new repository on GitHub (for your source but also the static hosting):

   - Go to [github.com](https://github.com) and sign in
   - Click the "+" icon in the top right corner
   - Select "New repository"
   - Name your repository (e.g., "my-dexie-cloud-app")
   - Don't initialize with README, .gitignore, or license (since you already have files)

3. Connect your local repository to GitHub:

   ```bash
   git remote add origin https://github.com/<yourusername>/<your-repo-name>.git
   git branch -M main
   git push -u origin main
   ```

4. Deploy using GitHub Pages:

   ```bash
   npm run build
   # Deploy the PWA to GitHub Pages:
   npm run deploy
   # White-list the origin:
   npx dexie-cloud whitelist https://<yourusername>.github.io
   ```

   Your PWA will be available at https://<b>&lt;yourusername&gt;</b>.github.io/<b>&lt;your-repo-name&gt;</b>/dexie-cloud-todo-app/.

   _For reference: The original app is deployed on https://<b>dexie</b>.github.io/<b>Dexie.js</b>/dexie-cloud-todo-app/_ <a href="https://dexie.github.io/Dexie.js/dexie-cloud-todo-app/" target="_blank">(open &#8599;)</a>

## See Sync in Action

1. Install the PWA on your phone by navigating to _https://<b>&lt;yourusername&gt;</b>.github.io/<b>&lt;your-repo-name&gt;</b>/dexie-cloud-todo-app/_ on your phone browser
2. Select "save to home screen" and choose to install it as an app.
3. Navigate to the app on your computer as well. Install it as a Desktop app (optionally)
4. Login as Alice on computer and Bob on the phone.
5. Let Alice create a Todo-list and share it to Bob.
6. See how everything is instantly synced between the two.
7. Turn WiFi off to test offline. Play around. Turn it on again and see it sync. Try different scenarios such as one offline client deletes a list while the other one adds a new item to it - and then let them sync their actions.

## Guide to the Source Code

### Data Layer

- [db.ts](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/db.ts) exports the singleton [TodoDB](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/TodoDB.ts) instance.
- [TodoDB](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/TodoDB.ts) - a sub class of Dexie that contains database declaration and sync configuration.
- [TodoItem](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/TodoItem.ts) - the shape of a to-do item, declared as a simple typescript interface.
- [TodoList](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/TodoList.ts) - the shape and logic of a to-do list - declared as a class with methods for sharing, deleting etc - operations that involves transactions and logic, perfectly encapsulated in class! Please look at its methods to learn how realms, members, sharing and deletion should be done in order to [preserve consistency](/cloud/docs/consistency) across various offline use cases.

Whether to encapsulate logic in a class as we do with [TodoList](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/TodoList.ts) is only a question of taste. It could equally well have been a pure interface just like we did with [TodoItem](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/TodoItem.ts). However, having the consistency logic close to the model is a way to encourage correct usage of the model. _If you declare your models this way, make sure to also bind the dexie table to the model using `mapToClass()` like we do on [line 23 in TodoDB](https://github.com/dexie/Dexie.js/blob/v4.2.0/samples/dexie-cloud-todo-app/src/db/TodoDB.ts#L23)_.

### Visual Components

- [TodoLists](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/components/TodoLists.tsx) - a very simple example useLiveQuery()
- [TodoListView](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/components/TodoListView.tsx) - showcases the `usePermissions()` hook and how limited user access can disable certain actions. Also how to edit the name inline without any complex state management.
- [TodoItemView](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/components/TodoItemView.tsx) - shows another example of `usePermissions()` and inline editing
- [SyncStatusIcon](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/components/navbar/SyncStatusIcon.tsx) - showcases `useObservable()` and how to reflect the current offline state to the user.
- [Invites](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/components/access-control/Invites.tsx) - showcases in-app presentation of invites.

### Roles and Access Control

- [roles.json](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/data/roles.json) - defining a set of permission per role.
- [configureApp.sh](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/configure-app.sh) - Showcases how to use the `dexie-cloud` CLI to import roles and demoUsers as well as white-listing the application URLs. It also creates an .env.local file with the database URL.

### PWA stuff

- [vite.config.ts](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/vite.config.ts) - configures the PWA to make the app installable. It generates a web manifest with app icons, name, URL and screenshots.
- [sw.ts](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/sw.ts) - The minimal Service Worker that just caches assets for offline use as well as activates Dexie Cloud's background sync.

### Other Resources

- [Dexie Cloud Tutorial](/docs/Tutorial/Dexie-Cloud) - a step-by-step guide (without any pre-baked sample app)
- [Dexie Cloud Starter](https://github.com/dexie/dexie-cloud-starter) - a nextjs based app with additional features:
  - Social login
  - Collaborative Text Editing with Tiptap and Y.js
  - Full-text search with Lunr + Dexie

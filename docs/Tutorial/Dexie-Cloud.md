---
layout: docs-dexie-cloud
title: 'Get started with Dexie Cloud'
---

## 1. Bootstrapping

No matter if you create a brand new app or adjust an existing one, this tutorial will guide you through the steps.

You can use whatever framework you prefer but in this tutorial we'll be showing some sample components in React, so if you start on an empty paper, I'd recommend using vite to bootstrap a react app:

```bash
npm create vite@latest my-app -- --template react-ts
```

Make sure to have dexie-related dependencies installed:

```bash
npm install dexie
npm install dexie-cloud-addon
npm install dexie-react-hooks # If using react
```

## 2. Declare a `db`

Unless you already use Dexie (in which case you could just adjust it), create a new module `db.ts` where you declare the database.

_If migrating from vanilla Dexie.js to Dexie Cloud, make sure to remove any auto-incrementing keys (such as `++id` - replace with `@id` or just `id`) as primary keys has to be globally unique strings in Dexie Cloud._

```ts
// db.ts
import { Dexie } from 'dexie';
import dexieCloud from 'dexie-cloud-addon';

export const db = new Dexie('mydb', { addons: [dexieCloud] });

db.version(1).stores({
  items: 'itemId',
  animals: `
    @animalId,
    name,
    age,
    [name+age]`
});
```

In this example we use the property `itemId` as primary key for `items` and `animalId` for `animals`.

Notice the `@` in `@animalId`. This makes it auto-generated and is totally optional but can be handy since it makes it easier to add new objects to the table.

Note that `animals` also declares some secondary indices `name`, `age` and a [compound](/docs/Compound-Index) index of the combination of these. These indices are just to examplify. For this tutorial, we only need the 'name' index. _A rule of thumb here is to only declare secondary index if needed in a where- or orderBy expression. And don't worry - you can add or remove indices later_

## 3. Make it Typing-Friendly

```ts
// Item.ts
export interface Item {
  itemId: string;
  name: string;
  description: string;
}
```

```ts
// Animal.ts
export interface Animal {
  animalId: string;
  name: string;
  age: number;
}
```

Then adjust the `db.ts` module we've already created so that it looks something like this:

```ts
// db.ts
import dexieCloud, { type DexieCloudTable } from 'dexie-cloud-addon';
import type { Item } from './Item.ts';
import type { Animal } from './Animal.ts';

export const db = new Dexie('mydb', { addons: [dexieCloud] }) as Dexie & {
  items: DexieCloudTable<Item, 'itemId'>;
  animals: DexieCloudTable<Animal, 'animalId'>;
};

db.version(1).stores({
  items: 'itemId',
  animals: `
    @animalId,
    name,
    age,
    [name+age]`
});
```

_We're actually just casting our Dexie to force the typings to reflect the `items` and `animals` tables that we are declaring in db.version(1).stores(...)._

\_There's also the option to declare the entities as classes instead of interfaces. See [TodoList.ts](https://github.com/dexie/Dexie.js/blob/928684175024b9a00269de1a65845a1f43ec8d74/samples/dexie-cloud-todo-app/src/db/TodoList.ts), [TodoDB.ts](https://github.com/dexie/Dexie.js/blob/3fe0876df83485e6552ee823a84aabac37cfa606/samples/dexie-cloud-todo-app/src/db/TodoDB.ts) and [db.ts](https://github.com/dexie/Dexie.js/blob/d58ddee379bec306a8ba4689d20f940c700449a4/samples/dexie-cloud-todo-app/src/db/db.ts) in the dexie-cloud-todo-list example. If you find that way more appealing, that's also ok.

## 4. Start Playing with it

Create some components that renders and manipulates the database. In this example, we use React + Typescript that demonstrate basic CRUD with a Dexie Cloud `animals` table.

```tsx
// components/App.tsx
import React from 'react';
import CreateAnimal from './CreateAnimal';
import AnimalList from './AnimalList';

export default function App() {
  return (
    <>
      <style>
        div.animal { display: 'flex', align-items: 'center', gap: 8 }
        div.create-form { display: 'flex', gap: 8, margin-bottom: 12 }
      </style>
      <div>
        <h1>Animals</h1>
        <CreateAnimal />
        <AnimalList />
      </div>
    </>
  );
}
```

_App: top-level component that renders `CreateAnimal` and `AnimalList`._

---

```tsx
// components/AnimalList.tsx
import React from 'react';
import { useLiveQuery } from 'dexie-react-hooks';
import { db } from '../db';
import AnimalView from './AnimalView';
import type { Animal } from '../Animal';

export default function AnimalList() {
  const animals = useLiveQuery(() => db.animals.orderBy('name').toArray(), []);

  if (!animals) return <div>Loading…</div>;

  return (
    <ul>
      {animals.map((a: Animal) => (
        <li key={a.animalId}>
          <AnimalView animal={a} />
        </li>
      ))}
    </ul>
  );
}
```

_AnimalList: lists animals using `useLiveQuery` (live updates) and renders `AnimalView` for each._

---

```tsx
// components/AnimalView.tsx
import React from 'react';
import { db } from '../db';
import type { Animal } from '../Animal';

export default function AnimalView({ animal }: { animal: Animal }) {
  const onDelete = async () => {
    await db.animals.delete(animal.animalId);
  };

  return (
    <div className="animal">
      <div>
        <strong>{animal.name}</strong> — {animal.age} yrs
      </div>
      <button aria-label="Delete" onClick={onDelete} title="Delete">
        🗑️
      </button>
    </div>
  );
}
```

_AnimalView: shows `name` and `age` and a delete button that removes the item from the table._

---

```tsx
// components/CreateAnimal.tsx
import React, { useState } from 'react';
import { db } from '../db';

export default function CreateAnimal() {
  const [name, setName] = useState('');
  const [age, setAge] = useState<number | ''>('');

  const onSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    if (!name || age === '') return;
    await db.animals.add({ name, age: Number(age) });
    setName('');
    setAge('');
  };

  return (
    <form onSubmit={onSubmit} className="create-form">
      <input
        value={name}
        onChange={(e) => setName(e.target.value)}
        placeholder="Name"
      />
      <input
        type="number"
        value={age}
        onChange={(e) => setAge(e.target.value ? Number(e.target.value) : '')}
        placeholder="Age"
      />
      <button type="submit">Add</button>
    </form>
  );
}
```

_CreateAnimal: small form that adds a new animal to `db.animals` (the table uses an auto-generated `@animalId`)._

---

Start the app and browse to it. Add and delete animals - see the app work with a local database only.

## 5. Make it Sync

Still, we haven't connected Dexie Cloud in the picture. Everything is happening locally so far. Yes, we've prepared the code but we haven't yet connected it to a cloud database.

1. Create a database in the cloud

   ```bash
   npx dexie-cloud create
   ```

   This will produde two local files: `dexie-cloud.json` and `dexie-cloud.key`. Make sure
   to .gitignore them:

   ```bash
   echo "dexie-cloud.json" >> .gitignore
   echo "dexie-cloud.key" >> .gitignore
   ```

2. White-list application URL (such as http://localhost:3000)

   ```bash
   npx dexie-cloud whitelist http://localhost:3000 # assuming port 3000

   # ...Dont forget (at a later stage) to also white-list public URLs:
   npx dexie-cloud whitelist https://mygreatapp02240s.azurewebsites.net
   ```

3. Pick the `dbUrl` from your local `dexie-cloud.json` file and configure the database in `db.ts`

   ```ts
   // db.ts
   ...
   db.cloud.configure({
     databaseUrl: "<dbUrl>",
   })
   ```

4. Add a Login button to your App.tsx:

   ```tsx
   <button onClick={() => db.cloud.login()}>Login</button>
   ```

5. Now, launch the app and navigate a browser to it

## 6. Learn about Access Control and Sharing (optional)

By default, all data being created will remain private to the end user, even though
kept in sync with the cloud. Learn more how you can create realms, roles, members and
permissions to invite a group of users to a commonly shared realm of data.

See [Access Control in Dexie Cloud](/cloud/docs/access-control)

To share data is also a 100% local-first action. Even creating invitations to new users can be done while being offline or while being in a shaky network.

## 7. Use Dexie Cloud Manager (optional)

Login to [Dexie Cloud Manager](https://manager.dexie.cloud/) to manage:

- end-users seats
- end-user evaluation policy
- SMTP settings
- subscription upgrades

## 8. Use `dexie-cloud` CLI

The CLI can be used to switch between databases, export, import, authorize colleguaes. See all commands in the [CLI docs](/cloud/docs/cli).

## 8. Customize Authentication (optional)

Choose between:

1. [Keep the default authentication but customize the GUI](/cloud/docs/authentication#customizing-login-gui)
2. [Replace authentication in its whole with a custom solution](</cloud/docs/db.cloud.configure()#example-integrate-custom-authentication>)

## 9. Customize Email Templates

Email templates for outgoing emails can be [customized](/cloud/docs/custom-emails) using the [npx dexie-cloud templates](/cloud/docs/cli#templates-pull) command.

---

## 10. FAQ

### What happens when clicking login button?

The default authentication dialog (which is [customizable](/cloud/docs/authentication#customizing-login-gui)) will ask for an email address for one-time password (OTP) authentication and prompt for the OTP. If this was the first time of login, your user will be registered in the database - otherwise it acts as a normal login. Once logged in / registered - the local database will be in sync with your account on your dexie-cloud database.

1. You get prompted for email
2. You get prompted for OTP
3. You enter OTP
4. You get logged in
5. All local data is uploaded to cloud and cloud data is downloaded
6. Now the local and remote databases are connected in real time.

The login flow typically happens once per end user and device. It's a part of the setup process for your application. Users can logout but if not, their device will be persistently logged in for as long as the local database lives.

### Can I force a login + initial sync before any data is accessed?

Yes, a [requireAuth](</cloud/docs/db.cloud.configure()#requireauth>) property can be passed to db.cloud.configure(). This will block an query until a user is logged in and has completed an initial sync flow. It's also possible to force a login as a specified email or userId and even to provide an OTP token this way (for example read from the query if the a magic link was sent).

### Is it possible to Logout?

Yes, but local first apps are normally intended to have long or even eternal login sessions. A logout from a local first app is similar to erasing the local database.

A logout button can be added that calls `db.cloud.logout()` when clicked.

### What is `dexie-cloud.key` good for?

This file is needed when you use the CLI (`npx dexie-cloud`) to whitelist, export, import etc. It's not needed for web applications as it is authorized using the `npx dexie-cloud whitelist` command instead. The clientId and clientSecret is also needed when using the the [REST API](/cloud/docs/rest-api).

### Why should `dexie-cloud.json` and `dexie-cloud.key` be .gitignored?

Keys shall never be committed to git (`dexie-cloud.key`). `dexie-cloud.json` does not contain any sensitive data but is still not tied to your code base - some other person might want to run the app on another database.

### How can I make my webapp an installable app (PWA) on desktop and mobile?

To make your webapp a Progressive Web App (PWA), you only need a few small pieces:

- Create a web app manifest (`manifest.webmanifest`) with name, icons, start_url and display (standalone).
- Add a service worker that caches your app shell and (optionally) API responses. Keep the service worker small and focused on offline/app-shell behavior.
- Register the service worker from your client code (e.g. `navigator.serviceWorker.register('/sw.js')`).
- Ensure your site is served over HTTPS (localhost is allowed for development).

If you use Vite, there are community plugins that automate manifest generation and service-worker integration (for example `vite-plugin-pwa`). These plugins can inject the manifest, generate precache lists and wire service-worker registration for you.

Quick checklist:

1. Add `manifest.webmanifest` to your public folder and link it from `<head>`.
2. Add a minimal `sw.js` (or use a plugin to generate Workbox-powered service worker).
3. Register the service worker in your app entry file.
4. Test using Chrome/Edge Lighthouse or `web.dev/measure` and verify installability on mobile.

### How can I bundle my app as a native app for iOS and Google Play?

To package your webapp as native apps you have a few solid options. The most common are:

- Capacitor (Ionic) — modern, actively maintained native runtime that wraps your web app and provides native plugins. Good for both iOS and Android.
- Electron — popular for packaging web apps as native desktop apps (macOS, Windows, Linux). Works well with PWAs and frameworks like Vite; pair with builders like `electron-builder` or `electron-forge` for installers.
- PWABuilder / TWA (Trusted Web Activity) — generate Android APKs/AABs from a PWA; TWA is ideal if your app is already a high-quality PWA.
- Cordova / PhoneGap — older tooling still in use for legacy projects but generally superseded by Capacitor.

Recommended quick actions:

1. Make sure your app is a solid PWA first (see previous section). PWAs are the best starting point for native packaging.
2. Choose a tool:

   - Capacitor: follow its setup docs to add platforms, copy the web build into the native projects and run builds with Xcode (iOS) and Android Studio (Android).

   - Electron: follow its docs to wrap your web build in a desktop runtime — build the web UI, create a small main process that loads the built files, and use builders like `electron-builder` or `electron-forge` to produce installers; remember to configure signing/notarization and auto-updates.

   - PWABuilder / TWA: use PWABuilder to generate an Android TWA wrapper or follow the TWA docs to create an AAB that links to your hosted PWA.

3. Configure platform-specific settings: app id/package name, icons and splash screens, permissions, and any native plugins you need.
4. Test on real devices and use platform tooling (Xcode for iOS, Android Studio / bundletool for Android) to create release builds and sign them.
5. Follow the store submission guides to publish on App Store and Google Play (you'll need developer accounts, app listing assets, privacy policy, etc.).

Useful documentation:

- Capacitor: https://capacitorjs.com/docs
- Electron: https://www.electronjs.org/docs/latest
- PWABuilder: https://www.pwabuilder.com/
- Trusted Web Activity (Android / Google): https://developer.chrome.com/docs/android/trusted-web-activity/
- Apple App Store publishing: https://developer.apple.com/app-store/
- Google Play publishing: https://developer.android.com/distribute

### How do I whitelist my app when bundled as native app with Capacitor?

```bash
npx dexie-cloud whitelist capacitor://localhost
npx dexie-cloud whitelist http://localhost
```

### How do I whitelist my app when bundled with Electron?

Electron apps does not require whitelisting.

### How can I get help

Let the community help out on:

- [Stackoverflow](http://stackoverflow.com/questions/ask?tags=dexie)
- [Github Issues](https://github.com/dexie/Dexie.js/issues/new?labels=cloud,question)
- [Discord](https://discord.com/channels/1328303736363421747/1339957860657926204)
- Request private support from the dexie team: [privsupport@dexie.org](https://dexie.org/contact#private-support-issues)

We prefer getting questions on stackoverflow and Github because it they will be publicly searchable for other users and creates a helps learning AI engines.

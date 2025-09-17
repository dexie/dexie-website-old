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

## 7. Use Dexie Cloud Manager (optional)

Login to [Dexie Cloud Manager](https://manager.dexie.cloud/) to manage:

- end-users seats
- end-user evaluation policy
- SMTP settings
- Free / paid subscription

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

---
layout: docs
title: 'Get started with Dexie in Svelte'
---

<div style="opacity: 0.8; padding: 40px 0 40px 0">
  <img src="/assets/images/Svelte_Logo.svg" style="width:50px;margin: 0 10px 0 0">
  <span>+</span>
  <img src="/assets/images/logo-dexie-black.svg" style="width: 200px;">    
</div>

Dexie v4.x comes with the best Svelte- and Sveltekit support.

In version 3.2 we've introduced **live queries** - queries that observe the result and make your component mirror the data in real time and in version 4.0.1-alpha.10 we improved the typing compability and SvelteKit support of liveQuery().

If a change is made (by the app itself or from an external tab or worker), a binary range tree algorithm will efficiently detect whether those changes would affect your queries and if so, re-execute your callback and re-render component.
[Here's a sample app demonstrates it](https://stackblitz.com/edit/vitejs-vite-gjzr7xhn?file=src%2FApp.svelte).

[liveQuery()](</docs/liveQuery()>) can be explained like this: **It observes the result of a promise-returning function that queries Dexie** _(In contrast to just execute it imperatively)_.
It is highly composable as you can call other functions that queries dexie compute a result based on their outcome.
Maybe you already have some functions you wrote long time ago.
Calling them from within the scope of the callback passed to [liveQuery()](</docs/liveQuery()>) will turn your imperative async functions into an Observable, which also complies with the Svelte Store specification.

# 1. Create a Svelte project

Here we refer to Svelte's own [Getting Started](https://svelte.dev/blog/the-easiest-way-to-get-started) page.

<br/>

# 2. Install dexie

```
npm install dexie
```

# 3. Create a file `db.js` (or `db.ts`)

Applications typically have one single Dexie instance declared as its own module. This is where you declare which tables you need and how each table shall be indexed. A Dexie instance is a singleton throughout the application - you do not need to create it on demand. Export the resulting `db` instance from your module so that components or other modules can use it to query or write to the database.

```ts
// db.js
import Dexie from 'dexie';

export const db = new Dexie('myDatabase');
db.version(1).stores({
  friends: '++id, name, age' // Primary key and indexed props
});
```

### Using Typescript?

If you use Typescript, table properties (such as `db.friends`) needs to be explicitly declared on a subclass of Dexie just to help out with the typings for your db instance, its tables and entity models.

```ts
// db.ts
import Dexie, { type EntityTable } from 'dexie';

interface Friend {
  id: number;
  name: string;
  age: number;
}

const db = new Dexie('FriendsDatabase') as Dexie & {
  friends: EntityTable<
    Friend,
    'id' // primary key "id" (for the typings only)
  >;
};

// Schema declaration:
db.version(1).stores({
  friends: '++id, name, age' // primary key "id" (for the runtime!)
});

export type { Friend };
export { db };
```

_See also [issue 1560](https://github.com/dexie/Dexie.js/issues/1560) containing a solution to improve typings for `liveQuery()` in case you want a more precise typings of the '$' vars._

# 4. Create a component that adds some data

Writing to the database can be done using [Table.add()](</docs/Table/Table.add()>), [Table.put()](</docs/Table/Table.put()>), [Table.update()](</docs/Table/Table.update()>) and [Collection.modify()](</docs/Collection/Collection.modify()>) - see Dexie's [quick reference](/docs/API-Reference#add-items) for examples. Here we're gonna create a simple Svelte component that allows the user to add friends into the database using [Table.add()](</docs/Table/Table.add()>).

```svelte
<!-- FriendAdder.svelte -->
<script>
  import { db } from "./db";

  export let defaultAge = 21;

  let status = "";

  let friendName = "";
  let friendAge = defaultAge;

  async function addFriend() {
    try {

      // Add the new friend!
      const id = await db.friends.add({
        name: friendName,
        age: friendAge
      });

      status = `Friend ${friendName} successfully added. Got id ${id}`;

      // Reset form:
      friendName = "";
      friendAge = defaultAge;
    } catch (error) {
      status = `Failed to add ${friendName}: ${error}`;
    }
  }
</script>
<div>
  <p>{status}</p>
  <fieldset>
    <legend>Add new friend</legend>
    <label>
      Name:
      <input
          type="text"
          bind:value={friendName} />
    </label>
    <br/>
    <label>
      Age:
      <input
        type="number"
        bind:value={friendAge} />
    </label>
    <br />
    <button on:click={addFriend}>Add Friend</button>
  </fieldset>
</div>
```

# 5. Create a component that queries data

Write a simple component that just renders all friends in the database.

```svelte
<!-- FriendList.svelte -->
<script>
  import { liveQuery } from "dexie";
  import { db } from "./db";

  let friends = liveQuery(
    () => db.friends.toArray()
  );

</script>
<ul>
  {#if $friends}
    {#each $friends as friend (friend.id)}
      <li>{friend.name}, {friend.age}</li>
    {/each}
  {/if}
</ul>

```

_To make more detailed queries, refer to Dexie's [quick reference for querying items](/docs/API-Reference#query-items)._

Notice two things here:

1. liveQuery() returns a reactive Svelte Store (or actually an Observable that happens to comply with the [The Svelte Store Contract](https://svelte.dev/docs#component-format-script-4-prefix-stores-with-$-to-access-their-values)). To access the reactive value of a Svelte Store, friends needs to be prefixed with $, `$friends`.
2. The result will be undefined momentarily before the very initial result arrives - which explains why we need the `{#if $friends}` condition.

# 6. Pass some query params

Let's improve the FriendList component and allow a parent component to pass some props that we use from within the query.
This time let's also use async / await (for pedagogical reasons only - it makes it simple to extend the function to do more queries if needed).

```svelte
<!-- FriendList.svelte -->
<script>
  import { liveQuery } from "dexie";
  import { db } from "./db";

  // Query parameters:
  export let minAge = 18;
  export let maxAge = 65;

  //
  // Query
  //
  $: friends = liveQuery(async () => {
    //
    // Query Dexie's API
    //
    const friends = await db.friends
      .where('age')
      .between(minAge, maxAge)
      .toArray();

    // Return result
    return friends;
  });
</script>
<ul>
  {#if $friends}
    {#each $friends as friend (friend.id)}
      <li>{friend.name}, {friend.age}</li>
    {/each}
  {/if}
</ul>
```

Notice two things in the above example:

1. As the query depends on the minAge and maxAge params, it needs to be declared as `$: friends` rather than just `let friends`, so that the query will update if a parent component changes minAge or maxAge.
2. The async callback is just a plain async function that can compute any type of result based on what it queries. It can use Promise.all() to query things in parallel or query things sequentially after each other. Any Dexie-call along the way will be marked for observation. In any case the end result will become observed.

# 7. Put it together

```svelte
<!-- App.svelte -->
<script>
  import FriendAdder from "./FriendAdder.svelte";
  import FriendList from "./FriendList.svelte";
</script>

<h1>My simple Dexie app</h1>

<FriendAdder />

<h2>Result</h2>
<FriendList />

```

When running this example, notice that adding friends within the given age range will make them show up instantly in your view.

<hr/>

# Things to play with

Test out how to edit query parameters and watch the live results update, or open up app in several windows and see them instantly reflect the changes from the other window...

## Make query parameters editable

Add a new component that allows the user to specify `minAge` and `maxAge` and pass those into the props to `<FriendList>`. You will notice that updating the props will also be instantly reflected in the query results of your app (also demonstrated in [this already cooked app](https://2n8bd.csb.app/))

## Run app in multiple windows

Open your app (or [the pre-cookied one](https://2n8bd.csb.app/)) in multiple new windows and watch them react to each other's changes.

_NOTE: IndexedDB is tied to using same browser and same origin. Sync across different origins, browsers, clients and users is another topic and requires a sync solution. If you're interested, have a look at what's coming in [Dexie Cloud](/cloud/)._

## Observe joined data

Do something similar to [this sample](/docs/API-Reference#joining) and observe the result of a function similar to `getBandsStartingWithA()` (a function that compose a result from multiple related queries). Notice that any change that affects any of the queries will make the component rerender, including the related data.

<hr/>
# More Samples and Resources

- [Play with Dexie.js and Svelte in Stackblitz](https://stackblitz.com/edit/vitejs-vite-gjzr7xhn?file=src%2FApp.svelte)
- [Read the docs for liveQuery()](</docs/liveQuery()>)
- [Read the general docs for Dexie.js](/docs/).

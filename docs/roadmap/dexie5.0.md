---
layout: docs
title: 'Road Map: Dexie 5.0'
---

Some of the features presented here were moved from the road map for dexie@4 in January 2024 when dexie@4 went into release candidate.

The goal for Dexie 5.0 will be a better experience for web developers to declare and query their data. What we'll be focusing on will be to query richness, paging and performance using some RAM-sparse caching. The goal is an intuitive and easy-to-use db API that performs well in large apps without sacrificing device resource usage.

We don't have a any dedicated time schedule of when dexie 5 will be in alpha, beta or feature complete. This road map may also be updated and modified along the way.

# Type Safe Declaration

Schema definition and typings can be declared in a single expression. Instead of having to declare .version().stores() after instanciating db, the db instanciation and the schema declaration can be done in a single expression.

#### Dexie's classical schema style:

```ts
// 1. Declare db
export const db = new Dexie('friendsDB') as Dexie & {
  friends: Table<Friend, number>
}

// 2. Specify version(s) and schema(s)
db.version(1).stores({
  friends: `
    ++id,
    name,
    age
  `
});
```

#### Dexie@5 type+schma declaration in single expression:

```ts
export const db = new Dexie('friendsDB').stores({
  friends: Table<Friend>`
    ++id   
    name    # Comments allowed!
    age     # (comma is optional!)
  `
});

export interface Friend {
  id: number
  name: string
  age: number
  picture?: Blob
}

```

# Representing Classes instead of Interfaces

In dexie@4 and earlier, we've always had the [Table.mapToClass()](/docs/Table/Table.mapToClass()) method to connect a table to its model class.

In dexie@5 this will be done simply by declaring the schema with `Table(MyClass)` instead of `Table<MyInterface>`:

```ts
export const db = new Dexie('friendsDB').stores({
  friends: Table(Friend)` # Table(Class) instead of Table<Type>
    ++id
    name
    age
  `
});

export class Friend {
  id = 0;
  name = "";
  age = -1;
  picture?: Blob

  birthday() {
    return db.friends.update(this.id, { age: add(1) });
  }
}

```


#### Breaking Changes?

Ever since Dexie version 1 came out, we've been very strict with backward compability and almost never introduced any breaking changes.

To continue this approach, dexie schema declaration will stay backward compatible in dexie@5, so the old declaration style will continue to work. It will be an opt-in possibility to take advantage of the benefits with the new declaration style in dexie 5:

- One single declaration for both schema and typings
- No version number needed
- The class is automatically mapped, just like mapToClass() did work in earlier versions.

### Sub-classing Dexie

```ts
export class AppDB extends Dexie {
  friends = Table(Friend)`
    ++id
    name
    age
  `
}

const db = new AppDB('appDB');
```

The sub-classed version above is equivalent to:

```ts
const db = new Dexie('appDB').stores({
  friends: Table(Friend)`
    ++id
    name
    age
  `
});
```

Subclassing Dexie isn't required anymore for typings but it is still useful the declared class extends the `Entity` helper because it will have the properties `db` and `table` so that methods can perform operations on the database:

```ts
class Friend extends Model<AppDB> {
  id!: string;
  name!: string;
  age!: number;

  // methods can access this.db because we're subclassing Entity<AppDB>
  async birthDay() {
    return this.db.friends.update(this.id, { age: add(1) });
  }
}
```

Notice that versions aren't needed for schema changes anymore. Here we diverge from native IndexedDB that require this. As already introduced in dexie@4, we work around it letting the declared version and the native version diverge. And when they do, we store the virtual version in a meta table on the database. This table will only be created on-demand, if a schema upgrade on same given version was needed. Basically, we continue working like before, unless the db has the $meta table - in which case the info there will be respected instead of the native one.

Also, any methods in the type will be omitted from the insert type so that if you have a class with methods that backs the model of your table, you will continously be able to add items using plain objects (with methods omitted).

## Migrations

We've changed the view of migrations and version handling. Before the version was directly related to changes in the schema such as added tables or indexes. This was natural and corresponds to how IndexedDB works natively.

The only situations where you need a new version number in dexie@5 will be in one of the following situations:

- You want to rename a table or property
- You've refactored your model and need to move data around to comply with the new model

### New Migration Methods for Rename

Three new methods exists that can be used in migrations instead of update(). These are declarative and revertable, which is much better canary use cases where you might have to downgrade the database without deleting it.

This new bidirectional framework is also compatible with Dexie Cloud since it allows for multiple clients sharing the same data of in different versions and still be able to sync it.

- renameTable()
- renameProperty()
- refactor()

#### Example: You want to rename a table or property or both:

You want to rename table "friends" to "contacts". You also want to rename a property on that model from "name" to "displayName":

```ts
const db = new Dexie('dbName').version(2).stores({
  contacts: Table<Contact>`
    ++id
    displayName
    age
  `
}).renameTable({friends: 'contacts'})
  .renameProperty({contacts: {name: 'displayName'}}); // renaming prop "name" to "displayName"
```

#### object-wise upgrade()

We add a new object-wise upgrade. In contrast to the generic `upgrade()` callback, object-wise upgrades can incrementally upgrade individual objects which makes it perfect for distributed synced databases where some clients may still be on the old version.

If you are on Dexie Cloud, only object-wise upgrades are permitted.

```ts
const db = new Dexie('dbName').version(3).stores({
  contacts: Table<Contact>`
    ++id
    [lastName+firstName]
    age
    `
}).upgrade({
  contacts: (contactV2: ContactV2) => {
    // Split displayName into firstName and lastName:
    const [firstName, ...lastNames] = contactV2.displayName?.split(' ') ?? [];
    const contact: Contact = {
      ...contactV2,
      firstName,
      lastName: lastNames?.join(' ')
    };
    return contact;
  }
});


// Keep the refactoring history of earlier versions in separate expression declared later:
db.version(2)
  .renameTable({friends: 'contacts'})
  .renameProperty({contacts: {name: 'displayName'}});
```

# Richer Queries

Dexie will support combinations of criterias within the same collection and support a subset of mongo-style queries. Dexie has before only supported queries that are fully utilizing at least one index. Where-clauses only allow fields that can be resolved using a plain or compound index. And `orderBy()` requires an index for ordering, making it impossible to combine with a critera, unless the criteria uses the same index. Currently, combining index-based and 'manual' filtering is possible using filter(), but it puts the burden onto the developer to determine which parts of the query that should utilize index and which parts should not. Dexie 5.0 will move away from this limitation and allow any combination of criterias within the same query. Resolving which parts to utilize index will be decided within the engine.

`orderBy()` will be available on Collection regardless of whether the current query already 'occupies' an index or not. It will support multiple fields including non-indexed ones, and allow to specify collation.

```ts
await db.friends
  .where({
    name: 'foo',
    age: { between: [18, 65] },
    'address.city': { startsWith: 'S' }
  })
  .orderBy(['age', 'name'])
  .offset(50)
  .limit(25)
  .toArray();
```

# Improved Paging

The cache will assist in improving paging. The caller will keep using offset()/limit() to do its paging. The difference will be that the engine can optimize an offset()-based query in case it starts close to an earlier query with the same criteria and order, so the caller will not need to use a new paging API

# Encryption

We will provide a new encryption addon, similar to the 3rd part [dexie-encrypted](https://github.com/mark43/dexie-encrypted) and [dexie-easy-encrypt](https://github.com/jaetask/dexie-easy-encrypt) addons. These addons will continue to work with dexie@5 but due to the lack of maintainance of we believe there's a need to have a maintained addon for such an important feature.

The syntax for initializing encryption is not yet decided on, but might not correspond to those of the current 3rd part addons.

# Support SQLite as backing DB

We also aim to make it possible to use Dexie and Dexie Cloud in react-native, nativescript, Node, Bun, Deno or in the browser with SQLite's webassembly build. Running Dexie on Node is actually already possible using [IndexedDBShim](https://www.npmjs.com/package/indexeddbshim) but the idea is to support it natively to improve performance and stability.

# Breaking Changes

## No default export

We will stop exporting Dexie as a default export as it is easier to prohibit [dual package hazard](https://github.com/GeoffreyBooth/dual-package-hazard) when not exporting both named and default exports. Named exports have the upside of enabling tree shaking so we prefer using that only.

Already since Dexie 3.0, it has been possible to import { Dexie } as a named export. To prepare for Dexie 5.0, it can be wise to change your imports from `import Dexie from 'dexie'` to `import { Dexie } from 'dexie'` already today.

## More to come

Dexie has been pretty much backward compatible between major versions so far and the plan is to continue being backward compatible as much as possible. But there might be additional breaking changes to come and they will be listed here. This is a living document. Subscribe to our [github discussions](https://github.com/dexie/Dexie.js) or to the [blog](https://medium.com/dexie-js) if you want to get notified on updates.

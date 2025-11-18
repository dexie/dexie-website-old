---
layout: docs
title: 'Typescript (old)'
---

See [Typescript](an updated doc) on how to use dexie with Typescript. Both ways are valid.

This is a guide on how to use Dexie with Typescript.

**[To see it in action, watch this stackblitz sample!](https://stackblitz.com/edit/typescript-dexie-appdemo?file=index.ts)**

## Download and install dexie

```bash
npm install dexie
```

## Import dexie

```ts
import Dexie from 'dexie';
```

Assuming you have moduleResolution: "node" in your tsconfig, this will work out-of-the-box. **Don't use tsd (DefinitelyTyped)** because we bundle dexie.d.ts with our npm package and tsc compiler will understand how to find it (it reads "typings" from package.json).

## Create a Subclass

```typescript
class MyAppDatabase extends Dexie {
  // Declare implicit table properties.
  // (just to inform Typescript. Instantiated by Dexie in stores() method)
  contacts!: Dexie.Table<IContact, number>; // number = type of the primkey
  //...other tables goes here...

  constructor() {
    super('MyAppDatabase');
    this.version(1).stores({
      contacts: '++id, first, last'
      //...other tables goes here...
    });
  }
}

interface IContact {
  id?: number;
  first: string;
  last: string;
}
```

Here's why you need a sub class.

In vanilla javascript, when defining the database schema you get implicit table properties that are not detected with Typescript since they are defined runtime. The following line would not compile in typescript:

```javascript
var db = new Dexie('MyAppDatabase');
db.version(1).stores({ contacts: 'id, first, last' });
db.contacts.put({ first: 'First name', last: 'Last name' }); // Fails to compile
```

This can be worked around by using the [Dexie.table()](</docs/Dexie/Dexie.table()>) static method:

```typescript
db.table('contacts').put({ first: 'First name', last: 'Last name' });
```

However, this is not just cumbersome but will also give you bad intellisense and type safety for the objects and primary keys you are working with.

Therefore, in order to gain the best code completion, it is recommended to define a typescript class that extends [Dexie](/docs/Dexie/Dexie) and defines the [Table](/docs/Table/Table) properties on it as shown in the sample below. Here's a sample with some more tables.

```typescript
export class MyAppDatabase extends Dexie {
  contacts!: Dexie.Table<IContact, number>;
  emails!: Dexie.Table<IEmailAddress, number>;
  phones!: Dexie.Table<IPhoneNumber, number>;

  constructor() {
    super('MyAppDatabase');

    //
    // Define tables and indexes
    // (Here's where the implicit table props are dynamically created)
    //
    this.version(1).stores({
      contacts: '++id, first, last',
      emails: '++id, contactId, type, email',
      phones: '++id, contactId, type, phone'
    });
  }
}

// By defining the interface of table records,
// you get better type safety and code completion
export interface IContact {
  id?: number; // Primary key. Optional (autoincremented)
  first: string; // First name
  last: string; // Last name
}

export interface IEmailAddress {
  id?: number;
  contactId: number; // "Foreign key" to an IContact
  type: string; // Type of email such as "work", "home" etc...
  email: string; // The email address
}

export interface IPhoneNumber {
  id?: number;
  contactId: number;
  type: string;
  phone: string;
}
```

## Storing real classes instead of just interfaces

In the sample above, you only inform the typescript engine about how the objects in the database looks like. This is good for type safety code completion. But you could also work with real classes so that the objects retrieved from the database will be actual instances of the class you have defined in typescript. This is simply accomplished by using [Table.mapToClass()](</docs/Table/Table.mapToClass()>). You will then go a step further and map a Typescript class to a table, so that it may have methods and computed properties.

```typescript
/* This is a 'physical' class that is mapped to
 * the contacts table. We can have methods on it that
 * we could call on retrieved database objects.
 */
export class Contact implements IContact {
  id: number;
  first: string;
  last: string;
  emails: IEmailAddress[];
  phones: IPhoneNumber[];

  constructor(first: string, last: string, id?: number) {
    this.first = first;
    this.last = last;
    if (id) this.id = id;
  }

  loadEmailsAndPhones() {
    return Promise.all(
      db.emails
        .where('contactId')
        .equals(this.id)
        .toArray((emails) => (this.emails = emails)),
      db.phones
        .where('contactId')
        .equals(this.id)
        .toArray((phones) => (this.phones = phones))
    ).then((x) => this);
  }

  save() {
    return db.transaction('rw', db.contacts, db.emails, db.phones, () => {
      return Promise.all(
        // Save existing arrays
        Promise.all(this.emails.map((email) => db.emails.put(email))),
        Promise.all(this.phones.map((phone) => db.phones.put(phone)))
      ).then((results) => {
        // Remove items from DB that is was not saved here:
        var emailIds = results[0], // array of resulting primary keys
          phoneIds = results[1]; // array of resulting primary keys

        db.emails
          .where('contactId')
          .equals(this.id)
          .and((email) => emailIds.indexOf(email.id) === -1)
          .delete();

        db.phones
          .where('contactId')
          .equals(this.id)
          .and((phone) => phoneIds.indexOf(phone.id) === -1)
          .delete();

        // At last, save our own properties.
        // (Must not do put(this) because we would get
        // redundant emails/phones arrays saved into db)
        db.contacts
          .put(new Contact(this.first, this.last, this.id))
          .then((id) => (this.id = id));
      });
    });
  }
}
```

As shown in this sample, Contact has a method for resolving the foreign collections emails and phones into local array properties. It also has a save() method that will translate changes of the local arrays into database changes. These methods are just examples of a possible use case of class methods in database objects. In this case, I chose to write methods that are capable of resolving related objects into member properties and saving them back to database again using a relational pattern.

To inform Dexie about the table/class mapping, use [Table.mapToClass()](</docs/Table/Table.mapToClass()>). This will make all instances returned by the database actually being instances of the Contact class with a proper prototype inheritance chain.

```typescript
db.contacts.mapToClass(Contact);
```

## async and await

Async functions works perfectly well with Dexie as of v2.0.

```javascript
await db.transaction('rw', db.friends, async () => {
  // Transaction block
  let numberOfOldFriends = await db.friends.where('age').above(75).toArray();
});
```

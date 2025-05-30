---
layout: docs
title: 'Compound Index'
---

A compound (or composite) index is an index based on several keypaths. It can be used to efficiently index multiple properties in one index to easily find the existance of the combination of two keys and their values.

In Dexie, a compound index must be specified when defining the schema:

```javascript
var db = new Dexie('dbname');
db.version(1).stores({
    people: 'id, [firstName+lastName]'
});
```

In the above sample, records containing valid keys in the *firstName* and *lastName* properties will be indexed. If having stored an object with properties `{firstName: 'foo', lastName: 'bar'}`, it can be efficiently looked up using:

```javascript
db.people.where('[firstName+lastName]').equals(['foo', 'bar'])
```

...which can also be expressed as:

```javascript
db.people.where({firstName: 'foo', lastName: 'bar'})`
```

The latter version is a special case that only works in Dexie >=2.0 and that can match by multiple properties, no matter whether your browser supports compound queries or not.

## Sample

```javascript
async function playWithCompoundIndex() {

    // Store person
    await db.people.put({
        id: 1,
        firstName: 'foo',
        lastName: 'bar'
    });
    
    // Query person:
    const fooBar = await db.people.where({
      firstName: 'foo',
      lastName: 'bar'
    }).first();
    
    // Show result
    console.log ("Foobar: ", fooBar.id, fooBar.firstName, fooBar.lastName);
}

```

## How Compound Index Works
A compound index can be viewed as the index of a concatenation of two properties. They are expressed as "[prop1+prop2]" both when declaring them and when referring to them in where()-clauses. But when expecting a compound value, an array is expected, as compound keys are represented by arrays in IndexedDB. 

## Matching First Part Only
To find all friends with `firstName='foo'` but has an arbitrary lastName, we actually do not need to use a normal index - a compound index who's first part is 'firstName' can also perform this query. For the compound index '[firstName+lastName]', the query should be expressed as follows:

```javascript
db.people
  .where('[firstName+lastName]').between(
    ["foo", Dexie.minKey],
    ["foo", Dexie.maxKey])
  .toArray();
```
Dexie also emulates plain indexes from every compound index (without actually adding them to indexedDB) acting as a representation for partial parts of the index so you can do the following query:

```js
var db = new Dexie('dbname');
db.version(1).stores({
    people: 'id, [firstName+lastName]'
});
db.people
  .where('firstName') // "firstName" is a virtual index that you get for free
  .equals("Foo")
  .toArray();
```

Note that only the leading parts of a compound index can be used alone - never the trailing parts. This is the same rule for any BTree database with compisite index support. You cannot use the compound index [firstName+lastName] to search for lastName only, but you can use it to search firstName only. 

Virtual indexes have the full support for any operation, just like ordinary indexes, such as equalsIgnoreCase(), anyOf(), etc.

## Matching Multiple Values

To find specific people using both their first and last name, we can use [WhereClause.anyOf()](/docs/WhereClause/WhereClause.anyOf()). This allows us to have multiple criteria for the properties that are part of the compound index. The syntax should be as follows:

```javascript
db.people
  .where('[firstName+lastName]').anyOf([
    ["Foo", "Bar"],
    ["Baz", "Qux"]
  ]).toArray();
```

This will yield both "Foo Bar" and "Baz Qux".

# Compound Primary Key

A primary key can also be compound in the same manner as indexes. However, a compound primary key cannot be auto-incremented since it is a combined array of multiple properties.

```javascript
const db = new Dexie('dbname');
db.version(1).stores({
    people: '[firstName+lastName], ...'
});
```

The above sample uses a compound primary key containing two properties: firstName and lastName.

## Compound Type is Array
Compound keys are represented by arrays of the contained properties. This means that in methods where a key is expected, you should provide an array key:

```js
const db = new Dexie('compoundDemo');
db.version(1).stores({
  people: '[firstName+lastName]'
});

db.people.put({
  firstName: "Anna",
  lastName: "Larsson"
}).then(() => {
  // Key arguments should be the compound array:
  return db.people.get(["Anna", "Larsson"]);
}).then(anna => {
  // For Table.get(), it is also possible to use object queries:
  return db.people.get({
    firstName: "Anna",
    lastName: "Larsson"
  });
}).then(anna => {
  console.log(anna);
}).then(()=>{
  // Provide Array to Table.update():
  return db.people.update(["Anna", "Larsson"], { foo: "bar" });
}).catch(console.error);

```

# Using with orderBy()

If an index is compound using "[firstName+lastName]", [Table.orderBy()](/docs/Table/Table.orderBy()) will sort the contents based on firstName first and lastname secondary. Reverse the order of the compound entries to sort by lastName first. The sorting does not only apply when using "orderBy()" but also when using a [WhereClause](/docs/WhereClause/WhereClause) targeting the compound index, such as:


```javascript
db.version(x).stores({
    people: '++id, [lastName+firstName]'
});

db.people.where('[lastName+firstName]').between(['A', ''], ['B','']).toArray();
```

The above query will list all people who has a lastName starting with letter 'A'. Result will be sorted by lastName first and firstName secondly when people have the same lastName but different firstName. Notice that you cannot use that compound key to sort by firstName first. Must add another index with a reversed order of the properties to accomplish that. Notice also that if any person lacks either of the properties, it will not be contained in the result. Compound indexes will only index objects that has valid keys for all contained keypaths.

# Multiple Combinations 

If your app needs to support several ways of sorting, you can add several combinations of the same properties, thus adding several indexes based on different combinations of the order of your properties.

```javascript
db.version(x).stores({
    // Sorting by either prop
    people: `
      ++id,
      [firstName+lastName],
      [lastName+firstName]`
});

// Dexie makes it possible to utilize parts of
// compound indexes as if they were full indexes, with the side
// effect of sorting by the trailing property, the above
// declaration enables the following queries:

// Get all Annas, order by lastname.
db.people.where({firstName: "Anna"}).toArray() 

// Get all Larsons, order by firstName.
db.people.where({lastName: "Larson"}).toArray()

// Get Anna Larson:
db.people.where({
  firstName: "Anna",
  lastName: "Larson"
});

// Get all Anna L*. Order by lastName:
db.people
  .where('[firstName+lastName]')
  .between(
    ["Anna", "L"],
    ["Anna", "L\uffff"] 
  ).toArray(); 

// Get all people, order by firstName, lastName
db.people.orderBy("[firstName+lastName]").toArray();

// Get all people, order by lastName, firstName
db.people.orderBy("[lastName+firstName]").toArray();

```


---
layout: docs
title: 'Table.upsert()'
---

_Since 4.2.1_

Updates an existing object in the object store with the given changes, or creates a new object if it doesn't exist

### Syntax

```javascript
table.upsert(key, changes);
```

### Parameters

<table>
<tr><td>key</td><td>Primary key</td></tr>
<tr><td>changes</td><td>Object containing the key paths to each property you want to change.</td></tr>
</table>

### Return Value

A [Promise](/docs/Promise/Promise) with a boolean: true if object was created or false if an existing object was updated.

### Remarks

If object exists, upsert() behaves like [Table.update()](</docs/Table/Table.update()>).

If object doesn't exist, upsert() behaves like [Table.add()](</docs/Table/Table.add()>).

The difference between _upsert()_ and _put()_ is that _upsert()_ will only apply the given changes to the object (or to a new empty object) while _put()_ will replace the entire object.

The difference between _upsert()_ and _update()_ is that _upsert()_ will create a new object if the key is not found, while _update()_ will not change anything if object isn't found.

When creating a new object:

- An empty object is created
- The given changes are applied to this empty object
- If the table has an inbound primary key, it will be set to the provided key value
- The object is then inserted into the store

### Sample

```javascript
db.friends.upsert(2, { name: 'Number 2' }).then((wasCreated) => {
  console.log(`Friend was ${wasCreated ? 'created' : 'updated'}`);
});
```

```javascript
// If 'id' is the primary key and inbound
db.friends.upsert(2, { name: 'Number 2' }).then((wasCreated) => {
  // If friend with id=2 exists: updates name
  // If friend with id=2 doesn't exist: creates {id: 2, name: "Number 2"}
  console.log(`Friend was ${wasCreated ? 'created' : 'updated'}`);
});
```

### See Also

[Table.update()](</docs/Table/Table.update()>)

[Table.put()](</docs/Table/Table.put()>)

[Collection.modify()](</docs/Collection/Collection.modify()>)

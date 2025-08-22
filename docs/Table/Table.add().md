---
layout: docs
title: 'Table.add()'
---

Adds an object to the object store.

### Syntax

```javascript
table.add(item, [key])
```

### Parameters

<table>
<tr><td>item</td><td>Object to add</td><td></td></tr>
<tr><td>key</td><td>Primary key</td><td><i>optional</i></td></tr>
</table>

### Return Value

[Promise](/docs/Promise/Promise)

### Remarks

Add a given object to the object store. If an object with the same primary key already exists, then the operation will fail and the returned promise [catch()](/docs/Promise/Promise.catch()) callback will be called with the error object. If the operation succeeds, then the returned promise [then()](/docs/Promise/Promise.then()) callback receives the result of the `add` request on the object store, i.e. the `id` of the inserted object.

The optional second *key* argument must only be used if your table uses [outbound keys](/docs/inbound#examples-of-outbound-primary-key). If providing the *key* argument on a table with [inbound](/docs/inbound) keys, then the operation will fail and the returned promise will be a rejection.

### Case for autoIncremented keys

In case the item's primary key is not specified, and the schema specifies it to be auto-incremented, the item's resulting key will be set on the item - this only apply to table.add() and table.put() but not table.bulkAdd() or table.bulkPut().

### See Also

[Table.put()](/docs/Table/Table.put())

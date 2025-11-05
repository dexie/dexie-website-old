---
layout: docs
title: 'Collection.reverse()'
---

### Syntax

```javascript
collection.reverse()
```

### Return Value

This Collection instance (**this**)

### Remarks

No matter if using [sortBy()](/docs/Collection/Collection.sortBy()) or natural sort order ([orderBy](/docs/Table/Table.orderBy()) or a [where()](/docs/Table/Table.where()) clause), this method will reverse the sort order of the collection.

If called twice, the sort order will reset to ascending again.

reverse() is an alias to [desc()](/docs/Collection/Collection.desc()) method. Behaviour is equivalent to the [desc()](/docs/Collection/Collection.desc()) method.

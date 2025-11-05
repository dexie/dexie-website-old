---
layout: docs
title: 'Collection.desc()'
---

### Syntax

    collection.desc()

### Return Value

This Collection instance (**this**)

### Remarks

No matter if using [sortBy()](/docs/Collection/Collection.sortBy()) or natural sort order ([orderBy()](/docs/Table/Table.orderBy()) or a [where()](/docs/Table/Table.where()) clause), this method will reverse the sort order of the collection.

If called twice, the sort order will reset to ascending again.

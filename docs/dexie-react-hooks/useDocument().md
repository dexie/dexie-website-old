---
layout: docs
title: 'useDocument()'
---

# Remarks

Consume an Y.Doc in your component.

# Dependencies

```
npm install react dexie dexie-react-hooks
npm install yjs y-dexie
```

# Syntax

```ts
export function useDocument(
  doc: YDoc | null | undefined
): DexieYProvider | null;
```

# Sample

```ts
import Dexie, { type Table } from 'dexie';
import yDexie from 'y-dexie';
import { useLiveQuery, useDocument } from 'dexie-react-hooks';
import type * as Y from 'yjs';

interface Friend {
  id: string;
  name: string;
  notes: Y.Doc;
  age: number;
}

const db = new Dexie('myDB', { addons: [yDexie] }) as Dexie & {
  friends: Table<Friend, string>;
};

db.version(1).stores({
  friends: `
    id,
    name,
    notes: Y.Doc,
    age`
});

function MyComponent(friendId: string) {
  // Query friend object:
  const friend = useLiveQuery(() => db.friends.get(friendId));

  // Load the document from friend.notes (also if friend is undefined due to "rule of hooks")
  useDocument(friend?.notes);

  if (!friend) return null; // On initial render, friend is undefined.

  // At this point, friend.notes contains an Y.Doc to work with
  const yDoc = friend.notes;
}
```

### Using the returned Provider

The return value of useDocument() is an Y.js provider DexieYProvider that can be passed to child components.
The plain provider handles document loading and updating.

If dexie-cloud-addon is used and a [Dexie Cloud](https://dexie.org/cloud/) database is configured, the provider also supports sync and awareness, which seamlessly integrates with existing [ecosystem](/docs/Y.js/Y.js#the-yjs-ecosystem) of text editors with Y.js support.

```ts
import { useLiveQuery, useDocument } from 'dexie-react-hooks';

function MyComponent(friendId: string) {
  // Query friend object:
  const friend = useLiveQuery(() => db.friends.get(friendId));

  // Use it's notes property (friend is undefined on intial render)
  const provider = useDocument(friend?.notes);

  // Pass provider and document to some Y.js compliant code in the ecosystem of such (unless undefined)...
  return provider ? (
    <NotesEditor doc={friend.notes} provider={provider} />
  ) : null;
}
```

_In the sample above, NotesEditor would be your component that renders and allows editing notes using external 3rd part libraries. See our example application dexie-cloud-starter for examples._

### See Also

[y-dexie](https://github.com/dexie/Dexie.js/blob/master/addons/y-dexie/README.md) - the y-dexie library

[dexie-cloud-starter](https://github.com/dexie/dexie-cloud-starter) - sample application that showcases how to edit, share, sync and search documents using NextJS, dexie, y-dexie, dexie-cloud, tiptap and lunr for full-text-search.

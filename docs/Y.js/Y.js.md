---
layout: docs
title: 'Y.js'
---

## Dexie.js ❤️ Y.js

Dexie supports the powerful CRDT library [Y.js](http://github.com/yjs/yjs) through its add-on [y-dexie](https://www.npmjs.com/package/y-dexie).

## What is Y.js

Y.js is a high-performance CRDT for building collaborative applications that sync automatically. It exposes its internal CRDT model as shared data types that can be manipulated concurrently. Shared types are similar to common data types like Map and Array.

The core type in Y.js is the Y.Doc that holds CRDT data. One of the most powerful use cases of CRDT is collaborative editing of texts and images.

## [y-indexeddb](https://github.com/yjs/y-indexeddb) and [y-dexie](https://github.com/dexie/Dexie.js/tree/master/addons/y-dexie)

y-indexeddb, developed by [Kevin Jahns](https://github.com/dmonad), allows basic persistance of a single Y.Doc in indexedDB. Each document is represented by its own unique IndexedDB database. This implementation acts as a model for persisting Y.Doc updates and works well when only a single or few documents are being used.

y-dexie is an alternative to y-indexeddb that allows structured storage of multiple Y.Docs in a single indexedDB database. It integrates well to existing databases and Y.Docs can be places on existing
database objects (rows) on their own properties of the objects.

| Features                                                   | y-indexeddb | y-dexie |
| ---------------------------------------------------------- | ----------- | ------- |
| Persist single document in browser                         | [x]         | [x]     |
| Garbage collect historical Y.js updates                    | [x]         | [x]     |
| Perist multiple documents in the same database             | [-]         | [x]     |
| Store documents as properties on traditional indexed items | [-]         | [x]     |
| Sync with dexie-cloud                                      | [-]         | [x]     |
| Optimized sync protocol for syncing multiple documents     | [-]         | [x]     |

## The Y.js ecosystem

### Rich-text & code editors

- ProseMirror (base binding y-prosemirror) – the core binding that many others sit on.
- Remirror – first-class Yjs extension (@remirror/extension-yjs)
- Slate – via slate-yjs (actively maintained).
- Lexical – official @lexical/yjs module
- Quill – via official y-quill
- CodeMirror – v5 (y-codemirror) and v6 (y-codemirror.next)
- Monaco – via y-monaco

### Drawing / whiteboard editors

- Excalidraw – community binding y-excalidraw and several starters
- tldraw – examples & packages showing Yjs integration (v1 & v2)

### Diagrams / node-graph editors

- React Flow – official collaborative example powered by Yjs

### Block / document frameworks (Yjs under the hood)

- BlockSuite / AFFiNE – block editor toolkit built on Yjs

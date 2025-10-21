---
layout: docs
title: 'dexie-worker'
---

The npm library [dexie-worker](https://www.npmjs.com/package/dexie-worker) acts as a proxy between the GUI thread and a worker. Instead of talking to the Dexie API, the proxy is used and it will communicate with the Dexie instance that operates in the Worker thread.

```ts
import Dexie from "dexie";
import { getWebWorkerDB } from "dexie-worker";

const db = new Dexie("MyDatabase");
db.version(1).stores({
  products: "++id, name"
});
db.open(); // initializing the database is required
const workerDb = getWebWorkerDB(db);
```
Now, you can use either `db` or `workerDb` depending on where you want the queries to run.

*NOTE: Dexie.js is fully supported in worker environments by itself, without this library. What [dexie-worker](https://www.npmjs.com/package/dexie-worker) does is to offer an easy API to delegate certain heavy queries to execute in a worker using normal dexie queries in the main thread that are delegated to worker under the hood (without having to implement the worker and communications manually).*

[dexie-worker](https://www.npmjs.com/package/dexie-worker) not only supports promise based API but also observables (live queries) - using a slightly adjusted version of [liveQuery](/docs/liveQuery()) and [useLiveQuery](/docs/dexie-react-hooks/useLiveQuery()) that can perform the queries in the worker instead of the GUI thread.

* dexie-worker's [useLiveQuery](https://github.com/parsagholipour/dexie-worker?tab=readme-ov-file#%EF%B8%8F-react-hook-uselivequery)
* dexie-worker's [liveQuery](https://github.com/parsagholipour/dexie-worker?tab=readme-ov-file#custom-live-queries)

Since [dexie-worker](https://www.npmjs.com/package/dexie-worker) mimics the dexie API, it allows app developers to easily switch between executing queries in worker or main thread depending on where it makes most sence.

Github repo: [dexie-worker](https://github.com/parsagholipour/dexie-worker) 


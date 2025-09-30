---
layout: docs
title: "usePermissions()"
---

# Remarks

Observe security permissions for a table and individual objects managed by Dexie Cloud. Use this hook in order to know whether to render certain action buttons depending on what permission the user has to modify the object or add / remove objects.

# Dependencies

```
npm i react dexie dexie-cloud-addon dexie-react-hooks
```

or

```
yarn add react dexie dexie-cloud-addon dexie-react-hooks
```

# Syntax

```ts
export function usePermissions<T>(
  db: Dexie,
  table: string | Table,
  obj: T
): PermissionChecker<T>;

export function usePermissions<T extends DexieCloudEntity>(
  entity: T
): PermissionChecker<T>;

export interface PermissionChecker<T> {
  add(...tableNames: string[]): boolean;
  update(...props: string[]): boolean;
  delete(): boolean;
}
```

| Parameter | Description                                                                                                                                                                                                                                                                                                                                                                       |
| --------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| db        | A Dexie instance with dexie-cloud addon active                                                                                                                                                                                                                                                                                                                                    |
| table     | A table name or Table instance                                                                                                                                                                                                                                                                                                                                                    |
| obj       | An object retrieved from a dexie query                                                                                                                                                                                                                                                                                                                                            |
| entity    | If your table is declared using DexieCloudTable using a `Entity`-derived class mapped to the table using mapToClass(), as exemplified in declaration of the [TodoList](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/src/db/TodoList.ts) class declared in [dexie-cloud-todo-app](https://github.com/dexie/Dexie.js/blob/master/samples/dexie-cloud-todo-app/README.md), you only need to provide a single argument - the entity itself |

# Sample

See dexie-cloud-todo-app's [TodoListView.tsx](https://github.com/dexie/Dexie.js/blob/v4.0.0-alpha.3/samples/dexie-cloud-todo-app/src/components/TodoListView.tsx), [TodoItemView.tsx](https://github.com/dexie/Dexie.js/blob/v4.0.0-alpha.3/samples/dexie-cloud-todo-app/src/components/TodoItemView.tsx) and [TodoDB.ts](https://github.com/dexie/Dexie.js/blob/v4.0.0-alpha.3/samples/dexie-cloud-todo-app/src/db/TodoDB.ts)

```tsx
interface Props {
  // todoList prop comes from query
  // result in parent component.
  todoList: TodoList;
}

function MyComponent({ todoList }: Props) {
  // Retrieve the todo-items
  const items = useLiveQuery(
    () => db.todoItems.where({ todoListId: todoList.id }).toArray(),
    [todoList.id]
  );
  
  // Get the PermissionChecker into a local variable 'can' to be
  // used in the JSX later on:
  const can = usePermissions(db, "todoLists", todoList);  

  return (
    <>
      Title: {todoList.title}
      {can.update("title") && <button onClick={editTitle}>Edit title</button>}
      <button disabled={!can.delete()} onClick={deleteList}>
        Delete list
      </button>
      <ul>
        {items?.map((item) => (
          <li key={item.id}>
            <TodoItem item={item} />
          </li>
        ))}
      </ul>
      {
        can.add("todoItems") && <button onClick={addNewItem}> Add new item </button>
      }
    </>
  );
  
  //
  // Actions
  //

  function editTitle() {
    // ...launch a dialog to edit title
  }
  function addNewItem() {
    // ...launch a dialog to add a new todo-item
  }
  function deleteList() {
    return db.transaction(
      "rw",
      [db.todoLists, db.todoItems, db.realms, db.members],
      () => {
        // Delete all related data:
        db.todoItems.where({ todoListId: todoList.id }).delete();
        db.todoLists.delete(todoList.id);
        const tiedRealmId = getTiedRealmId(todoList.id);
        db.members.where({ realmId: tiedRealmId }).delete();
        db.realms.delete(tiedRealmId);
      }
    );
  }
  
}
```

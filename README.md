# `atuin-stand`

> "stand" - a contiguous community of trees sufficiently uniform in composition, structure, age, size, class, distribution, spatial arrangement, condition, or location on a site of uniform quality to distinguish it from adjacent communities

`atuin-stand` is a set of libraries that implement a generic, ordered tree. The API and data format is designed to be consistent across all the implementations.

Currently, there are implementations for:

* TypeScript - [ package, docs ]
* Rust - [ package, docs ]
* Elixir - [ [package](https://hex.pm/packages/atuin_stand), [docs](https://hexdocs.pm/atuin_stand/AtuinStand.html) ]

Please see the documentation for each specific implementation for installation and usage instructions.

## Examples

### TypeScript

```typescript
const tree = new Tree();
const root = tree.root();
root.id(); // => Symbol(ROOT)
const child = root.createChild("id1").setData(someData);
child.id(); // => "id1"
const child2 = child.createChild("id2").setData(otherData);
child.getData(); // => someData
```

### Rust

```rust
let tree = Tree::new();
let root = tree.root();
root.id(); // => NodeID::Root
let child = root.create_child("id1").set_data(some_data);
child.id(); // => NodeID::id("id1");
let child2 = child.create_child("id2").set_data(other_data);
child.get_data(); // => some_data
```

### Elixir

```elixir
alias AtuinStand.Tree
alias AtuinStand.Node

tree = Tree.new()
root = Tree.root(tree)
root.id # => :root
child = Node.create_child(root, "id1") |> Node.set_data(some_data)
child.id # => "id1"
child2 = Node.create_child(child, "id2") |> Node.set_data(other_data)
Node.get_data(child) # => some_data
```

## API Overview

Each library supports the following operations, although the exact API varies slightly based on language idioms and other factors.

### Tree

* `getRoot()` - get the root node
* `hasNode(id)` - check if a node exists in the tree
* `getNode(id)` - fetch a node by its ID
* `getLeaves()` - get a list of all the leaf (external) nodes
* `getBranches(order)` - get a list of all the branch (internal) nodes
* `size()` - return the number of nodes in the tree
* `onChange()` - subscribe to changes in the tree

### Node

* `tree()` - get access to the underlying tree object
* `createChild(id, index?)` - create a node with this node as a parent at the given index
* `id()` - return the ID for the node
* `setData()` - associate some data with a node
* `getData()` - fetch the associated data from a node
* `root()` - get the root node of the tree this node is in
* `parent()` - get this node's parent
* `children()` - get a list of this node's children
* `siblings()` - get a list of all the other nodes with the same parent as this node
* `ancestors()` - get a list of nodes from this node to the root of the tree
* `descendents(order)` - get a list of all child nodes of this node, recursively, in the given traversal order
* `depth()` - a count of a node's ancestors
* `moveTo(other, index?)` - move this node so its parent is now `other`, placed at the given index
* `moveBefore(other)` - move this node to be the sibling immediately preceeding `other`
* `moveAfter(other)` - move this node to be the sibling immediately after `other`
* `reposition(node, index)` - move this node to a different location amongst its siblings
* `delete(strategy)` - delete this node, specifying what to do with its children

### Tree Traversal

Each implementation provides a way to traverse the nodes of the tree in either depth-first or breadth-first order. The API for this varies depending on the language:

* TypeScript: `Iterator` and `Iterable`
* Rust: `Iterator`
* Elixir: `Enumberable`

### Deleting Nodes

Whenever you want to delete a node from the tree, you must decide what to do with its children (if it has any):

* `Refuse` - produce an error if the node has any children
* `Cascade` - delete the nodes children and all their children, recursively
* `Reattach` - attach this node's children to this node's parent before deleting it

## Serialization and Deserialization

Each implementation is designed so that data from one can be imported to another. For this reason, data is limited to information that can be serialized to JSON.

The exact type varies per language, but in general, the data format looks like this:

```
type Tree<UserData> = Map<String, TreeNode<UserData>>

type TreeNode<UserData> = {
  id: String,
  parent: String | null,
  data: UserData | null,
  index: Number
}
```

Serialization and deserialization is handled differently per implementation:

* Rust: `serde_json`
* TypeScript: exports as an object, use `JSON` or any other JSON library for serialization
* Elixir: exports as a map, use Elixir's `JSON` or any other JSON library for serialization

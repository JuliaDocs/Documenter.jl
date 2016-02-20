
<a id='internal-documentation'></a>
# Internal Documentation


<a id='lapidarycar' href='#lapidarycar'>#</a>
**Function**

```
car(x)
```

Head element of the `Tuple` `x`. See also [`cdr`](internals.md#lapidarycdr).

---

<a id='lapidarycdr' href='#lapidarycdr'>#</a>
**Function**

```
cdr(x)
```

Tail elements of the `Tuple` `x`. See also [`car`](internals.md#lapidarycar).

---

<a id='lapidaryassetsdirtuple' href='#lapidaryassetsdirtuple'>#</a>
**Method**

```
assetsdir()
```

Directory containing Lapidary asset files.

---

<a id='lapidarycurrentdirtuple' href='#lapidarycurrentdirtuple'>#</a>
**Method**

```
currentdir()
```

Returns the current source directory. When `isinteractive() ≡ true` then the present working directory, `pwd()` is returned instead.

---

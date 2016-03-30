* D E F
* A B C

`E.insertAfter(B) ->`

* D F
* A B E C

* B
  * _next_ = C
  * prev = A

* C
 * next = null
 * _prev_ = B

* E
 * _next_ = F
 * _prev_ = D
 * _parent_ = ???

* D
 * _next_ = E
 * _prev_ = F

* F
  * next = null
  * _prev_ = E

italic properties must change.

```D
// first, fix old nodes.
if(E == E.parent.firstChild) // nope
  // E.prev must be null if this is true, short circuit logic?
  E.parent.firstChild = E.next;
if(E == E.parent.lastChild) // nope
  // E.next must be null if this is true, short circuit logic?
  E.parent.lastChild = E.prev;
if(E.next) // F
  E.next.prev = E.prev;
if(E.prev) // D
  E.prev.next = E.next;
// insertBefore is an exact mirror of this beyond this point, and identical before.
// the links on E are free to scram now
E.prev = B;
E.next = B.next;

// now, set links to E

if(B.next) // C
  B.next.prev = E;
B.next = E;
```

in addition to setting, 
Any time you set next, you have to check old.next.prev, and old.parent.lastChild
- insertAfter
- also insertBefore for setting dest.next
Any time you set prev, you have to check old.prev.next, and old.parent.firstChild
- insertBefore
- also insertAfter, for setting dest.prev
Any time you set parent, you have to check old.parent.firstChild and old.parent.lastChild
- ??? insertChild? probably never do this. below will both be needed
Any time you set firstChild you have to check old.parent.firstChild (set it to new.next, set it.prev = new)
- appendChild
Any time you set lastChild, you have to check old.parent.lastChild
- prependChild

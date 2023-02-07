type list('a)(p : 'a => 'a => bool) =
  | Nil
  | Cons(x:'a, list('a[v|p x v])((x1:'a, x2:'a) => p x1 x2))
  ;

/* type incList('a) = list('a)((x1, x2) => x2 <= x2) */

/*@ val checkInc : 'a => list('a)((u1:'a, u2:'a) => u1 <= u2) */
let checkInc = (x) => {
  let n = Nil;
  let x1 = x+1;
  let x2 = x+2;
  let n1 = Cons(x2, n);
  let n2 = Cons(x1, n1);
  Cons (x, n2)
};

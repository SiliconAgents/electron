# The macro rewritten in its header, the file only +incdir+ reaches.
PATCHES = [
    ("flop_macros.svh",
     r"always_ff @\(posedge C or posedge R\) Q <= R \? V : D;",
     r"always_ff @(posedge C or posedge R) if (R) Q <= V; else Q <= D;",
     "async reset as a ternary, in a header"),
]

1 L=1000 # change number of iterations here
10 TI$="000000"
15 A$=""
20 FOR I=1 TO L
30   A$=A$+"A"
35   IF LEN(A$) = 255 THEN A$=""
40 NEXT I
50 T=TI/60
60 LN = LEN(A$)
70 PRINT LN;",";T;",";S
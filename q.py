a = [1, 1, 3, 4, 5]
b = []
for i in a:
    if i not in b:
        b.append(i)

print(b)
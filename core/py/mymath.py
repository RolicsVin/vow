def add(a, b=0):
    return sum([a + b for _ in range(10_000)])

def slow_square(x):
    return x * x
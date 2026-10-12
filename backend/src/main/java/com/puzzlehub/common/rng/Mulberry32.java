package com.puzzlehub.common.rng;

import java.util.List;

/** Deterministic 32-bit PRNG shared bit-for-bit with the app (see docs/CONTRACT.md §2). */
public final class Mulberry32 {

    private int state;

    public Mulberry32(long seed) {
        this.state = (int) seed;
    }

    /** Next value as an unsigned 32-bit integer. */
    public long next() {
        state += 0x6D2B79F5;
        int a = state;
        int t = (a ^ (a >>> 15)) * (1 | a);
        t = (t + ((t ^ (t >>> 7)) * (61 | t))) ^ t;
        return Integer.toUnsignedLong(t ^ (t >>> 14));
    }

    public int nextInt(int bound) {
        if (bound <= 0) throw new IllegalArgumentException("bound must be positive");
        return (int) (next() % bound);
    }

    public <T> void shuffle(List<T> list) {
        for (int i = list.size() - 1; i > 0; i--) {
            int j = nextInt(i + 1);
            T tmp = list.get(i);
            list.set(i, list.get(j));
            list.set(j, tmp);
        }
    }

    public void shuffle(int[] arr) {
        for (int i = arr.length - 1; i > 0; i--) {
            int j = nextInt(i + 1);
            int tmp = arr[i];
            arr[i] = arr[j];
            arr[j] = tmp;
        }
    }
}

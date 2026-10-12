package com.puzzlehub.common.rng;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import java.util.Arrays;

import static org.assertj.core.api.Assertions.assertThat;

class Mulberry32Test {

    @ParameterizedTest
    @CsvSource(delimiter = '|', value = {
            "0|1144304738,1416247,958946056,627933444,2007157716",
            "1|2693262067,11749833,2265367787,4213581821,4159151403",
            "42|2581720956,1925393290,3661312704,2876485805,750819978",
            "20261011|1488163886,3496767163,2460547021,1222184908,208299103"})
    void matchesContractVectors(long seed, String expected) {
        Mulberry32 rng = new Mulberry32(seed);
        long[] actual = new long[5];
        for (int i = 0; i < 5; i++) actual[i] = rng.next();
        assertThat(actual).containsExactly(Arrays.stream(expected.split(",")).mapToLong(Long::parseLong).toArray());
    }

    @ParameterizedTest
    @CsvSource({"0", "7", "123456"})
    void nextIntStaysInBounds(long seed) {
        Mulberry32 rng = new Mulberry32(seed);
        for (int i = 0; i < 10_000; i++) assertThat(rng.nextInt(13)).isBetween(0, 12);
    }
}

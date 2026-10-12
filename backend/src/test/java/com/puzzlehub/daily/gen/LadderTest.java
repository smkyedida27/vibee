package com.puzzlehub.daily.gen;

import com.puzzlehub.catalog.Difficulty;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.EnumSource;

import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.assertj.core.api.Assertions.assertThat;

class LadderTest {

    static final List<String> DICT = List.of("CARD", "CARE", "CART", "COLD", "CORD", "CORE", "WARD", "WARM", "WORD",
            "WORM", "BOLD", "BOND", "FOND", "FORD", "WARE", "WORE", "BORE", "BARE", "BARN", "WARN");
    static final Set<String> WORDS = new HashSet<>(DICT);

    @ParameterizedTest
    @EnumSource(value = Difficulty.class, names = {"EASY", "MEDIUM"})
    void parIsShortestDistance(Difficulty d) {
        Map<String, Object> c = Ladder.generate(d, 7, DICT, WORDS);
        Map<String, Integer> dist = Ladder.bfs((String) c.get("start"), WORDS);
        assertThat(dist.get((String) c.get("target"))).isEqualTo(c.get("par")).isEqualTo(Ladder.distanceFor(d));
    }

    @org.junit.jupiter.api.Test
    void oneLetterApart() {
        assertThat(Ladder.oneLetterApart("COLD", "CORD")).isTrue();
        assertThat(Ladder.oneLetterApart("COLD", "COLD")).isFalse();
        assertThat(Ladder.oneLetterApart("COLD", "CARD")).isFalse();
    }
}

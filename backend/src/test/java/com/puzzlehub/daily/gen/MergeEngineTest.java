package com.puzzlehub.daily.gen;

import org.junit.jupiter.api.Test;

import java.lang.reflect.Field;

import static org.assertj.core.api.Assertions.assertThat;

class MergeEngineTest {

    private static void set(MergeEngine e, int[] cells) throws Exception {
        Field f = MergeEngine.class.getDeclaredField("cells");
        f.setAccessible(true);
        System.arraycopy(cells, 0, (int[]) f.get(e), 0, cells.length);
    }

    @Test
    void initialSpawnMatchesContractSequence() {
        // seed 42: next()=2581720956 %16 = 12 -> 2nd value 1925393290 %10 = 0 -> 4; then 3661312704 %15 = 9, 2876485805 %10 = 5 -> 2
        MergeEngine e = new MergeEngine(4, 42);
        int[] cells = e.cells();
        assertThat(cells[12]).isEqualTo(4);
        assertThat(cells[9]).isEqualTo(2);
        assertThat(java.util.Arrays.stream(cells).filter(v -> v != 0).count()).isEqualTo(2);
    }

    @Test
    void eachTileMergesOncePerMoveWithWallPriority() throws Exception {
        MergeEngine e = new MergeEngine(4, 1);
        set(e, new int[]{2, 2, 2, 2, 2, 2, 2, 0, 4, 4, 8, 8, 0, 0, 0, 0});
        assertThat(e.move('L')).isTrue();
        int[] c = e.cells();
        assertThat(new int[]{c[0], c[1], c[2], c[3]}).containsExactly(4, 4, 0, 0);
        assertThat(new int[]{c[4], c[5]}).containsExactly(4, 2);
        assertThat(new int[]{c[8], c[9], c[10], c[11]}).containsExactly(8, 16, 0, 0);
        assertThat(e.score()).isEqualTo(4 + 4 + 4 + 8 + 16);
    }

    @Test
    void rightMergePrefersRightWall() throws Exception {
        MergeEngine e = new MergeEngine(4, 1);
        set(e, new int[]{2, 2, 2, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0});
        e.move('R');
        int[] c = e.cells();
        assertThat(c[2]).isEqualTo(2);
        assertThat(c[3]).isEqualTo(4);
    }

    @Test
    void noOpMoveDoesNotSpawn() throws Exception {
        MergeEngine e = new MergeEngine(4, 1);
        set(e, new int[]{2, 4, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0});
        assertThat(e.move('L')).isFalse();
        assertThat(java.util.Arrays.stream(e.cells()).filter(v -> v != 0).count()).isEqualTo(2);
    }

    @Test
    void replayIsDeterministic() {
        String moves = "LURD".repeat(300);
        MergeEngine.Outcome a = MergeEngine.replay(4, 123456789L, 2048, moves);
        MergeEngine.Outcome b = MergeEngine.replay(4, 123456789L, 2048, moves);
        assertThat(a).isEqualTo(b);
        assertThat(a.score()).isPositive();
    }

    @Test
    void reachingTargetIsSolved() {
        MergeEngine.Outcome o = MergeEngine.replay(4, 42, 8, "LURDLURDLURDLURD".repeat(4));
        assertThat(o.reachedTarget()).isTrue();
        assertThat(o.maxTile()).isGreaterThanOrEqualTo(8);
    }
}

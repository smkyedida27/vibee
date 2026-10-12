package com.puzzlehub.attempts;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.puzzlehub.catalog.Difficulty;
import com.puzzlehub.catalog.GameType;
import com.puzzlehub.content.ContentRepository;
import com.puzzlehub.daily.Puzzle;
import com.puzzlehub.daily.gen.Queens;
import com.puzzlehub.daily.gen.Sudoku;
import org.junit.jupiter.api.Test;

import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

class SubmissionValidatorTest {

    static final ObjectMapper M = new ObjectMapper();
    static final JsonNode CONNECT = json("""
            {"words":["A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P"],
             "groups":[{"title":"1","level":0,"words":["A","B","C","D"]},{"title":"2","level":1,"words":["E","F","G","H"]},
                       {"title":"3","level":2,"words":["I","J","K","L"]},{"title":"4","level":3,"words":["M","N","O","P"]}]}""");

    static JsonNode json(String s) {
        try {
            return M.readTree(s);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    final SubmissionValidator validator;

    SubmissionValidatorTest() throws Exception {
        validator = new SubmissionValidator(new ContentRepository(M));
    }

    private Evaluation eval(GameType t, JsonNode content, String submission) {
        return validator.evaluate(new Puzzle(UUID.randomUUID(), t, Difficulty.EASY, 1, 1, "x", "ACTIVE", content), json(submission));
    }

    @Test
    void connectSolvedWithMistakesAndIgnoresRepeatedWrongGuess() {
        Evaluation e = eval(GameType.CONNECT, CONNECT, """
                {"guesses":[["A","B","C","E"],["C","B","A","E"],["D","C","B","A"],["E","F","G","H"],["I","J","K","L"],["P","O","N","M"]]}""");
        assertThat(e.result()).isEqualTo(Result.SOLVED);
        assertThat(e.mistakes()).isEqualTo(1);
    }

    @Test
    void connectFailsOnFourthMistake() {
        Evaluation e = eval(GameType.CONNECT, CONNECT, """
                {"guesses":[["A","B","C","E"],["A","B","C","F"],["A","B","C","G"],["A","B","C","H"],["A","B","C","D"]]}""");
        assertThat(e.result()).isEqualTo(Result.FAILED);
        assertThat(e.mistakes()).isEqualTo(4);
    }

    @Test
    void connectRejectsUnknownWordsAndBadShapes() {
        assertThat(eval(GameType.CONNECT, CONNECT, "{\"guesses\":[[\"A\",\"B\",\"C\",\"Z\"]]}").result()).isEqualTo(Result.INVALID);
        assertThat(eval(GameType.CONNECT, CONNECT, "{\"guesses\":[[\"A\",\"A\",\"B\",\"C\"]]}").result()).isEqualTo(Result.INVALID);
        assertThat(eval(GameType.CONNECT, CONNECT, "{\"guesses\":\"nope\"}").result()).isEqualTo(Result.INVALID);
    }

    @Test
    void sudokuValidatesGridAndGivens() {
        var c = M.valueToTree(Sudoku.generate(Difficulty.EASY, 3));
        String solution = c.get("solution").asText();
        assertThat(eval(GameType.SUDOKU, c, "{\"grid\":\"" + solution + "\",\"mistakes\":1}").result()).isEqualTo(Result.SOLVED);
        assertThat(eval(GameType.SUDOKU, c, "{\"grid\":\"" + solution + "\",\"mistakes\":3}").result()).isEqualTo(Result.FAILED);
        char[] broken = solution.toCharArray();
        char tmp = broken[0];
        broken[0] = broken[1];
        broken[1] = tmp;
        assertThat(eval(GameType.SUDOKU, c, "{\"grid\":\"" + new String(broken) + "\"}").result()).isEqualTo(Result.INVALID);
    }

    @Test
    void queensAcceptsSolutionOnly() {
        JsonNode c = M.valueToTree(Queens.generate(Difficulty.EASY, 11));
        assertThat(eval(GameType.QUEENS, c, "{\"queens\":" + c.get("solution") + "}").result()).isEqualTo(Result.SOLVED);
        assertThat(eval(GameType.QUEENS, c, "{\"queens\":[0,0,0,0,0,0,0]}").result()).isEqualTo(Result.INVALID);
    }

    @Test
    void ladderChecksDictionaryAndSteps() {
        JsonNode c = json("{\"start\":\"COLD\",\"target\":\"WARM\",\"par\":4}");
        Evaluation ok = eval(GameType.LADDER, c, "{\"path\":[\"COLD\",\"CORD\",\"CARD\",\"WARD\",\"WARM\"]}");
        assertThat(ok.result()).isEqualTo(Result.SOLVED);
        assertThat(ok.steps()).isEqualTo(4);
        assertThat(eval(GameType.LADDER, c, "{\"path\":[\"COLD\",\"WARM\"]}").result()).isEqualTo(Result.INVALID);
        assertThat(eval(GameType.LADDER, c, "{\"path\":[\"COLD\",\"CXLD\",\"CARD\",\"WARD\",\"WARM\"]}").result()).isEqualTo(Result.INVALID);
    }

    @Test
    void mergeReplaysAndRejectsGarbage() {
        JsonNode c = json("{\"size\":4,\"seed\":42,\"target\":8}");
        assertThat(eval(GameType.MERGE, c, "{\"moves\":\"" + "LURD".repeat(16) + "\"}").result()).isEqualTo(Result.SOLVED);
        assertThat(eval(GameType.MERGE, c, "{\"moves\":\"LXR\"}").result()).isEqualTo(Result.INVALID);
        assertThat(eval(GameType.MERGE, c, "{\"moves\":\"" + "L".repeat(5001) + "\"}").result()).isEqualTo(Result.INVALID);
    }
}

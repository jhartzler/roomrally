# Multiple Correct Answers for Speed Trivia

## Problem

Speed trivia questions currently support only one correct answer. Some questions naturally have multiple valid answers (e.g., "Which of these are fruits?" where 2+ options are correct).

## Design

**Approach:** Replace `correct_answer` (string) with `correct_answers` (jsonb array) on both `trivia_questions` and `trivia_question_instances`.

**Behavior:**
- Players still pick one option per question
- If their pick matches any correct answer, they score full points (same time-decay formula)
- Questions can have 1-4 correct answers (backward compatible with existing single-answer questions)
- During review, all correct answers are highlighted green on stage and player views

## Changes

### Database
- Migration: rename `correct_answer` → `correct_answers` on `trivia_questions` and `trivia_question_instances`
- Data migration wraps existing string values in arrays: `"Strawberry"` → `["Strawberry"]`
- Column type changes from string to jsonb

### Models
- `TriviaQuestion`: validate `correct_answers` is array with 1+ elements, each must be in `options`
- `TriviaQuestionInstance`: same validations, update `correct_answer` references
- `TriviaAnswer#determine_correctness`: `correct_answers.include?(selected_option)`

### Service Layer
- `Games::SpeedTrivia#assign_questions`: copy `correct_answers` array instead of single string
- `Games::SpeedTrivia#submit_answer`: no change needed (delegates to model)

### Views
- Stage reviewing: show all correct answers (not just one)
- Player hand: show all correct answers when player got it wrong
- Vote summary: highlight all correct options green
- Host controls: show all correct answers

### Seed Data
- Update `config/standard_trivia.yml` to use `correct_answers: [...]` format
- Add at least one multi-answer question for testing

### Tests
- Update existing tests for new field name
- Add tests for multi-answer questions (correct if any match, incorrect if none match)
- System test with multi-answer question

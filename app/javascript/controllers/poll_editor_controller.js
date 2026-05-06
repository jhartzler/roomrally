import QuestionListEditorController from "controllers/question_list_editor_controller"

// Thin wrapper for the poll question editor.
// All structural logic (drag/drop, collapse, options) lives in the shared base.
// Poll-specific: no correct answer UI.
export default class extends QuestionListEditorController {
  static targets = [
    "questionList", "questionTemplate", "countDisplay",
    "questionField", "optionField", "positionField", "positionBadge",
    "optionRow", "optionLetter", "optionsContainer", "addOptionButton",
    "collapsibleContent", "collapseAllButton"
  ]
}

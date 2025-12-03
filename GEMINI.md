# OpenJokeMachine

## General Instructions

- Write code in a red/green refactor style when possible. If fixing a problem, write a test first that reproduces the problem, watch it fail, then make it pass. If implementing a new feature or module, first write some general tests, watch them fail, then make them pass. After you make them pass, in a separate step, refactor your code to remove duplication, apply tidyings, and improve design while keeping tests green along the way.
- Tests should follow a pyramid structure of mostly lightweight unit tests, then fewer request specs, and a few key system specs. Do not allow flakey tests to continue and keep the test suite performant.
- Adhere to Rails conventions when possible.
- Adhere to OOP principles such as the law of Demeter, identifying duck types, keeping objects responsible for themselves and not other objects. Consider messages that must be passed and let that influence your solutions.
- Write rubocop compliant code. Code must pass rubocop and rspec before being considered done.

## Running commands
- Use binstubs when available such as bin/rspec and bin/rubocop

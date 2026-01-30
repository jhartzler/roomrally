# OpenJokeMachine

## General Instructions

- You value code correctness and believe that iteratively building a solution is better than coding a lot up front and then verifying. To this end you prefer to write code in a red/green refactor style when possible. If fixing a problem, you like to write a test first that reproduces the problem, watch it fail, then make it pass. If implementing a new feature or module, you first write some general tests, watch them fail, then make them pass. After you make them pass, in a separate step, you then refactor your code to remove duplication, apply tidyings, and improve design while keeping tests green along the way.
- You believe that OOP principles such as the law of Demeter, identifying duck types, keeping objects responsible for themselves and not other objects, leads to a coherent and easily modifiable design. You like to consider messages that must be passed and let that influence your solutions, rather than merely considering the nouns involved.
- You like separating your work into atomic commits - you understand that it is easier to review code when it is divided into small commits each with only 1 concern, each of which atomically passes rubocop and rspec. You dislike large batches of changes that are unrelated to each other. You dislike commits that have multiple concerns, preferring to separate them.
- You understand that keyword args can provide long-term advantages over positional arguments, as they remove important connascences of position by replacing them with connascence of name. You prefer using keyword args where possible.
- You prefer self documenting code to unneeded comments. You dislike wanton, unneeded comments, and prefer tight comments that record why code needs to deviate from standard practice, or limited comments to explain critical sections of code. You allow your code to express itself rather than relying on comments, and you systematically remove comments made to yourself, before committing. 

## Testing
- You believe that tests which follow a pyramid structure of mostly lightweight unit tests, then fewer request specs, and a few key system specs, is best. You hate flakey specs and consider them a showstopper to development. You consider a slow and nonperformant test suite a showstopper to development. If these occur you really want to find the root cause of the flakiness, and solve it permanently going forward. You believe root fixes are better than band aid solutions.
- You like running focused, targeted specs after changes to one module, and then running the whole spec suite after completing one batch of changes.

## Ruby on Rails
- You prefer to follow Rails conventions when possible, unless a specific use case for this app means the conventions are not applicable. To this end you love using RESTful verbs in controllers, creating more specific controllers rather than fewer general ones, and more models to hold business logic (and concerns), rather than resorting to service objects.
- **Controllers should ONLY use standard REST actions**: `index`, `show`, `new`, `create`, `edit`, `update`, `destroy`. Never add custom actions like `start_question` or `close_round`. Instead, create a new, more specific controller. For example, instead of `GamesController#start_question`, create `Games::QuestionsController#create`. This keeps controllers small, focused, and easy to test.
- You love writing rubocop compliant code, except when best practice requires reconfiguring rubocop to fit your needs. You check it with bin/rubocop -P before considering your work done.
  
## Running commands
- Use binstubs when available such as bin/rspec and bin/rubocop

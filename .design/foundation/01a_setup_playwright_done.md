# Ticket 01a: Setup Playwright for System Tests

## Description
Replace the default Selenium with Playwright for running system tests. Playwright is a more modern and reliable choice for controlling browsers.

## Acceptance Criteria
- The `playwright-ruby-client` gem is added to the `Gemfile`.
- Playwright browser binaries are installed.
- RSpec is configured to use Playwright as the driver for system tests.
- A simple system test can be run successfully using Playwright.

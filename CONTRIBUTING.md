# Contributing to Plaza Finance

Thank you for your interest in contributing to Plaza Finance. This guide outlines best practices and coding standards to ensure high-quality contributions.

---

## General Guidelines

- **Be descriptive**: Clearly explain your changes in commit messages and pull requests.
- **Follow the branching strategy**:
  - Use `feature/<short-description>` for new features.
  - Use `fix/<short-description>` for bug fixes.
- **Ensure code quality**:
  - Run linters, formatters, and tests before submitting a pull request.
- **Document your work**:
  - Provide comments and documentation where necessary.

---

## Solidity Development Standards

### Code Style

- Use **Solidity 0.8.x** or later to avoid manual `SafeMath` handling.
- Ensure **consistent naming**:  
  - Functions and variables → `camelCase`
  - Constants → `UPPER_CASE`
  - Contracts and libraries → `PascalCase`
- Avoid unnecessary storage variables—prefer `memory` or `calldata` where possible.
- Use **events** for state changes to improve traceability.
- Use **custom errors** instead of `require` strings to save gas:
  
  ```solidity
  error Unauthorized();
  ```

### Security Best Practices

- Use OpenZeppelin libraries for standard contract implementations.
- Implement access control using `Ownable` or `AccessControl`.
- Always validate external inputs and avoid untrusted external calls.
- Follow the **Checks-Effects-Interactions** pattern to prevent reentrancy.

### Testing

- Ensure 100% test coverage for smart contract changes.
- Write tests using **Foundry’s Forge** framework.
- Use fuzz testing to catch edge cases:
  
  ```solidity
  function testExample(uint256 amount) public {
      vm.assume(amount > 0);
      assertEq(contract.exampleFunction(amount), expectedResult);
  }
  ```

## Rust Development Standards

### Code Style

- Use **Rust 2021 Edition**.
- Follow the Rust API Guidelines and use `rustfmt` for formatting:
  
  ```sh
  cargo fmt --all
  ```

- Use `clippy` for linting:
  
  ```sh
  cargo clippy --all --no-deps
  ```

### Security & Performance

- Use strict type safety and avoid unnecessary `unwrap()` calls.
- Implement unit tests with:
  
  ```sh
  cargo test
  ```

- Optimize for gas efficiency when interfacing with smart contracts.

## Submitting a Pull Request (PR)

1. Fork the Repository
2. Create a New Branch
3. Make Your Changes
4. Run Tests and Format Your Code
5. Commit Your Changes
6. Push Your Changes to GitHub
7. Open a Pull Request

## Reporting Issues

### Check for Existing Issues

- Before opening a new issue, search existing issues to avoid duplicates.

### Open a New Issue

- If no existing issue covers your concern, create a new issue and include:
  - A clear title summarizing the issue.
  - Steps to reproduce (for bugs).
  - Expected vs. actual behavior.
  - Any possible solutions (if applicable).

Thank you for contributing to Plaza Finance.

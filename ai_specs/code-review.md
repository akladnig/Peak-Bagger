Act as a senior software engineer. Review the following code for best practice, logical errors, performance bottlenecks, and duplicate logic.

Context: Language: Flutter, platform: macOs target environment: production, and any known constraints.

Please analyze:
Best Practices: Identify code that does adhere to best practices
Correctness: Identify bugs, edge cases (e.g., null handling, empty inputs), or race conditions.
Consistency: Identify code that 
Performance: Flag inefficient loops (O(n²)), N+1 database queries, or memory leaks.
Maintainability: Find duplicate code that could be consolidated and suggest improvements for naming or modularity.
Security: Check for common vulnerabilities like SQL injection or improper input validation.
Output: Provide findings ranked by severity (Critical, High, Medium, Low) with a brief explanation and a refactored code snippet for each suggested fix."
For Duplicate Code: "Search this code for duplicated logic. Identify all places where this pattern occurs and suggest a single, reusable function or utility class to consolidate it into a single source of truth."
For Performance Optimization: "Profile this code mentally. Identify the top 3 performance bottlenecks and explain the trade-offs (e.g., memory vs. speed) for your suggested optimizations."
